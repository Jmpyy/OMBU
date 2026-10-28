-- Descripciones de los atajos para el menú de atajos de ombu (Super+K).
--
-- Se carga antes de definir los atajos y envuelve hl.bind: si la combinación está en la tabla
-- de abajo, le agrega la descripción, y `hyprctl binds -j` la devuelve para que el menú la
-- muestre. Los atajos que no están acá no aparecen en el menú.
--
-- Formato: "Categoría|Texto" o "Categoría|Texto|Teclas" (las teclas se escriben a mano cuando
-- un renglón resume varios atajos, por ejemplo Super + 1…6). La clave es la combinación tal
-- cual se la pasa a hl.bind, por ejemplo "SUPER + Q".

local D = {
    -- Apps
    ["SUPER + Space"]               = "Apps|Abrir el launcher",
    ["SUPER + Return"]              = "Apps|Abrir la terminal",
    ["SUPER + W"]                   = "Apps|Abrir el navegador",
    ["SUPER + E"]                   = "Apps|Abrir el explorador de archivos",
    ["SUPER + SHIFT + E"]           = "Apps|Explorador en la carpeta de la terminal",
    ["SUPER + SHIFT + T"]           = "Apps|Abrir el editor",
    ["SUPER + C"]                   = "Apps|Calculadora",
    ["SUPER + V"]                   = "Apps|Historial del portapapeles",
    ["SUPER + P"]                   = "Apps|Selector de color",
    ["CONTROL + SHIFT + Escape"]    = "Apps|Monitor del sistema (btop)",

    -- Ventanas
    ["SUPER + Q"]                   = "Ventanas|Cerrar la ventana",
    ["SUPER + F"]                   = "Ventanas|Pantalla completa",
    ["SUPER + D"]                   = "Ventanas|Maximizar sin tapar la barra|Super + D  /  Super + M",
    ["SUPER + T"]                   = "Ventanas|Flotante o en mosaico",
    ["SUPER + O"]                   = "Ventanas|Flotante fija (imagen en imagen)",
    ["SUPER + J"]                   = "Ventanas|Cambiar la división del mosaico",
    ["SUPER + N"]                   = "Ventanas|Minimizar",
    ["SUPER + SHIFT + N"]           = "Ventanas|Ver las minimizadas",
    ["SUPER + R"]                   = "Ventanas|Modo redimensionar (flechas, Esc sale)",
    ["SUPER + Left"]                = "Ventanas|Mover el foco|Super + ← ↑ ↓ →",
    ["SUPER + SHIFT + Left"]        = "Ventanas|Mover la ventana|Super + Shift + ← ↑ ↓ →",
    ["ALT + Tab"]                   = "Ventanas|Cambiar de ventana",
    ["SUPER + mouse:272"]           = "Ventanas|Arrastrar la ventana|Super + clic izquierdo",
    ["SUPER + mouse:273"]           = "Ventanas|Cambiar el tamaño|Super + clic derecho",

    -- Escritorios
    ["SUPER + code:10"]             = "Escritorios|Ir al escritorio|Super + 1 … 6",
    ["SUPER + SHIFT + code:10"]     = "Escritorios|Mandar la ventana al escritorio|Super + Shift + 1 … 6",
    ["SUPER + Tab"]                 = "Escritorios|Escritorio siguiente",
    ["SUPER + SHIFT + Tab"]         = "Escritorios|Escritorio anterior",
    ["SUPER + CONTROL + Tab"]       = "Escritorios|Volver al escritorio anterior",
    ["SUPER + mouse_down"]          = "Escritorios|Pasar de escritorio con la rueda|Super + rueda",
    ["SUPER + S"]                   = "Escritorios|Mostrar u ocultar el escritorio especial",
    ["SUPER + ALT + S"]             = "Escritorios|Mandar la ventana al escritorio especial",

    -- Capturas
    ["SUPER + SHIFT + S"]           = "Capturas|Región y editor (Satty)",
    ["Print"]                       = "Capturas|Región y editor",
    ["SHIFT + Print"]               = "Capturas|Región directa",
    ["SUPER + Print"]               = "Capturas|Todo el monitor",
    ["CONTROL + Print"]             = "Capturas|Copiar el texto de una región (OCR)",

    -- Notificaciones
    ["SUPER + code:59"]             = "Notificaciones|Descartar la última|Super + ,",
    ["SUPER + SHIFT + code:59"]     = "Notificaciones|Descartar todas|Super + Shift + ,",
    ["SUPER + CONTROL + code:59"]   = "Notificaciones|No molestar|Super + Ctrl + ,",
    ["SUPER + ALT + code:59"]       = "Notificaciones|Abrir la acción de la última|Super + Alt + ,",
    ["SUPER + SHIFT + ALT + code:59"] = "Notificaciones|Historial|Super + Shift + Alt + ,",

    -- Sistema
    ["SUPER + K"]                   = "Sistema|Esta lista de atajos",
    ["SUPER + ALT + Space"]         = "Sistema|Menú del sistema (estilo, ajustes, capturas...)",
    ["SUPER + A"]                   = "Sistema|Panel lateral (resumen y estado de la PC)",
    ["SUPER + ALT + N"]             = "Estudio e IA|Anotar parcial, entrega o nota",
    ["SUPER + CONTROL + Space"]     = "Sistema|Elegir el fondo de pantalla|Super + Ctrl + Espacio",
    ["SUPER + CONTROL + SHIFT + Space"] = "Sistema|Elegir el tema de colores|Super + Ctrl + Shift + Espacio",
    ["SUPER + Escape"]              = "Sistema|Menú de energía|Super + Esc  /  Super + X",
    ["SUPER + CONTROL + L"]         = "Sistema|Bloquear la pantalla",
    ["SUPER + B"]                   = "Sistema|Mostrar u ocultar la barra",
    ["SUPER + F12"]                 = "Sistema|Subir el brillo|Super + F12  /  tecla de brillo",
    ["SUPER + F11"]                 = "Sistema|Bajar el brillo|Super + F11  /  tecla de brillo",
    ["SUPER + Plus"]                = "Sistema|Acercar la pantalla (zoom)|Super + +  /  Super + -",
    ["SUPER + CONTROL + ALT + Z"]   = "Sistema|Quitar el zoom",
}

-- Hyprland llama a hl.bind(teclas, acción, opciones): se envuelve una sola vez
if not hl.__ombu_atajos then
    local bind = hl.bind
    hl.bind = function(keys, action, opts)
        local d = D[keys]
        if d and not (opts and opts.description) then
            opts = opts or {}
            opts.description = d
        end
        return bind(keys, action, opts)
    end
    hl.__ombu_atajos = true
end
