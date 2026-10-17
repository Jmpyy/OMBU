import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

// Tarjeta de una notificación. Se usa en los avisos emergentes y en el historial.
Rectangle {
    id: root

    required property var entry
    // En los avisos emergentes la tarjeta lleva fondo y borde propios
    property bool floating: false

    readonly property var extraActions: entry.actionList.filter(a => a.identifier !== "default")

    // Las capturas de pantalla traen su imagen: se muestra grande, como miniatura
    readonly property string previewSource: {
        if (entry.appName !== "Capturas")
            return "";
        const path = entry.image || entry.appIcon;
        if (!path)
            return "";
        return path.startsWith("/") ? "file://" + path : path;
    }

    readonly property string iconSource: {
        if (previewSource !== "")
            return "";
        if (entry.image)
            return entry.image;
        if (entry.appIcon)
            return entry.appIcon.startsWith("/") ? "file://" + entry.appIcon : Quickshell.iconPath(entry.appIcon, "");
        const e = DesktopEntries.heuristicLookup(entry.desktopEntry || entry.appName);
        return e ? Quickshell.iconPath(e.icon, "") : "";
    }

    function ago(then: date, now: date): string {
        const s = Math.max(0, Math.floor((now - then) / 1000));
        if (s < 60)
            return "ahora";
        const m = Math.floor(s / 60);
        if (m < 60)
            return "hace " + m + " min";
        const h = Math.floor(m / 60);
        return h < 24 ? "hace " + h + " h" : "hace " + Math.floor(h / 24) + " d";
    }

    // Los avisos con cuenta regresiva llevan una barra de tiempo abajo
    readonly property bool timed: floating && entry.hasTimer

    implicitHeight: content.implicitHeight + (timed ? 34 : 26)
    radius: 18
    color: floating ? Theme.bg : Theme.surface
    border.width: floating ? 1 : 0
    border.color: hover.hovered ? Qt.rgba(1, 1, 1, 0.24) : Theme.border

    Behavior on border.color {
        ColorAnimation {
            duration: 160
        }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: root.entry.hovered = hovered
    }

    // Clic en la tarjeta: ejecuta la acción principal y la cierra
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifs.invoke(root.entry)
    }

    // Marca de urgencia
    Rectangle {
        visible: root.entry.critical
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: parent.height * 0.5
        radius: 2
        color: Theme.danger

        // Respira para llamar la atención sin ser agresiva
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.entry.critical

            NumberAnimation {
                to: 0.35
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
    }

    // Tiempo que le queda al aviso; se detiene cuando el mouse está encima
    Rectangle {
        visible: root.timed
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.bottomMargin: 9
        height: 3
        radius: 1.5
        width: (parent.width - 36) * root.entry.remaining
        color: root.entry.critical ? Theme.danger : Theme.accent
        opacity: hover.hovered ? 1 : 0.7

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.timed ? -4 : 0
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 12
            color: root.floating ? Theme.surface : Theme.bg

            Image {
                id: icon

                anchors.centerIn: parent
                width: 28
                height: 28
                visible: source != "" && status !== Image.Error
                source: root.iconSource
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MIcon {
                anchors.centerIn: parent
                visible: !icon.visible
                name: root.previewSource !== "" ? "photo_camera" : "notifications"
                color: Theme.textDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: root.entry.appName
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.ago(root.entry.time, Chrono.date)
                    color: Theme.textDim
                    font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.entry.summary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.entry.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.72)
                font.pixelSize: 13
            }

            // Miniatura (solo las capturas de pantalla)
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.preferredHeight: 120
                visible: root.previewSource !== ""

                Rectangle {
                    id: previewMask

                    anchors.fill: parent
                    radius: 12
                    visible: false
                    layer.enabled: true
                }

                Image {
                    anchors.fill: parent
                    source: root.previewSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: previewMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }
            }

            // Acciones adicionales que ofrece la app
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.extraActions.length > 0
                spacing: 6

                Repeater {
                    model: root.extraActions

                    Rectangle {
                        id: pill

                        required property var modelData

                        width: label.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: pillArea.containsMouse ? Theme.accent : Theme.track

                        Text {
                            id: label

                            anchors.centerIn: parent
                            text: pill.modelData.text
                            color: pillArea.containsMouse ? "#14131a" : Theme.text
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: pillArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.invokeAction(root.entry, pill.modelData.identifier)
                        }
                    }
                }
            }
        }
    }

    // Cerrar
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 24
        height: 24
        radius: 12
        opacity: hover.hovered ? 1 : 0
        visible: opacity > 0.01
        color: closeArea.containsMouse ? Theme.danger : Theme.track

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        MIcon {
            anchors.centerIn: parent
            name: "close"
            font.pixelSize: 14
            color: closeArea.containsMouse ? "#14131a" : Theme.textDim
        }

        MouseArea {
            id: closeArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.dismiss(root.entry)
        }
    }
}
