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

- Revisá que no entren contraseñas, tokens ni claves (`git diff --cached`). El hook [`.githooks/pre-commit`](.githooks/pre-commit) lo revisa solo (archivos personales, secretos, sintaxis de QML/bash/Python y los tests) y frena el commit si algo falla. Se activa una vez por clon con `git config core.hooksPath .githooks`; **no lo saltees** (`--no-verify`) sin el visto bueno de la persona.
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
MainMenu.qml       menú de la araña (sesión y sistema); Actions.qml es el catálogo de acciones
SidePanel.qml      panel lateral: Resumen y Sistema (Seguridad, SysStat)
Agenda Subs Facu   calendario, pagos y anotador de la facultad
bin/               scripts: capturas (shot.sh: editor, OCR), portapapeles, explorador, avisos de agentes
```

## Cómo correrlo y probarlo

- Arranca con `quickshell -c ombu -n -d` (lo hace Hyprland). **Recarga solo** al guardar un `.qml`.
- **Después de cada cambio: `bin/check.sh`** (o `bin/check.sh -w` justo después de guardar, espera la recarga). Dice si la config cargó, la causa real si no (la última línea `caused by`; las `Type X unavailable` son efecto dominó) y los avisos nuevos; sale con 0/1/2. Trampas de la recarga: Quickshell recarga solo si cambia el **contenido** (`touch` no alcanza); si el archivo se **reemplaza** (`sed -i`, que crea otro inode) puede perder el vigilante hasta la próxima recarga buena; y tras un error de sintaxis puede quedarse con la versión rota en memoria aunque el archivo ya esté bien: `bin/check.sh -r` reinicia ombu.
- Log: `qs -c ombu log`. Instancias vivas: `qs list --all` (**tiene que haber una sola**; dos copias pelean por D-Bus y duplican barras).
- Comandos IPC para probar sin teclado: `qs -c ombu ipc call bar mixer|calendar|apps|tray|control`, `power toggle`, `launcher toggle`, `lock preview` (vista previa inofensiva, Esc la cierra), `lock saver`, `welcome play`, `clip toggle`, `focus start|pause|stop|skip|mode <modo>|idea "texto"|status`, `notif ...`. Ver `shell.qml`.
- **`lock lock` es un bloqueo real**: solo se abre con la contraseña. No lo uses para probar; usá `lock preview`.
- Validar Hyprland: `Hyprland --verify-config` (o `-c archivo.lua`).

## Diseño (no lo cambies sin hablarlo)

- Menús **sólidos**, sin transparencia. Minimalismo: la persona rechazó mascotas, monitores del sistema y título de ventana activa.
- Los menús **crecen desde la barra** con esquinas cóncavas (`DropPopup`, `DropShape`). Las ventanas de capa de ombu se animan solas en QML; una regla de Hyprland desactiva la animación propia (`ombu-*`).
- Ventanas layer-shell de **tamaño fijo**: redimensionar cada cuadro causa temblor. Los popups esperan al primer cuadro (`ready`) antes de animar.
- Rendimiento: timers a 12 fps en el salvapantallas y el bloqueo; el blur se cachea (`layer.enabled`).
- **Animación:** usá la escala de `Theme`, por rol: `animQuick` (100, hover y clic), `animFast` (150, bordes, opacidad, indicadores), `animNormal` (200, movimiento y tamaño, menús) y `animSlow` (320, progreso y fundidos grandes), con `Theme.ease` (OutCubic). Solo las coreografías (sacudidas, pulsos en bucle, despedida, escalonados) llevan tiempos propios.
- **Tipografía:** usá la escala de `Theme`, por rol: `fontTiny` 10, `fontCaption` 11, `fontSmall` 12, `fontBody` 13, `fontEmphasis` 15, `fontTitle` 17, `fontHeading` 22; íconos `iconXs` 14, `iconSm` 16, `iconMd` 18, `iconLg` 24. Solo lo de 26 px o más (relojes, cifras, íconos protagonistas) lleva tamaño propio.
- Estilo de escritorio, no de celular: esquinas suaves (`Theme.controlRadius`, `cardRadius`), sliders de 30 px, el acento lleno solo en la acción principal. Nada de píldoras gigantes ni botones táctiles. `Theme.outline` es el filo de la barra y de los menús que cuelgan de ella; las tarjetas centradas usan `Theme.border`.
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
- `Hyprland.toplevels` puede traer **ventanas fantasma** (sin escritorio): el Minecraft Launcher esconde su ventana y queda ahí. Usá siempre `Apps.windows` (las filtra) para listarlas o contarlas. Para ir a una ventana (y traerla si estaba minimizada en `special:minimized`) usá `Apps.focusWindow(t)`: antes estaba copiada en el launcher, el menú de apps y los avisos.
- Hay apps que **capturan SIGTERM** (el Minecraft Launcher): cerrar un proceso en segundo plano escala a SIGKILL por PID (`Apps.close`).
- Las reglas de ventanas de la persona mandan los juegos al escritorio con nombre `gaming` (id negativo): la barra lo muestra solo si tiene ventanas.

**Pantalla y capturas**
- Dos monitores: `HDMI-A-1` (principal, 1920x1080) y `DP-1` (un TV **vertical**: `transform = 1`, 1080x1920, en `1920x-493`; `DP-2` es el puerto fantasma del adaptador, desactivado en `monitors.lua`). Antes `grim` se colgaba en el TV por `DP-2`; con `DP-1` se pudo capturar (`timeout 4 grim -o DP-1`). Igual capturá siempre con `-o` y con límite de tiempo.
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
- La lista permitida (`is_safe` en `bin/agent-confirm.py`) es lo único que se aprueba solo; lo que no está, nunca. **Después de tocar las listas, `tests/agent_confirm_test.py`**, y antes de sumar un comando pensá si alguna bandera puede ejecutar otro programa o escribir un archivo.
- La tarjeta (`NotifCard.qml`) muestra la carpeta, el comando completo en un bloque de código y los botones. Se activa con los hints `x-ombu-kind:confirm`, `x-ombu-risky`, `x-ombu-compound` y `x-ombu-cwd` de `notify-send`.

## Modo foco

- `Focus.qml` (singleton) lleva el temporizador (25 min de estudio, 5 de descanso, 15 cada 4 bloques), los tres modos y la estadística. Se guarda en `~/.local/share/ombu/focus.json`; las ideas, en `ideas.md` de esa carpeta.
- Publica el estado en `~/.local/state/ombu/modo` (`estudio activo`, `trabajo inactivo`, `libre inactivo`...) para que otros programas, como un hook de IA, sepan si la persona está estudiando.
- El bloqueo (solo en modo estudio, durante el bloque de estudio) **avisa y cierra a los 15 s** las ventanas de juegos. Se cierra enfocando la ventana y cerrando la activa: `hl.dsp.window.close({ window = ... })` **no cierra** en esta versión de Hyprland. Si la app ignora el cierre (un launcher que solo se esconde, un juego), a los 10 s se le manda SIGTERM al proceso (nunca SIGKILL). Lo que decide queda en el log con el prefijo `FOCO:` (`qs -c ombu log | grep FOCO:`).
- La vigilancia mira **ventanas y procesos** cada segundo y agrupa por familia (el launcher y el juego de Minecraft comparten un solo cartel). El launcher se detecta por su proceso (`minecraft-launc`, el `comm` de 15 caracteres) apenas arranca, sin esperar a que dibuje la ventana; sin ventana va directo a SIGTERM al vencer el plazo. Para sumar otro programa a la lista: `blockedPattern` (por clase de ventana) o `blockedProcesses` (por nombre de proceso) en `Focus.qml`.
- **Sitios web** (`blockedSites` en `Focus.qml`): se reconocen por el título de la ventana del navegador (Zen), es decir, por la pestaña **activa**; al vencer el plazo se manda Ctrl+W a esa ventana con `hl.dsp.send_shortcut` (cierra la pestaña, no la ventana). Entre dos envíos pasan 3 s, para no cerrar por error la pestaña siguiente si el título tarda en actualizarse. Hoy: Instagram, TikTok, Facebook, X, Reddit, Twitch y Netflix; YouTube **no** está bloqueado a propósito (la persona busca videos del tema). Para probar sin tocar pestañas reales: una página local con `<title>Instagram prueba</title>` abierta con `zen-browser file://...`, y parar el temporizador apenas se cierre (Zen vuelve a la pestaña anterior, que también puede ser bloqueada).
- **Entorno de estudio** (`Focus.kits`): al tocar Empezar desde cero (no al reanudar ni tras un descanso) y con el modo Estudio, se abre lo del tipo elegido: `programacion` = NotebookLM + Zed en `~/Universidad`; `otro` = solo NotebookLM. **Sin terminal** desde el 24/10 (`focus tool ai` sigue existiendo) y sin `matematica`. NotebookLM abre en una **ventana propia** (`zen-browser --new-window`; con la URL sola Zen la agregaba como pestaña a la ventana abierta) **en el TV** (`Focus.sideMonitor`, el que no es `Screens.primary`) mediante [`bin/to-monitor.sh`](bin/to-monitor.sh) `PATRON MONITOR SEGUNDOS -- programa…`: anota las ventanas que ya había, lanza el programa y manda al monitor la primera ventana nueva cuyo título coincide (`hl.dsp.window.move({ monitor = "DP-1", window = "address:0x…" })`, probado). Se abren de a una cada 0,7 s. El PATH de la sesión de Hyprland **no incluye `~/.local/bin`**: `agy` se llama con su ruta completa. Por consola: `focus kit <tipo>`, `focus open`, `focus tool notebook|ide|ai`. Para probar sin dejar ventanas colgadas, cerrá después lo que se abrió.
- **El bloque sobrevive a las recargas:** `focus.json` guarda `running`, `phase`, `endsAt`, `remaining` y `overrideUntil` (se guarda al empezar, pausar, parar, cambiar de fase y cada minuto de estudio) y `Focus.resume()` lo retoma al iniciar: en marcha con el mismo final, o en pausa con lo que le quedaba. Si el bloque terminó con el shell caído o la PC apagada, queda parado. Antes cada `.qml` guardado volvía el temporizador a cero. **Solo el modo Estudio** suma minutos de hoy, racha y días del calendario: el modo Trabajo tiene temporizador y descansos pero no cuenta como estudio. Probado con `focus start`/`pause` en modo trabajo + recarga.
- Saltar el bloqueo exige esperar 60 s (fricción a propósito) y lo pausa 15 min.
- Probar el bloqueo: `kitty --class steam_app_prueba -o confirm_os_window_close=0 -e sleep 600` (sin esa opción kitty pide confirmación y la ventana no se cierra).
- **Cartel** (`FocusBlock.qml`): al detectar un juego durante el bloque de estudio muestra una tarjeta encima de todo, con una frase, el nombre de lo que se cierra y la cuenta regresiva de 15 s. No toma el teclado. El botón "Cerrar y estudiar" cierra el juego **al instante** (`Focus.closeBlocked()`, o `qs -c ombu ipc call focus closeblocked`); no hay forma de solo esconder el cartel.
- **Modo estudio para la IA** (`bin/agent-study.sh`): si `~/.local/state/ombu/modo` dice `estudio activo` (y el archivo tiene menos de 40 min, por si el shell se cayó), el hook le pasa al agente unas reglas: solo temas de la facultad, enseñar en vez de resolver, y las ideas ajenas van al cajón (`qs -c ombu ipc call focus idea "texto"`). Claude Code lo recibe por `UserPromptSubmit` (`additionalContext`) y Antigravity por `PreInvocation` (`injectSteps` con `ephemeralMessage`). Si trabajás en este repo y el modo estudio está activo, **seguí esas reglas**: la persona puede pausar el temporizador desde la barra.


