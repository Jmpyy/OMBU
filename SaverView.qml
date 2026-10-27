import QtQuick
import Quickshell

// Lluvia de código con el logo (ver Saver). La usan la pantalla de bloqueo y la bienvenida.
Item {
    id: root

    // Cuánto se ve, de 0 a 1
    property real amount: 1

    // Cuántas celdas de texto caben en esta pantalla
    // advanceWidth() es una función: sin nombrar el tamaño aquí, el ancho no se recalcula cuando la fuente
    // termina de aplicarse, y la grilla (y el logo) quedaban calculados con un ancho de más o de menos
    readonly property real cw: {
        fm.font.pixelSize;
        fm.font.family;
        return fm.advanceWidth("M");
    }
    readonly property real lh: fm.lineSpacing
    readonly property int cols: Math.floor(width / cw)
    readonly property int rows: Math.floor(height / lh)
    // Dónde queda la grilla de texto: la compartida (Saver.cols x Saver.rows, la más grande de todos los
    // monitores) centrada en este; en un monitor más chico queda por fuera y se recorta (clip)
    readonly property real gridX: Math.round((width - Saver.cols * cw) / 2)
    readonly property real gridY: Math.round((height - Saver.rows * lh) / 2)

    // Rampa de la lluvia: con Ombú, los violetas de siempre; con los demás temas, derivada de su acento
    readonly property bool ombuLook: Theme.accent.toString().toLowerCase() === "#a78bfa"
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property color floorColor: ombuLook ? "#08070d" : mix(Theme.bg, "#000000", 0.45)
    readonly property color dimColor: ombuLook ? "#2b2350" : mix(floorColor, Theme.accent, 0.22)
    readonly property color midColor: ombuLook ? "#5b49a8" : mix(floorColor, Theme.accent, 0.55)
    readonly property color brightColor: ombuLook ? "#9b87f5" : Theme.accent
    readonly property color headColor: ombuLook ? "#f1edff" : mix(Theme.accent, Theme.text, 0.8)
    readonly property color logoColor: ombuLook ? "#b6a4ff" : mix(Theme.accent, Theme.text, 0.3)
    readonly property color logoHiColor: ombuLook ? "#ffffff" : Theme.text

    clip: true
    opacity: amount
    visible: amount > 0.01
    // La lluvia y el logo se calculan una sola vez para todos los monitores, del tamaño del más grande en
    // cada dirección (ver Saver.report). Antes mandaba «el principal», pero al crearse la ventana todavía
    // no sabe en qué monitor está y cualquiera se creía el principal: con el TV vertical ganaba él y el
    // logo del monitor principal quedaba fuera de pantalla.
    readonly property string sizeKey: "vista-" + Math.random().toString(36).slice(2)
    function reportSize(): void {
        if (cols > 0 && rows > 0)
            Saver.report(sizeKey, cols, rows);
    }
    onColsChanged: reportSize()
    onRowsChanged: reportSize()
    Component.onCompleted: reportSize()
    Component.onDestruction: Saver.forget(sizeKey)

    FontMetrics {
        id: fm

        font.family: "monospace"
        font.pixelSize: Theme.saverFontSize
    }

    Rectangle {
        anchors.fill: parent
        color: root.floorColor
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: Saver.cols
        gridRows: Saver.rows
        text: Saver.dim
        color: root.dimColor
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: Saver.cols
        gridRows: Saver.rows
        text: Saver.mid
        color: root.midColor
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: Saver.cols
        gridRows: Saver.rows
        text: Saver.bright
        color: root.brightColor
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: Saver.cols
        gridRows: Saver.rows
        text: Saver.head
        color: root.headColor
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: Saver.cols
        gridRows: Saver.rows
        text: Saver.logo
        color: root.logoColor
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: Saver.cols
        gridRows: Saver.rows
        text: Saver.logoHi
        color: root.logoHiColor
    }

    // Toques de historieta encima de la lluvia (solo temas de cómic y no en la bienvenida, que dura 4 s)
    SaverComic {
        anchors.fill: parent
        visible: Theme.comicArt && !Saver.welcome
    }
}
