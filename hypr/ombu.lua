-- Configuración de Hyprland (0.56 o más nuevo, con config en Lua) para usar ombu.
--
-- Uso: en tu hyprland.lua agregá esta línea (ombu tiene que estar en ~/.config/quickshell/ombu):
--
--     dofile(os.getenv("HOME") .. "/.config/quickshell/ombu/hypr/ombu.lua")
--
-- Si ya tenés atajos propios en Super+Espacio, Super+V, etc., cambiá los de acá abajo.

local mainMod = "SUPER"
local ombu = os.getenv("HOME") .. "/.config/quickshell/ombu"
local ipc = "quickshell -c ombu ipc call "

-- Arranque del shell (-n evita que se abra dos veces)
hl.on("hyprland.start", function ()
    hl.exec_cmd("quickshell -c ombu -n -d")
end)

-- Las capas de ombu (ombu-bar, ombu-power, ombu-launcher...) se animan solas en QML:
-- sin esto, Hyprland les sumaría su propia animación de capa y se vería doble.
hl.layer_rule({ match = { namespace = "^ombu-.*$" }, no_anim = true })

hl.config({
    misc = {
        -- Si el programa de bloqueo se cae con la pantalla bloqueada, permite lanzar otro en
        -- su lugar (sin esto la sesión queda trabada hasta reiniciarla desde una TTY)
        allow_session_lock_restore = true,
        -- ombu apaga los monitores tras 30 min de inactividad: cualquier tecla o movimiento
        -- del mouse los despierta, aunque el shell no estuviera vivo para encenderlos.
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
})

---------------------
---- SHELL: MENÚS ----
---------------------

hl.bind(mainMod .. " + Space",       hl.dsp.exec_cmd(ipc .. "launcher toggle"))
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd(ipc .. "power toggle"))
hl.bind(mainMod .. " + X",           hl.dsp.exec_cmd(ipc .. "power toggle"))
hl.bind(mainMod .. " + CONTROL + L", hl.dsp.exec_cmd(ipc .. "lock lock"))
hl.bind(mainMod .. " + B",           hl.dsp.exec_cmd(ipc .. "bar toggle"))

-- Notificaciones (estilo Omarchy). Se usa el código de tecla de la coma (59) para que
-- funcione igual con cualquier distribución de teclado.
hl.bind(mainMod .. " + code:59",               hl.dsp.exec_cmd(ipc .. "notif dismiss"))
hl.bind(mainMod .. " + SHIFT + code:59",       hl.dsp.exec_cmd(ipc .. "notif dismissAll"))
hl.bind(mainMod .. " + CONTROL + code:59",     hl.dsp.exec_cmd(ipc .. "notif dnd"))
hl.bind(mainMod .. " + ALT + code:59",         hl.dsp.exec_cmd(ipc .. "notif invoke"))
hl.bind(mainMod .. " + SHIFT + ALT + code:59", hl.dsp.exec_cmd(ipc .. "notif history"))

------------------------
---- SHELL: UTILIDADES ----
------------------------

-- Capturas: Print = elegir el área, Super+Print = el monitor con foco
hl.bind("Print",               hl.dsp.exec_cmd(ombu .. "/bin/shot.sh region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(ombu .. "/bin/shot.sh full"))

-- Historial del portapapeles (cliphist + rofi)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(ombu .. "/bin/clip.sh"))

-- Explorador de archivos en la carpeta de la terminal con foco
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(ombu .. "/bin/files-here.sh"))

---------------------------
---- VENTANAS (opcional) ----
---------------------------

-- Minimizar: Hyprland no tiene minimizar de verdad, así que la ventana se manda a un
-- workspace especial oculto. Se restaura desde el menú de apps abiertas de la barra
-- o espiando todas las minimizadas con Super+Shift+N.
hl.bind(mainMod .. " + N",         hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.workspace.toggle_special("minimized"))

-- Ventana flotante fija (sticky), ideal para Picture-in-Picture: alterna entre
-- "flotante chica fija en pantalla" y volver a tiling.
hl.bind(mainMod .. " + O", function()
    local w = hl.get_active_window()
    if not w then return end
    if w.floating and w.pinned then
        hl.dispatch(hl.dsp.window.pin())
        hl.dispatch(hl.dsp.window.float({ action = "disable" }))
    else
        hl.dispatch(hl.dsp.window.float({ action = "enable" }))
        hl.dispatch(hl.dsp.window.resize({ x = 640, y = 360, relative = false }))
        hl.dispatch(hl.dsp.window.center())
        if not w.pinned then hl.dispatch(hl.dsp.window.pin()) end
    end
end)

-- Modo redimensionar: Super+R entra, las flechas ajustan, Esc o Enter salen.
-- La barra de ombu muestra un aviso mientras el modo está activo.
hl.define_submap("resize", "reset", function()
    hl.bind("Right",  hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })
    hl.bind("Left",   hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
    hl.bind("Down",   hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })
    hl.bind("Up",     hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
