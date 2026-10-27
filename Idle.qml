pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Inactividad: a los idleLockSeconds se bloquea la sesión (con el salvapantallas a la
// vista) y a los idleScreenOffSeconds se apagan los monitores. IdleMonitor respeta las
// pausas que piden los reproductores de video, así que no bloquea mientras mirás uno.
Singleton {
    id: root

    property int lockSeconds: Theme.idleLockSeconds
    property int screenOffSeconds: Theme.idleScreenOffSeconds

    // Modo de prueba: en lugar de bloquear de verdad abre la vista previa (se cierra sola
    // con Esc) y no apaga los monitores, solo lo anota en el log.
    property bool testMode: false
    // El bloqueo actual lo causó la inactividad (el salvapantallas arranca a la vista)
    property bool lockedByIdle: false
    property bool screensOff: false

    // Los detectores no se vuelven a armar si se les cambia el tiempo estando activos: hay que
    // apagarlos y encenderlos (rearm). Solo hace falta al cambiar los tiempos en marcha (pruebas).
    property bool monitorsOn: true

    // Pedidos de «no bloquees» de los videos: Zen/Firefox los mandan por org.freedesktop.ScreenSaver, que
    // en Hyprland no atendía nadie, y ombu bloqueaba a los 5 minutos aunque estuvieras mirando un video.
    // Los atiende bin/screensaver.py (corre aparte, así no pierde los pedidos cuando ombu se recarga) y
    // escribe el estado en ombu-inhibit.json. Si ese proceso muriera, el archivo deja de actualizarse y a
    // los 3 minutos se deja de respetar: un pedido colgado nunca puede dejar la sesión sin bloquear.
    property var inhibitApps: []
    property double inhibitAt: 0
    property double nowSec: Date.now() / 1000
    readonly property bool inhibited: !testMode && inhibitApps.length > 0 && nowSec - inhibitAt < 180

    function readInhibit(): void {
        try {
            const d = JSON.parse(inhibitFile.text());
            inhibitApps = Array.isArray(d.apps) ? d.apps : [];
            inhibitAt = Number(d.at ?? 0);
        } catch (e) {
            inhibitApps = [];
        }
        nowSec = Date.now() / 1000;
    }

    // Para depurar (ipc call idle status)
    function describe(): string {
        return (inhibited ? "no bloquea: lo pide " + inhibitApps.join(", ") : "bloquea a los " + lockSeconds + " s sin actividad") + (testMode ? " (modo prueba)" : "");
    }

    FileView {
        id: inhibitFile

        path: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/ombu-inhibit.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readInhibit()
    }

    // El archivo lo crea el servicio al arrancar: se vuelve a leer un momento después por si no existía
    Timer {
        interval: 2500
        running: true
        onTriggered: inhibitFile.reload()
    }

    // Mientras hay un pedido, se revisa que siga fresco (el servicio reescribe la hora cada minuto)
    Timer {
        interval: 60000
        repeat: true
        running: root.inhibitApps.length > 0
        onTriggered: root.nowSec = Date.now() / 1000
    }

    onInhibitedChanged: console.log("ombu: " + (inhibited ? "no se bloquea, lo pide " + inhibitApps.join(", ") : "vuelve el bloqueo por inactividad"))

    // Basta con nombrarlo desde shell.qml para que exista. Arranca el servicio de pedidos (si ya corre
    // uno, el nuevo sale solo)
    function start(): void {
        Quickshell.execDetached(["python3", "-I", Quickshell.shellPath("bin/screensaver.py")]);
    }

    function rearm(): void {
        monitorsOn = false;
        Qt.callLater(() => root.monitorsOn = true);
    }

    function lockNow(): void {
        // La vista previa también pone Ui.locked, pero se cierra con Esc: si quedó abierta y te fuiste,
        // se pasa a un bloqueo de verdad (antes la sesión quedaba abierta para siempre)
        if (Ui.locked && (!Ui.lockPreview || testMode))
            return;
        console.log("ombu: inactividad, bloqueando" + (testMode ? " (prueba, vista previa)" : (Ui.locked ? " (había una vista previa abierta)" : "")));
        lockedByIdle = true;
        Ui.lockPreview = testMode;
        Ui.locked = true;
    }

    function setScreens(on: bool): void {
        if (testMode) {
            console.log("ombu: (prueba) monitores " + (on ? "encendidos" : "apagados"));
            return;
        }
        // Nunca se apagan los monitores de una sesión que no esté bloqueada
        if (!on && !Ui.locked)
            return;
        if (on && !screensOff)
            return;
        screensOff = !on;
        console.log("ombu: monitores " + (on ? "encendidos" : "apagados"));
        // El formato con tabla es obligatorio: dpms("on") alterna en vez de encender
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "' + (on ? "on" : "off") + '" })']);
    }

    IdleMonitor {
        enabled: root.monitorsOn && !root.inhibited
        timeout: root.lockSeconds
        // En uso normal respeta los pedidos de "no bloquear" de los reproductores de video;
        // el modo de prueba los ignora para poder verificar la detección
        respectInhibitors: !root.testMode
        onIsIdleChanged: {
            if (isIdle)
                root.lockNow();
        }
    }

    IdleMonitor {
        enabled: root.monitorsOn && !root.inhibited
        timeout: root.screenOffSeconds
        respectInhibitors: !root.testMode
        onIsIdleChanged: root.setScreens(!isIdle)
    }

    Connections {
        target: Ui

        function onLockedChanged(): void {
            if (!Ui.locked)
                root.lockedByIdle = false;
        }
    }
}
