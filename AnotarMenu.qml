import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Anotador rápido al centro (Super+Alt+N, ipc call note toggle): escribís como en el papel
// («parcial eda jueves 18hs», «tp2 testing 15/11», «repasar punteros eda») y abajo se ve lo que
// entendió antes de guardar. Enter guarda (agenda o nota), Tab alterna «avisar a mamá», Esc cierra.
PanelWindow {
    id: win

    required property var modelData

    property bool family: false
    property string error: ""

    readonly property var p: Facu.parsedFor === input.text.trim() ? Facu.parsed : null
    readonly property bool canSave: p !== null && !Facu.saving && (p.isNote ? (p.detail || p.title) !== "" : p.date !== "")

    function save(): void {
        if (!canSave)
            return;
        const parsed = p;
        error = "";
        Facu.save(parsed, family, err => {
            if (err !== "") {
                win.error = err;
                return;
            }
            const where = parsed.isNote ? "Nota" + (parsed.subject ? " de " + parsed.subject.name : "") : parsed.when;
            Quickshell.execDetached(["notify-send", "-a", "ombu", "-h", "string:x-ombu-kind:note", "-i", "checkbox", "Anotado", (parsed.isNote ? parsed.detail : parsed.title) + " · " + where]);
            Ui.noteOpen = false;
        });
    }

    // Arranca en 0: la animación de entrada empieza con el primer cuadro (ver FirstFrame más abajo)
    property real anim: 0

    Behavior on anim {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    property bool activeOnScreen: false

    Connections {
        id: opening

        target: Ui

        function onNoteOpenChanged() {
            if (!Ui.noteOpen)
                return;
            if (Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
            input.text = Ui.notePrefill;
            Ui.notePrefill = "";
            win.family = false;
            win.error = "";
            Facu.parse(input.text);
            Qt.callLater(() => input.forceActiveFocus());
        }
    }

    onAnimChanged: if (anim <= 0.001)
        activeOnScreen = false

    Component.onCompleted: if (Ui.noteOpen)
        opening.onNoteOpenChanged()

    FirstFrame {
        onReady: win.anim = Qt.binding(() => Ui.noteOpen ? 1 : 0)
    }

    screen: modelData
    visible: (anim > 0.001 && activeOnScreen) || (Ui.noteOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-note"
    WlrLayershell.keyboardFocus: Ui.noteOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.anim

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.noteOpen = false
        }
    }

    HardShadow {
        target: card
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2
        width: 600
        height: column.implicitHeight + 32
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: Theme.comic ? 2 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border
        opacity: win.anim
        scale: 0.94 + 0.06 * win.anim
        transformOrigin: Item.Top

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            // Título
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MIcon {
                    name: "edit_note"
                    font.pixelSize: 20
                    color: Theme.accent
                }

                Text {
                    text: "Anotar"
                    color: Theme.text
                    font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
                    font.pixelSize: Theme.comic ? 20 : 15
                    font.letterSpacing: Theme.comic ? 1 : 0
                    font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "Enter guarda · Esc cierra"
                    color: Theme.textDim
                    font.pixelSize: 11
                }
            }

            // Campo
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                radius: Theme.controlRadius
                color: Theme.surface
                border.width: Theme.comic ? 2 : 1
                border.color: Theme.comic ? Theme.ink : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)

                TextInput {
                    id: input

                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.pixelSize: 16
                    clip: true
                    onTextChanged: {
                        win.error = "";
                        Facu.parse(text);
                    }
                    onAccepted: win.save()
                    Keys.onEscapePressed: Ui.noteOpen = false
                    Keys.onTabPressed: win.family = !win.family

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "parcial eda jueves 18hs · tp2 testing 15/11 · repasar punteros eda"
                        color: Theme.textDim
                        font.pixelSize: 14
                    }
                }
            }

            // Lo que entendió
            Rectangle {
                visible: win.p !== null
                Layout.fillWidth: true
                implicitHeight: preview.implicitHeight + 24
                radius: Theme.controlRadius
                color: Theme.surface
                border.width: Theme.comic ? 1.5 : 1
                border.color: Theme.comic ? Theme.ink : Theme.border

                readonly property color kc: Facu.kindColor(win.p?.kind ?? "")

                // Franja del color del tipo
                Rectangle {
                    x: 1
                    y: 1
                    width: 4
                    height: parent.height - 2
                    radius: 2
                    color: parent.kc
                }

                ColumnLayout {
                    id: preview

                    x: 16
                    y: 12
                    width: parent.width - 30
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Sticker {
                            text: win.p?.kindName ?? ""
                            tint: Facu.kindColor(win.p?.kind ?? "")
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (win.p?.isNote ? win.p?.detail : win.p?.title) || "…"
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }

                    // Cuándo, o adónde va la nota
                    RowLayout {
                        spacing: 6

                        MIcon {
                            name: win.p?.isNote ? "folder" : (win.p?.needsDate ? "help" : "calendar_month")
                            font.pixelSize: 15
                            color: win.p?.needsDate ? Theme.warn : Theme.textDim
                        }

                        Text {
                            text: win.p?.isNote ? (win.p?.subject ? "Notas de " + win.p.subject.name + " · ~/Universidad/" + win.p.subject.dir + "/notas.md" : "Notas generales") : (win.p?.needsDate ? "¿Qué día? Sumá «jueves», «mañana» o «15/11»" : win.p?.when ?? "")
                            color: win.p?.needsDate ? Theme.warn : Theme.text
                            font.pixelSize: 12
                        }
                    }

                    RowLayout {
                        visible: !(win.p?.isNote ?? true) && (win.p?.reminders ?? []).length > 0
                        spacing: 6

                        MIcon {
                            name: "notifications"
                            font.pixelSize: 15
                            color: Theme.textDim
                        }

                        Text {
                            text: "Te avisa " + Facu.remindersText(win.p?.reminders ?? []) + (Agenda.apiConnected ? " · también en el celular" : "")
                            color: Theme.textDim
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // Avisar a mamá (calendario familiar) y guardar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    visible: Agenda.familyCalendarId !== "" && !(win.p?.isNote ?? true)
                    implicitWidth: famRow.implicitWidth + 18
                    implicitHeight: 30
                    radius: Theme.controlRadius
                    color: win.family ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (famHover.hovered ? Theme.hover : Theme.surface)

                    Row {
                        id: famRow

                        anchors.centerIn: parent
                        spacing: 6

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: win.family ? "check_box" : "check_box_outline_blank"
                            font.pixelSize: 16
                            color: win.family ? Theme.accent : Theme.textDim
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Avisar también a mamá"
                            color: win.family ? Theme.accent : Theme.text
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tab"
                            color: Theme.textDim
                            font.pixelSize: 10
                        }
                    }

                    HoverHandler {
                        id: famHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: win.family = !win.family
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: win.error
                    color: Theme.danger
                    elide: Text.ElideRight
                    font.pixelSize: 12
                }

                Rectangle {
                    implicitWidth: saveText.implicitWidth + 28
                    implicitHeight: 32
                    radius: Theme.controlRadius
                    color: win.canSave ? Theme.accent : Theme.track
                    border.width: Theme.comic && win.canSave ? 1.5 : 0
                    border.color: Theme.ink

                    Text {
                        id: saveText

                        anchors.centerIn: parent
                        text: Facu.saving ? "Guardando…" : (win.p?.isNote ? "Guardar nota" : "Agendar")
                        color: win.canSave ? Theme.accentText : Theme.textDim
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        cursorShape: win.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                    TapHandler {
                        onTapped: win.save()
                    }
                }
            }
        }
    }
}
