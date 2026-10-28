import QtQuick
import QtQuick.Layouts
import Quickshell

// Modo foco, a la manera de macOS: modo, temporizador (el anillo y el botón principal son lo único en
// color), entorno de estudio, el día y la semana, y un cajón de ideas; los grupos se separan con líneas
// finas, sin cajas.
DropPopup {
    id: root

    // Botón de texto chico (pausar el bloqueo): con borde, rojo si es peligroso
    component Pill: Rectangle {
        id: pill

        property string text
        property bool danger: false

        signal clicked

        implicitHeight: 26
        implicitWidth: label.implicitWidth + 20
        radius: Theme.controlRadius - 3
        color: area.containsMouse ? Theme.hover : "transparent"
        border.width: 1
        border.color: danger ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.5) : Theme.border

        Text {
            id: label

            anchors.centerIn: parent
            text: pill.text
            color: pill.danger ? Theme.danger : Theme.text
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // Mostrar la lista de ideas guardadas
    property bool showIdeas: false

    bodyWidth: 320
    bodyHeight: column.implicitHeight + 16

    ColumnLayout {
        id: column

        x: 8
        y: 6
        width: root.bodyWidth - 16
        spacing: 2

        // Modo
        Segmented {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            current: Focus.mode
            model: [
                {
                    id: "estudio",
                    name: "Estudio"
                },
                {
                    id: "trabajo",
                    name: "Trabajo"
                },
                {
                    id: "libre",
                    name: "Libre"
                }
            ]
            onPicked: id => Focus.setMode(id)
        }

        // Temporizador
        FocusRing {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            title: Focus.mode === "libre" ? "Modo libre" : Focus.phaseName
            time: Focus.clock(Focus.remaining)
            active: Focus.running
            dim: Focus.mode === "libre"
            progress: Focus.mode === "libre" ? 0 : 1 - Focus.remaining / Focus.lengthOf(Focus.phase)
        }

        // Controles
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            Layout.bottomMargin: 6
            spacing: 14

            RoundButton {
                icon: "stop"
                enabled: Focus.running || Focus.remaining !== Focus.lengthOf(Focus.phase)
                onClicked: Focus.stop()
            }

            RoundButton {
                primary: true
                icon: Focus.running ? "pause" : "play_arrow"
                onClicked: Focus.running ? Focus.pause() : Focus.start()
            }

            RoundButton {
                icon: "skip_next"
                enabled: Focus.running
                onClicked: Focus.next(false)
            }
        }

        // Aviso del bloqueo y salida con fricción
        MenuRow {
            visible: Focus.mode === "estudio" && Focus.running && Focus.phase === "estudio"
            icon: Focus.blocking ? "block" : "lock_open"
            text: Focus.blocking ? "Juegos y redes bloqueados" : "Bloqueo pausado"
            color: "transparent"

            Pill {
                visible: Focus.blocking
                text: Focus.unlockLeft > 0 ? "Esperá " + Focus.unlockLeft + " s · cancelar" : "Pausar"
                danger: true
                onClicked: Focus.unlockLeft > 0 ? Focus.cancelUnlock() : Focus.requestUnlock()
            }
        }

        // Entorno de estudio: qué toca hoy y las herramientas para abrir a mano
        MenuSeparator {
            visible: Focus.mode !== "trabajo"
        }

        MenuSection {
            visible: Focus.mode !== "trabajo"
            text: "Entorno de estudio"
        }

        Segmented {
            visible: Focus.mode !== "trabajo"
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            current: Focus.kit
            model: Focus.kits
            onPicked: id => Focus.setKit(id)
        }

        Repeater {
            model: Focus.mode !== "trabajo" ? [
                {
                    tool: "notebook",
                    icon: "menu_book",
                    name: "Abrir NotebookLM"
                },
                {
                    tool: "ide",
                    icon: "code",
                    name: "Abrir el editor"
                },
                {
                    tool: "ai",
                    icon: "terminal",
                    name: "Abrir Antigravity"
                }
            ] : []

            MenuRow {
                required property var modelData

                icon: modelData.icon
                text: modelData.name
                onClicked: Focus.openTool(modelData.tool)
            }
        }

        MenuRow {
            visible: Focus.mode !== "trabajo"
            icon: "auto_awesome"
            text: "Abrir mi entorno al empezar"
            onClicked: Focus.toggleAutoOpen()

            ToggleSwitch {
                on: Focus.autoOpen
                onToggled: Focus.toggleAutoOpen()
            }
        }

        // El día y la semana (minutos de Focus.history; hoy en color)
        MenuSeparator {}

        MenuSection {
            text: "Hoy"
            detail: Focus.minutesText(Focus.studyToday) + " · " + Focus.cycles + (Focus.cycles === 1 ? " bloque" : " bloques") + " · racha de " + Focus.streak + (Focus.streak === 1 ? " día" : " días")
        }

        ColumnLayout {
            id: weekBox

            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.topMargin: 2
            spacing: 4

            readonly property var days: {
                const out = [];
                const now = new Date();
                let total = 0;
                let max = 30;
                for (let i = 6; i >= 0; i--) {
                    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i, 12);
                    const key = Qt.formatDate(d, "yyyy-MM-dd");
                    const m = Focus.history[key] ?? 0;
                    total += m;
                    max = Math.max(max, m);
                    out.push({
                        label: Qt.locale("es_AR").dayName(d.getDay(), Locale.ShortFormat).charAt(0).toUpperCase(),
                        minutes: m,
                        today: i === 0
                    });
                }
                return {
                    list: out,
                    total: total,
                    max: max
                };
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                spacing: 6

                Repeater {
                    model: weekBox.days.list

                    Item {
                        id: bar

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: dayLabel.top
                            anchors.bottomMargin: 3
                            width: Math.min(parent.width, 22)
                            height: bar.modelData.minutes > 0 ? Math.max(4, (parent.height - 18) * bar.modelData.minutes / weekBox.days.max) : 3
                            radius: 3
                            color: bar.modelData.minutes === 0 ? Theme.track : (bar.modelData.today ? Theme.accent : Qt.rgba(1, 1, 1, 0.35))
                        }

                        Text {
                            id: dayLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: bar.modelData.label
                            color: bar.modelData.today ? Theme.text : Theme.textDim
                            font.pixelSize: Theme.fontTiny
                            font.weight: bar.modelData.today ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignRight
                text: weekBox.days.total > 0 ? "Semana: " + Focus.minutesText(weekBox.days.total * 60) : "Sin datos esta semana"
                color: Theme.textDim
                font.pixelSize: Theme.fontCaption
            }
        }

        // Cajón de ideas: anotar y seguir
        MenuSeparator {}

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            implicitHeight: 32
            radius: Theme.controlRadius - 3
            color: Theme.surface
            border.width: idea.activeFocus ? 1 : 0
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 8

                MIcon {
                    name: "lightbulb"
                    color: Theme.textDim
                    font.pixelSize: Theme.iconSm
                }

                TextInput {
                    id: idea

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.pixelSize: Theme.fontBody
                    clip: true
                    onAccepted: {
                        Focus.saveIdea(text);
                        text = "";
                        savedNote.opacity = 1;
                        savedTimer.restart();
                    }

                    // Texto de ayuda; tras guardar, confirma unos segundos
                    Text {
                        visible: idea.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: savedNote.opacity > 0 ? "✓ Guardada en tus ideas" : "Anotar una idea y seguir"
                        color: savedNote.opacity > 0 ? Theme.accent : Theme.textDim
                        font.pixelSize: Theme.fontBody
                    }
                }

                // Ver las ideas guardadas
                Rectangle {
                    visible: Focus.ideas.length > 0
                    Layout.preferredWidth: countText.implicitWidth + 14
                    Layout.preferredHeight: 22
                    radius: 6
                    color: root.showIdeas || countArea.containsMouse ? Theme.hover : "transparent"

                    Text {
                        id: countText

                        anchors.centerIn: parent
                        text: Focus.ideas.length + (root.showIdeas ? " ▴" : " ▾")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: countArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showIdeas = !root.showIdeas
                    }
                }

                // Solo guarda el estado de "recién guardada"; el aviso se muestra en el campo
                Item {
                    id: savedNote

                    opacity: 0

                    Timer {
                        id: savedTimer

                        interval: 2500
                        onTriggered: savedNote.opacity = 0
                    }
                }
            }
        }

        // Ideas guardadas: las más nuevas arriba; la X de cada una la borra
        ListView {
            id: ideaList

            visible: root.showIdeas && Focus.ideas.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.preferredHeight: Math.min(contentHeight, 196)
            clip: true
            spacing: 0
            model: Focus.ideas
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: ideaRow

                required property var modelData

                width: ListView.view.width
                height: ideaText.implicitHeight + 14
                radius: Theme.controlRadius - 3
                color: rowHover.hovered ? Theme.surface : "transparent"

                HoverHandler {
                    id: rowHover
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 8

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            id: ideaText

                            width: parent.width
                            text: ideaRow.modelData.text
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: Theme.fontBody
                        }

                        Text {
                            visible: ideaRow.modelData.date !== ""
                            text: ideaRow.modelData.date.slice(8, 10) + "/" + ideaRow.modelData.date.slice(5, 7) + " " + ideaRow.modelData.time
                            color: Theme.textDim
                            font.pixelSize: Theme.fontTiny
                        }
                    }

                    MIcon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        opacity: rowHover.hovered ? 1 : 0
                        name: "close"
                        font.pixelSize: Theme.iconSm
                        color: Theme.textDim

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Focus.deleteIdea(ideaRow.modelData.line)
                        }
                    }
                }
            }
        }
    }
}
