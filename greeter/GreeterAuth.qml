pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Greetd

// Inicio de sesión contra greetd. La contraseña solo vive en memoria el instante que tarda
// greetd (y PAM) en pedirla.
Singleton {
    id: root

    // idle | checking | failed | launching
    property string state: "idle"
    property string message: ""

    property string pending: ""

    function fail(text: string): void {
        pending = "";
        state = "failed";
        message = text;
    }

    function submit(password: string): void {
        if (state === "checking" || state === "launching" || password.length === 0)
            return;
        if (!Greetd.available) {
            fail("No hay conexión con greetd");
            return;
        }
        pending = password;
        state = "checking";
        message = "";
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        Greetd.createSession(GreeterConfig.user);
    }

    function reset(): void {
        if (state === "failed") {
            state = "idle";
            message = "";
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired) {
                Greetd.respond(root.pending);
                root.pending = "";
            }
        }

        function onAuthFailure(message: string): void {
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
            root.fail("Contraseña incorrecta");
        }

        function onReadyToLaunch(): void {
            root.state = "launching";
            // Un instante para que se vea "Iniciando sesión…" antes de que el greeter se cierre
            launchTimer.start();
        }

        function onError(error: string): void {
            root.fail("Error de greetd");
            console.warn("ombu-greeter: error de greetd:", error);
        }
    }

    Timer {
        id: launchTimer

        interval: 450
        onTriggered: Greetd.launch(GreeterConfig.session, GreeterConfig.environment, true)
    }
}
