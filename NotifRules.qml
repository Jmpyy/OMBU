pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Reglas para ajustar notificaciones de ciertas apps antes de mostrarlas: pasarlas a español y
// no avisar de algo que ya tenés a la vista. Se agregan reglas a la lista de abajo.
//
// Cada regla tiene:
//   match(n)        qué notificaciones le tocan (n.appName, n.summary, n.body)
//   translate       pares [expresión, reemplazo] que se aplican al texto
//   asApp / icon    el aviso se muestra como de otra app (nombre e ícono), p. ej. los de Claude Code
//   speak(n)        reescribe el aviso entero: devuelve [título, texto] o null si no sabe qué decir
//   hideWhenVisible clase de ventana (ej. "kitty"): si hay una a la vista en algún monitor, la
//                   notificación se descarta (no tiene sentido avisar de lo que estás mirando)
Singleton {
    id: root

    // Logo de Claude: archivo propio de la persona (no va al repo: es una marca de otra empresa). Si no
    // existe, la tarjeta cae al ícono genérico.
    readonly property string claudeIcon: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/icons/claude.svg"

    readonly property var rules: [
        {
            // Claude Code avisa por la terminal (kitty) cuando espera algo de vos: aparece como Claude Code,
            // con su logo, y habla en primera persona
            match: n => n.appName.toLowerCase() === "kitty" && /claude/i.test(n.summary + " " + n.body),
            asApp: "Claude Code",
            icon: root.claudeIcon,
            speak: n => {
                const t = n.summary + " " + n.body;
                let m;
                if (/is waiting for your input/i.test(t))
                    return ["Te estoy esperando", "Terminé lo que estaba haciendo y necesito tu respuesta para seguir."];
                if ((m = t.match(/needs your permission to use (.+?)\.?\s*$/i)))
                    return ["Necesito tu permiso", "Quiero usar «" + m[1] + "». ¿Me dejás?"];
                if (/needs your permission/i.test(t))
                    return ["Necesito tu permiso", "Hay algo que no puedo hacer sin que me des el visto bueno."];
                if (/needs your attention/i.test(t))
                    return ["Necesito tu atención", "Hay algo que tenés que ver antes de que siga."];
                return null;
            },
            translate: [[/Claude is waiting for your input/i, "Claude te está esperando"], [/Claude needs your permission to use (.+)/i, "Claude necesita tu permiso para usar $1"], [/Claude needs your permission/i, "Claude necesita tu permiso"], [/Claude needs your attention/i, "Claude necesita tu atención"]],
            hideWhenVisible: "kitty"
        },
        {
            // Aviso de kitty cuando termina un comando largo (notify_on_cmd_finish en kitty.conf).
            // No se descarta nunca: kitty ya lo manda solo si esa terminal no está a la vista.
            match: n => n.appName.toLowerCase() === "kitty" && /^Command .+ finished with status/.test(n.body),
            translate: [[/^kitty$/, "Comando terminado"], [/^Command (.+) finished with status: 0\.?\s*$/, "«$1» terminó bien"], [/^Command (.+) finished with status: (\d+)\.?\s*$/, "«$1» terminó con error (código $2)"]]
        },
        {
            // "Terminó" de Claude Code y Antigravity (los manda bin/agent-notify.sh)
            match: n => ["claude code", "antigravity"].includes(n.appName.toLowerCase()),
            hideWhenVisible: "kitty"
        },
        {
            // Sung avisa qué empieza a sonar (título = tema, texto = artista) y reemplaza su propio aviso en
            // cada cambio de tema. Lleva la portada y no aparece si ya tenés Sung a la vista.
            match: n => (n.desktopEntry ?? "").toLowerCase() === "sung" || n.appName.toLowerCase() === "sung",
            asApp: "Sung · Ahora suena",
            hideWhenVisible: "sung",
            cover: true
        }
    ]

    // Portada del tema que anuncia un aviso de música, sacada del reproductor por MPRIS. Solo si el
    // reproductor ya muestra ese mismo tema: el aviso puede llegar antes que los datos nuevos y se vería la
    // portada del anterior. YouTube: hqdefault siempre existe (maxresdefault no, ver Media.artUrl).
    function coverFor(n: var): string {
        const p = Media.all.find(x => (x.dbusName ?? "").toLowerCase().endsWith("." + (n.desktopEntry || n.appName).toLowerCase()));
        if (!p || p.trackTitle !== n.summary)
            return "";
        return Media.artUrl(p.trackArtUrl ?? "", true);
    }

    // Escritorios que se están viendo ahora (uno por monitor)
    readonly property var visibleWorkspaces: Hyprland.monitors.values.map(m => m.activeWorkspace?.id).filter(id => id !== undefined)
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace?.id ?? -1

    function ruleFor(n: var): var {
        return rules.find(r => r.match(n)) ?? null;
    }

    // ¿Hay una ventana de esa clase en el escritorio con foco?
    function isVisible(windowClass: string): bool {
        return Hyprland.toplevels.values.some(t => (t.wayland?.appId === windowClass || t.lastIpcObject?.class === windowClass) && t.workspace?.id === focusedWorkspace);
    }

    // Verdadero si la notificación no hay que mostrarla
    function shouldDrop(n: var): bool {
        // Las confirmaciones de comandos de un agente nunca se descartan: hay algo esperando respuesta
        if (n.hints && n.hints["x-ombu-kind"] === "confirm")
            return false;
        const rule = ruleFor(n);
        return rule !== null && !!rule.hideWhenVisible && isVisible(rule.hideWhenVisible);
    }

    // Nombres de botones que las apps mandan en inglés (Discord manda «View»). Se comparan sin
    // distinguir mayúsculas y valen para todas las apps; lo que no está en la lista queda igual.
    readonly property var actionNames: ({
            "view": "Ver",
            "view message": "Ver mensaje",
            "reply": "Responder",
            "open": "Abrir",
            "open in browser": "Abrir en el navegador",
            "show": "Mostrar",
            "dismiss": "Descartar",
            "close": "Cerrar",
            "mark as read": "Marcar como leído",
            "snooze": "Posponer",
            "delete": "Borrar",
            "archive": "Archivar",
            "mute": "Silenciar",
            "ignore": "Ignorar",
            "accept": "Aceptar",
            "decline": "Rechazar",
            "answer": "Contestar",
            "join": "Unirse",
            "later": "Más tarde",
            "cancel": "Cancelar",
            "copy": "Copiar",
            "undo": "Deshacer",
            "retry": "Reintentar",
            "details": "Detalles",
            "settings": "Ajustes"
        })

    function translateAction(text: string): string {
        return actionNames[text.trim().toLowerCase()] ?? text;
    }

    // [título, texto] que reemplazan a los del aviso, o null si la regla no reescribe nada
    function speak(n: var): var {
        const rule = ruleFor(n);
        return rule && rule.speak ? rule.speak(n) : null;
    }

    // Texto traducido de un campo (o el mismo si ninguna regla le toca)
    function translate(n: var, text: string): string {
        const rule = ruleFor(n);
        if (!rule || !rule.translate)
            return text;
        let out = text;
        for (const [from, to] of rule.translate)
            out = out.replace(from, to);
        return out;
    }
}
