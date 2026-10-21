pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Autenticación con PAM para el bloqueo de pantalla.
// La contraseña solo vive en memoria el instante que tarda PAM en pedirla.
Singleton {
    id: root

    // idle | checking | failed
    property string state: "idle"
    property string message: ""

    property string pending: ""

    function submit(password: string): void {
        if (state === "checking" || password.length === 0)
            return;
        pending = password;
        state = "checking";
        message = "";
        if (!pam.start()) {
            pending = "";
            state = "failed";
            message = "No se pudo iniciar la verificación";
        }
    }

    function reset(): void {
        if (state !== "checking") {
            state = "idle";
            message = "";
        }
    }

    PamContext {
        id: pam

        config: "unlock"
        configDirectory: Quickshell.shellPath("pam.d")

        onPamMessage: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            }
        }

        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success) {
                root.state = "idle";
                root.message = "";
                Ui.locked = false;
            } else {
                root.state = "failed";
                root.message = result === PamResult.MaxTries ? "Demasiados intentos" : (result === PamResult.Error ? "Error del sistema de autenticación" : "Contraseña incorrecta");
            }
        }

        onError: error => {
            root.pending = "";
            root.state = "failed";
            root.message = "No se pudo verificar la contraseña";
        }
    }

    // Si PAM no contesta (un módulo colgado, una contraseña vencida que pide otra), el campo quedaba
    // deshabilitado en «Verificando…» para siempre y no había forma de entrar sin reiniciar
    Timer {
        interval: 20000
        running: root.state === "checking"
        onTriggered: {
            pam.abort();
            root.pending = "";
            root.state = "failed";
            root.message = "La verificación tardó demasiado: probá de nuevo";
        }
    }

    Connections {
        target: Ui

        function onLockedChanged() {
            if (!Ui.locked) {
                root.pending = "";
                root.state = "idle";
                root.message = "";
            }
        }
    }
}