## Mapa por área (estado actual)

Solo lo vigente y sus trampas. El porqué de cada cambio y lo que hubo antes está en `git log`.

### Barra y menús

- `TopBar.qml` va solo en `Screens.primary` (en el TV no hay barra; un menú pedido para otro monitor se redirige a ella). Izquierda: el logo abre `MainMenu.qml` (menú de la araña: sesión y sistema, Apariencia › temas con vista previa; Super+Alt+Espacio; `ipc call menu toggle|open "Tema"|close|theme <id>`). Derecha: aviso de modo, segundo plano (si hay algo), cronómetro de foco (solo con sesión) y el grupo fijo volumen · avisos · centro de control (`BarGroup.qml`).
- **Cada cosa en un solo lugar:** barra = estado; centro de control (`ControlMenu.qml`: brillo y volumen con `PillSlider`, Foco/No molestar/Teclado) = lo que se prende y apaga seguido; menú de la araña = sesión y sistema; panel lateral = facultad y seguridad; launcher = encuentra todo.
- `DropPopup`: `entered` pasa a `true` recién cuando el mouse llega al **cuerpo** del menú (al abrirse, la barra recibe un «salió» falso y el menú se cerraba a los 100 ms). No se cierra solo si hay texto escrito. `BarButton.hovered` es una marca propia que apaga `forgetHover()`: Wayland no siempre avisa que el mouse se fue.
- `AppsMenu` = minimizadas (`special:minimized`) + bandeja (`Apps.trayItems`, cada una con su `TrayMenu`) + apps sin ventana (`bgapps.py`). `Apps.tucked` cuenta las tres. Se actualiza con `openwindow`/`closewindow` de Hyprland y un sondeo de respaldo cada 30 s (1,5 s con el menú abierto), para lo que arranca sin ventana o muere después de cerrarla.
- `Actions.qml` es el único catálogo de acciones (lo usan `MainMenu` y el launcher). `Actions.runLater` corre la acción 260 ms después de cerrar el menú: vive en el singleton y sobrevive a la ventana.

