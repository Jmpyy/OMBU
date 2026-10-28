import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Centro de control, a la manera de macOS: brillo y volumen arriba y, debajo, interruptores en píldora
// (ícono, nombre y estado). Los que tienen más ajustes llevan una zona › que despliega el detalle ahí
// mismo (uno a la vez; se cierra con el menú). Foco abre su propio menú. Los pagos y la música están en
// el panel lateral y el fondo se elige con Super+Ctrl+Espacio o desde el menú de la araña.
DropPopup {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    // Detalle desplegado: "" o el id de la píldora ("night")
    property string detail: ""

    onOpenChanged: {
        if (open)
            Brightness.refresh();
        else
            detail = "";
    }

    signal openFocus

    // Interruptor en píldora. `detailId` agrega la zona › que despliega el detalle; `navigates` muestra
    // la flecha sin separador (toda la píldora lleva a otro menú).
    component Toggle: Rectangle {
        id: pill

        property string icon
        property string title
        property string subtitle
        property bool on: false
        property string detailId: ""
        property bool navigates: false
        readonly property bool expanded: detailId !== "" && root.detail === detailId

        signal clicked

        implicitHeight: 54
        radius: Theme.controlRadius + 4
        color: Theme.surface
        border.width: Theme.comic ? 2 : 0
        border.color: Theme.comic ? (pill.on ? Theme.accent : Theme.ink) : "transparent"

        // Resaltado al pasar el mouse, por zona: la píldora entera o solo la flecha
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.hover
            opacity: main.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animQuick
                }
            }
        }

        Rectangle {
            id: badge

            x: 11
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: pill.on ? Theme.accent : Theme.track

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            MIcon {
                anchors.centerIn: parent
                name: pill.icon
                font.pixelSize: Theme.iconMd
                color: pill.on ? Theme.accentText : Theme.text
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: chevronZone.visible ? chevronZone.left : parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: pill.title
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: pill.subtitle
                elide: Text.ElideRight
                color: pill.on ? Theme.accent : Theme.textDim
                font.pixelSize: Theme.fontCaption
            }
        }

        MouseArea {
            id: main

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }

        // Zona de la flecha: va después de `main`, así se queda con el clic
        Item {
            id: chevronZone

            visible: pill.detailId !== "" || pill.navigates
            anchors.right: parent.right
            width: 28
            height: parent.height

            Rectangle {
                visible: pill.detailId !== ""
                width: 1
                height: parent.height - 22
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.border
            }

            Rectangle {
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 12
                color: Theme.hover
                opacity: pill.detailId !== "" && chevronArea.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animQuick
                    }
                }
            }

            MIcon {
                anchors.centerIn: parent
                name: "chevron_right"
                font.pixelSize: Theme.iconSm
                color: Theme.textDim
                rotation: pill.expanded ? 90 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.animFast
                        easing.type: Theme.ease
                    }
                }
            }

            MouseArea {
                id: chevronArea

                anchors.fill: parent
                enabled: pill.detailId !== ""
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detail = pill.expanded ? "" : pill.detailId
            }
        }
    }

    bodyWidth: 384
    bodyHeight: column.implicitHeight + 28

    ColumnLayout {
        id: column

        x: 16
        y: 4
        width: root.bodyWidth - 32
        spacing: 10

        PillSlider {
            Layout.fillWidth: true
            visible: Brightness.available
            icon: "brightness_6"
            label: "Brillo"
            value: Brightness.level
            onMoved: v => Brightness.setLevel(v)
        }

        PillSlider {
            Layout.fillWidth: true
            iconClickable: true
            icon: (root.sink?.audio?.muted ?? false) || (root.sink?.audio?.volume ?? 0) <= 0 ? "volume_off" : ((root.sink?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up")
            label: "Volumen"
            value: root.sink?.audio?.volume ?? 0
            muted: root.sink?.audio?.muted ?? false
            onMoved: v => {
                if (root.sink?.audio)
                    root.sink.audio.volume = v;
            }
            onIconClicked: {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Toggle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Focus.running ? (Focus.phase === "estudio" ? "school" : "coffee") : "timer"
                title: "Foco"
                subtitle: Focus.running ? Focus.phaseName + " · " + Focus.clock(Focus.remaining) : "Apagado"
                on: Focus.running
                navigates: true
                onClicked: root.openFocus()
            }

            Toggle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Notifs.dnd ? "notifications_off" : "notifications"
                title: "No molestar"
                subtitle: Notifs.dnd ? (Notifs.dndByFocus ? "Por el modo foco" : "Activado") : "Apagado"
                on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Toggle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "nightlight"
                title: "Luz nocturna"
                subtitle: NightLight.hint
                on: NightLight.active
                detailId: "night"
                onClicked: NightLight.toggle()
            }

            Toggle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "keyboard"
                title: "Teclado"
                subtitle: Keyboard.code === "LATAM" ? "Latinoamericano" : (Keyboard.code === "US" ? "Inglés (EE. UU.)" : Keyboard.code)
                onClicked: Keyboard.toggle()
            }
        }

        // Detalle de la luz nocturna: cuánta calidez y si va sola de noche
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.detail === "night"
            opacity: visible ? 1 : 0
            spacing: 8

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }

            PillSlider {
                Layout.fillWidth: true
                icon: "thermostat"
                label: "Calidez"
                valueText: NightLight.temperature + " K"
                // Más a la derecha, más cálida (menos kelvin), como en macOS
                value: (6000 - NightLight.temperature) / 3500
                onMoved: v => NightLight.setTemperature(Math.round((6000 - v * 3500) / 100) * 100)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 2

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Automática"
                        color: Theme.text
                        font.pixelSize: Theme.fontBody
                    }

                    Text {
                        text: NightLight.scheduleText
                        color: Theme.textDim
                        font.pixelSize: Theme.fontCaption
                    }
                }

                ToggleSwitch {
                    on: NightLight.auto
                    onToggled: NightLight.setAuto(!NightLight.auto)
                }
            }
        }
    }
}
