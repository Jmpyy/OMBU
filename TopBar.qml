import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var modelData

    // 0 = escondida arriba del borde, 1 = completamente visible
    property real reveal: Ui.barShown ? 1 : 0
    // Evitan que el clic que cierra un menú lo vuelva a abrir
    property double dismissedMixer: 0
    property double dismissedApps: 0
    property double dismissedCalendar: 0

    readonly property real fullHeight: Theme.barHeight + Theme.fillet
    readonly property real sideMargin: Theme.margin + Theme.fillet / 2

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string volumeIcon: muted || volume <= 0 ? "volume_off" : (volume < 0.5 ? "volume_down" : "volume_up")

    function popupKey(kind: string): string {
        return kind + "@" + screen.name;
    }

    function togglePopup(kind: string): void {
        Ui.popup = Ui.popup === popupKey(kind) ? "" : popupKey(kind);
    }

    screen: modelData
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: fullHeight
    exclusiveZone: Ui.barShown ? Theme.barHeight : 0
    WlrLayershell.namespace: "nuestro-bar"

    // Los clics solo se capturan sobre la barra; las esquinas dejan pasar
    mask: Region {
        item: strip
    }

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.revealDuration
            easing.type: Easing.OutCubic
        }
    }

    // Todo se desliza junto desde el borde del monitor
    Item {
        id: slide

        width: parent.width
        height: win.fullHeight
        y: -(1 - win.reveal) * win.fullHeight

        // Barra + esquinas cóncavas como una sola silueta
        Shape {
            id: shape

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.bg
                strokeColor: "transparent"
                startX: 0
                startY: 0

                PathLine {
                    x: shape.width
                    y: 0
                }
                PathLine {
                    x: shape.width
                    y: win.fullHeight
                }
                PathArc {
                    x: shape.width - Theme.fillet
                    y: Theme.barHeight
                    radiusX: Theme.fillet
                    radiusY: Theme.fillet
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: Theme.fillet
                    y: Theme.barHeight
                }
                PathArc {
                    x: 0
                    y: win.fullHeight
                    radiusX: Theme.fillet
                    radiusY: Theme.fillet
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }

        // Área útil de la barra
        Item {
            id: strip

            width: parent.width
            height: Theme.barHeight

            // Izquierda: logo (abre el menú de energía) + workspaces
            Row {
                anchors.left: parent.left
                anchors.leftMargin: win.sideMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Rectangle {
                    id: logoButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 24
                    radius: 8
                    color: logoArea.containsMouse || Ui.powerOpen ? Theme.hover : "transparent"

                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: "file:///usr/share/icons/cachyos.svg"
                        sourceSize: Qt.size(72, 72)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    MouseArea {
                        id: logoArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.powerOpen = !Ui.powerOpen
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: 5

                        Rectangle {
                            id: dot

                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool active: Hyprland.focusedWorkspace?.id === wsId
                            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                            anchors.verticalCenter: parent.verticalCenter
                            width: active ? 22 : 8
                            height: 8
                            radius: 4
                            color: active ? Theme.accent : (occupied ? Theme.text : Theme.textDim)
                            opacity: active || occupied ? 1 : 0.45

                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                // Hyprland 0.56 con config Lua: el dispatch es código Lua
                                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + dot.wsId + "\" })")
                            }
                        }
                    }
                }
            }

            // Centro: reloj (abre el calendario)
            Rectangle {
                id: clockButton

                readonly property bool isOpen: Ui.popup === win.popupKey("calendar")

                anchors.centerIn: parent
                width: clockText.implicitWidth + 22
                height: 24
                radius: 8
                color: clockArea.containsMouse || isOpen ? Theme.hover : "transparent"

                Text {
                    id: clockText

                    anchors.centerIn: parent
                    text: Chrono.date.toLocaleString(Chrono.locale, "ddd d MMM  HH:mm").replace(/\./g, "")
                    color: Theme.text
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: clockArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Date.now() - win.dismissedCalendar > 300)
                            win.togglePopup("calendar");
                    }
                }
            }

            // Derecha: volumen + apps abiertas
            Row {
                anchors.right: parent.right
                anchors.rightMargin: win.sideMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Layout de teclado: clic para alternar (igual que Alt+Shift)
                Rectangle {
                    id: keyboardButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: keyboardRow.implicitWidth + 18
                    height: 24
                    radius: 8
                    color: keyboardArea.containsMouse ? Theme.hover : "transparent"

                    Row {
                        id: keyboardRow

                        anchors.centerIn: parent
                        spacing: 5

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "keyboard"
                            font.pixelSize: 17
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Keyboard.code
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: keyboardArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Keyboard.toggle()
                    }
                }

                Rectangle {
                    id: mixerButton

                    readonly property bool isOpen: Ui.popup === win.popupKey("mixer")

                    anchors.verticalCenter: parent.verticalCenter
                    width: mixerRow.implicitWidth + 18
                    height: 24
                    radius: 8
                    color: mixerArea.containsMouse || isOpen ? Theme.hover : "transparent"

                    Row {
                        id: mixerRow

                        anchors.centerIn: parent
                        spacing: 5

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: win.volumeIcon
                            font.pixelSize: 17
                            color: win.muted ? Theme.danger : Theme.text
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(win.volume * 100) + "%"
                            color: win.muted ? Theme.textDim : Theme.text
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: mixerArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                if (win.sink?.audio)
                                    win.sink.audio.muted = !win.sink.audio.muted;
                            } else if (Date.now() - win.dismissedMixer > 300) {
                                win.togglePopup("mixer");
                            }
                        }
                        onWheel: wheel => {
                            if (win.sink?.audio)
                                win.sink.audio.volume = Math.max(0, Math.min(1, win.sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                        }
                    }
                }

                Rectangle {
                    id: appsButton

                    readonly property bool isOpen: Ui.popup === win.popupKey("apps")

                    anchors.verticalCenter: parent.verticalCenter
                    width: appsRow.implicitWidth + 16
                    height: 24
                    radius: 8
                    color: appsArea.containsMouse || isOpen ? Theme.hover : "transparent"

                    Row {
                        id: appsRow

                        anchors.centerIn: parent
                        spacing: 2

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand_more"
                            rotation: appsButton.isOpen ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.popupDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Hyprland.toplevels.values.length
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        // Apps que siguen corriendo sin ventana
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Apps.background.length > 0
                            text: "+" + Apps.background.length
                            color: Theme.accent
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: appsArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Date.now() - win.dismissedApps > 300)
                                win.togglePopup("apps");
                        }
                    }
                }
            }
        }
    }

    MixerMenu {
        barWindow: win
        anchorItem: mixerButton
        open: mixerButton.isOpen

        onDismissed: {
            win.dismissedMixer = Date.now();
            if (mixerButton.isOpen)
                Ui.popup = "";
        }
    }

    CalendarMenu {
        barWindow: win
        anchorItem: clockButton
        open: clockButton.isOpen

        onDismissed: {
            win.dismissedCalendar = Date.now();
            if (clockButton.isOpen)
                Ui.popup = "";
        }
    }

    AppsMenu {
        barWindow: win
        anchorItem: appsButton
        open: appsButton.isOpen

        onDismissed: {
            win.dismissedApps = Date.now();
            if (appsButton.isOpen)
                Ui.popup = "";
        }
    }
}
