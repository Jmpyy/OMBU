import QtQuick
import QtQuick.Layouts

// Tarjeta «Ahora» del Resumen: lo próximo de la agenda con cuánto falta y, si hay un bloque de foco en
// marcha o en pausa, cómo va.
ComicCard {
    id: root

    // Lo de esta semana (más lejos no es «ahora»); los pagos no, tienen su tarjeta
    readonly property var next: Agenda.upcoming(12).find(x => !x.tag.startsWith("sub:") && Agenda.parseDay(x.day) - Agenda.now < 7 * 86400000) ?? null
    // En marcha, o un bloque de estudio empezado y en pausa
    readonly property bool focusOn: Focus.running || (Focus.phase === "estudio" && Focus.remaining < Focus.studyLength)
    readonly property int focusLeft: Focus.running ? Math.max(0, Math.round((Focus.endsAt - Focus.nowMs) / 1000)) : Focus.remaining

    // "en 2 h 15 min", "hoy", "mañana", "en 5 días"
    function countdown(it: var): string {
        const now = Agenda.now;
        const days = Math.round((Agenda.parseDay(it.day) - Agenda.parseDay(Agenda.ymd(now))) / 86400000);
        if (days === 0 && it.time) {
            const [h, m] = it.time.split(":").map(Number);
            const mins = h * 60 + m - (now.getHours() * 60 + now.getMinutes());
            if (mins <= 0)
                return "ahora";
            return mins < 60 ? "en " + mins + " min" : "en " + Math.floor(mins / 60) + " h" + (mins % 60 ? " " + (mins % 60) + " min" : "");
        }
        return Facu.leftText(days);
    }

    title: "Ahora"
    tint: Theme.accent

    // Lo próximo
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Theme.controlRadius
            color: Qt.rgba(ic.color.r, ic.color.g, ic.color.b, 0.16)

            MIcon {
                id: ic

                anchors.centerIn: parent
                name: root.next ? Facu.kindIcon(Facu.kindOf(root.next) || "evento") : "event_available"
                color: root.next ? Facu.kindColor(Facu.kindOf(root.next) || "evento") : Theme.textDim
                font.pixelSize: 20
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.next ? root.next.title : (Agenda.googleLoading ? "Cargando agenda…" : "Nada en la agenda")
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: root.next ? Chrono.capitalize(Agenda.parseDay(root.next.day).toLocaleDateString(Chrono.locale, "dddd d/M")) + (root.next.time ? " · " + root.next.time : "") : "Buen momento para adelantar algo"
                elide: Text.ElideRight
                color: Theme.textDim
                font.pixelSize: 12
            }
        }

        Text {
            visible: root.next !== null
            text: root.next ? root.countdown(root.next) : ""
            color: Theme.accent
            font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
            font.pixelSize: Theme.comic ? 18 : 13
            font.letterSpacing: Theme.comic ? 1 : 0
            font.weight: Theme.comic ? Font.Normal : Font.DemiBold
        }
    }

    // Bloque de foco
    RowLayout {
        visible: root.focusOn
        Layout.fillWidth: true
        spacing: 8

        MIcon {
            name: Focus.phase === "estudio" ? "target" : "coffee"
            font.pixelSize: 16
            color: Focus.phase === "estudio" ? "#6f9bf0" : Theme.textDim
        }

        Text {
            Layout.fillWidth: true
            text: (Focus.phase === "estudio" ? "Bloque de " + Focus.mode : "Descanso") + (Focus.running ? "" : " · en pausa")
            elide: Text.ElideRight
            color: Theme.text
            font.pixelSize: 12
        }

        Text {
            text: Math.floor(root.focusLeft / 60) + ":" + String(root.focusLeft % 60).padStart(2, "0")
            color: Theme.textDim
            font.pixelSize: 12
            font.family: "monospace"
        }
    }
}
