pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

// Luz nocturna: entibia la pantalla de noche con hyprsunset, que cambia la matriz de color de Hyprland
// (por eso las capturas no lo muestran). Va sola de startMinute a endMinute; el interruptor manual vale
// hasta el próximo cambio de tramo, como en macOS. Se guarda en ~/.local/share/ombu/nocturna.json.
//   qs -c ombu ipc call night toggle|on|off|auto|temp <K>|status
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/nocturna.json"
    readonly property int neutral: 6500

    property bool auto: true
    property int temperature: 4000
    property int startMinute: 20 * 60
    property int endMinute: 7 * 60
    // null = sigue el horario; true/false = elegido a mano, hasta que cambie el tramo (manualNight)
    property var manual: null
    property bool manualNight: false

    readonly property bool night: {
        const d = Chrono.date;
        const m = d.getHours() * 60 + d.getMinutes();
        return Logic.inRange(m, startMinute, endMinute);
    }
    readonly property bool active: manual !== null ? manual : (auto && night)
    // «Hasta las 7:00», «Desde las 20:00»... para el centro de control
    readonly property string hint: {
        const hhmm = m => Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0");
        if (active)
            return manual !== null && !night ? "Activada" : "Hasta " + hhmm(endMinute);
        if (manual === false && night)
            return "Apagada por hoy";
        return auto ? "Desde " + hhmm(startMinute) : "Apagada";
    }

    readonly property string scheduleText: {
        const hhmm = m => Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0");
        return "De " + hhmm(startMinute) + " a " + hhmm(endMinute);
    }

    function setAuto(on: bool): void {
        auto = on;
        manual = null;
        save();
    }

    function toggle(): void {
        set(!active);
    }

    function set(on: bool): void {
        manual = on;
        manualNight = night;
        save();
    }

    function followSchedule(): void {
        manual = null;
        auto = true;
        save();
    }

    function setTemperature(k: int): void {
        temperature = Math.max(2500, Math.min(6000, k));
        save();
    }

    function save(): void {
        file.setText(JSON.stringify({
            auto: auto,
            temperature: temperature,
            start: startMinute,
            end: endMinute,
            manual: manual,
            manualNight: manualNight
        }));
    }

    // Al cambiar de tramo (anochece o amanece) vuelve a mandar el horario
    onNightChanged: if (manual !== null && night !== manualNight) {
        manual = null;
        save();
    }

    // Temperatura que tiene la pantalla ahora; la transición la acerca de a pasos a la que corresponde
    property int shown: neutral
    readonly property int target: active ? temperature : neutral
    property bool ready: false

    onTargetChanged: if (ready)
        ensure.running = true

    function send(k: int): void {
        Quickshell.execDetached(k >= neutral ? ["hyprctl", "hyprsunset", "identity"] : ["hyprctl", "hyprsunset", "temperature", String(k)]);
    }

    Component.onCompleted: {
        try {
            const s = JSON.parse(file.text());
            auto = s.auto ?? true;
            temperature = s.temperature ?? 4000;
            startMinute = s.start ?? startMinute;
            endMinute = s.end ?? endMinute;
            manualNight = s.manualNight ?? false;
            // Si mientras ombu no corría cambió el tramo, lo manual ya no vale
            manual = (s.manual === true || s.manual === false) && manualNight === night ? s.manual : null;
        } catch (e) {}
        // Al arrancar (o recargar) se aplica directo, sin transición: la pantalla puede estar ya cálida
        shown = target;
        ready = true;
        ensure.running = true;
    }

    FileView {
        id: file

        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    // hyprsunset tiene que estar corriendo para recibir órdenes: si no está, se lanza aparte (sobrevive
    // a las recargas de ombu) y se le da un segundo para abrir su socket
    Process {
        id: ensure

        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null || { setsid -f hyprsunset -i >/dev/null 2>&1; sleep 1; }"]
        onExited: {
            if (root.shown === root.target)
                root.send(root.shown);
            else
                fade.start();
        }
    }

    // Unos 0,8 s de un extremo al otro, en pasos de 250 K
    Timer {
        id: fade

        interval: 80
        repeat: true
        onTriggered: {
            const d = root.target - root.shown;
            root.shown += Math.sign(d) * Math.min(Math.abs(d), 250);
            root.send(root.shown);
            if (root.shown === root.target)
                stop();
        }
    }
}
