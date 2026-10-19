pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Noticias del panel lateral. Solo baja algo cuando se las pide (bin/rss.py, que además guarda una
// copia de 15 minutos): con el panel cerrado no hay ninguna consulta de fondo. Al iniciar lee la copia
// del disco (sin red), así que el panel muestra algo al instante y se actualiza por detrás.
Singleton {
    id: root

    // [{id, name, items: [{title, link, source, time}]}]
    property var categories: []
    property real updated: 0
    property bool loading: false
    property string error: ""

    // Titulares que ya abriste (por su dirección). Solo vive mientras el shell: se apagan en la lista.
    property var seen: ({})

    function markSeen(link: string): void {
        seen = Object.assign({}, seen, {
            [link]: true
        });
    }

    // Todas juntas, lo más nuevo primero (para la pestaña «Todo»)
    readonly property var all: {
        const out = [];
        for (const c of categories)
            for (const it of c.items)
                out.push(Object.assign({}, it, {
                    category: c.name,
                    categoryId: c.id
                }));
        return out.sort((a, b) => b.time - a.time).slice(0, 40);
    }

    function load(force: bool): void {
        if (loading)
            return;
        if (!force && updated > 0 && Date.now() - updated * 1000 < 15 * 60000)
            return;
        loading = true;
        proc.command = [Quickshell.shellPath("bin/rss.py")].concat(force ? ["--refresh"] : []);
        proc.running = true;
    }

    // La copia guardada, sin importar su edad: solo se usa si todavía no hay nada más nuevo
    Process {
        id: cacheProc

        running: true
        command: [Quickshell.shellPath("bin/rss.py"), "--cached"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (root.updated === 0 && (r.categories ?? []).length > 0) {
                        root.categories = r.categories;
                        root.updated = r.updated ?? 0;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const r = JSON.parse(text);
                    // Una respuesta vacía no borra lo que ya se estaba mostrando
                    if ((r.categories ?? []).some(c => c.items.length > 0) || root.categories.length === 0) {
                        root.categories = r.categories ?? [];
                        root.updated = r.updated ?? 0;
                    }
                    root.error = r.error ?? "";
                } catch (e) {
                    root.error = "No se pudieron leer las noticias";
                }
            }
        }
    }
}
