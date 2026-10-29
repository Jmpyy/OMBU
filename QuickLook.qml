import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Vista rápida a pantalla completa (Look): una tarjeta grande sobre el fondo oscurecido, en el monitor
// con foco. Espacio o Esc la cierran, ←/→ pasan las páginas de un PDF, Enter abre el archivo en su app.
PanelWindow {
    id: win

    required property var modelData

    // Arranca en 0: la animación de entrada espera al primer cuadro (FirstFrame)
    property real p: 0
    // Monitor en el que se abrió, para completar la animación de salida
    property bool activeOnScreen: false

    Behavior on p {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Theme.ease
        }
    }

    Connections {
        id: opening

        target: Look

        function onOpenChanged(): void {
            if (Look.open && Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    // Se crea recién al abrirse (LazyLoader en shell.qml): el aviso de apertura ya pasó
    Component.onCompleted: if (Look.open)
        opening.onOpenChanged()

    FirstFrame {
        onReady: win.p = Qt.binding(() => Look.open ? 1 : 0)
    }

    readonly property var kindInfo: ({
            "image": ["image", "Imagen"],
            "pdf": ["picture_as_pdf", "PDF"],
            "video": ["movie", "Video"],
            "audio": ["music_note", "Audio"],
            "text": ["description", "Texto"],
            "dir": ["folder", "Carpeta"],
            "other": ["draft", "Archivo"],
            "none": ["error", "No existe"]
        })
    readonly property string detail: {
        const k = Look.kind;
        if (k === "pdf")
            return "PDF · página " + Look.page + " de " + Look.pages;
        if (k === "dir")
            return "Carpeta · " + Look.lines.length + (Look.lines.length === 1 ? " elemento" : " elementos");
        if (k === "text")
            return "Texto · " + Look.lines.length + " líneas";
        if (k === "other")
            return (Look.lines[0] ?? "") + " · " + Math.max(1, Math.round(parseInt(Look.lines[1] ?? "0") / 1024)) + " KB";
        return (kindInfo[k] ?? ["", ""])[1];
    }

    // El teclado (Espacio, Esc, flechas) va a la vista apenas aparece
    onVisibleChanged: if (visible)
        keys.forceActiveFocus()

    screen: modelData
    visible: p > 0.001 && activeOnScreen
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-look"
    WlrLayershell.keyboardFocus: Look.open && activeOnScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Look.close()
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Escape)
                Look.close();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Look.openInApp();
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp)
                Look.turn(-1);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown)
                Look.turn(1);
            else if (event.key === Qt.Key_Down)
                scroller.flick(0, -1200);
            else if (event.key === Qt.Key_Up)
                scroller.flick(0, 1200);
            else
                return;
            event.accepted = true;
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.round(parent.width * 0.86)
        height: Math.round(parent.height * 0.88)
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.p
        scale: 0.97 + 0.03 * win.p

        // Un clic dentro de la tarjeta no la cierra
        MouseArea {
            anchors.fill: parent
        }

        // Encabezado: tipo, nombre, detalle, Abrir y cerrar
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            height: 40

            MIcon {
                id: kindIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: (win.kindInfo[Look.kind] ?? ["draft"])[0]
                color: Theme.textDim
                font.pixelSize: Theme.iconLg
            }

            Column {
                anchors.left: kindIcon.right
                anchors.leftMargin: 12
                anchors.right: actions.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: Look.name
                    elide: Text.ElideMiddle
                    color: Theme.text
                    font.pixelSize: Theme.fontEmphasis
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: Look.loading && Look.kind === "" ? "Cargando…" : win.detail
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font.pixelSize: Theme.fontCaption
                }
            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // La acción principal lleva el acento
                Rectangle {
                    width: openLabel.implicitWidth + 28
                    height: 32
                    radius: Theme.controlRadius
                    color: openArea.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                    visible: Look.kind !== "none"

                    Text {
                        id: openLabel

                        anchors.centerIn: parent
                        text: "Abrir"
                        color: Theme.accentText
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: openArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Look.openInApp()
                    }
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme.controlRadius
                    color: closeArea.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animQuick
                        }
                    }

                    MIcon {
                        anchors.centerIn: parent
                        name: "close"
                    }

                    MouseArea {
                        id: closeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Look.close()
                    }
                }
            }
        }

        // Contenido
        Item {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 16

            // Imagen o página de PDF (los GIF se animan)
            AnimatedImage {
                anchors.fill: parent
                visible: Look.kind === "image" && Look.path.toLowerCase().endsWith(".gif")
                source: visible ? Look.image : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Image {
                anchors.fill: parent
                visible: (Look.kind === "image" && !Look.path.toLowerCase().endsWith(".gif")) || Look.kind === "pdf"
                source: visible ? Look.image : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                // Al tamaño de la pantalla (al doble, en 1080p era decodificar de más)
                sourceSize: Qt.size(body.width, body.height)
                onStatusChanged: if (status === Image.Ready && Look.open)
                    console.log("LOOK:", Look.kind, "visible en", Date.now() - Look.openedAt, "ms")
            }

            // Flechas para pasar las páginas del PDF
            Repeater {
                model: Look.kind === "pdf" && Look.pages > 1 ? [-1, 1] : []

                Rectangle {
                    required property int modelData

                    anchors.verticalCenter: parent.verticalCenter
                    x: modelData < 0 ? 0 : body.width - width
                    width: 40
                    height: 40
                    radius: 20
                    color: arrowArea.containsMouse ? Theme.track : Theme.surface
                    opacity: (modelData < 0 ? Look.page > 1 : Look.page < Look.pages) ? 1 : 0.35

                    MIcon {
                        anchors.centerIn: parent
                        name: parent.modelData < 0 ? "chevron_left" : "chevron_right"
                        font.pixelSize: Theme.iconLg
                    }

                    MouseArea {
                        id: arrowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Look.turn(parent.modelData)
                    }
                }
            }

            // Texto o contenido de una carpeta
            Rectangle {
                anchors.fill: parent
                visible: Look.kind === "text" || Look.kind === "dir"
                radius: Theme.controlRadius
                color: Theme.surface

                Flickable {
                    id: scroller

                    anchors.fill: parent
                    anchors.margins: 16
                    clip: true
                    contentHeight: textView.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: textView

                        width: scroller.width
                        text: Look.kind === "text" || Look.kind === "dir" ? Look.lines.join("\n") : ""
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        color: Theme.text
                        font.family: Look.kind === "text" ? "CaskaydiaCove Nerd Font Mono" : ""
                        font.pixelSize: Look.kind === "text" ? Theme.fontSmall : Theme.fontBody
                        lineHeight: Look.kind === "dir" ? 1.5 : 1.15
                    }
                }
            }

            // Video y audio: se cargan solo cuando hacen falta
            Loader {
                anchors.fill: parent
                active: Look.open && (Look.kind === "video" || Look.kind === "audio")
                source: "LookVideo.qml"
                onLoaded: {
                    item.audioOnly = Look.kind === "audio";
                    item.source = "file://" + (Look.lines[0] ?? "");
                }
            }

            // Lo que no se puede mostrar
            Column {
                anchors.centerIn: parent
                visible: Look.kind === "other" || Look.kind === "none"
                spacing: 12

                MIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Look.kind === "none" ? "error" : "draft"
                    color: Theme.textDim
                    font.pixelSize: 96
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Look.kind === "none" ? "El archivo ya no existe" : "No hay vista previa para este tipo de archivo"
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                }
            }
        }
    }
}