### Launcher, portapapeles, atajos y fondos

- `LauncherMenu` (Super+Espacio, estilo Spotlight): apps y acciones por puntaje (las acciones restan 10.5 para que a igual coincidencia gane la app), abreviaturas (`subsequence`: «zn» → Zen), `=` cuentas (solo pasa la lista blanca `[0-9+\-*/().%\s]`), conversiones, `/texto` busca archivos con `fd`; Ctrl+Y vista previa (`bin/ql.sh`). Favoritas y ocultas en `Launch.qml`. `ipc call launcher search "<texto>"|preview`.
- `ClipMenu` + `Clip.qml`: historial de cliphist (`bin/clip*.sh`).
- `KeysMenu` (Super+K) muestra los atajos de `hyprctl binds -j` que tienen descripción en `hypr/atajos.lua` (`"SUPER + Q" = "Categoría|Texto|Teclas"`): un atajo nuevo sin entrada ahí no aparece. El singleton se llama `Atajos` porque `Keys` choca con QML.
- `WallpaperPicker` (Super+Ctrl+Espacio; `ipc call wallpaper menu|set <ruta>|current`): moverse pone `Walls.preview`; lo elegido es `Walls.current` (`fondo.json`). Carpetas: `~/Imágenes/Fondos` y `~/Imágenes`. Capturas en `~/Imágenes/Capturas`.

