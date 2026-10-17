import QtQuick
import QtQuick.Shapes

// Silueta de un menú que cuelga de la barra: arriba se funde con ella
// mediante esquinas cóncavas, abajo tiene esquinas redondeadas.
// El ancho total es panelWidth + 2 * fillet.
Shape {
    id: root

    required property real panelWidth
    required property real panelHeight

    readonly property real f: Theme.fillet
    readonly property real r: Theme.popupRadius

    width: panelWidth + 2 * f
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
            x: root.width - root.f
            y: root.f
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: root.width - root.f
            y: root.height - root.r
        }
        PathArc {
            x: root.width - root.f - root.r
            y: root.height
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Clockwise
        }
        PathLine {
            x: root.f + root.r
            y: root.height
        }
        PathArc {
            x: root.f
            y: root.height - root.r
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Clockwise
        }
        PathLine {
            x: root.f
            y: root.f
        }
        PathArc {
            x: 0
            y: 0
            radiusX: root.f
            radiusY: root.f
            direction: PathArc.Counterclockwise
        }
    }
}
