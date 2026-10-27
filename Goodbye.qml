pragma Singleton

import QtQuick
import Quickshell

// Despedida antes de apagar, reiniciar o cerrar sesión: la pantalla se funde a negro con el logo del tema
// y «Apagando…» (GoodbyeView), y recién después se manda la orden. Lo usan el menú de energía, el del
// sistema y los botones de la pantalla de bloqueo. La orden se lanza con execDetached: los menús se
// destruyen al cerrarse (LazyLoader) y un Process suyo moriría con ellos.
Singleton {
    id: root

    // "" | "poweroff" | "reboot" | "logout"
    property string action: ""
    // Prueba (ipc call power goodbye): toda la despedida, pero sin mandar la orden
    property bool dry: false

    readonly property var commands: ({
            poweroff: ["systemctl", "poweroff"],
            reboot: ["systemctl", "reboot"],
            logout: ["hyprctl", "dispatch", "hl.dsp.exit()"]
        })
    readonly property string label: action === "reboot" ? "Reiniciando…" : (action === "logout" ? "Cerrando sesión…" : "Apagando…")

    function test(): void {
        if (action !== "")
            return;
        dry = true;
        run("poweroff");
    }

    function run(kind: string): void {
        if (action !== "" || !commands[kind])
            return;
        Ui.powerOpen = false;
        Ui.sysMenuOpen = false;
        Ui.launcherOpen = false;
        Ui.popup = "";
        action = kind;
        go.restart();
    }

    // Tiempo para ver la despedida antes de que el sistema empiece a cerrar todo
    Timer {
        id: go

        interval: 1500
        onTriggered: {
            if (root.dry) {
                console.log("DESPEDIDA: prueba, no se apaga nada");
                root.dry = false;
                root.action = "";
                return;
            }
            console.log("DESPEDIDA: " + root.commands[root.action].join(" "));
            Quickshell.execDetached(root.commands[root.action]);
            giveUp.restart();
        }
    }

    // Si a los 15 s seguimos acá, algo lo frenó (un programa que pide esperar, otra sesión abierta): se
    // vuelve al escritorio y se avisa, en vez de quedar con la pantalla negra
    Timer {
        id: giveUp

        interval: 15000
        onTriggered: {
            const what = root.action === "reboot" ? "reiniciar" : (root.action === "logout" ? "cerrar la sesión" : "apagar");
            root.action = "";
            Quickshell.execDetached(["notify-send", "-a", "Sistema", "-i", "dialog-warning", "No se pudo " + what, "Algo frenó la orden. Probá de nuevo o mirá journalctl -b."]);
        }
    }
}
