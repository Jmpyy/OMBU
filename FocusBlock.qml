import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Cartel del modo estudio: aparece cuando se intenta abrir un juego durante un bloque de estudio.
// Muestra qué se va a cerrar, cuánto falta y una frase para volver al estudio. Sale en el monitor
// con foco y no toma el teclado: se puede ignorar y el juego se cierra solo.
PanelWindow {
    id: win

    required property var modelData

    // Arranca en 0: la animación de entrada empieza con el primer cuadro (ver FirstFrame más abajo)
    property real p: 0
    // Monitor en el que apareció, para completar la animación de salida
    property bool activeOnScreen: false

    Behavior on p {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Theme.ease
        }
    }

    Connections {
        id: opening

        target: Focus

        function onNoticeVisibleChanged() {
            if (Focus.noticeVisible && Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    // Se crea recién al abrirse (LazyLoader en shell.qml): el aviso de apertura ya pasó, así que se
    // corre acá; la animación de entrada espera al primer cuadro de la ventana para no verse como un salto
    Component.onCompleted: if (Focus.noticeVisible)
        opening.onNoticeVisibleChanged()

    FirstFrame {
        onReady: win.p = Qt.binding(() => Focus.noticeVisible ? 1 : 0)
    }

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
    WlrLayershell.namespace: "ombu-focus"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p
    }

    Rectangle {
        anchors.centerIn: parent
        width: 440
        height: content.implicitHeight + 56
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.p
        scale: 0.94 + 0.06 * win.p

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 28
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)

                MIcon {
                    anchors.centerIn: parent
                    name: "school"
                    color: Theme.accent
                    font.pixelSize: 30
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Ahora toca estudiar"
                color: Theme.text
                font.pixelSize: Theme.fontHeading
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Focus.noticePhrase
                wrapMode: Text.Wrap
                color: Theme.text
                font.pixelSize: Theme.fontEmphasis
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Focus.noticeLeft > 0 ? Focus.noticeTitle + (Focus.noticeKind === "web" ? " se cierra en " : " se cierra en ") + Focus.noticeLeft + " s" : "Cerrando " + Focus.noticeTitle + "…"
                wrapMode: Text.Wrap
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 19
                    color: backHover.hovered ? Qt.lighter(Theme.accent, 1.12) : Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Cerrar y estudiar"
                        color: Theme.accentText
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: backHover
                    }
                    TapHandler {
                        onTapped: Focus.closeBlocked()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: unlockText.implicitWidth + 32
                    Layout.preferredHeight: 38
                    radius: 19
                    color: unlockHover.hovered ? Theme.hover : "transparent"
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: unlockText

                        anchors.centerIn: parent
                        text: Focus.unlockLeft > 0 ? "Esperá " + Focus.unlockLeft + " s · cancelar" : (Focus.noticeKind === "web" ? "Necesito entrar" : "Necesito jugar")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontBody
                    }

                    HoverHandler {
                        id: unlockHover
                    }
                    TapHandler {
                        onTapped: Focus.unlockLeft > 0 ? Focus.cancelUnlock() : Focus.requestUnlock()
                    }
                }
            }
        }
    }
}
