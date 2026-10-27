import QtQuick
import Quickshell
import Quickshell.Io

// Reiniciar y apagar desde la pantalla de bloqueo. Piden un
// segundo toque para no ejecutarse por error.
Row {
    id: root

    // Índice de la acción esperando confirmación (-1 = ninguna)
    property int armed: -1

    readonly property var actions: [
        {
            label: "Reiniciar",
            icon: "restart_alt",
            goodbye: "reboot",
            confirm: true
        },
        {
            label: "Apagar",
            icon: "power_settings_new",
            goodbye: "poweroff",
            confirm: true
        }
    ]

    spacing: 10

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = -1
    }

    Repeater {
        model: root.actions

        Rectangle {
            id: button

            required property int index
            required property var modelData
            readonly property bool isArmed: root.armed === index
            readonly property bool isDanger: modelData.confirm

            width: 46
            height: 46
            radius: 23
            color: isArmed ? (isDanger ? Theme.danger : Theme.accent) : (buttonHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            MIcon {
                anchors.centerIn: parent
                name: button.modelData.icon
                color: button.isArmed ? Theme.accentText : Qt.rgba(1, 1, 1, 0.85)
                font.pixelSize: 22
            }

            // Nombre de la acción (o aviso de confirmación) sobre el botón
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                opacity: buttonHover.hovered || button.isArmed ? 1 : 0
                text: button.isArmed ? "Tocá de nuevo" : button.modelData.label
                color: button.isArmed && button.isDanger ? Theme.danger : Qt.rgba(1, 1, 1, 0.8)
                font.pixelSize: 12
                font.weight: Font.Medium

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                    }
                }
            }

            HoverHandler {
                id: buttonHover
            }

            TapHandler {
                onTapped: {
                    if (button.modelData.confirm && !button.isArmed) {
                        root.armed = button.index;
                        disarm.restart();
                        return;
                    }
                    root.armed = -1;
                    // Despedida (se ve dentro del bloqueo, LockScreen) y recién después la orden
                    Goodbye.run(button.modelData.goodbye);
                }
            }
        }
    }
}
