import QtQuick
import QtQuick.Layouts
import Quickshell

// Modo foco: modo, temporizador de estudio y descanso, estadística del día y un cajón de ideas.
DropPopup {
    id: root

    // Botón redondeado de texto: lleno para lo principal, con borde para lo demás
    component Pill: Rectangle {
        id: pill

        property string text
        property bool filled: false
        property bool selected: false
        property bool danger: false
        property bool enabled: true

        signal clicked

        implicitHeight: 32
        implicitWidth: label.implicitWidth + 28
        radius: height / 2
        opacity: enabled ? 1 : 0.45
        color: filled ? (area.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent) : (selected ? Theme.surface : (area.containsMouse && enabled ? Theme.hover : "transparent"))
        border.width: filled ? 0 : 1
        border.color: selected ? Theme.accent : (danger ? Theme.danger : Theme.border)

        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }

        Text {
            id: label

            anchors.centerIn: parent
            text: pill.text
            color: pill.filled ? "#14131a" : (pill.selected ? Theme.text : (pill.danger ? Theme.danger : Theme.textDim))
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pill.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (pill.enabled)
                pill.clicked()
        }
    }

    // Mostrar la lista de ideas guardadas
    property bool showIdeas: false

    bodyWidth: 340
    bodyHeight: column.implicitHeight + 26

    ColumnLayout {
        id: column

        x: 16
        y: 2
        width: root.bodyWidth - 32
        spacing: 14

        // Modo
        Segmented {
            Layout.fillWidth: true
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
            title: Focus.mode === "libre" ? "Modo libre" : Focus.phaseName
            time: Focus.clock(Focus.remaining)
            active: Focus.running
            dim: Focus.mode === "libre"
            progress: Focus.mode === "libre" ? 0 : 1 - Focus.remaining / Focus.lengthOf(Focus.phase)
        }

        // Controles
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
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

        // Entorno de estudio: qué toca hoy y las herramientas para abrir a mano
        ColumnLayout {
            visible: Focus.mode !== "trabajo"
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "ENTORNO DE ESTUDIO"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Segmented {
                Layout.fillWidth: true
                current: Focus.kit
                model: Focus.kits
                onPicked: id => Focus.setKit(id)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        {
                            tool: "notebook",
                            icon: "menu_book",
                            name: "NotebookLM"
                        },
                        {
                            tool: "ide",
                            icon: "code",
                            name: "Editor"
                        },
                        {
                            tool: "ai",
                            icon: "terminal",
                            name: "Antigravity"
                        }
                    ]

                    Rectangle {
                        id: toolTile

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 54
                        radius: Theme.controlRadius
                        color: toolArea.containsMouse ? Theme.hover : Theme.surface

                        Behavior on color {
                            ColorAnimation {
                                duration: 90
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            MIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: toolTile.modelData.icon
                                font.pixelSize: 22
                                color: Theme.text
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: toolTile.modelData.name
                                color: Theme.textDim
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: toolArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Focus.openTool(toolTile.modelData.tool)
                        }
                    }
                }
            }

            // Interruptor: abrir el entorno solo al empezar a estudiar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Theme.controlRadius
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        Layout.fillWidth: true
                        text: "Abrir mi entorno al empezar"
                        color: Theme.text
                        font.pixelSize: 13
                    }

                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 22
                        radius: 11
                        color: Focus.autoOpen ? Theme.accent : Theme.track

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Rectangle {
                            x: Focus.autoOpen ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: Focus.autoOpen ? "#14131a" : Theme.text

                            Behavior on x {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Focus.toggleAutoOpen()
                }
            }
        }

        // Estadística del día
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        value: Focus.minutesText(Focus.studyToday),
                        caption: "hoy"
                    },
                    {
                        value: String(Focus.cycles),
                        caption: Focus.cycles === 1 ? "bloque" : "bloques"
                    },
                    {
                        value: String(Focus.streak),
                        caption: Focus.streak === 1 ? "día de racha" : "días de racha"
                    }
                ]

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Theme.controlRadius
                    color: Theme.surface

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.value
                            color: Theme.text
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.caption
                            color: Theme.textDim
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        // Minutos de los últimos 7 días (de Focus.history); hoy en violeta
        ColumnLayout {
            id: weekBox

            Layout.fillWidth: true
            spacing: 6

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

                Text {
                    text: "ÚLTIMOS 7 DÍAS"
                    color: Theme.textDim
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: weekBox.days.total > 0 ? Focus.minutesText(weekBox.days.total * 60) : "Sin datos"
                    color: Theme.textDim
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
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
                            width: Math.min(parent.width, 26)
                            height: bar.modelData.minutes > 0 ? Math.max(4, (parent.height - 18) * bar.modelData.minutes / weekBox.days.max) : 3
                            radius: 4
                            color: bar.modelData.minutes === 0 ? Theme.track : (bar.modelData.today ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45))
                        }

                        Text {
                            id: dayLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: bar.modelData.label
                            color: bar.modelData.today ? Theme.text : Theme.textDim
                            font.pixelSize: 10
                            font.weight: bar.modelData.today ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }

        // Aviso del bloqueo y salida con fricción
        Rectangle {
            visible: Focus.mode === "estudio" && Focus.running && Focus.phase === "estudio"
            Layout.fillWidth: true
            implicitHeight: lockRow.implicitHeight + 20
            radius: Theme.controlRadius
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)

            RowLayout {
                id: lockRow

                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                MIcon {
                    name: Focus.blocking ? "block" : "lock_open"
                    color: Theme.accent
                    font.pixelSize: 18
                }

                Text {
                    Layout.fillWidth: true
                    text: Focus.blocking ? "Juegos y redes bloqueados mientras estudiás" : "Bloqueo pausado"
                    wrapMode: Text.Wrap
                    color: Theme.text
                    font.pixelSize: 12
                }

                Pill {
                    visible: Focus.blocking
                    implicitHeight: 28
                    text: Focus.unlockLeft > 0 ? "Esperá " + Focus.unlockLeft + " s · cancelar" : "Pausar bloqueo"
                    danger: true
                    onClicked: Focus.unlockLeft > 0 ? Focus.cancelUnlock() : Focus.requestUnlock()
                }
            }
        }

        // Cajón de ideas: anotar y seguir
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.controlRadius
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                MIcon {
                    name: "lightbulb"
                    color: Theme.textDim
                    font.pixelSize: 17
                }

                TextInput {
                    id: idea

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: "#14131a"
                    font.pixelSize: 13
                    clip: true
                    onAccepted: {
                        Focus.saveIdea(text);
                        text = "";
                        savedNote.opacity = 1;
                        savedTimer.restart();
                    }

                    // Texto de ayuda; tras guardar, confirma en violeta unos segundos
                    Text {
                        visible: idea.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: savedNote.opacity > 0 ? "✓ Guardada en tus ideas" : "Anotar una idea y seguir (Enter)"
                        color: savedNote.opacity > 0 ? Theme.accent : Theme.textDim
                        font.pixelSize: 13
                        font.weight: savedNote.opacity > 0 ? Font.DemiBold : Font.Normal
                    }
                }

                // Ver las ideas guardadas
                Rectangle {
                    visible: Focus.ideas.length > 0
                    Layout.preferredWidth: countText.implicitWidth + 16
                    Layout.preferredHeight: 24
                    radius: 7
                    color: root.showIdeas ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : (countHover.hovered ? Theme.hover : Theme.track)

                    Text {
                        id: countText

                        anchors.centerIn: parent
                        text: Focus.ideas.length + (root.showIdeas ? " ▴" : " ▾")
                        color: root.showIdeas ? Theme.accent : Theme.textDim
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: countHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.showIdeas = !root.showIdeas
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
        Rectangle {
            visible: root.showIdeas && Focus.ideas.length > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(ideaList.contentHeight, 196) + 12
            radius: Theme.controlRadius
            color: Theme.surface

            ListView {
                id: ideaList

                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 2
                model: Focus.ideas
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: ideaRow

                    required property var modelData

                    width: ListView.view.width
                    height: ideaText.implicitHeight + 14
                    radius: 8
                    color: rowHover.hovered ? Theme.hover : "transparent"

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
                                font.pixelSize: 13
                            }

                            Text {
                                visible: ideaRow.modelData.date !== ""
                                text: ideaRow.modelData.date.slice(8, 10) + "/" + ideaRow.modelData.date.slice(5, 7) + " " + ideaRow.modelData.time
                                color: Theme.textDim
                                font.pixelSize: 10
                            }
                        }

                        MIcon {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                            opacity: rowHover.hovered ? 1 : 0
                            name: "close"
                            font.pixelSize: 16
                            color: Theme.textDim

                            TapHandler {
                                onTapped: Focus.deleteIdea(ideaRow.modelData.line)
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }
    }
}
