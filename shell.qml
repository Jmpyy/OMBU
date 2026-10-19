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
        // Nombrarlo arranca la agenda: feriados, Google Calendar y los recordatorios con hora
        Agenda.check();
        Subs.list;
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

    Variants {
        model: Quickshell.screens

        KeysMenu {}
    }

    Variants {
        model: Quickshell.screens

        SystemMenu {}
    }

    Variants {
        model: Quickshell.screens

        WallpaperPicker {}
    }

    // qs -c ombu ipc call bar toggle  -> mostrar/ocultar la barra
    // qs -c ombu ipc call bar mixer   -> abrir/cerrar la mezcladora (monitor con foco)
    // qs -c ombu ipc call bar apps    -> abrir/cerrar las apps abiertas (monitor con foco)
    IpcHandler {
        function toggle(): void {
            Ui.powerOpen = false;
            Ui.launcherOpen = false;
            Ui.clipOpen = false;
            Ui.popup = "";
            Ui.keysOpen = !Ui.keysOpen;
        }

        function close(): void {
            Ui.keysOpen = false;
        }

        target: "keys"
    }

    // qs -c ombu ipc call media toggle|next|previous|status  -> el reproductor de música
    IpcHandler {
        function toggle(): void {
            Media.toggle();
        }

        function next(): void {
            Media.next();
        }

        function previous(): void {
            Media.previous();
        }

        function status(): string {
            return Media.describe();
        }

        target: "media"
    }

    // qs -c ombu ipc call menu toggle  -> menú del sistema (Super+Alt+Espacio)
    IpcHandler {
        function toggle(): void {
            Ui.powerOpen = false;
            Ui.launcherOpen = false;
            Ui.clipOpen = false;
            Ui.keysOpen = false;
            Ui.popup = "";
            Ui.sysMenuOpen = !Ui.sysMenuOpen;
        }

        function close(): void {
            Ui.sysMenuOpen = false;
        }

        // ipc call menu open "Estilo>Tema"  -> abre el menú directo en esa sección
        function open(path: string): void {
            Ui.powerOpen = false;
            Ui.launcherOpen = false;
            Ui.clipOpen = false;
            Ui.keysOpen = false;
            Ui.popup = "";
            Ui.sysMenuStart = path;
            Ui.sysMenuOpen = true;
        }

        // ipc call menu theme tokyo  -> cambia de tema sin abrir el menú
        function theme(id: string): string {
            if (!Themes.find(id))
                return "no existe " + id + " (hay: " + Themes.palettes.map(p => p.id).join(", ") + ")";
            Themes.set(id);
            return "ok";
        }

        target: "menu"
    }

    // qs -c ombu ipc call subs add Netflix 11850 ARS 6 mama "Mercado Pago"  -> sumar un pago mensual
    //   (moneda ARS o USD; día 1-31, o -1 para el último del mes; quien paga: yo o mama)
    IpcHandler {
        function add(name: string, amount: string, currency: string, day: string, payer: string, method: string): string {
            return Subs.add(name, parseFloat(amount), currency, parseInt(day), payer, method);
        }

        function remove(name: string): string {
            return Subs.remove(name);
        }

        function list(): string {
            return Subs.upcoming.map(u => u.sub.name + ": " + Subs.money(u.sub.amount, u.sub.currency) + ", " + Subs.whenText(u.days).toLowerCase() + " (" + (u.sub.payer === "mama" ? "paga mamá" : "pagás vos") + ")").join("\n");
        }

        target: "subs"
    }

    // qs -c ombu ipc call agenda add 2026-10-20 19:00 "Examen"  -> anotar un evento
    IpcHandler {
        function add(day: string, time: string, title: string, remind: string): void {
            Agenda.add(day, time, title, "", remind === "" ? [0] : remind.split(",").map(x => parseInt(x)), undefined);
        }

        function remove(title: string): void {
            for (const e of Agenda.local.filter(x => x.title === title))
                Agenda.remove(e.id);
        }

        function google(url: string): void {
            Agenda.setUrl(url);
        }

        function reminders(): void {
            Agenda.check();
        }

        // ipc call agenda summary  -> muestra el resumen del día ahora
        function summary(): void {
            Agenda.showSummary();
        }

        // ipc call agenda destination google|local  -> adónde van los eventos nuevos
        function destination(where: string): void {
            Agenda.setCreateInGoogle(where === "google");
        }

        target: "agenda"
    }

    IpcHandler {
        function set(path: string): void {
            Walls.set(path);
        }

        function current(): string {
            return Walls.current;
        }

        // ipc call wallpaper menu  -> selector de fondos (Super+Ctrl+Espacio)
        function menu(): void {
            Ui.powerOpen = false;
            Ui.launcherOpen = false;
            Ui.clipOpen = false;
            Ui.keysOpen = false;
            Ui.sysMenuOpen = false;
            Ui.popup = "";
            Ui.wallMenuOpen = !Ui.wallMenuOpen;
        }

        target: "wallpaper"
    }

    IpcHandler {
        function up(): void {
            Brightness.step(5);
        }

        function down(): void {
            Brightness.step(-5);
        }

        target: "brightness"
    }

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

        function payments(): void {
            const key = "payments@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        function control(): void {
            const key = "control@" + (Hyprland.focusedMonitor?.name ?? "");
            Ui.popup = Ui.popup === key ? "" : key;
        }

        function walls(): void {
            Ui.popup = "";
            Ui.wallMenuOpen = !Ui.wallMenuOpen;
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

        // focus kit programacion|matematica|otro · focus open (todo el entorno) · focus tool notebook|ide|ai
        function kit(name: string): void {
            Focus.setKit(name);
        }

        function open(): void {
            Focus.openKit();
        }

        function tool(name: string): void {
            Focus.openTool(name);
        }

        function mode(name: string): void {
            Focus.setMode(name);
        }

        function idea(text: string): void {
            Focus.saveIdea(text);
        }

        // ipc call focus ideaDelete "texto"  -> borra la idea con ese texto
        function ideaDelete(text: string): string {
            const found = Focus.ideas.find(i => i.text === text);
            if (!found)
                return "no encontrada";
            Focus.deleteIdea(found.line);
            return "borrada";
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

        // ipc call launcher preview  -> vista previa (Quick Look) de la fila elegida
        function preview(): void {
            Ui.launcherPreviewTick += 1;
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
