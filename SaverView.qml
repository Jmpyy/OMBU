import QtQuick

// Lluvia de código con el logo (ver Saver). La usan la pantalla de bloqueo y la bienvenida.
Item {
    id: root

    // Cuánto se ve, de 0 a 1
    property real amount: 1

    // Cuántas celdas de texto caben en esta pantalla
    readonly property real cw: fm.advanceWidth("M")
    readonly property real lh: fm.lineSpacing
    readonly property int cols: Math.floor(width / cw)
    readonly property int rows: Math.floor(height / lh)
    // Dónde queda la grilla de texto (está centrada)
    readonly property real gridX: Math.round((width - cols * cw) / 2)
    readonly property real gridY: Math.round((height - rows * lh) / 2)

    clip: true
    opacity: amount
    visible: amount > 0.01
    onColsChanged: Saver.configure(cols, rows)
    onRowsChanged: Saver.configure(cols, rows)

    FontMetrics {
        id: fm

        font.family: "monospace"
        font.pixelSize: Theme.saverFontSize
    }

    Rectangle {
        anchors.fill: parent
        color: "#08070d"
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: root.cols
        gridRows: root.rows
        text: Saver.dim
        color: "#2b2350"
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: root.cols
        gridRows: root.rows
        text: Saver.mid
        color: "#5b49a8"
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: root.cols
        gridRows: root.rows
        text: Saver.bright
        color: "#9b87f5"
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: root.cols
        gridRows: root.rows
        text: Saver.head
        color: "#f1edff"
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: root.cols
        gridRows: root.rows
        text: Saver.logo
        color: "#b6a4ff"
    }

    SaverLayer {
        cellWidth: root.cw
        cellHeight: root.lh
        gridCols: root.cols
        gridRows: root.rows
        text: Saver.logoHi
        color: "#ffffff"
    }
}
