import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

// Contenido de la pantalla de bloqueo (se usa tanto en la vista previa como en el bloqueo real).
Item {
    id: root

    // En vista previa Esc cierra la ventana; en el bloqueo real Esc solo borra lo escrito
    property bool preview: false

    readonly property string userName: Quickshell.env("USER") ?? ""
    property real shakeX: 0

    function focusInput(): void {
        input.forceActiveFocus();
    }

    Component.onCompleted: Qt.callLater(focusInput)

    // Fondo: el mismo wallpaper, desenfocado y oscurecido
    Image {
        id: wallpaper

        anchors.fill: parent
        source: "file://" + Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.18
        saturation: -0.1
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.45
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Chrono.date.toLocaleString(Chrono.locale, "HH:mm")
            color: "#f4f4fa"
            font.pixelSize: 132
            font.weight: Font.Light
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Chrono.capitalize(Chrono.date.toLocaleDateString(Chrono.locale, "dddd d 'de' MMMM"))
            color: Qt.rgba(1, 1, 1, 0.78)
            font.pixelSize: 22
        }

        Item {
            Layout.preferredHeight: 48
        }

        // Avatar y nombre
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 76
            Layout.preferredHeight: 76
            radius: 38
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: root.userName.charAt(0).toUpperCase()
                color: "#14131a"
                font.pixelSize: 34
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            text: root.userName
            color: "#f4f4fa"
            font.pixelSize: 17
            font.weight: Font.Medium
        }

        // Campo de contraseña
        Rectangle {
            id: field

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 22
            Layout.preferredWidth: 330
            Layout.preferredHeight: 54
            radius: 27
            color: Theme.bg
            border.width: 1
            border.color: Auth.state === "failed" ? Theme.danger : (input.activeFocus ? Theme.accent : Theme.border)
            transform: Translate {
                x: root.shakeX
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 8
                spacing: 12

                MIcon {
                    name: "lock"
                    color: Theme.textDim
                    font.pixelSize: 20
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    enabled: Auth.state !== "checking"
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: "#14131a"
                    font.pixelSize: 17
                    clip: true
                    focus: true

                    onTextChanged: {
                        if (Auth.state === "failed")
                            Auth.reset();
                    }

                    onAccepted: {
                        if (text.length === 0)
                            return;
                        const password = text;
                        text = "";
                        Auth.submit(password);
                    }

                    Keys.onEscapePressed: {
                        if (root.preview)
                            Ui.locked = false;
                        else
                            text = "";
                    }

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Contraseña"
                        color: Theme.textDim
                        font.pixelSize: 17
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: input.text.length > 0 ? Theme.accent : Theme.surface

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    MIcon {
                        anchors.centerIn: parent
                        name: Auth.state === "checking" ? "hourglass_top" : "arrow_forward"
                        color: input.text.length > 0 ? "#14131a" : Theme.textDim
                        font.pixelSize: 20
                    }

                    TapHandler {
                        onTapped: input.accepted()
                    }
                }
            }
        }

        // Estado de la verificación
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.preferredHeight: 20
            text: Auth.state === "checking" ? "Verificando…" : Auth.message
            color: Auth.state === "failed" ? Theme.danger : Theme.textDim
            font.pixelSize: 14
        }
    }

    // Layout de teclado: importa al escribir una contraseña con símbolos
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        spacing: 8

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "keyboard"
            color: Qt.rgba(1, 1, 1, 0.7)
            font.pixelSize: 18
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Keyboard.code
            color: Qt.rgba(1, 1, 1, 0.7)
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.preview
            text: "·  vista previa, Esc para cerrar"
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 13
        }

    }

    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: root
            property: "shakeX"
            to: -12
            duration: 55
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 12
            duration: 90
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: -8
            duration: 80
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 0
            duration: 70
        }
    }

    Connections {
        target: Auth

        function onStateChanged() {
            if (Auth.state === "failed") {
                shake.restart();
                root.focusInput();
            }
        }
    }
}
