import QtQuick
import QtQuick.Layouts

// Centro de dispositivos: los discos del equipo y las unidades que conectaste, con el
// espacio que queda en cada una.
DropPopup {
    id: root

    onOpenChanged: if (open)
        Disks.refresh()

    bodyWidth: 380
    bodyHeight: column.implicitHeight + 26

    ColumnLayout {
        id: column

        x: 16
        y: 2
        width: root.bodyWidth - 32
        spacing: 8

        Text {
            text: "ESTE EQUIPO"
            color: Theme.textDim
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Repeater {
            model: Disks.internal

            DeviceCard {
                required property var modelData

                Layout.fillWidth: true
                volume: modelData
            }
        }

        Text {
            Layout.topMargin: 8
            visible: Disks.removable.length > 0
            text: "EXTRAÍBLES"
            color: Theme.textDim
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Repeater {
            model: Disks.removable

            DeviceCard {
                required property var modelData

                Layout.fillWidth: true
                volume: modelData
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            visible: Disks.removable.length === 0
            text: "Conectá un pendrive o un disco y aparece acá"
            color: Theme.textDim
            font.pixelSize: 12
        }
    }
}