### Panel lateral

- `SidePanel` (Super+A; `ipc call side toggle|open resumen|sistema|close`; una pestaña desconocida abre la última): cajón pegado al borde izquierdo y fundido con la barra (`SideShape`). `SideEdge` lo abre con el mouse quieto medio segundo en el borde (no en `gaming`). Se cierra 150 ms después de sacar el mouse.
- **Resumen:** `Estacion` (clima de wttr.in, dólar de dolarapi y proyectos por git; copia en `~/.cache/ombu/estacion.json`, baja cada 30 min), `NowCard`, `FacuCard`, agenda (`AgendaRow`), estudio, pagos, ideas y música (`MediaCard`). Tarjetas con `ComicCard` y `Sticker`.
- El chat con los agentes se sacó el 28/10 (no se usaba); está en el historial de git si hace falta.
- **Sistema:** `SecurityView` + `Seguridad.qml` (`bin/seguridad.py watch 3`: puertos, servicios caídos, firewall, actualizaciones, procesos; `kill` se niega con los de `PROTECTED`) y las medidas (`SysStat` → `bin/sysstat.py`, usa `nvidia-smi`). **Solo corren con esa pestaña abierta.**

### Facultad, agenda y pagos

- `bin/anotar.py` entiende frases («parcial eda jueves 18hs») → evento con avisos por tipo y etiqueta `facu:<tipo>:<materia>`, o nota en `~/Universidad/<dir>/notas.md`. `AnotarMenu` (Super+Alt+N, `ipc call note toggle|open "texto"|close|parsed`) y `Facu.qml`. **Después de tocar el parser: `tests/anotar_test.py`.** Todo usa `~/Universidad` (con mayúscula).
- `Agenda.qml` junta eventos propios (`agenda.json`), Google (`bin/gcal.py`, OAuth con PKCE; o `bin/ics.py` con `OMBU_ICS_URL`), feriados y días de estudio, y manda los recordatorios con `notify-send` (los ya mandados quedan en `$XDG_RUNTIME_DIR/ombu-avisos.json`). Calendarios ocultos y silenciados en `calendario.json` (los pagos `sub:` nunca se silencian). Resumen del día una vez por día (`ipc call agenda summary`). **`agenda add` crea el evento en el Google Calendar real**: para probar avisos usá `ipc call agenda test` (local, se borra solo). `tests/gcal_mock_test.py` prueba gcal contra un servidor falso.
- **Credenciales, token y la URL del `.ics` jamás al repo ni a un log** (`google-{client,token}.json`, modo 600).
- `Subs.qml` (pagos): `suscripciones.json`, modo 600, **datos personales: no van al repo ni a la memoria con montos**. Cada pago es un evento repetido con etiqueta `sub:<id>` (el día 31 se guarda como `-1`, último del mes); lo que paga mamá va al calendario familiar (`Agenda.familyCalendarId`).

