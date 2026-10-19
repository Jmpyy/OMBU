pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Datos del Resumen del panel lateral (tu estación personal): nombre, clima, dólar y proyectos. Todo lo
// trae bin/estacion.py y solo cuando se abre el panel; al iniciar se lee la copia del disco (sin red).
// Los datos personales salen de ~/.local/share/ombu/estacion.json:
//   {"nombre": "Juampy", "ciudad": "", "meta": 120}    (ciudad vacía = la deduce wttr.in por la IP;
//   meta = minutos de estudio por día)
Singleton {
    id: root

    property string name: ""
    property string city: ""
    property int goal: 120

    // Última copia de red: {updated, weather, dolar, error}
    property var net: ({})
    property bool loading: false
    // Repos y facultad, lo más reciente primero: [{name, when, subject, dirty}]
    property var projects: []

    readonly property var weather: net.weather ?? null
    readonly property var dolar: net.dolar ?? null

    readonly property string displayName: {
        if (name !== "")
            return name;
        const u = Quickshell.env("USER") ?? "";
        return u.charAt(0).toUpperCase() + u.slice(1);
    }

    function greeting(date: date): string {
        const h = date.getHours();
        return h < 6 ? "Buenas noches" : h < 13 ? "Buen día" : h < 20 ? "Buenas tardes" : "Buenas noches";
    }

    function money(n: real): string {
        return "$" + Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    }

    function readConfig(): void {
        try {
            const c = JSON.parse(configFile.text() || "{}");
            name = c.nombre ?? "";
            city = c.ciudad ?? "";
            goal = Math.max(10, Number(c.meta ?? 120));
        } catch (e) {}
    }

    // Se llama al abrir el panel: la red solo si la copia tiene más de 30 minutos
    function load(): void {
        if (!loading && !(net.updated > 0 && Date.now() - net.updated * 1000 < 30 * 60000)) {
            loading = true;
            netProc.command = [Quickshell.shellPath("bin/estacion.py"), "net"].concat(city !== "" ? ["--city", city] : []);
            netProc.running = true;
        }
        projProc.running = false;
        projProc.running = true;
    }

    FileView {
        id: configFile

        path: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/estacion.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.readConfig();
        }
        Component.onCompleted: root.readConfig()
    }

    // La copia guardada, sin importar su edad: solo si todavía no hay nada más nuevo
    Process {
        running: true
        command: [Quickshell.shellPath("bin/estacion.py"), "net", "--cached"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (!(root.net.updated > 0))
                        root.net = r;
                } catch (e) {}
            }
        }
    }

    Process {
        id: netProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    root.net = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: projProc

        command: [Quickshell.shellPath("bin/estacion.py"), "proyectos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.projects = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
}
