pragma Singleton

import QtQuick
import Quickshell

// Tokens de diseño: todo el aspecto sale de acá.
Singleton {
    // Geometría
    readonly property int barHeight: 32
    readonly property int fillet: 16      // radio de las esquinas cóncavas
    readonly property int margin: 14
    readonly property int popupRadius: 16
    readonly property int cardRadius: 28

    // Colores
    readonly property color bg: "#14131a"           // sólido, sin transparencia
    readonly property color surface: "#1d1c26"      // tarjetas y filas sobre el fondo
    readonly property color track: "#2b2a38"        // pista de los sliders
    readonly property color text: "#e8e8f0"
    readonly property color textDim: "#8a8a9c"
    readonly property color accent: "#a78bfa"
    readonly property color danger: "#f87171"
    readonly property color hover: Qt.rgba(1, 1, 1, 0.09)
    readonly property color border: Qt.rgba(1, 1, 1, 0.08)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)

    // Tipografía
    readonly property int fontSize: 13
    readonly property string iconFont: "Material Symbols Rounded"

    // Animación
    readonly property int revealDuration: 420
    readonly property int popupDuration: 260
}
