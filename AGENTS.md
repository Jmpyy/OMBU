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
Launch*.qml        launcher: favoritas, más usadas y qué se oculta (Launch.qml)
Clip*.qml          historial del portapapeles (cliphist); bin/clip*.sh lo guardan y pegan
Focus*.qml         modo foco: temporizador 25/5, modos estudio/trabajo/libre y bloqueo de juegos
bin/               scripts: capturas (shot.sh: editor, OCR), portapapeles, explorador, avisos de agentes
```

## Cómo correrlo y probarlo

- Arranca con `quickshell -c ombu -n -d` (lo hace Hyprland). **Recarga solo** al guardar un `.qml`.
- Log: `qs -c ombu log`. Instancias vivas: `qs list --all` (**tiene que haber una sola**; dos copias pelean por D-Bus y duplican barras).
- Comandos IPC para probar sin teclado: `qs -c ombu ipc call bar devices|mixer|calendar|apps|tray`, `power toggle`, `launcher toggle`, `lock preview` (vista previa inofensiva, Esc la cierra), `lock saver`, `welcome play`, `clip toggle`, `focus start|pause|stop|skip|mode <modo>|idea "texto"|status`, `notif ...`. Ver `shell.qml`.
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

**Ventanas y apps**
- `Hyprland.toplevels` puede traer **ventanas fantasma** (sin escritorio): el Minecraft Launcher esconde su ventana y queda ahí. Usá siempre `Apps.windows` (las filtra) para listarlas o contarlas.
- Hay apps que **capturan SIGTERM** (el Minecraft Launcher): cerrar un proceso en segundo plano escala a SIGKILL por PID (`Apps.close`).
- Las reglas de ventanas de la persona mandan los juegos al escritorio con nombre `gaming` (id negativo): la barra lo muestra solo si tiene ventanas.

**Pantalla y capturas**
- Dos monitores: `HDMI-A-1` (principal) y `DP-2` (un TV, suele estar apagado). **`grim` se cuelga en DP-2**: capturá siempre con `grim -o HDMI-A-1` y con límite de tiempo.
- La persona **usa la PC mientras trabajás**. El IPC de ombu actúa sobre el **monitor con foco**: si el foco está en otro lado, el menú aparece ahí y la captura sale vacía.
- Para el repo, capturá y **recortá** (ImageMagick: `magick in.png -crop WxH+X+Y out.png`) para que no entre nada de otras ventanas.

**Sistema**
- **No hay suspend real**: el driver NVIDIA (GSP) cuelga la GPU al despertar. "Reposo" bloquea y muestra el salvapantallas.
- Discord pide no bloquear la pantalla en llamadas de voz; una regla de Hyprland (`idle_inhibit = "none"`) lo ignora.

## Avisos y confirmaciones de los agentes

- `bin/agent-notify.sh`: avisa cuando Claude Code o Antigravity terminan una tarea. Si la terminal no tiene el foco, avisa siempre y permite hacer clic para volver a la consola al instante. Lo llaman los hooks de cada uno (`~/.claude/settings.json` y `~/.gemini/config/hooks.json`).
- `bin/agent-confirm.sh` (→ `agent-confirm.py`): confirma comandos de Bash desde una tarjeta de ombu cuando la terminal **no** tiene el foco. Claude Code lo usa como hook **`PermissionRequest`** (se dispara solo cuando iba a pedirte permiso) y Antigravity como `PreToolUse` de `run_command`. Reglas de seguridad, que no hay que aflojar:
  - **El valor por defecto es no decidir, nunca permitir.** Si no se entiende el pedido, se cierra la tarjeta o vence (45 s), el agente pregunta en la consola.
  - Los comandos de solo lectura (`ls`, `git status`...) no muestran tarjeta.
  - Los comandos **destructivos** (`rm`, `sudo`, `git push`, `pacman`...) o muy largos no tienen botón "Permitir": solo "Denegar" o "Ir a la consola".
  - Un clic suelto en la tarjeta o `notif invoke` **no aprueba nada** (`Notifs.invoke` ignora las de tipo `confirm`): solo el botón.
  - En Claude Code, `exit 1` **no bloquea** (error no bloqueante); para denegar hay que devolver el JSON de `PermissionRequest` o salir con `exit 2`.
- La tarjeta (`NotifCard.qml`) muestra la carpeta, el comando completo en un bloque de código y los botones. Se activa con los hints `x-ombu-kind:confirm`, `x-ombu-risky`, `x-ombu-compound` y `x-ombu-cwd` de `notify-send`.

## Modo foco

- `Focus.qml` (singleton) lleva el temporizador (25 min de estudio, 5 de descanso, 15 cada 4 bloques), los tres modos y la estadística. Se guarda en `~/.local/share/ombu/focus.json`; las ideas, en `ideas.md` de esa carpeta.
- Publica el estado en `~/.local/state/ombu/modo` (`estudio activo`, `trabajo inactivo`, `libre inactivo`...) para que otros programas, como un hook de IA, sepan si la persona está estudiando.
- El bloqueo (solo en modo estudio, durante el bloque de estudio) **avisa y cierra a los 15 s** las ventanas de juegos. Se cierra enfocando la ventana y cerrando la activa: `hl.dsp.window.close({ window = ... })` **no cierra** en esta versión de Hyprland. Si la app ignora el cierre (un launcher que solo se esconde, un juego), a los 10 s se le manda SIGTERM al proceso (nunca SIGKILL). Lo que decide queda en el log con el prefijo `FOCO:` (`qs -c ombu log | grep FOCO:`).
- La vigilancia mira **ventanas y procesos** cada segundo y agrupa por familia (el launcher y el juego de Minecraft comparten un solo cartel). El launcher se detecta por su proceso (`minecraft-launc`, el `comm` de 15 caracteres) apenas arranca, sin esperar a que dibuje la ventana; sin ventana va directo a SIGTERM al vencer el plazo. Para sumar otro programa a la lista: `blockedPattern` (por clase de ventana) o `blockedProcesses` (por nombre de proceso) en `Focus.qml`.
- **Sitios web** (`blockedSites` en `Focus.qml`): se reconocen por el título de la ventana del navegador (Zen), es decir, por la pestaña **activa**; al vencer el plazo se manda Ctrl+W a esa ventana con `hl.dsp.send_shortcut` (cierra la pestaña, no la ventana). Entre dos envíos pasan 3 s, para no cerrar por error la pestaña siguiente si el título tarda en actualizarse. Hoy: Instagram, TikTok, Facebook, X, Reddit, Twitch y Netflix; YouTube **no** está bloqueado a propósito (la persona busca videos del tema). Para probar sin tocar pestañas reales: una página local con `<title>Instagram prueba</title>` abierta con `zen-browser file://...`, y parar el temporizador apenas se cierre (Zen vuelve a la pestaña anterior, que también puede ser bloqueada).
- **Entorno de estudio** (`Focus.kits`): al tocar Empezar desde cero (no al reanudar ni tras un descanso) y con el modo Estudio, se abre lo del tipo elegido: `programacion` = NotebookLM en Zen + Zed en `~/universidad` + terminal con Antigravity (`agy`); `matematica` = NotebookLM + Antigravity; `otro` = solo NotebookLM. Se abren de a una cada 0,7 s. El PATH de la sesión de Hyprland **no incluye `~/.local/bin`**: `agy` se llama con su ruta completa. Por consola: `focus kit <tipo>`, `focus open`, `focus tool notebook|ide|ai`. Para probar sin dejar ventanas colgadas, cerrá después lo que se abrió.
- Saltar el bloqueo exige esperar 60 s (fricción a propósito) y lo pausa 15 min.
- Probar el bloqueo: `kitty --class steam_app_prueba -o confirm_os_window_close=0 -e sleep 600` (sin esa opción kitty pide confirmación y la ventana no se cierra).
- **Cartel** (`FocusBlock.qml`): al detectar un juego durante el bloque de estudio muestra una tarjeta encima de todo, con una frase, el nombre de lo que se cierra y la cuenta regresiva de 15 s. No toma el teclado. El botón "Cerrar y estudiar" cierra el juego **al instante** (`Focus.closeBlocked()`, o `qs -c ombu ipc call focus closeblocked`); no hay forma de solo esconder el cartel.
- **Modo estudio para la IA** (`bin/agent-study.sh`): si `~/.local/state/ombu/modo` dice `estudio activo` (y el archivo tiene menos de 40 min, por si el shell se cayó), el hook le pasa al agente unas reglas: solo temas de la facultad, enseñar en vez de resolver, y las ideas ajenas van al cajón (`qs -c ombu ipc call focus idea "texto"`). Claude Code lo recibe por `UserPromptSubmit` (`additionalContext`) y Antigravity por `PreInvocation` (`injectSteps` con `ephemeralMessage`). Si trabajás en este repo y el modo estudio está activo, **seguí esas reglas**: la persona puede pausar el temporizador desde la barra.


