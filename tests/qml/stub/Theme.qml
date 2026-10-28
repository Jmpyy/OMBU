pragma Singleton

import QtQuick

// Theme de mentira para probar los controles sin Quickshell (el real lee el tema con FileView).
// Solo lo que usan los controles que se prueban; los valores no importan.
QtObject {
    readonly property color accent: "#e23030"
    readonly property color accentText: "#14131a"
    readonly property color bg: "#161011"
    readonly property color surface: "#211819"
    readonly property color track: "#2e2425"
    readonly property color text: "#f4e8d3"
    readonly property color textDim: "#a89a8c"
    readonly property color danger: "#ff5555"
    readonly property color ink: "#0a0708"
    readonly property color shadow: "transparent"
    readonly property bool comic: false
    readonly property string displayFont: ""
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property int controlRadius: 10
    readonly property int fontSmall: 12
    readonly property int fontBody: 13
    readonly property int fontCaption: 11
    readonly property int iconSm: 16
    readonly property int iconMd: 18
    readonly property int animFast: 150
    readonly property int ease: Easing.OutCubic
}