### Notificaciones

- `Notifs.qml` es el servidor (tiene que ser el único). Todo aviso se va solo salvo `kind === "confirm"`: 6 s por defecto, 30 si es crítico; el hover pausa, pero `hardLimit` lo cierra igual. Los que sobreviven a una recarga van solo al historial. Un aviso reemplazado (`replaces_id`) no pasa por `onNotification`: `Notifs.replaced()` lo recopia. `NotificationAction.invoke()` ya cierra la notificación: no llames a `dismiss()` después.
- Botones: `invokeAction` y además `Notifs.focusApp` si la acción es «ir a la app» (las apps de Electron reciben la acción y no hacen nada). `NotifRules.qml` traduce botones, descarta lo que ya estás viendo, reescribe los avisos de Claude Code en primera persona (`speak`) con su logo `~/.local/share/ombu/icons/claude.svg` (**marca de otra empresa: no va al repo**) y le pone la portada a los de Sung.
- El historial (`NotifMenu`) se agrupa por app.
- **No molestar y modo foco:** el bloque de estudio lo activa (`Notifs.dndByFocus`) y al pausar, parar o pasar al descanso lo apaga, solo si lo había activado él. Con No molestar pasan los críticos (las confirmaciones de los agentes lo son) y los que traen `x-ombu-urgent:1`: recordatorios `facu:parcial|recuperatorio|final|entrega`, pagos `sub:` del día y los avisos de `Focus.notify`. Para sumar otro: mandarlo con `-h int:x-ombu-urgent:1`.

### Música

