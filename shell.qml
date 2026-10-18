import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

ShellRoot {
    // Sin esto Pipewire no entrega volumen ni mute de los nodos
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        // Nombrarlo crea el detector de inactividad (bloqueo a los 5 min, monitores a los 30)
        Idle.start();
    }

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

        WelcomeWindow {}
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

    Variants {
        model: Quickshell.screens

        FocusBlock {}
    }

    Variants {
        model: Quickshell.screens

        ClipMenu {}
    }

    // qs -c ombu ipc call bar toggle  -> mostrar/ocultar la barra
    // qs -c ombu ipc call bar mixer   -> abrir/cerrar la mezcladora (monitor con foco)
    // qs -c ombu ipc call bar apps    -> abrir/cerrar las apps abiertas (monitor con foco)
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

        // Abre o cierra el menú del primer ícono de la bandeja (monitor con foco)
        function tray(): void {
            const item = SystemTray.items.values[0];
            if (!item)
                return;
            const key = "tray-" + item.id + "@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        function devices(): void {
            const key = "devices@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        function focus(): void {
            const key = "focus@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        function apps(): void {
            const key = "apps@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        target: "bar"
    }

    // qs -c ombu ipc call focus start|pause|stop|skip|mode estudio|idea "texto"|status
    IpcHandler {
        function start(): void {
            Focus.start();
        }

        function pause(): void {
            Focus.pause();
        }

        function stop(): void {
            Focus.stop();
        }

        function skip(): void {
            Focus.next(false);
        }

        function closeblocked(): void {
            Focus.closeBlocked();
        }

        function mode(name: string): void {
            Focus.setMode(name);
        }

        function idea(text: string): void {
            Focus.saveIdea(text);
        }

        function status(): string {
            return Focus.mode + " " + (Focus.running ? Focus.phase + " " + Focus.clock(Focus.remaining) : "parado") + " | hoy " + Focus.minutesText(Focus.studyToday) + ", " + Focus.cycles + " bloques, racha " + Focus.streak + " | bloqueo " + (Focus.blocking ? "activo" : "inactivo");
        }

        target: "focus"
    }

    // qs -c ombu ipc call launcher toggle
    // qs -c ombu ipc call launcher search "texto"  -> abre con el texto ya escrito
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

        // Abre o enfoca una app por su id (ej. "org.kde.dolphin")
        function run(id: string): void {
            Launch.open(DesktopEntries.applications.values.find(e => e.id === id), false);
        }

        target: "launcher"
    }

    // qs -c ombu ipc call clip toggle  -> abrir o cerrar el historial del portapapeles
    IpcHandler {
        function toggle(): void {
            Ui.powerOpen = false;
            Ui.launcherOpen = false;
            Ui.popup = "";
            Ui.clipOpen = !Ui.clipOpen;
        }

        function close(): void {
            Ui.clipOpen = false;
        }

        target: "clip"
    }

    // qs -c ombu ipc call notif dismiss     -> cerrar la última notificación
    // qs -c ombu ipc call notif dismissAll  -> cerrar todas
    // qs -c ombu ipc call notif invoke      -> ejecutar la acción de la última
    // qs -c ombu ipc call notif dnd         -> activar o desactivar No molestar
    // qs -c ombu ipc call notif history     -> abrir o cerrar el historial
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

    // qs -c ombu ipc call lock lock     -> bloqueo REAL de la sesión
    // qs -c ombu ipc call lock preview  -> vista previa (ventana común, Esc la cierra)
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

        // Vista previa con el salvapantallas ya a la vista (inofensiva: Esc la cierra)
        function saver(): void {
            if (Ui.locked && !Ui.lockPreview)
                return;
            if (Ui.locked) {
                Saver.active = true;
                return;
            }
            Idle.lockedByIdle = true;
            Ui.lockPreview = true;
            Ui.locked = true;
        }

        target: "lock"
    }

    // qs -c ombu ipc call idle test 10  -> simula la inactividad con 10 s: abre la vista previa
    //                                      en vez de bloquear y no apaga los monitores
    // qs -c ombu ipc call idle reset    -> vuelve a los tiempos normales
    IpcHandler {
        function test(seconds: int): void {
            Idle.testMode = true;
            Idle.lockSeconds = seconds;
            Idle.rearm();
        }

        function reset(): void {
            Idle.testMode = false;
            Idle.lockSeconds = Theme.idleLockSeconds;
            Idle.screenOffSeconds = Theme.idleScreenOffSeconds;
            Idle.rearm();
        }

        target: "idle"
    }

    // qs -c ombu ipc call welcome play  -> repite la bienvenida del inicio de sesión
    IpcHandler {
        function play(): void {
            Welcome.play();
        }

        target: "welcome"
    }

    // qs -c ombu ipc call power toggle
    IpcHandler {
        function toggle(): void {
            Ui.powerOpen = !Ui.powerOpen;
        }

        target: "power"
    }
}
