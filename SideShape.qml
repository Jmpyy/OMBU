import QtQuick
import QtQuick.Shapes

// Silueta del panel lateral: sale del borde izquierdo de la pantalla y se funde con la barra (arriba)
// y con el borde inferior (abajo) mediante esquinas cóncavas, igual que los menús de la barra
// (DropShape). El ancho total es panelWidth + fillet: la curva sobresale a la derecha del cuerpo.
Shape {
    id: root

    required property real panelWidth
    required property real panelHeight

    readonly property real f: Theme.fillet

    width: panelWidth + f
    height: panelHeight
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: Theme.bg
        strokeColor: "transparent"
        startX: 0
        startY: 0

        PathLine {
            x: root.width
            y: 0
        }
        PathArc {
            x: root.panelWidth
            y: root.f
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: root.panelWidth
            y: root.height - root.f
        }
        PathArc {
            x: root.width
            y: root.height
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: 0
            y: root.height
        }
        PathLine {
            x: 0
            y: 0
        }
    }

    // Contorno: solo el lado derecho; arriba y abajo se funde con la barra y con el borde de la pantalla
    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.comic ? Theme.ink : Theme.outline
        strokeWidth: Theme.comic ? 2 : 1
        startX: root.width
        startY: 0

        PathArc {
            x: root.panelWidth
            y: root.f
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: root.panelWidth
            y: root.height - root.f
        }
        PathArc {
            x: root.width
            y: root.height
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
    }
}
