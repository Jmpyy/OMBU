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
    property double dismissedNotifs: 0

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
    WlrLayershell.namespace: "ombu-bar"

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
                    radius: 12
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
            BarButton {
                id: clockButton

                readonly property bool isOpen: Ui.popup === win.popupKey("calendar")

                anchors.centerIn: parent
                implicitHeight: 24
                active: isOpen
                label: Chrono.date.toLocaleString(Chrono.locale, "ddd d MMM  HH:mm").replace(/\./g, "")
                labelSize: Theme.fontSize
                labelWeight: Font.Medium
                onClicked: {
                    if (Date.now() - win.dismissedCalendar > 300)
                        win.togglePopup("calendar");
                }
            }

            // Derecha: aviso de modo + una cápsula con los indicadores del sistema
            Row {
                anchors.right: parent.right
                anchors.rightMargin: win.sideMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Aviso mientras un modo de atajos está activo (ej. redimensionar con flechas)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Submap.active
                    width: submapText.implicitWidth + 22
                    height: 24
                    radius: 12
                    color: Theme.accent

                    Text {
                        id: submapText

                        anchors.centerIn: parent
                        text: Submap.label + "  ·  Esc para salir"
                        color: "#14131a"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: cluster.implicitWidth + 6
                    height: 28
                    radius: 14
                    color: Theme.surface

                    Row {
                        id: cluster

                        anchors.centerIn: parent
                        spacing: 2

                        // Layout de teclado: clic para alternar (igual que Alt+Shift)
                        BarButton {
                            id: keyboardButton

                            anchors.verticalCenter: parent.verticalCenter
                            icon: "keyboard"
                            label: Keyboard.code
                            labelMinWidth: 42
                            onClicked: Keyboard.toggle()
                        }

                        // Volumen: clic abre la mezcladora, rueda cambia el volumen, clic del medio silencia
                        BarButton {
                            id: mixerButton

                            readonly property bool isOpen: Ui.popup === win.popupKey("mixer")

                            anchors.verticalCenter: parent.verticalCenter
                            active: isOpen
                            icon: win.volumeIcon
                            iconColor: win.muted ? Theme.danger : Theme.text
                            label: Math.round(win.volume * 100) + "%"
                            labelColor: win.muted ? Theme.textDim : Theme.text
                            labelMinWidth: 34
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton) {
                                    if (win.sink?.audio)
                                        win.sink.audio.muted = !win.sink.audio.muted;
                                } else if (Date.now() - win.dismissedMixer > 300) {
                                    win.togglePopup("mixer");
                                }
                            }
                            onScrolled: wheel => {
                                if (win.sink?.audio)
                                    win.sink.audio.volume = Math.max(0, Math.min(1, win.sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                            }
                        }

                        // Notificaciones: la campana suena cuando llega una; clic abre el historial
                        BarButton {
                            id: bellButton

                            readonly property bool isOpen: Ui.popup === win.popupKey("notifs")

                            anchors.verticalCenter: parent.verticalCenter
                            active: isOpen
                            icon: Notifs.dnd ? "notifications_off" : (Notifs.count > 0 ? "notifications_unread" : "notifications")
                            iconColor: Notifs.dnd ? Theme.textDim : Theme.text
                            iconOrigin: Item.Top
                            label: Notifs.count > 0 ? String(Notifs.count) : ""
                            labelColor: Theme.accent
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton)
                                    Notifs.dnd = !Notifs.dnd;
                                else if (Date.now() - win.dismissedNotifs > 300)
                                    win.togglePopup("notifs");
                            }

                            // La campana se mece y el número "salta" al llegar una notificación
                            SequentialAnimation {
                                id: ring

                                NumberAnimation {
                                    target: bellButton
                                    property: "iconRotation"
                                    to: 20
                                    duration: 80
                                    easing.type: Easing.OutQuad
                                }
                                NumberAnimation {
                                    target: bellButton
                                    property: "iconRotation"
                                    to: -16
                                    duration: 120
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: bellButton
                                    property: "iconRotation"
                                    to: 11
                                    duration: 110
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: bellButton
                                    property: "iconRotation"
                                    to: -6
                                    duration: 100
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: bellButton
                                    property: "iconRotation"
                                    to: 0
                                    duration: 120
                                    easing.type: Easing.OutQuad
                                }
                            }

                            NumberAnimation {
                                id: pop

                                target: bellButton.labelItem
                                property: "scale"
                                from: 1.8
                                to: 1
                                duration: 380
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.6
                            }

                            Connections {
                                target: Notifs

                                function onReceived(): void {
                                    if (!Notifs.dnd)
                                        ring.restart();
                                    pop.restart();
                                }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: 14
                            color: Theme.border
                        }

                        // Apps abiertas: ventanas y las que siguen corriendo sin ventana
                        BarButton {
                            id: appsButton

                            readonly property bool isOpen: Ui.popup === win.popupKey("apps")

                            anchors.verticalCenter: parent.verticalCenter
                            active: isOpen
                            icon: "expand_more"
                            iconRotation: isOpen ? 180 : 0
                            label: String(Hyprland.toplevels.values.length)
                            onClicked: {
                                if (Date.now() - win.dismissedApps > 300)
                                    win.togglePopup("apps");
                            }

                            Behavior on iconRotation {
                                NumberAnimation {
                                    duration: Theme.popupDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Apps que siguen corriendo sin ventana
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Apps.background.length > 0
                                text: "+" + Apps.background.length
                                color: Theme.accent
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
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

    NotifMenu {
        barWindow: win
        anchorItem: bellButton
        open: bellButton.isOpen

        onDismissed: {
            win.dismissedNotifs = Date.now();
            if (bellButton.isOpen)
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
