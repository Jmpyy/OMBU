pragma Singleton

import QtQuick
import Quickshell

// Datos de esta instalación. install.sh reemplaza los valores marcados con @@ por los reales
// (y deja el modo de prueba apagado); estos son los de desarrollo.
Singleton {
    // Usuario que inicia sesión (el greeter es de un solo usuario)
    readonly property string user: Quickshell.env("OMBU_GREETER_USER") ?? ""
    // Monitor donde se muestra el formulario; en los demás solo fondo y reloj
    readonly property string primaryOutput: Quickshell.env("OMBU_GREETER_OUTPUT") ?? ""
    // Comando de la sesión y variables que se le pasan (igual que hacía el greeter de Noctalia)
    readonly property var session: ["/usr/bin/start-hyprland"]
    readonly property var environment: ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_CURRENT_DESKTOP=Hyprland"]
    // Carpeta donde el greeter avisa que arrancó bien (la vigila run-greeter.sh)
    readonly property string runtimeDir: Quickshell.env("OMBU_GREETER_RT") ?? "/tmp/ombu-greeter"
    // Modo de prueba: ventana común en lugar de pantalla completa e intentos automáticos de
    // contraseña contra un greetd falso. Apagado en la instalación real.
    readonly property bool testMode: (Quickshell.env("OMBU_GREETER_TEST") ?? "") === "1"
}
