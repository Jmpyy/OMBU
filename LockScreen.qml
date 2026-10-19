import QtQuick
import QtQuick.Layouts
import Quickshell

// Contenido de la pantalla de bloqueo (se usa tanto en la vista previa como en el bloqueo real).
//
// Composición: al centro el reloj, el saludo, el avatar con su anillo de segundos y el campo de
// contraseña; a la izquierda lo que suena; a la derecha las notificaciones; abajo los avisos
// de teclado y los botones de energía. El salvapantallas lo tapa todo cuando está activo.
Item {
    id: root

    // En vista previa Esc cierra la ventana; en el bloqueo real Esc solo borra lo escrito
    property bool preview: false

    readonly property string userName: Quickshell.env("USER") ?? ""
    readonly property string displayName: (userName === "jmpyy" || userName === "juampy") ? "JUAMPY" : userName.toUpperCase()
    readonly property string greeting: {
        const h = Chrono.date.getHours();
        return h < 6 ? "Buenas noches" : (h < 13 ? "Buen día" : (h < 20 ? "Buenas tardes" : "Buenas noches"));
    }
    property real shakeX: 0

    function focusInput(): void {
        input.forceActiveFocus();
    }

    Component.onCompleted: Qt.callLater(focusInput)

    LockBackdrop {
        anchors.fill: parent
        animating: Saver.fade < 0.99
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 0

        // Reloj: los dos puntos laten despacio
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

                text: ":"
                color: Theme.comic ? Theme.text : "#f4f4fa"
                font.family: Theme.displayFont || Qt.application.font.family
                font.pixelSize: Theme.comic ? 150 : 132
                font.weight: Theme.comic ? Font.Normal : Font.Light
                font.letterSpacing: Theme.comic ? 4 : 0

                // Parpadea una vez por segundo con un fundido corto (una animación continua haría
                // redibujar toda la pantalla 60 veces por segundo)
                property bool lit: true

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
                    running: root.visible && Saver.fade < 0.99
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
            Layout.preferredHeight: Theme.comic ? 28 : 44
        }

        // Sticker estilo Peter Parker en temas de cómic, o Avatar común en el resto
        NameBadge {
            visible: Theme.comic
            Layout.alignment: Qt.AlignHCenter
            name: root.displayName
            alert: Auth.state === "failed"
            transform: Translate {
                x: root.shakeX
            }
        }

        AvatarRing {
            visible: !Theme.comic
            Layout.alignment: Qt.AlignHCenter
            letter: root.userName.charAt(0).toUpperCase()
            alert: Auth.state === "failed"
        }

        Text {
            visible: !Theme.comic
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            text: root.greeting + ", " + root.userName
            color: "#f4f4fa"
            font.pixelSize: 18
            font.weight: Font.Medium
        }

        // Campo de contraseña: se ensancha al enfocarlo
        Item {
            id: fieldContainer

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.comic ? 28 : 22
            Layout.preferredWidth: input.activeFocus ? 380 : 340
            Layout.preferredHeight: 54

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            HardShadow {
                target: field
                offset: 5
            }

            Rectangle {
                id: field

                anchors.fill: parent
                radius: Theme.comic ? 10 : 27
                color: Theme.bg
                border.width: Theme.comic ? 2 : 1
                border.color: Auth.state === "failed" ? Theme.danger : (input.activeFocus ? Theme.accent : (Theme.comic ? Theme.ink : Theme.border))
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
                        selectedTextColor: Theme.accentText
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

                        // Cualquier tecla despierta el salvapantallas (y la letra igual se escribe)
                        Keys.onPressed: event => {
                            Saver.wake();
                            // Hyprland no avisa del Bloq Mayús: se vuelve a leer tras apretarlo
                            if (event.key === Qt.Key_CapsLock)
                                Keyboard.refreshLeds();
                            event.accepted = false;
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
                                duration: 150
                            }
                        }

                        MIcon {
                            anchors.centerIn: parent
                            name: input.echoMode === TextInput.Password ? "visibility" : "visibility_off"
                            color: Theme.textDim
                            font.pixelSize: 18
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
                        radius: Theme.comic ? 8 : 19
                        color: input.text.length > 0 ? Theme.accent : Theme.surface
                        border.width: Theme.comic ? 1.5 : 0
                        border.color: Theme.comic ? Theme.ink : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        MIcon {
                            anchors.centerIn: parent
                            name: Auth.state === "checking" ? "hourglass_top" : "arrow_forward"
                            color: input.text.length > 0 ? Theme.accentText : Theme.textDim
                            font.pixelSize: 20
                        }

                        TapHandler {
                            onTapped: input.accepted()
                        }
                    }
                }
            }
        }

        // Estado de la verificación y aviso de Bloq Mayús
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.preferredWidth: 320
            Layout.preferredHeight: 32

            Text {
                anchors.centerIn: parent
                visible: !Keyboard.caps || Auth.state === "failed" || Auth.state === "checking"
                text: Auth.state === "checking" ? "Verificando…" : Auth.message
                color: Auth.state === "failed" ? Theme.danger : Theme.textDim
                font.pixelSize: 14
            }

            LockChip {
                anchors.centerIn: parent
                visible: Keyboard.caps && Auth.state === "idle"
                icon: "keyboard_capslock"
                label: "Bloq Mayús activado"
                warn: true
            }
        }
    }

    // Lo que suena, a la izquierda
    LockMedia {
        anchors.left: parent.left
        anchors.leftMargin: 56
        anchors.verticalCenter: parent.verticalCenter
    }

    // Notificaciones pendientes (solo app y título), a la derecha
    LockNotifs {
        anchors.right: parent.right
        anchors.rightMargin: 56
        anchors.verticalCenter: parent.verticalCenter
    }

    // Abajo al centro: layout de teclado (importa al escribir con símbolos)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38
        spacing: 10

        LockChip {
            icon: "keyboard"
            label: Keyboard.code
        }

        LockChip {
            visible: root.preview
            label: "Vista previa · Esc para cerrar"
        }
    }

    // Abajo a la derecha: energía
    LockPower {
        anchors.right: parent.right
        anchors.rightMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
    }

    // Abajo a la izquierda: la marca
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

    // Salvapantallas: lluvia de código con el logo. Tapa todo mientras está activo y se
    // desvanece al tocar una tecla o mover el mouse, dejando ver la pantalla de bloqueo.
    SaverView {
        anchors.fill: parent
        amount: Saver.fade
    }

    // Cualquier actividad en la pantalla de bloqueo despierta el salvapantallas
    HoverHandler {
        onPointChanged: Saver.pointer(point.position.x, point.position.y)
    }

    TapHandler {
        onTapped: Saver.wake()
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
