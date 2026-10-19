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
    property double dismissedFocus: 0
    property double dismissedApps: 0
    property double dismissedDevices: 0
    property double dismissedControl: 0
    property double dismissedCalendar: 0
    property double dismissedNotifs: 0

    readonly property real fullHeight: Theme.barHeight + Theme.fillet
    readonly property real sideMargin: Theme.margin + Theme.fillet / 2

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string volumeIcon: muted || volume <= 0 ? "volume_off" : (volume < 0.5 ? "volume_down" : "volume_up")

    // Hay una sesión de foco a medias: el cronómetro se ve en la barra
    readonly property bool focusShown: Focus.mode !== "libre" && (Focus.running || Focus.remaining !== Focus.lengthOf(Focus.phase))
    // De dónde crece el menú de foco: del cronómetro si está a la vista, si no del centro de
    // control. Se fija al abrirlo para que no salte si empezás el temporizador con el menú abierto.
    property Item focusFrom: controlButton

    Binding {
        target: win
        property: "focusFrom"
        value: win.focusShown ? focusButton : controlButton
        when: Ui.popup !== win.popupKey("focus")
    }

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
                strokeColor: Theme.outline
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

            // Izquierda: logo (abre el menú del sistema) + workspaces
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
                    color: logoArea.containsMouse || Ui.sysMenuOpen ? Theme.hover : "transparent"

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
                        onClicked: {
                            // El menú del sistema (el de energía sigue en Super+Esc y en Sistema)
                            Ui.powerOpen = false;
                            Ui.launcherOpen = false;
                            Ui.clipOpen = false;
                            Ui.keysOpen = false;
                            Ui.popup = "";
                            Ui.sysMenuStart = "";
                            Ui.sysMenuOpen = !Ui.sysMenuOpen;
                        }
                    }
                }

                WorkspaceStrip {
                    anchors.verticalCenter: parent.verticalCenter
                    screenName: win.screen.name
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

                        // Modo foco: solo aparece mientras hay una sesión (en marcha o en pausa); el resto
                        // del tiempo se abre desde el centro de control. Es una píldora violeta con un anillo
                        // de avance y el tiempo en grande para que se note de lejos.
                        Rectangle {
                            id: focusButton

                            readonly property bool isOpen: Ui.popup === win.popupKey("focus")
                            readonly property real progress: Focus.mode === "libre" ? 0 : 1 - Focus.remaining / Focus.lengthOf(Focus.phase)
                            readonly property color tone: Focus.running ? Theme.accent : Theme.textDim

                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.focusShown
                            implicitWidth: chipRow.implicitWidth + 22
                            implicitHeight: 24
                            radius: height / 2
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, isOpen || chipArea.containsMouse ? 0.28 : 0.16)
                            border.width: 1
                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Focus.running ? 0.45 : 0.2)

                            onProgressChanged: chipRing.requestPaint()
                            onToneChanged: chipRing.requestPaint()

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 7

                                Canvas {
                                    id: chipRing

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    antialiasing: true
                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.lineWidth = 2.4;
                                        ctx.lineCap = "round";
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.16);
                                        ctx.beginPath();
                                        ctx.arc(8, 8, 6.2, 0, Math.PI * 2);
                                        ctx.stroke();
                                        if (focusButton.progress > 0.01) {
                                            ctx.strokeStyle = focusButton.tone;
                                            ctx.beginPath();
                                            ctx.arc(8, 8, 6.2, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, focusButton.progress));
                                            ctx.stroke();
                                        }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Focus.clock(Focus.remaining)
                                    color: focusButton.tone
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    font.features: {
                                        "tnum": 1
                                    }
                                }

                                MIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !Focus.running
                                    name: "pause"
                                    font.pixelSize: 14
                                    color: Theme.textDim
                                }
                            }

                            MouseArea {
                                id: chipArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Date.now() - win.dismissedFocus > 300)
                                        win.togglePopup("focus");
                                }
                            }
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

                        // Centro de control: brillo, volumen y ajustes rápidos; el número avisa de
                        // unidades conectadas
                        BarButton {
                            id: controlButton

                            readonly property bool isOpen: Ui.popup === win.popupKey("control")

                            anchors.verticalCenter: parent.verticalCenter
                            active: isOpen
                            icon: "tune"
                            label: Disks.removable.length > 0 ? String(Disks.removable.length) : ""
                            labelColor: Theme.accent
                            onClicked: {
                                if (Date.now() - win.dismissedControl > 300)
                                    win.togglePopup("control");
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
                            label: String(Apps.windows.length)
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

    FocusMenu {
        barWindow: win
        anchorItem: win.focusFrom
        open: focusButton.isOpen

        onDismissed: {
            win.dismissedFocus = Date.now();
            if (focusButton.isOpen)
                Ui.popup = "";
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

    ControlMenu {
        barWindow: win
        anchorItem: controlButton
        open: controlButton.isOpen

        onOpenDevices: win.togglePopup("devices")
        onOpenFocus: win.togglePopup("focus")
        onOpenWalls: {
            Ui.popup = "";
            Ui.wallMenuOpen = true;
        }
        onOpenPayments: win.togglePopup("payments")
        onDismissed: {
            win.dismissedControl = Date.now();
            if (controlButton.isOpen)
                Ui.popup = "";
        }
    }

    PaymentsMenu {
        readonly property bool isOpen: Ui.popup === win.popupKey("payments")

        barWindow: win
        anchorItem: controlButton
        open: isOpen

        onDismissed: {
            if (isOpen)
                Ui.popup = "";
        }
    }

    DevicesMenu {
        readonly property bool isOpen: Ui.popup === win.popupKey("devices")

        barWindow: win
        anchorItem: controlButton
        open: isOpen

        onDismissed: {
            win.dismissedDevices = Date.now();
            if (isOpen)
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
