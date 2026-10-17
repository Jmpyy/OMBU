import QtQuick
import Quickshell
import Quickshell.Wayland

// Greeter de ombu para greetd. Corre como el usuario "greeter" dentro de un Hyprland mínimo
// (ver hyprland.lua.in y run-greeter.sh), antes de que exista la sesión del usuario.
ShellRoot {
    id: root

    readonly property bool test: GreeterConfig.testMode
    // Intentos automáticos de contraseña, SOLO en modo de prueba y contra un greetd falso
    readonly property var testAttempts: (Quickshell.env("OMBU_GREETER_TEST_PASSWORDS") ?? "").split(",").filter(p => p.length > 0)
    property int attempt: 0

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property var modelData
            // El formulario va en el monitor principal; si no está, en el primero
            readonly property bool primary: GreeterConfig.primaryOutput !== "" && Quickshell.screens.some(s => s.name === GreeterConfig.primaryOutput) ? modelData.name === GreeterConfig.primaryOutput : modelData === Quickshell.screens[0]

            // Instalación real: una ventana a pantalla completa por monitor
            PanelWindow {
                screen: scope.modelData
                visible: !root.test
                color: "#08070d"
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "ombu-greeter"
                WlrLayershell.keyboardFocus: scope.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                GreeterScreen {
                    anchors.fill: parent
                    interactive: scope.primary
                }
            }

            // Pruebas: una ventana común en el monitor actual
            FloatingWindow {
                visible: root.test && scope.primary
                implicitWidth: 1280
                implicitHeight: 720
                color: "#08070d"

                GreeterScreen {
                    anchors.fill: parent
                }
            }
        }
    }

    // Avisa a run-greeter.sh que la interfaz arrancó bien; si no llega, ese script cierra todo
    // y el respaldo pone el greeter de Noctalia
    Timer {
        interval: 1500
        running: Quickshell.screens.length > 0
        onTriggered: Quickshell.execDetached(["sh", "-c", "mkdir -p '" + GreeterConfig.runtimeDir + "' && touch '" + GreeterConfig.runtimeDir + "/ready'"])
    }

    // Solo pruebas: manda los intentos de contraseña de OMBU_GREETER_TEST_PASSWORDS, uno cada 4 s
    Timer {
        interval: 4000
        repeat: true
        running: root.test && root.attempt < root.testAttempts.length
        onTriggered: {
            GreeterAuth.submit(root.testAttempts[root.attempt]);
            root.attempt++;
        }
    }
}