## Brillo y proyectos de C

- **Brillo:** [`Brightness.qml`](Brightness.qml) usa `ddcutil` (DDC/CI). Detecta el bus I2C del primer monitor que responde y manda un cambio a la vez, porque cada llamada tarda unos cientos de ms. `ipc call brightness up|down` cambia de a 5 y muestra el indicador de [`Osd.qml`](Osd.qml) (`kind` volumen o brillo). Los primeros segundos tras iniciar el shell todavía no hay bus detectado y el atajo no hace nada.
- **C:** [`bin/cproj.sh`](bin/cproj.sh) arma un proyecto en `~/universidad`. `make leaks` usa valgrind; el sanitizer de fugas (LeakSanitizer) no se pudo comprobar en el entorno aislado de Claude.
- **Centro de control:** [`ControlMenu.qml`](ControlMenu.qml) reúne brillo y volumen (sliders de [`PillSlider.qml`](PillSlider.qml)) y tiles (teclado, modo foco, No molestar, dispositivos); sacó de la barra los botones de teclado y dispositivos. El menú de Dispositivos sigue siendo `DevicesMenu` pero cuelga del botón del centro (`ipc call bar control`). Sin hacer clic a mano no se pudo comprobar el arrastre de los sliders ni los tiles.
- **Menú de foco:** [`FocusMenu.qml`](FocusMenu.qml) usa [`Segmented.qml`](Segmented.qml), [`FocusRing.qml`](FocusRing.qml) y [`RoundButton.qml`](RoundButton.qml). El botón del modo foco solo está en la barra con una sesión en marcha o en pausa (`focusShown` en [`TopBar.qml`](TopBar.qml)); si no, el menú crece desde el centro de control. `focusFrom` se fija al abrir el menú para que no salte.
- **Fondos:** [`Walls.qml`](Walls.qml) busca imágenes (`find`, un nivel) en `Walls.dirs`, guarda la elegida en `~/.local/share/ombu/fondo.json` y la publica en `Walls.current`; la usan `Wallpaper.qml` y `LockBackdrop.qml`. [`WallpaperMenu.qml`](WallpaperMenu.qml) es el selector. `ipc call wallpaper set <ruta>` y `current` sirven para probar sin hacer clic. Verificado cambiando el fondo y comparando el color del borde de pantalla; el clic en una miniatura no se pudo probar a mano.
- **Menú de atajos:** [`KeysMenu.qml`](KeysMenu.qml) (Super+K, `ipc call keys toggle`) muestra lo que lee [`Atajos.qml`](Atajos.qml) de `hyprctl binds -j`: solo los atajos con descripción. Las descripciones están en [`hypr/atajos.lua`](hypr/atajos.lua) (tabla `"SUPER + Q" = "Categoría|Texto|Teclas opcionales"`), que envuelve `hl.bind` y se carga con `dofile` antes de los atajos (desde `hypr/ombu.lua` y desde el `binds.lua` de Juan). Para que un atajo nuevo aparezca hay que agregarlo a esa tabla. No se puede llamar `Keys.qml` al singleton: choca con el `Keys` de QML.
- **Agenda del calendario:** [`Agenda.qml`](Agenda.qml) junta eventos propios (`~/.local/share/ombu/agenda.json`), Google Calendar, feriados y días de estudio (`Focus.history`), y manda los recordatorios con `notify-send` (propios a la hora, Google 10 min antes). Se arranca desde `shell.qml` (`Agenda.check()`); sin eso los recordatorios no suenan hasta abrir el calendario. Google se lee con [`bin/ics.py`](bin/ics.py) (solo biblioteca estándar; expande `RRULE`, `EXDATE` y `RECURRENCE-ID`), con la dirección en el entorno (`OMBU_ICS_URL`, no en los argumentos) y copia en `~/.cache/ombu/google.ics`; [`bin/feriados.sh`](bin/feriados.sh) baja los feriados. **La dirección secreta nunca va al repo ni a los logs.** Probado con un `.ics` sintético (semanal con `EXDATE`, clase movida, UTC, todo el día, anual), no con el Google Calendar real de Juan. `ipc call agenda add|remove|google|reminders` sirve para probar.
- **Google Calendar por la API:** [`bin/gcal.py`](bin/gcal.py) (OAuth de escritorio con PKCE y servidor de retorno en 127.0.0.1; `status|auth|list|add|delete|disconnect`, todo en JSON; solo biblioteca estándar). `Agenda.qml` lo prefiere sobre `bin/ics.py` cuando hay sesión; Google ya expande las repeticiones (`singleEvents`). Solo borra eventos con la marca privada `ombu=1`. Credenciales y token en `~/.local/share/ombu/google-{client,token}.json`, modo 600, **jamás al repo ni a un log**. [`tests/gcal_mock_test.py`](tests/gcal_mock_test.py) prueba todo contra un servidor falso (permiso, state falso, páginas, calendarios, renovación, crear, borrar, desconectar). Con Google de verdad no se probó (Juan debe crear las credenciales, ver [`docs/google-calendar.md`](docs/google-calendar.md)).
- **Estilo de escritorio, no de celular:** controles con esquinas suaves (`Theme.controlRadius` = 10), tarjetas flotantes de 18 (`Theme.cardRadius`), sliders de 30 px, selectores de 28 px y botones redondos chicos; el violeta lleno solo en la acción principal, el resto en tono suave. Un amigo de Juan dijo que el sistema parecía un celular: evitá píldoras gigantes, botones táctiles y mucho relleno.
- **Contorno:** `Theme.outline` (blanco al 20 %) dibuja el filo de la barra (`TopBar.qml`) y el de los menús que cuelgan de ella (`DropShape.qml`, un trazo aparte que no cubre el borde de arriba, porque ahí el menú se funde con la barra). Sirve para que el menú no se confunda con una terminal oscura. Las tarjetas centradas (launcher, portapapeles, atajos) usan `Theme.border`, más tenue.
