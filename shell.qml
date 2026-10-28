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
        model: Screens.list

        Wallpaper {}
    }

    // La barra va solo en el monitor principal: en el TV vertical no hacía falta (pedido de la persona) y
    // cada barra crea todos sus menús (~40-60 MB). El TV queda entero para lo que se ponga ahí.
    Variants {
        model: Screens.primary ? [Screens.primary] : []

        TopBar {}
    }

    // La bienvenida solo existe mientras dura (video y lluvia de código ocupan memoria)
    LazyLoader {
        active: Welcome.shown

        Variants {
            model: Screens.list

            WelcomeWindow {}
        }
    }

    Variants {
        model: Screens.list

        VolumeOsd {}
    }

    Variants {
        model: Screens.list

        NotifToasts {}
    }

    // Despedida antes de apagar, reiniciar o cerrar sesión (ver Goodbye): solo existe mientras dura
    LazyLoader {
        active: Goodbye.action !== ""

        Variants {
            model: Screens.list

            GoodbyeWindow {}
        }
    }

    // La vista previa del bloqueo (ipc call lock preview) casi nunca está abierta: se crea al abrirla.
    // El bloqueo real (Lock) no pasa por acá: ext-session-lock crea sus superficies al bloquear.
    Variants {
        model: Screens.list

        LazyLoader {
            id: lockPreview

            required property var modelData

            active: Ui.locked && Ui.lockPreview

            LockPreview {
                modelData: lockPreview.modelData
            }
        }
    }

    Lock {}


    // Menús que casi nunca están abiertos (energía, cartel del modo foco, atajos, menú del sistema, fondos):
    // se crean al abrirlos y se destruyen al terminar de cerrarse (~20 MB menos; la primera aparición
    // tarda ~100-150 ms más). Siguen abiertos mientras su ventana se ve, para la animación de cierre.
    Variants {
        model: Screens.list

        LazyLoader {
            id: powerMenuLoader

            required property var modelData
            // La ventana se ve (la actualiza ella misma): así sigue viva durante la animación de cierre
            property bool shown: false

            active: Ui.powerOpen || shown

            PowerMenu {
                modelData: powerMenuLoader.modelData
                onVisibleChanged: powerMenuLoader.shown = visible
                Component.onCompleted: powerMenuLoader.shown = visible
            }
        }
    }

    Variants {
        model: Screens.list

        LazyLoader {
            id: launcherLoader

            required property var modelData
            // La ventana se ve (la actualiza ella misma): así sigue viva durante la animación de cierre
            property bool shown: false

            active: Ui.launcherOpen || shown

            LauncherMenu {
                modelData: launcherLoader.modelData
                onVisibleChanged: launcherLoader.shown = visible
                Component.onCompleted: launcherLoader.shown = visible
            }
        }
    }

    Variants {
        model: Screens.list

        LazyLoader {
            id: focusBlockLoader

            required property var modelData
            // La ventana se ve (la actualiza ella misma): así sigue viva durante la animación de cierre
            property bool shown: false

            active: Focus.noticeVisible || shown

            FocusBlock {
                modelData: focusBlockLoader.modelData
                onVisibleChanged: focusBlockLoader.shown = visible
                Component.onCompleted: focusBlockLoader.shown = visible
            }
        }
    }

    Variants {
        model: Screens.list

        LazyLoader {
            id: clipLoader

            required property var modelData
            // La ventana se ve (la actualiza ella misma): así sigue viva durante la animación de cierre
            property bool shown: false

            active: Ui.clipOpen || shown

            ClipMenu {
                modelData: clipLoader.modelData
                onVisibleChanged: clipLoader.shown = visible
                Component.onCompleted: clipLoader.shown = visible
            }
        }
    }

    Variants {
        model: Screens.list

        LazyLoader {
            id: keysMenuLoader

            required property var modelData
            // La ventana se ve (la actualiza ella misma): así sigue viva durante la animación de cierre
            property bool shown: false

            active: Ui.keysOpen || shown

            KeysMenu {
                modelData: keysMenuLoader.modelData
                onVisibleChanged: keysMenuLoader.shown = visible
                Component.onCompleted: keysMenuLoader.shown = visible
            }
        }
    }

    Variants {
        model: Screens.list

        LazyLoader {
            id: noteMenuLoader

            required property var modelData
            // La ventana se ve (la actualiza ella misma): así sigue viva durante la animación de cierre
            property bool shown: false

            active: Ui.noteOpen || shown

            AnotarMenu {
                modelData: noteMenuLoader.modelData
                onVisibleChanged: noteMenuLoader.shown = visible
                Component.onCompleted: noteMenuLoader.shown = visible
            }
        }
    }

    // El panel lateral y su borde sensible viven solo en el monitor principal: el que está más a la
    // izquierda (y, si hay empate, más arriba)
    Variants {
        model: Screens.primary ? [Screens.primary] : []

        SidePanel {}
    }

    Variants {
        model: Screens.primary ? [Screens.primary] : []

        SideEdge {}
    }

    Variants {
        model: Screens.list

        LazyLoader {
            id: wallpaperPickerLoader

            required property var modelData
            // La ventana se ve (la actualiza ella misma): así sigue viva durante la animación de cierre
            property bool shown: false

            active: Ui.wallMenuOpen || shown

            WallpaperPicker {
                modelData: wallpaperPickerLoader.modelData
                onVisibleChanged: wallpaperPickerLoader.shown = visible
                Component.onCompleted: wallpaperPickerLoader.shown = visible
            }
        }
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

    // qs -c ombu ipc call side toggle|open <resumen|chat|sistema>|close  -> panel lateral (Super+A)
    IpcHandler {
        function toggle(): void {
            Ui.sideTab = "";
            Ui.sideOpen = !Ui.sideOpen;
        }

        function open(tab: string): void {
            Ui.sideTab = tab;
            Ui.sideOpen = true;
        }

        function close(): void {
            Ui.sideOpen = false;
        }

        target: "side"
    }

    // qs -c ombu ipc call note toggle|open "texto"|close|parse "texto"  -> anotador rápido (Super+Alt+N)
    IpcHandler {
        function toggle(): void {
            Ui.launcherOpen = false;
            Ui.keysOpen = false;
            Ui.popup = "";
            Ui.noteOpen = !Ui.noteOpen;
        }

        function open(text: string): void {
            Ui.notePrefill = text;
            Ui.noteOpen = false;
            Ui.noteOpen = true;
        }

        function close(): void {
            Ui.noteOpen = false;
        }

        // Lo que entendió el anotador del texto (lo último que se parseó; para probar)
        function parsed(): string {
            return JSON.stringify(Facu.parsed);
        }

        target: "note"
    }

    // qs -c ombu ipc call media toggle|next|previous|status  -> el reproductor de música
    IpcHandler {
        // Las teclas multimedia (binds.lua) llaman a estos: controlan el mismo reproductor que la tarjeta
        // de música (playerctl elegía otro por su cuenta) y muestran qué suena
        function toggle(): void {
            Media.toggle();
            Osd.showMedia();
        }

        function next(): void {
            Media.next();
            Osd.showMedia();
        }

        function previous(): void {
            Media.previous();
            Osd.showMedia();
        }

        function cycle(): void {
            Media.cycle();
        }

        function status(): string {
            return Media.describe();
        }

        target: "media"
    }

    // qs -c ombu ipc call menu toggle|open "Tema"|close|theme <id>  -> menú de la araña (Super+Alt+Espacio)
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

        // ipc call menu open "Tema"  -> abre el menú directo en la página de temas
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

        // ipc call agenda test  -> recordatorio de prueba en un minuto (solo local, nunca en Google)
        function test(): string {
            return Agenda.testReminder();
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

    // qs -c ombu ipc call night toggle|on|off|auto|temp <K>|status  -> luz nocturna (hyprsunset)
    IpcHandler {
        function toggle(): void {
            NightLight.toggle();
        }

        function on(): void {
            NightLight.set(true);
        }

        function off(): void {
            NightLight.set(false);
        }

        // Vuelve al horario automático (deja de valer lo elegido a mano)
        function auto(): void {
            NightLight.followSchedule();
        }

        function temp(k: int): string {
            NightLight.setTemperature(k);
            return String(NightLight.temperature);
        }

        function status(): string {
            return JSON.stringify({
                active: NightLight.active,
                night: NightLight.night,
                manual: NightLight.manual,
                temperature: NightLight.temperature,
                shown: NightLight.shown,
                hint: NightLight.hint
            });
        }

        target: "night"
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

        function control(): void {
            const key = "control@" + (Hyprland.focusedMonitor?.name ?? "");
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

        // focus kit programacion|otro · focus open (todo el entorno) · focus tool notebook|ide|ai
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

        // ipc call idle status  -> si algo (un video) está frenando el bloqueo por inactividad
        function status(): string {
            return Idle.describe();
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
            Welcome.play(true);
        }

        target: "welcome"
    }

    // qs -c ombu ipc call power toggle
    // qs -c ombu ipc call power goodbye  -> muestra la despedida de apagar SIN apagar (para probarla)
    IpcHandler {
        function toggle(): void {
            Ui.powerOpen = !Ui.powerOpen;
        }

        function goodbye(): void {
            Goodbye.test();
        }

        target: "power"
    }
}
