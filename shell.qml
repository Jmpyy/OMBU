import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire

ShellRoot {
    // Sin esto Pipewire no entrega volumen ni mute de los nodos
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    // Historial del portapapeles (lo usa Super+V, ver bin/clip.sh)
    Process {
        running: true
        command: [Quickshell.shellPath("bin/clipwatch.sh")]
    }

    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens

        TopBar {}
    }

    Variants {
        model: Quickshell.screens

        VolumeOsd {}
    }

    Variants {
        model: Quickshell.screens

        NotifToasts {}
    }

    Variants {
        model: Quickshell.screens

        LockPreview {}
    }

    Lock {}


    Variants {
        model: Quickshell.screens

        PowerMenu {}
    }

    Variants {
        model: Quickshell.screens

        LauncherMenu {}
    }

    // qs -c nuestro ipc call bar toggle  -> mostrar/ocultar la barra
    // qs -c nuestro ipc call bar mixer   -> abrir/cerrar la mezcladora (monitor con foco)
    // qs -c nuestro ipc call bar apps    -> abrir/cerrar las apps abiertas (monitor con foco)
    IpcHandler {
        function toggle(): void {
            Ui.barShown = !Ui.barShown;
        }

        function mixer(): void {
            const key = "mixer@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        function calendar(): void {
            const key = "calendar@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        function apps(): void {
            const key = "apps@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        target: "bar"
    }

    // qs -c nuestro ipc call launcher toggle
    // qs -c nuestro ipc call launcher search "texto"  -> abre con el texto ya escrito
    IpcHandler {
        function toggle(): void {
            Ui.powerOpen = false;
            Ui.popup = "";
            // Solo se limpia al abrir: al cerrar, el texto queda hasta que termina la animación
            if (!Ui.launcherOpen)
                Ui.launcherPrefill = "";
            Ui.launcherOpen = !Ui.launcherOpen;
        }

        function search(text: string): void {
            Ui.powerOpen = false;
            Ui.popup = "";
            Ui.launcherPrefill = text;
            Ui.launcherOpen = true;
        }

        function close(): void {
            Ui.launcherOpen = false;
        }

        target: "launcher"
    }

    // qs -c nuestro ipc call notif dismiss     -> cerrar la última notificación
    // qs -c nuestro ipc call notif dismissAll  -> cerrar todas
    // qs -c nuestro ipc call notif invoke      -> ejecutar la acción de la última
    // qs -c nuestro ipc call notif dnd         -> activar o desactivar No molestar
    // qs -c nuestro ipc call notif history     -> abrir o cerrar el historial
    IpcHandler {
        function dismiss(): void {
            Notifs.dismissLatest();
        }

        function dismissAll(): void {
            Notifs.dismissAll();
        }

        function invoke(): void {
            Notifs.invokeLatest();
        }

        function dnd(): void {
            Notifs.dnd = !Notifs.dnd;
        }

        function history(): void {
            const key = "notifs@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        target: "notif"
    }

    // qs -c nuestro ipc call lock lock     -> bloqueo REAL de la sesión
    // qs -c nuestro ipc call lock preview  -> vista previa (ventana común, Esc la cierra)
    // No existe un comando para desbloquear a propósito: cualquier proceso del usuario
    // podría usarlo. El bloqueo real solo se abre con la contraseña.
    IpcHandler {
        function lock(): void {
            Ui.lockPreview = false;
            Ui.locked = true;
        }

        function preview(): void {
            // Nunca puede tocar un bloqueo real que ya esté activo
            if (Ui.locked && !Ui.lockPreview)
                return;
            Ui.lockPreview = true;
            Ui.locked = true;
        }

        // Solo cierra la vista previa; jamás un bloqueo real
        function closePreview(): void {
            if (Ui.lockPreview)
                Ui.locked = false;
        }

        target: "lock"
    }

    // qs -c nuestro ipc call power toggle
    IpcHandler {
        function toggle(): void {
            Ui.powerOpen = !Ui.powerOpen;
        }

        target: "power"
    }
}
