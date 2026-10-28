import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Lista de atajos de teclado al centro, como el portapapeles: se abre con Super+K, se busca
// escribiendo y se cierra con Esc. Aparece en el monitor con foco.
PanelWindow {
    id: win

    required property var modelData

    readonly property int maxListHeight: 500

    // Lo que muestra la lista: un encabezado por categoría y sus atajos, filtrados por la búsqueda
    readonly property var items: {
        const q = input.text.trim().toLowerCase();
        const out = [];
        let last = "";
        for (const e of Atajos.entries) {
            const hay = (e.text + " " + e.category + " " + e.alternatives.map(a => a.join(" ")).join(" ")).toLowerCase();
            if (q && !hay.includes(q))
                continue;
            if (e.category !== last) {
                out.push({
                    kind: "header",
                    title: e.category
                });
                last = e.category;
            }
            out.push({
                kind: "entry",
                text: e.text,
                alternatives: e.alternatives
            });
        }
        return out;
    }

    function scroll(delta: real): void {
        list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + delta));
    }

    // Arranca en 0: la animación de entrada empieza con el primer cuadro (ver FirstFrame más abajo)
    property real p: 0

    Behavior on p {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    // Guarda el monitor en el que se abrió para completar la animación de cierre
    property bool activeOnScreen: false

    Connections {
        id: opening

        target: Ui

        function onKeysOpenChanged() {
            if (!Ui.keysOpen)
                return;
            if (Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
            input.text = "";
            list.contentY = 0;
            Atajos.refresh();
            Qt.callLater(() => input.forceActiveFocus());
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    // Se crea recién al abrirse (LazyLoader en shell.qml): el aviso de apertura ya pasó, así que se
    // corre acá; la animación de entrada espera al primer cuadro de la ventana para no verse como un salto
    Component.onCompleted: if (Ui.keysOpen)
        opening.onKeysOpenChanged()

    FirstFrame {
        onReady: win.p = Qt.binding(() => Ui.keysOpen ? 1 : 0)
    }

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Ui.keysOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-keys"
    WlrLayershell.keyboardFocus: Ui.keysOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.keysOpen = false
        }
    }

    HardShadow {
        target: card
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        width: 700
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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 12

                MIcon {
                    name: "keyboard"
                    color: Theme.textDim
                    font.pixelSize: Theme.iconLg
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.pixelSize: Theme.fontTitle
                    clip: true
                    focus: true

                    Keys.onEscapePressed: Ui.keysOpen = false
                    Keys.onUpPressed: win.scroll(-120)
                    Keys.onDownPressed: win.scroll(120)

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar un atajo…"
                        color: Theme.textDim
                        font.pixelSize: Theme.fontTitle
                    }
                }

                Text {
                    text: "Esc para cerrar"
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSmall
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
                text: input.text.trim() !== "" ? "Sin resultados para “" + input.text + "”" : "No hay atajos con descripción"
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
            }

            ListView {
                id: list

                visible: win.items.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, win.maxListHeight)
                model: win.items
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property bool isHeader: modelData.kind === "header"

                    width: ListView.view.width
                    height: isHeader ? 30 : 32

                    Text {
                        visible: row.isHeader
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        // Como MenuSection: chico, gris y en minúsculas
                        text: row.isHeader ? row.modelData.title : ""
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        visible: !row.isHeader
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: Theme.controlRadius - 3
                        color: rowHover.hovered ? Theme.surface : "transparent"

                        HoverHandler {
                            id: rowHover
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: row.isHeader ? "" : row.modelData.text
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: Theme.fontBody
                            }

                            Repeater {
                                model: row.isHeader ? [] : row.modelData.alternatives

                                Row {
                                    id: alt

                                    required property var modelData
                                    required property int index

                                    spacing: 4

                                    Text {
                                        visible: alt.index > 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "o"
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontCaption
                                    }

                                    Repeater {
                                        model: alt.modelData

                                        Rectangle {
                                            id: chip

                                            required property string modelData

                                            width: Math.max(26, chipText.implicitWidth + 14)
                                            height: 22
                                            radius: 6
                                            color: Theme.surface
                                            border.width: 1
                                            border.color: Theme.border

                                            Text {
                                                id: chipText

                                                anchors.centerIn: parent
                                                text: chip.modelData
                                                color: Theme.text
                                                font.pixelSize: Theme.fontSmall
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
