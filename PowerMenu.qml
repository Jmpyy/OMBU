import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Menú central de energía: aparece en el monitor con foco.
PanelWindow {
    id: win

    required property var modelData

    // Índice de la acción esperando confirmación (-1 = ninguna)
    property int armed: -1

    readonly property var actions: [
        {
            label: "Bloquear",
            icon: "lock",
            lock: true,
            confirm: false
        },
        {
            // No suspende de verdad (la placa NVIDIA no despierta bien del suspend): bloquea
            // y deja el salvapantallas a la vista; al tocar algo pide la contraseña
            label: "Reposo",
            icon: "bedtime",
            rest: true,
            confirm: false
        },
        {
            label: "Cerrar sesión",
            icon: "logout",
            // Cierra Hyprland; greetd vuelve a mostrar el greeter
            command: ["hyprctl", "dispatch", "hl.dsp.exit()"],
            confirm: true
        },
        {
            label: "Reiniciar",
            icon: "restart_alt",
            command: ["systemctl", "reboot"],
            confirm: true
        },
        {
            label: "Apagar",
            icon: "power_settings_new",
            command: ["systemctl", "poweroff"],
            confirm: true
        }
    ]

    property real p: Ui.powerOpen ? 1 : 0

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
        function onPowerOpenChanged() {
            if (Ui.powerOpen && Hyprland.focusedMonitor?.name === modelData.name)
                win.activeOnScreen = true;
        }
    }

    onPChanged: if (p <= 0.001) activeOnScreen = false

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Ui.powerOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-power"
    WlrLayershell.keyboardFocus: Ui.powerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (!visible)
        armed = -1

    Process {
        id: runner
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: win.armed = -1
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.powerOpen = false
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.powerOpen = false

        HardShadow {
            target: card
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: row.implicitWidth + 56
            height: row.implicitHeight + 56 + title.implicitHeight + 16
            radius: Theme.comic ? 8 : Theme.cardRadius
            color: Theme.bg
            border.width: Theme.comic ? 2 : 1
            border.color: Theme.comic ? "#0a0708" : Theme.border
            opacity: win.p
            scale: 0.90 + 0.10 * win.p

            // Evita que un clic dentro de la tarjeta cierre el menú
            MouseArea {
                anchors.fill: parent
            }

            Text {
                id: title

                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                text: Theme.comic ? "ENERGÍA" : "Energía"
                color: Theme.comic ? Theme.accent : Theme.textDim
                font.pixelSize: Theme.comic ? 18 : Theme.fontSize
                font.weight: Font.DemiBold
                font.family: Theme.comic ? Theme.displayFont : ""
            }

            RowLayout {
                id: row

                anchors.top: title.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Repeater {
                    model: win.actions

                    Rectangle {
                        id: tile

                        required property int index
                        required property var modelData

                        readonly property bool isArmed: win.armed === index
                        readonly property bool isDanger: modelData.confirm && index === win.actions.length - 1

                        Layout.preferredWidth: 116
                        Layout.preferredHeight: 108
                        radius: Theme.comic ? 8 : 20
                        color: isArmed ? (isDanger ? Theme.danger : Theme.accent) : (tileArea.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.04))
                        border.width: Theme.comic ? 1.5 : 0
                        border.color: Theme.comic ? (tile.isArmed ? (tile.isDanger ? Theme.danger : Theme.accent) : (tileArea.containsMouse ? Theme.accent : "#0a0708")) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            MIcon {
                                Layout.alignment: Qt.AlignHCenter
                                name: tile.modelData.icon
                                font.pixelSize: 34
                                color: tile.isArmed ? Theme.accentText : (tile.isDanger && tileArea.containsMouse ? Theme.danger : Theme.text)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.isArmed ? "Tocá de nuevo" : tile.modelData.label
                                color: tile.isArmed ? Theme.accentText : Theme.text
                                font.pixelSize: Theme.comic ? 15 : Theme.fontSize
                                font.weight: Font.Medium
                                font.family: Theme.comic ? Theme.displayFont : ""
                            }
                        }

                        MouseArea {
                            id: tileArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (tile.modelData.confirm && !tile.isArmed) {
                                    win.armed = tile.index;
                                    disarm.restart();
                                    return;
                                }
                                Ui.powerOpen = false;
                                if (tile.modelData.rest) {
                    Ui.lockPreview = false;
                    Idle.lockedByIdle = true;
                    Ui.locked = true;
                    return;
                }
                if (tile.modelData.lock) {
                                    // Bloqueo real de la sesión (no la vista previa)
                                    Ui.lockPreview = false;
                                    Ui.locked = true;
                                    return;
                                }
                                runner.command = tile.modelData.command;
                                runner.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
