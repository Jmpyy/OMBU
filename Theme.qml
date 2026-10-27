pragma Singleton

import QtQuick
import Quickshell

// Tokens de diseño: todo el aspecto sale de acá. Los colores base vienen del tema elegido (Themes.qml).
Singleton {
    // Geometría
    readonly property int barHeight: 36
    readonly property int fillet: 16      // radio de las esquinas cóncavas
    readonly property int margin: 14
    readonly property int popupRadius: comic ? 8 : 16
    readonly property int cardRadius: comic ? 10 : 18
    // Controles (botones, sliders, selectores): esquinas suaves, no píldoras
    readonly property int controlRadius: comic ? 6 : 10

    // Colores
    readonly property color bg: Themes.active.bg  // sólido, sin transparencia
    readonly property color surface: Themes.active.surface  // tarjetas y filas sobre el fondo
    readonly property color track: Themes.active.track  // pista de los sliders
    readonly property color text: Themes.active.text
    readonly property color textDim: Themes.active.textDim
    readonly property color accent: Themes.active.accent
    readonly property color danger: Themes.active.danger
    readonly property color warn: Themes.active.warn
    // Texto e íconos sobre un fondo de acento (botones, pastilla del escritorio activo...). Oscuro en los
    // temas de acento claro y crema en los de acento rojo, donde el oscuro no se lee bien.
    // Sombra dura de las tarjetas (HardShadow): transparente salvo en los temas de cómic
    readonly property color shadow: Themes.active.shadow ?? "transparent"
    // Los temas de cómic llevan sombra dura, bordes de tinta, puntos de impresión y una tipografía de
    // historieta. Se usan en los «momentos» (bloqueo, salvapantallas, bienvenida, despedida, login,
    // stickers del escritorio vacío: comicArt/artFont) y no en la interfaz de todos los días (barra,
    // menús, panel, launcher, avisos), que con todo eso se veía saturada. comicChrome = true lo vuelve
    // a poner también en el día a día.
    readonly property bool comicArt: shadow.a > 0
    readonly property bool comicChrome: false
    readonly property bool comic: comicArt && comicChrome
    readonly property string artFont: Themes.active.display ?? ""
    readonly property string displayFont: comic ? artFont : ""
    readonly property color accentText: Themes.active.onAccent ?? "#14131a"
    // El negro cálido de los bordes de tinta de los temas de cómic
    readonly property color ink: "#0a0708"
    readonly property color hover: Qt.rgba(1, 1, 1, 0.09)
    readonly property color border: Qt.rgba(1, 1, 1, 0.08)
    // Contorno de la barra y de los menús que cuelgan de ella: se nota sobre una terminal oscura
    readonly property color outline: Qt.rgba(1, 1, 1, 0.2)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)

    // Fondo de pantalla por defecto: ninguno (se ve el color de fondo). Los fondos se eligen en el
    // selector (Super+Ctrl+Espacio) entre las imágenes de ~/Imágenes/Fondos
    readonly property string wallpaper: ""

    // Bloqueo por inactividad: a los idleLockSeconds se bloquea la sesión mostrando el
    // salvapantallas ASCII; a los idleScreenOffSeconds se apagan los monitores (siguen
    // bloqueados). Cualquier tecla o movimiento del mouse los despierta.
    readonly property int idleLockSeconds: 300
    readonly property int idleScreenOffSeconds: 1800
    // Cuadros por segundo del salvapantallas y segundos sin actividad en la pantalla de
    // bloqueo antes de que el salvapantallas vuelva solo
    readonly property int saverFps: 12
    readonly property int saverFontSize: 16
    readonly property int saverRewakeSeconds: 20

    // Tipografía
    readonly property int fontSize: 13
    readonly property string iconFont: "Material Symbols Rounded"

    // Animación
    readonly property int revealDuration: 420
    readonly property int popupDuration: 190
}
