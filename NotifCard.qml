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

    // Confirmación de un comando de un agente (bin/agent-confirm.py)
    readonly property bool confirm: entry.kind === "confirm"
    readonly property color confirmColor: entry.risky ? Theme.warn : Theme.accent
    readonly property var confirmActions: ["allow", "deny", "focus"].map(id => entry.actionList.find(a => a.identifier === id)).filter(a => a)
    readonly property string cwdShort: {
        const home = Quickshell.env("HOME") ?? "";
        const c = entry.cwd;
        return home !== "" && c.startsWith(home) ? "~" + c.slice(home.length) : c;
    }

    // Las capturas de pantalla traen su imagen: se muestra grande, como miniatura
    readonly property string previewSource: {
        if (entry.appName !== "Capturas")
            return "";
        let path = entry.image || entry.appIcon;
        if (!path)
            return "";
        // Quickshell entrega el ícono de la app como image://icon/LO-QUE-PIDIÓ-LA-APP
        if (path.startsWith("image://icon/"))
            path = path.slice("image://icon/".length);
        // Solo archivos de imagen: un nombre de ícono del tema no es una captura
        if (path.startsWith("file://"))
            return path;
        return path.startsWith("/") ? "file://" + path : "";
    }

    // Los íconos de tema llegan como image://icon/NOMBRE: si el tema no tiene ese ícono, Qt dibuja un
    // cuadro magenta de error en su lugar. Se resuelve por nombre y, si falta, no se muestra nada.
    function resolveIcon(src: string): string {
        if (!src.startsWith("image://icon/"))
            return src;
        const name = src.slice("image://icon/".length);
        return name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true);
    }

    readonly property string iconSource: {
        if (previewSource !== "")
            return "";
        if (entry.image)
            return resolveIcon(entry.image);
        if (entry.appIcon) {
            if (entry.appIcon.startsWith("/"))
                return "file://" + entry.appIcon;
            return resolveIcon(entry.appIcon.startsWith("image://") ? entry.appIcon : "image://icon/" + entry.appIcon);
        }
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

    implicitHeight: content.implicitHeight + (timed ? 32 : 26)
    radius: 14
    color: floating ? Theme.bg : Theme.surface
    border.width: floating ? 1 : 0
    border.color: hover.hovered ? Qt.rgba(1, 1, 1, 0.32) : Theme.outline

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
        anchors.leftMargin: 14
        anchors.bottomMargin: 8
        height: 2
        radius: 1
        width: (parent.width - 28) * root.entry.remaining
        color: root.entry.critical ? Theme.danger : Theme.accent
        opacity: hover.hovered ? 0.9 : 0.5

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
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: Theme.controlRadius
            color: root.confirm ? Qt.rgba(root.confirmColor.r, root.confirmColor.g, root.confirmColor.b, 0.16) : (root.floating ? Theme.surface : Theme.bg)

            Image {
                id: icon

                anchors.centerIn: parent
                width: 28
                height: 28
                visible: !root.confirm && source != "" && status !== Image.Error
                source: root.iconSource
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MIcon {
                anchors.centerIn: parent
                visible: root.confirm || !icon.visible
                name: root.confirm ? (root.entry.risky ? "warning" : "terminal") : (root.entry.appName === "Capturas" ? "photo_camera" : "notifications")
                color: root.confirm ? root.confirmColor : Theme.textDim
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
                visible: text.length > 0 && !root.confirm
                text: root.entry.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.72)
                font.pixelSize: 13
            }

            // Confirmación de un comando: carpeta, comando completo, aviso de riesgo y botones
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.confirm
                spacing: 8

                Row {
                    visible: root.entry.cwd !== ""
                    spacing: 6

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "folder_open"
                        color: Theme.textDim
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 270)
                        text: root.cwdShort
                        elide: Text.ElideMiddle
                        color: Theme.textDim
                        font.pixelSize: 12
                    }
                }

                // El comando, completo y en tipografía de código
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: cmdText.implicitHeight + 20
                    radius: 10
                    color: "#0f0e14"
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: cmdText

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        text: "$ " + root.entry.body
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 9
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: "CaskaydiaCove Nerd Font Mono"
                        font.pixelSize: 12
                        lineHeight: 1.15
                    }
                }

                // Comando delicado: no se aprueba desde la tarjeta
                Rectangle {
                    visible: root.entry.risky
                    Layout.fillWidth: true
                    implicitHeight: riskText.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.14)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        MIcon {
                            name: "warning"
                            color: Theme.warn
                            font.pixelSize: 17
                        }

                        Text {
                            id: riskText

                            width: parent.width - 28
                            text: "Comando delicado: revisalo en la consola. Desde acá solo podés denegarlo."
                            wrapMode: Text.Wrap
                            color: Theme.warn
                            font.pixelSize: 12
                        }
                    }
                }

                Text {
                    visible: root.entry.compound && !root.entry.risky
                    Layout.fillWidth: true
                    text: "Encadena varias órdenes o redirige la salida: leelas completas."
                    wrapMode: Text.Wrap
                    color: Theme.textDim
                    font.pixelSize: 12
                }

                // Botones: lo principal arriba, lo destructivo en rojo, lo demás discreto
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    Repeater {
                        model: root.confirmActions

                        Rectangle {
                            id: btn

                            required property var modelData
                            readonly property bool primary: modelData.identifier === "allow"
                            readonly property bool danger: modelData.identifier === "deny"

                            Layout.fillWidth: primary || danger
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: primary || danger ? 1 : label.implicitWidth + 28
                            radius: Theme.controlRadius
                            color: btn.primary ? (btnArea.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent) : (btn.danger && btnArea.containsMouse ? Theme.danger : (btnArea.containsMouse ? Theme.hover : "transparent"))
                            border.width: btn.primary ? 0 : 1
                            border.color: btn.danger ? Theme.danger : Theme.border

                            Text {
                                id: label

                                anchors.centerIn: parent
                                text: btn.modelData.text
                                color: btn.primary || (btn.danger && btnArea.containsMouse) ? "#14131a" : (btn.danger ? Theme.danger : Theme.textDim)
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: btnArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.invokeAction(root.entry, btn.modelData.identifier)
                            }
                        }
                    }
                }
            }

            // Miniatura (solo las capturas de pantalla)
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.preferredHeight: 120
                visible: root.previewSource !== "" && preview.status !== Image.Error

                Rectangle {
                    id: previewMask

                    anchors.fill: parent
                    radius: 12
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: preview

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
                visible: root.extraActions.length > 0 && !root.confirm
                spacing: 6

                Repeater {
                    model: root.extraActions

                    Rectangle {
                        id: pill

                        required property var modelData

                        width: label.implicitWidth + 24
                        height: 26
                        radius: 8
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
        width: 22
        height: 22
        radius: 7
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
