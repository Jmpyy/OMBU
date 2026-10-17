# AGENTS.md — ombu

Guía para agentes de IA (Claude Code, Antigravity...) que trabajan en este repositorio. ombu es un shell de escritorio para **Hyprland** hecho con **Quickshell (QML)**. Leé esto antes de tocar nada.

## Cómo trabajar con la persona

- Respondé en **español, con voseo** (es argentino/a).
- Antes de cualquier cambio **fuera de este repo** (paquetes con `pacman`, archivos de `/etc`, greetd, kernel, la config de Hyprland en `~/.config/hypr`), **explicá qué vas a hacer y esperá el visto bueno**. Los comandos con `sudo` los corre la persona, no vos (`! sudo ...`).
- **Nunca reinicies greetd** con una sesión abierta: la mata.
- **No borres, mové a la papelera** (`gio trash`). Antes de borrar algo, mirá qué es.
- **Contraseñas y tokens:** no los pidas ni los guardes. Si aparece uno en pantalla o en un archivo, avisá para que lo revoquen.
- Informá los resultados tal cual: si algo falló o no se pudo probar, decilo.

## El repositorio es público

Cada `git push` publica el contenido. Antes de commitear:

- Revisá que no entren contraseñas, tokens ni claves (`git diff --cached`).
- **No subas capturas de pantalla completa**: muestran las ventanas abiertas. Recortá cada menú por dentro de su borde (ver "Capturas").
- Commits en español, en pasado o descriptivos, y con la línea `Co-Authored-By` que corresponda a tu herramienta.

## Qué es cada cosa

```
shell.qml          punto de entrada: ventanas por monitor y comandos IPC
Theme.qml          colores, tamaños y tiempos (todo el aspecto sale de acá)
TopBar.qml         la barra; *Menu.qml son los menús que cuelgan de ella (DropPopup)
Notifs*.qml        servidor de notificaciones (es el único: no puede haber otro)
NotifRules.qml     reglas para traducir o descartar avisos de ciertas apps
Lock*.qml  Auth    bloqueo de pantalla (ext-session-lock) y PAM
Saver*.qml Idle    salvapantallas ASCII e inactividad (bloqueo a 5 min, monitores a 30)
Welcome*.qml       bienvenida al iniciar sesión (una vez por sesión)
greeter/           pantalla de login para greetd; install.sh toca el sistema
hypr/ombu.lua      configuración de Hyprland para compartir (copia de lo que usa la persona)
bin/               scripts: capturas (shot.sh: editor, OCR), portapapeles, explorador, avisos de agentes
```

## Cómo correrlo y probarlo

- Arranca con `quickshell -c ombu -n -d` (lo hace Hyprland). **Recarga solo** al guardar un `.qml`.
- Log: `qs -c ombu log`. Instancias vivas: `qs list --all` (**tiene que haber una sola**; dos copias pelean por D-Bus y duplican barras).
- Comandos IPC para probar sin teclado: `qs -c ombu ipc call bar devices|mixer|calendar|apps|tray`, `power toggle`, `launcher toggle`, `lock preview` (vista previa inofensiva, Esc la cierra), `lock saver`, `welcome play`, `notif ...`. Ver `shell.qml`.
- **`lock lock` es un bloqueo real**: solo se abre con la contraseña. No lo uses para probar; usá `lock preview`.
- Validar Hyprland: `Hyprland --verify-config` (o `-c archivo.lua`).

## Diseño (no lo cambies sin hablarlo)

- Menús **sólidos**, sin transparencia. Minimalismo: la persona rechazó mascotas, monitores del sistema y título de ventana activa.
- Los menús **crecen desde la barra** con esquinas cóncavas (`DropPopup`, `DropShape`). Las ventanas de capa de ombu se animan solas en QML; una regla de Hyprland desactiva la animación propia (`ombu-*`).
- Ventanas layer-shell de **tamaño fijo**: redimensionar cada cuadro causa temblor. Los popups esperan al primer cuadro (`ready`) antes de animar.
- Rendimiento: timers a 12 fps en el salvapantallas y el bloqueo; el blur se cachea (`layer.enabled`).
- Textos de la interfaz en español.

## Trampas conocidas

**Hyprland 0.56 con configuración en Lua**
- Los dispatch son código Lua: `hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'`.
- `hl.dsp.dpms("on")` **alterna** en vez de encender: usá siempre la tabla `hl.dsp.dpms({ action = "on" })`.
- `hl.layer_rule` necesita `match` como **tabla** (`{ namespace = "..." }`); con un string se ignora sin avisar.
- La configuración viva de la persona está en `~/.config/hypr/` (fuera de este repo). Si cambiás algo ahí, reflejalo en `hypr/ombu.lua`.

**Shell**
- La terminal es **zsh** (o fish) con alias que rompen comandos (`g`, `gpu`) y que no separa palabras de una variable (`$Q call ...` falla). Para varios pasos, escribí un script bash.
- No uses `pkill -f` con un patrón que también aparezca en tu propio comando: te matás a vos. Usá el PID o `pkill -x`.
- No borres con `rm` y una variable que pueda estar vacía.

**Pantalla y capturas**
- Dos monitores: `HDMI-A-1` (principal) y `DP-2` (un TV, suele estar apagado). **`grim` se cuelga en DP-2**: capturá siempre con `grim -o HDMI-A-1` y con límite de tiempo.
- La persona **usa la PC mientras trabajás**. El IPC de ombu actúa sobre el **monitor con foco**: si el foco está en otro lado, el menú aparece ahí y la captura sale vacía.
- Para el repo, capturá y **recortá** (ImageMagick: `magick in.png -crop WxH+X+Y out.png`) para que no entre nada de otras ventanas.

**Sistema**
- **No hay suspend real**: el driver NVIDIA (GSP) cuelga la GPU al despertar. "Reposo" bloquea y muestra el salvapantallas.
- Discord pide no bloquear la pantalla en llamadas de voz; una regla de Hyprland (`idle_inhibit = "none"`) lo ignora.

## Avisos de los agentes

`bin/agent-notify.sh` avisa cuando Claude Code o Antigravity terminan una tarea larga (30 s o más). Lo llaman los hooks de cada uno (`~/.claude/settings.json` y `~/.gemini/config/hooks.json`). Si hay una terminal a la vista, ombu descarta el aviso (regla en `NotifRules.qml`).
