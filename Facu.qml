pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// La facultad en ombu: el anotador rápido (bin/anotar.py entiende «parcial eda jueves 18hs») y la lista
// de entregas y parciales que muestra el Resumen. Lo que tiene fecha va a la agenda (Google Calendar si
// está conectado, así llegan los avisos al celular) con la etiqueta «facu:<tipo>:<materia>»; lo que no
// tiene fecha es una nota en ~/Universidad/<materia>/notas.md.
Singleton {
    id: root

    // Lo que entendió el anotador del texto actual (null = nada escrito)
    property var parsed: null
    property string parsedFor: ""
    property bool saving: false
    // Materias con sus notas: [{id, name, dir, notes, notesPath}]
    property var subjects: []

    function refreshSubjects(): void {
        if (!subjectsProc.running)
            subjectsProc.running = true;
    }

    // Abre las notas de una materia en Zed (crea el archivo si todavía no hay ninguna)
    function openNotes(s: var): void {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && { [ -e \"$1\" ] || printf '# %s\\n\\n' \"$2\" > \"$1\"; } && exec zeditor \"$1\"", "notas", s.notesPath, s.name]);
        Ui.sideOpen = false;
    }

    // Colores por tipo: lo que se rinde en rojo, las entregas en amarillo, las clases en azul
    function kindColor(kind: string): color {
        switch (kind) {
        case "parcial":
        case "recuperatorio":
        case "final":
            return Theme.danger;
        case "entrega":
            return Theme.warn;
        case "clase":
        case "consulta":
            return "#6f9bf0";
        case "nota":
            return Themes.active.border2 ?? Theme.accent;
        default:
            return Theme.accent;
        }
    }

    function kindIcon(kind: string): string {
        switch (kind) {
        case "parcial":
        case "recuperatorio":
        case "final":
            return "quiz";
        case "entrega":
            return "assignment";
        case "clase":
        case "consulta":
            return "school";
        case "nota":
            return "sticky_note_2";
        default:
            return "event";
        }
    }

    // [1440, 180] -> "1 día y 3 h antes"
    function remindersText(list: var): string {
        if (!list || list.length === 0)
            return "";
        const one = m => m === 0 ? "a la hora" : (m % 1440 === 0 ? (m / 1440) + (m === 1440 ? " día" : " días") : (m % 60 === 0 ? (m / 60) + " h" : m + " min"));
        const parts = list.map(one);
        const body = parts.length > 1 ? parts.slice(0, -1).join(", ") + " y " + parts[parts.length - 1] : parts[0];
        return list.length === 1 && list[0] === 0 ? "a la hora" : body + " antes";
    }

    // Tipo de un evento de la agenda: por su etiqueta de ombu o, si lo cargaste en Google a mano, por el título
    function kindOf(it: var): string {
        const tag = it.tag ?? "";
        if (tag.startsWith("facu:"))
            return tag.split(":")[1] || "evento";
        const t = (it.title ?? "").toLowerCase();
        if (/\b(parcial|examen)\b/.test(t))
            return "parcial";
        if (/\brecu(peratorio)?\b/.test(t))
            return "recuperatorio";
        if (/\bfinal\b/.test(t))
            return "final";
        if (/\b(tp\s*\d*|entrega|trabajo pr[aá]ctico)\b/.test(t))
            return "entrega";
        return "";
    }

    // Entregas, parciales, recuperatorios y finales de los próximos 60 días (sin las clases), con los días
    // que faltan. Se recalcula al minuto (Agenda.now) y cuando cambia la agenda.
    readonly property var deadlines: {
        const now = Agenda.now;
        const out = [];
        const hhmm = Qt.formatTime(now, "HH:mm");
        const today = Agenda.ymd(now);
        // Para que dependa de los datos de la agenda
        const _ = [Agenda.google, Agenda.local];
        for (let i = 0; i < 60; i++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, 12);
            const day = Agenda.ymd(d);
            for (const it of Agenda.itemsFor(day, true)) {
                if (it.kind === "holiday" || it.done)
                    continue;
                const kind = kindOf(it);
                if (!["parcial", "recuperatorio", "final", "entrega"].includes(kind))
                    continue;
                if (day === today && it.time && it.time < hhmm)
                    continue;
                out.push({
                    day: day,
                    daysLeft: i,
                    time: it.time ?? "",
                    title: it.title,
                    kind: kind
                });
            }
        }
        return out;
    }

    // "hoy", "mañana", "en 5 días"
    function leftText(n: int): string {
        return n === 0 ? "hoy" : (n === 1 ? "mañana" : "en " + n + " días");
    }

    function parse(text: string): void {
        text = text.trim();
        if (text === "") {
            parsed = null;
            parsedFor = "";
            return;
        }
        parseTimer.pending = text;
        parseTimer.restart();
    }

    // Guarda lo que entendió: en la agenda o como nota. family = también en el calendario familiar.
    // done(mensaje de error o "") al terminar.
    function save(p: var, family: bool, done: var): void {
        if (!p || saving)
            return;
        if (p.isNote) {
            saving = true;
            noteProc.done = done;
            noteProc.command = [Quickshell.shellPath("bin/anotar.py"), "note", p.detail || p.title].concat(p.subject ? ["--subject", p.subject.id] : []);
            noteProc.running = true;
            return;
        }
        if (p.date === "") {
            if (done)
                done("Falta el día");
            return;
        }
        saving = true;
        const extra = {
            tag: p.tag,
            note: "Anotado con ombu",
            done: r => {
                root.saving = false;
                if (done)
                    done(r?.error ?? "");
            }
        };
        if (family && Agenda.familyCalendarId !== "")
            extra.calendar = Agenda.familyCalendarId;
        Agenda.add(p.date, p.time, p.title, "", p.reminders, extra);
    }

    Timer {
        id: parseTimer

        property string pending

        interval: 120
        onTriggered: {
            parseProc.input = pending;
            parseProc.command = [Quickshell.shellPath("bin/anotar.py"), "parse", pending];
            parseProc.running = true;
        }
    }

    Process {
        id: parseProc

        property string input

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parsed = JSON.parse(text);
                    root.parsedFor = parseProc.input;
                } catch (e) {}
            }
        }
    }

    Process {
        id: noteProc

        property var done

        stdout: StdioCollector {
            onStreamFinished: {
                root.saving = false;
                let err = "";
                try {
                    err = JSON.parse(text).error ?? "";
                } catch (e) {
                    err = "No se pudo guardar la nota";
                }
                root.refreshSubjects();
                if (noteProc.done)
                    noteProc.done(err);
            }
        }
    }

    Process {
        id: subjectsProc

        command: [Quickshell.shellPath("bin/anotar.py"), "subjects"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.subjects = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: refreshSubjects()
}