- `Media.qml` mantiene un reproductor **elegido** que no cambia al pausarlo: el que se pone a sonar pasa a ser el elegido. Si el reproductor dice que no puede, los controles van directo por `busctl` (Sung no avisa `CanPlay`). `MediaTimeline` llama a `positionChanged()` cada segundo mientras suena. `ipc call media toggle|next|previous|cycle|status`.
- Sung (`~/Proyectos/Sung`) sigue el tema leyendo `~/.local/share/color-schemes/Ombu.colors` (variable `SUNG_NOCTALIA_COLORS` en su `.desktop`; una reinstalación de Sung la pisa). La sesión de Hyprland no tiene `~/.local/bin` en el PATH: los lanzadores usan la ruta completa.

### Temas

- `Themes.qml` (paletas) → `Theme.qml` (tokens). `Themes.set` guarda `tema.json` y pinta el borde de Hyprland con `hyprctl eval`. **`hyprctl reload` lo devuelve al color por defecto**: reaplicalo con `ipc call menu theme <id>`. El borde degradé va como **tabla** `{ colors = {…}, angle = 45 }` (la cadena la rechaza el Lua).
- `bin/qt-theme.py` lleva el tema a Qt/Dolphin (qt6ct, `Ombu.colors`, íconos Papirus), kitty (`pkill -USR1 -x kitty`), starship, Vesktop (QuickCSS, solo si está vacío o ya es de ombu) y Zen (`userChrome.css` + un bloque en `user.js`). Las plantillas están en `extras/` con `@NOMBRE@`; deja copias `.pre-temas`.
- Cómic: `Theme.comicArt` (el tema tiene `shadow`) solo en los **momentos** (bloqueo, salvapantallas, bienvenida, despedida, stickers del escritorio, greeter); `Theme.comic` (la interfaz diaria) está apagado con `comicChrome: false`. Bangers vive en `~/.local/share/fonts/ombu/` (fuera del repo); **Quickshell ve las fuentes nuevas recién al reiniciarse**.

### Bloqueo, inactividad, bienvenida y despedida

- `Idle.qml`: bloqueo a 5 min, monitores a 30. `bin/screensaver.py` atiende `org.freedesktop.ScreenSaver` (los videos de Zen) y escribe `$XDG_RUNTIME_DIR/ombu-inhibit.json`; `Idle` lo ignora si tiene más de 3 min. `ipc call idle status`.
- `Saver*` a 12 fps con `Saver.clock`: una sola grilla del tamaño máximo de todos los monitores, centrada y recortada en cada uno. `Auth` aborta PAM a los 20 s; `Idle.lockNow()` convierte una vista previa en bloqueo real.
- `Welcome.qml` reproduce `~/.local/share/ombu/intro.mp4` (no está en el repo) dentro de un `LazyLoader`, con la lluvia de código de respaldo; con la marca `intro-en-login` no la repite (ya la pasó el greeter). `ipc call welcome play`.
- `Goodbye.run("poweroff"|"reboot"|"logout")` anima y manda la orden con `execDetached` (un `Process` dentro de un menú perezoso moriría con la ventana). Probar sin apagar: `ipc call power goodbye`.

### Arranque y login (tocan el sistema: visto bueno antes, y el `sudo` lo corre la persona)

- **Greeter** (`greeter/`): corre como el usuario `greeter` y no ve tu casa; `build.sh` le copia tema, fondo, fuente, intro y los componentes de `SHARED` (si el bloqueo suma un componente, agregalo ahí). Lo instalado es una copia: cambia solo con `sudo bash greeter/install.sh`. Probar: `OMBU_GREETER_TEST=1 quickshell -p <carpeta armada>`.
- **Plymouth** (`extras/boot/make-plymouth.py`, `install-plymouth.sh`): `two-step` **exige** `bullet`, `entry`, `lock`, `keyboard`, `capslock` y `keymap-render.png`. **Nunca pruebes Plymouth en vivo** (`plymouthd` / `--show-splash` desde otra consola): tira el Hyprland de la sesión. Para verlo hay que reiniciar.
- **Limine** (`extras/boot/limine-theme.py`, `install-limine.sh`): cambia solo el aspecto y se niega si tocara las entradas. Con `ENABLE_VERIFICATION=yes`, **después de editar `/boot/limine.conf` hay que correr `limine-enroll-config`** o puede no arrancar. Nunca `timeout: 0`. Respaldo: el menú de la placa (F12/F8/Esc). `tests/limine_theme_test.py`.

