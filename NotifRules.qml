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
            // "Terminó" de Claude Code y Antigravity (los manda bin/agent-notify.sh)
            match: n => ["claude code", "antigravity"].includes(n.appName.toLowerCase()),
            hideWhenVisible: "kitty"
        }
    ]

    // Escritorios que se están viendo ahora (uno por monitor)
    readonly property var visibleWorkspaces: Hyprland.monitors.values.map(m => m.activeWorkspace?.id).filter(id => id !== undefined)

    function ruleFor(n: var): var {
        return rules.find(r => r.match(n)) ?? null;
    }

    // ¿Hay una ventana de esa clase a la vista?
    function isVisible(windowClass: string): bool {
        return Hyprland.toplevels.values.some(t => t.wayland?.appId === windowClass && visibleWorkspaces.includes(t.workspace?.id));
    }

    // Verdadero si la notificación no hay que mostrarla
    function shouldDrop(n: var): bool {
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
