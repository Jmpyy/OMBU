import QtQuick
import QtQuick.Layouts
import Quickshell

// Pantalla de inicio de sesión de ombu: mismo estilo que la pantalla de bloqueo.
// En el monitor principal lleva el formulario; en los demás solo el fondo y el reloj.
Item {
    id: root

    // false: solo fondo, reloj y fecha (monitores secundarios)
    property bool interactive: true

    readonly property string userName: GreeterConfig.user
    // Nombre del cartel de los temas de cómic (el mismo que usa la pantalla de bloqueo)
    readonly property string displayName: (userName === "jmpyy" || userName === "juampy") ? "JUAMPY" : userName.toUpperCase()
    readonly property bool busy: GreeterAuth.state === "checking" || GreeterAuth.state === "launching"
    readonly property string greeting: {
        const h = Chrono.date.getHours();
        return h < 6 ? "Buenas noches" : (h < 13 ? "Buen día" : (h < 20 ? "Buenas tardes" : "Buenas noches"));
    }
    property real shakeX: 0

    function focusInput(): void {
        if (interactive)
            input.forceActiveFocus();
    }

    Component.onCompleted: {
        Keyboard.watch = interactive;
        Qt.callLater(focusInput);
    }

    LockBackdrop {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.interactive ? -40 : 0
        spacing: 0

        Row {
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: Chrono.date.toLocaleString(Chrono.locale, "HH")
                color: Theme.comic ? Theme.text : "#f4f4fa"
                font.family: Theme.displayFont || Qt.application.font.family
                font.pixelSize: Theme.comic ? 150 : 132
                font.weight: Theme.comic ? Font.Normal : Font.Light
                font.letterSpacing: Theme.comic ? 4 : 0
            }

            Text {
                id: colon

                property bool lit: true

                text: ":"
                color: Theme.comic ? Theme.text : "#f4f4fa"
                font.family: Theme.displayFont || Qt.application.font.family
                font.pixelSize: Theme.comic ? 150 : 132
                font.weight: Theme.comic ? Font.Normal : Font.Light
                font.letterSpacing: Theme.comic ? 4 : 0
                opacity: lit ? 1 : 0.28

                Behavior on opacity {
                    NumberAnimation {
                        duration: 450
                        easing.type: Easing.InOutSine
                    }
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: root.visible
                    onTriggered: colon.lit = !colon.lit
                }
            }

            Text {
                text: Chrono.date.toLocaleString(Chrono.locale, "mm")
                color: Theme.comic ? Theme.text : "#f4f4fa"
                font.family: Theme.displayFont || Qt.application.font.family
                font.pixelSize: Theme.comic ? 150 : 132
                font.weight: Theme.comic ? Font.Normal : Font.Light
                font.letterSpacing: Theme.comic ? 4 : 0
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Chrono.capitalize(Chrono.date.toLocaleDateString(Chrono.locale, "dddd d 'de' MMMM"))
            color: Qt.rgba(1, 1, 1, 0.78)
            font.pixelSize: 22
        }

        Item {
            visible: root.interactive
            Layout.preferredHeight: Theme.comic ? 28 : 44
        }

        // Cartel «HELLO my name is…» en los temas de cómic (igual que el bloqueo); el círculo con la inicial en el resto
        NameBadge {
            visible: root.interactive && Theme.comic
            Layout.alignment: Qt.AlignHCenter
            name: root.displayName
            alert: GreeterAuth.state === "failed"
            transform: Translate {
                x: root.shakeX
            }
        }

        AvatarRing {
            visible: root.interactive && !Theme.comic
            Layout.alignment: Qt.AlignHCenter
            letter: root.userName.charAt(0).toUpperCase()
            alert: GreeterAuth.state === "failed"
        }

        Text {
            visible: root.interactive && !Theme.comic
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            text: root.greeting + ", " + root.userName
            color: "#f4f4fa"
            font.pixelSize: 18
            font.weight: Font.Medium
        }

        // Campo de contraseña: se ensancha al enfocarlo
        Rectangle {
            id: field

            visible: root.interactive
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 22
            Layout.preferredWidth: input.activeFocus ? 380 : 340
            Layout.preferredHeight: 54
            radius: 27
            color: Theme.bg
            border.width: 1
            border.color: GreeterAuth.state === "failed" ? Theme.danger : (input.activeFocus ? Theme.accent : Theme.border)
            transform: Translate {
                x: root.shakeX
            }

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
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
                    enabled: !root.busy
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.pixelSize: 17
                    clip: true
                    focus: true

                    onTextChanged: GreeterAuth.reset()

                    onAccepted: {
                        if (text.length === 0)
                            return;
                        const password = text;
                        text = "";
                        GreeterAuth.submit(password);
                    }

                    Keys.onPressed: event => {
                        // Hyprland no avisa del Bloq Mayús: se vuelve a leer tras apretarlo
                        if (event.key === Qt.Key_CapsLock)
                            Keyboard.refreshLeds();
                        event.accepted = false;
                    }

                    Keys.onEscapePressed: text = ""

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Contraseña"
                        color: Theme.textDim
                        font.pixelSize: 17
                    }
                }

                // Ver u ocultar lo escrito
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    opacity: input.text.length > 0 ? 1 : 0
                    visible: opacity > 0.01
                    color: eyeHover.hovered ? Theme.hover : "transparent"

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }

                    MIcon {
                        anchors.centerIn: parent
                        name: input.echoMode === TextInput.Password ? "visibility" : "visibility_off"
                        color: Theme.textDim
                        font.pixelSize: 19
                    }

                    HoverHandler {
                        id: eyeHover
                    }
                    TapHandler {
                        onTapped: input.echoMode = input.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
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
                        name: root.busy ? "hourglass_top" : "arrow_forward"
                        color: input.text.length > 0 ? Theme.accentText : Theme.textDim
                        font.pixelSize: 20
                    }

                    TapHandler {
                        onTapped: input.accepted()
                    }
                }
            }
        }

        // Estado de la verificación y aviso de Bloq Mayús
        Item {
            visible: root.interactive
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.preferredWidth: 320
            Layout.preferredHeight: 32

            Text {
                anchors.centerIn: parent
                visible: !Keyboard.caps || GreeterAuth.state !== "idle"
                text: GreeterAuth.state === "checking" ? "Verificando…" : (GreeterAuth.state === "launching" ? "Iniciando sesión…" : GreeterAuth.message)
                color: GreeterAuth.state === "failed" ? Theme.danger : Theme.textDim
                font.pixelSize: 14
            }

            LockChip {
                anchors.centerIn: parent
                visible: Keyboard.caps && GreeterAuth.state === "idle"
                icon: "keyboard_capslock"
                label: "Bloq Mayús activado"
                warn: true
            }
        }
    }

    // Abajo al centro: layout de teclado (clic para alternar, igual que Alt+Shift)
    Row {
        visible: root.interactive
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38
        spacing: 10

        LockChip {
            icon: "keyboard"
            label: Keyboard.code

            TapHandler {
                onTapped: Keyboard.toggle()
            }
        }

        LockChip {
            icon: "desktop_windows"
            label: "Hyprland"
        }
    }

    LockPower {
        visible: root.interactive
        anchors.right: parent.right
        anchors.rightMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 52
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 42
        text: "ombu"
        color: Qt.rgba(1, 1, 1, 0.4)
        font.pixelSize: 15
        font.weight: Font.DemiBold
        font.letterSpacing: 3
    }

    // Al iniciar sesión la pantalla se oscurece suavemente
    Rectangle {
        anchors.fill: parent
        color: "#08070d"
        opacity: GreeterAuth.state === "launching" ? 0.55 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
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
        target: GreeterAuth

        function onStateChanged() {
            if (GreeterAuth.state === "failed") {
                shake.restart();
                root.focusInput();
            }
        }
    }
}
