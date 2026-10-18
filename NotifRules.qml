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
//   hideWhenVisible clase de ventana (ej. "kitty"): si hay una a la vista en algún monitor, la
//                   notificación se descarta (no tiene sentido avisar de lo que estás mirando)
Singleton {
    id: root

    readonly property var rules: [
        {
            // Claude Code avisa por la terminal (kitty) cuando espera algo de vos
            match: n => n.appName.toLowerCase() === "kitty" && /claude/i.test(n.summary + " " + n.body),
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
        }
    ]

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
