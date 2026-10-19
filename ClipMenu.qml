import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Historial del portapapeles al centro, como el launcher: buscás, elegís y se pega en la
// ventana donde estabas. Aparece en el monitor con foco.
//   Enter pega · Shift+Enter solo copia · Ctrl+P fija o suelta · Ctrl+Supr borra · Esc cierra
PanelWindow {
    id: win

    required property var modelData

    readonly property int maxListHeight: 440
    // Vaciar todo pide un segundo toque
    property bool clearArmed: false

    function matches(text: string, q: string): bool {
        return !q || text.toLowerCase().includes(q);
    }

    // Lo que muestra la lista: encabezados, textos fijados y entradas del historial
    readonly property var items: {
        const q = input.text.trim().toLowerCase();
        const out = [];
        const pins = Clip.pins.map((p, i) => ({
                    kind: "pin",
                    index: i,
                    text: p.text,
                    preview: p.text.replace(/\s+/g, " ").trim()
                })).filter(p => matches(p.preview, q));
        if (pins.length > 0) {
            out.push({
                kind: "header",
                title: "Fijados"
            });
            for (const p of pins)
                out.push(p);
        }
        const recent = Clip.entries.filter(e => matches(e.image ? "imagen" : e.preview, q)).map(e => ({
                    kind: "entry",
                    id: e.id,
                    line: e.line,
                    preview: e.preview,
                    image: e.image
                }));
        if (recent.length > 0) {
            out.push({
                kind: "header",
                title: pins.length > 0 ? "Recientes" : ""
            });
            for (const e of recent)
                out.push(e);
        }
        return out;
    }

    readonly property var current: list.currentIndex >= 0 && list.currentIndex < items.length ? items[list.currentIndex] : null

    function selectFirst(): void {
        const i = items.findIndex(x => x.kind !== "header");
        list.currentIndex = i;
    }

    // Mueve la selección saltando los encabezados
    function move(dir: int): void {
        let i = list.currentIndex + dir;
        while (i >= 0 && i < items.length && items[i].kind === "header")
            i += dir;
        if (i >= 0 && i < items.length)
            list.currentIndex = i;
    }

    function activate(item: var, paste: bool): void {
        if (!item || item.kind === "header")
            return;
        Ui.clipOpen = false;
        Clip.use(item, paste);
    }

    function togglePin(item: var): void {
        if (!item || item.kind === "header")
            return;
        if (item.kind === "pin")
            Clip.unpin(item.index);
        else if (!item.image)
            Clip.pinEntry(item);
    }

    onItemsChanged: Qt.callLater(selectFirst)

    property real p: Ui.clipOpen ? 1 : 0

    Behavior on p {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    // Guarda el monitor en el que se abrió para completar la animación de cierre
    property bool activeOnScreen: false

    Connections {
        target: Ui

        function onClipOpenChanged() {
            if (!Ui.clipOpen)
                return;
            if (Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
            win.clearArmed = false;
            input.text = "";
            Clip.refresh();
            win.selectFirst();
            Qt.callLater(() => input.forceActiveFocus());
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    Timer {
        id: disarm

        interval: 3000
        onTriggered: win.clearArmed = false
    }

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Ui.clipOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-clip"
    WlrLayershell.keyboardFocus: Ui.clipOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.clipOpen = false
        }
    }

    HardShadow {
        target: card
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        width: 660
        height: column.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.p
        scale: 0.90 + 0.10 * win.p
        transformOrigin: Item.Top

        // Evita que un clic dentro de la tarjeta cierre el menú
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 6

            // Búsqueda y botones
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                spacing: 12

                MIcon {
                    name: "content_paste"
                    color: Theme.textDim
                    font.pixelSize: 24
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.pixelSize: 18
                    clip: true
                    focus: true

                    Keys.onEscapePressed: Ui.clipOpen = false
                    Keys.onUpPressed: win.move(-1)
                    Keys.onDownPressed: win.move(1)
                    Keys.onReturnPressed: event => {
                        win.activate(win.current, !(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: event => {
                        win.activate(win.current, !(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                    Keys.onPressed: event => {
                        if (!(event.modifiers & Qt.ControlModifier))
                            return;
                        if (event.key === Qt.Key_P) {
                            win.togglePin(win.current);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete && win.current && win.current.kind !== "header") {
                            Clip.remove(win.current);
                            event.accepted = true;
                        }
                    }

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar en el portapapeles…"
                        color: Theme.textDim
                        font.pixelSize: 18
                    }
                }

                // Pausa: deja de guardar lo que se copia
                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: pauseRow.implicitWidth + 20
                    radius: 17
                    color: Clip.paused ? Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.18) : (pauseHover.hovered ? Theme.hover : "transparent")

                    Row {
                        id: pauseRow

                        anchors.centerIn: parent
                        spacing: 6

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Clip.paused ? "play_arrow" : "pause"
                            color: Clip.paused ? Theme.warn : Theme.textDim
                            font.pixelSize: 19
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Clip.paused
                            text: "En pausa"
                            color: Theme.warn
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    HoverHandler {
                        id: pauseHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Clip.togglePause()
                    }
                }

                // Vaciar todo (pide un segundo toque)
                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: clearRow.implicitWidth + 20
                    radius: 17
                    color: win.clearArmed ? Theme.danger : (clearHover.hovered ? Theme.hover : "transparent")

                    Row {
                        id: clearRow

                        anchors.centerIn: parent
                        spacing: 6

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "delete_sweep"
                            color: win.clearArmed ? Theme.onAccent : Theme.textDim
                            font.pixelSize: 19
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.clearArmed
                            text: "Tocá de nuevo"
                            color: Theme.onAccent
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    HoverHandler {
                        id: clearHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            if (!win.clearArmed) {
                                win.clearArmed = true;
                                disarm.restart();
                                return;
                            }
                            win.clearArmed = false;
                            Clip.wipe();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            Text {
                visible: win.items.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 14
                horizontalAlignment: Text.AlignHCenter
                text: input.text.trim() !== "" ? "Sin resultados para “" + input.text + "”" : "Todavía no copiaste nada"
                color: Theme.textDim
                font.pixelSize: 14
            }

            ListView {
                id: list

                visible: win.items.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, win.maxListHeight)
                model: win.items
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Item {
                    id: item

                    required property var modelData
                    required property int index
                    readonly property bool isHeader: modelData.kind === "header"
                    readonly property bool isImage: modelData.kind === "entry" && modelData.image
                    readonly property bool current: ListView.isCurrentItem
                    readonly property bool active: current || itemHover.hovered

                    width: ListView.view.width
                    height: isHeader ? (modelData.title === "" ? 4 : 30) : (isImage ? 88 : 56)

                    // Encabezado de sección
                    Text {
                        visible: item.isHeader && item.modelData.title !== ""
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        text: item.isHeader ? item.modelData.title.toUpperCase() : ""
                        color: Theme.textDim
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        visible: !item.isHeader
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: 14
                        color: item.current ? Theme.surface : (itemHover.hovered ? Theme.hover : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 14

                            // Miniatura de una imagen, o un ícono para el texto
                            Item {
                                Layout.preferredWidth: item.isImage ? 112 : 28
                                Layout.preferredHeight: item.isImage ? 64 : 28
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    id: thumbMask

                                    anchors.fill: parent
                                    radius: 10
                                    visible: false
                                    layer.enabled: true
                                }

                                Image {
                                    visible: item.isImage
                                    anchors.fill: parent
                                    source: item.isImage ? Clip.thumb(item.modelData) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                    asynchronous: true
                                    smooth: true
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: thumbMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1
                                    }
                                }

                                MIcon {
                                    visible: !item.isImage
                                    anchors.centerIn: parent
                                    name: item.modelData.kind === "pin" ? "push_pin" : "notes"
                                    color: item.modelData.kind === "pin" ? Theme.accent : Theme.textDim
                                    font.pixelSize: 22
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: item.isImage ? "Imagen" : (item.modelData.preview ?? "")
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: 14
                            }

                            // Acciones al pasar el mouse o con la fila seleccionada
                            Row {
                                visible: item.active
                                spacing: 2

                                Rectangle {
                                    visible: !item.isImage
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: pinHover.hovered ? Theme.hover : "transparent"

                                    MIcon {
                                        anchors.centerIn: parent
                                        name: "push_pin"
                                        color: item.modelData.kind === "pin" ? Theme.accent : Theme.textDim
                                        font.pixelSize: 17
                                    }

                                    HoverHandler {
                                        id: pinHover

                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: win.togglePin(item.modelData)
                                    }
                                }

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: delHover.hovered ? Theme.danger : "transparent"

                                    MIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        color: delHover.hovered ? Theme.onAccent : Theme.textDim
                                        font.pixelSize: 17
                                    }

                                    HoverHandler {
                                        id: delHover

                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: Clip.remove(item.modelData)
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            id: itemHover
                        }
                        TapHandler {
                            // Los botones de la derecha tienen sus propios toques
                            onTapped: eventPoint => {
                                if (eventPoint.position.x < parent.width - 80)
                                    win.activate(item.modelData, true);
                            }
                        }
                    }
                }
            }

            // Ayuda de teclas
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.topMargin: 2
                Layout.bottomMargin: 4
                text: "Enter pega  ·  Shift+Enter copia  ·  Ctrl+P fija  ·  Ctrl+Supr borra"
                color: Theme.textDim
                font.pixelSize: 11
            }
        }
    }
}