### Hyprland y ventanas

- Ventanas con `rounding = 12`, `rounding_power = 3.5` y sombra suave. Los diálogos flotan centrados; **las reglas por título llevan también los títulos en español** (el sistema está en español).
- Discord y Sung abren en el TV. El TV recorta los bordes (overscan): se arregla en el menú del TV, no con márgenes.
- Pendiente del visto bueno: `logind.conf.d` para el botón de encendido (la placa expone un «Sleep Button» que suspende, y el suspend cuelga la NVIDIA).

### Luz nocturna

- `NightLight.qml` usa `hyprsunset` (lo lanza aparte si no corre: sobrevive a las recargas): de 20:00 a 7:00 a 4000 K, con una transición de ~0,8 s en pasos de 250 K. El interruptor manual (tile del centro de control, acción del launcher) vale hasta el próximo cambio de tramo. Estado en `nocturna.json`. `ipc call night toggle|on|off|auto|temp <K>|status`.
- Cambia la matriz de color (CTM) de Hyprland, que se aplica después de componer: **`grim` no lo captura**. Para comprobarlo, `night status` (`shown`) o mirar la pantalla.

### Brillo y C

- `Brightness.qml` (ddcutil, DDC/CI) manda un cambio a la vez. El primer bus de `ddcutil detect` puede ser el TV («Invalid display»): el bueno es el de la línea `Display N`. `ipc call brightness up|down`.
- `bin/cproj.sh` arma un proyecto de C en `~/Universidad`; `make leaks` usa valgrind.

### Rendimiento y memoria

- Medí con PSS (`/proc/<pid>/smaps_rollup`) **recién reiniciado** (`bin/check.sh -r` y esperar ~15 s): cada recarga deja memoria sin liberar.
- La persona **prefiere memoria antes que 100–150 ms en la primera aparición**. Los menús que casi nunca se abren van en `LazyLoader` con `active: <bandera> || shown` (la ventana actualiza `shown` en `onVisibleChanged`) y la entrada espera a `FirstFrame`. Una ventana perezosa no puede tener un `Process` o un `Timer` que tenga que sobrevivirla.
- Los procesos externos corren solo mientras algo los muestra (sysstat, seguridad). Nada a 60 fps en el salvapantallas.

### Trampas de QML y Quickshell que ya costaron tiempo

- **Editá los `.qml` en el mismo archivo** (`open(p, "r+")` + `truncate()`): el `Edit` de los agentes y `sed -i` lo reemplazan, y Quickshell puede dejar de vigilarlo. Después, `bin/check.sh`.
- Un `TapHandler` dentro de algo que también se toca lleva `gesturePolicy: TapHandler.ReleaseWithinBounds` (si no, los dos reciben el clic). Se prueba con `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input prueba.qml`.
- En un `Repeater`, si el clic cambia el modelo, la fila se destruye en medio del manejador: guardá lo necesario y hacé lo que destruye al final.
- Algunos `component` internos nuevos dan «X is not a type»: usá un archivo propio.
- Nombres prohibidos: una propiedad `on` + mayúscula (`onAccent`) se toma como manejador; un `Row` no puede declarar `top` (FINAL); una función `fill` del singleton no se puede llamar desde un `component` interno.
- Un parámetro tipado `int` que no se pasa vale `0`, no `undefined`. Una lista de QML no pasa `Array.isArray`: contá con `l.length`. Los manejadores con parámetros se escriben `onPositionChanged: pos => { … }`.
- `qs kill` a veces deja el proceso trabado y sin atender D-Bus (no salen notificaciones); `check.sh -r` ya lo resuelve. ¿Está vivo? `timeout 5 qs -c ombu ipc call idle status`.
- Quickshell 0.3.2 a veces se cae **al cerrarse** (`SIGSEGV` en `~QQmlEngine`): es un bug de Quickshell y se relanza solo.
