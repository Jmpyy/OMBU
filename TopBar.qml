import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var modelData

    // 0 = escondida arriba del borde, 1 = completamente visible (durante la bienvenida baja al final)
    property real reveal: Ui.barShown && !Welcome.playing ? 1 : 0
    // Evitan que el clic que cierra un menú lo vuelva a abrir
    property double dismissedMixer: 0
    property double dismissedApps: 0
    property double dismissedDevices: 0
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

    // Los clics solo se capturan sobre la barra; las esquinas dejan pasar.
    // Se calcula con reveal y no con el elemento que se desliza: si la barra arranca escondida
    // (bienvenida), la zona quedaba fijada fuera de la pantalla y no recibía clics.
    mask: Region {
        x: 0
        y: 0
        width: win.width
        height: Math.round(Theme.barHeight * win.reveal)
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
            // Filo sutil abajo, para separar la barra del escritorio
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.border
                strokeWidth: 1
                startX: 0
                startY: win.fullHeight

                PathArc {
                    x: Theme.fillet
                    y: Theme.barHeight
                    radiusX: Theme.fillet
                    radiusY: Theme.fillet
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: shape.width - Theme.fillet
                    y: Theme.barHeight
                }
                PathArc {
                    x: shape.width
                    y: win.fullHeight
                    radiusX: Theme.fillet
                    radiusY: Theme.fillet
                    direction: PathArc.Clockwise
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

                WorkspaceStrip {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Centro: reloj (abre el calendario). La fecha se completa al pasar el mouse.
            BarButton {
                id: clockButton

                readonly property bool isOpen: Ui.popup === win.popupKey("calendar")

                anchors.centerIn: parent
                implicitHeight: 24
                active: isOpen
                onClicked: {
                    if (Date.now() - win.dismissedCalendar > 300)
                        win.togglePopup("calendar");
                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: clockButton.hovered || clockButton.isOpen ? Chrono.date.toLocaleString(Chrono.locale, "dddd d 'de' MMMM") : Chrono.date.toLocaleString(Chrono.locale, "ddd d MMM").replace(/\./g, "")
                    color: Theme.textDim
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Chrono.date.toLocaleString(Chrono.locale, "HH:mm")
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
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

                        // Bandeja del sistema (solo aparece si hay apps en ella)
                        TrayStrip {
                            id: tray

                            anchors.verticalCenter: parent.verticalCenter
                            barWindow: win
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tray.count > 0
                            width: 1
                            height: 14
                            color: Theme.border
                        }

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
                            label: win.muted ? "" : Math.round(win.volume * 100) + "%"
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

                        // Dispositivos: discos del equipo y unidades conectadas
                        BarButton {
                            id: devicesButton

                            readonly property bool isOpen: Ui.popup === win.popupKey("devices")

                            anchors.verticalCenter: parent.verticalCenter
                            active: isOpen
                            icon: Disks.removable.length > 0 ? "usb" : "hard_drive"
                            label: Disks.removable.length > 0 ? String(Disks.removable.length) : ""
                            labelColor: Theme.accent
                            onClicked: {
                                if (Date.now() - win.dismissedDevices > 300)
                                    win.togglePopup("devices");
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

    DevicesMenu {
        barWindow: win
        anchorItem: devicesButton
        open: devicesButton.isOpen

        onDismissed: {
            win.dismissedDevices = Date.now();
            if (devicesButton.isOpen)
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
