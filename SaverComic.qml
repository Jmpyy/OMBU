import QtQuick
import QtQuick.Shapes

// Toques de historieta sobre la lluvia del salvapantallas (solo con los temas de cómic, ver SaverView):
// trama de puntos y viñeteado de tinta (fijos), la araña colgada de su hilo como en la intro del
// arranque, y de vez en cuando una onomatopeya («¡THWIP!») en un estallido. Todo se mueve con el reloj del
// salvapantallas (Saver.clock, 12 cuadros por segundo): no suma animaciones a 60 fps.
Item {
    id: root

    // Segundos dentro del ciclo de 24 s del salvapantallas
    readonly property real t: Saver.clock
    readonly property real cycle: 24

    // Pseudoazar repetible: el mismo número da siempre lo mismo (cambia de ciclo en ciclo y por monitor)
    function rnd(n: real): real {
        const x = Math.sin(n * 12.9898) * 43758.5453;
        return x - Math.floor(x);
    }

    clip: true

    // ---- Trama de puntos y viñeteado: los bordes se oscurecen como el marco de una viñeta ----
    Halftone {
        art: true
        anchors.margins: 0
        strength: 0.06
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                centerRadius: Math.max(root.width, root.height) * 0.72
                focalX: root.width / 2
                focalY: root.height / 2

                GradientStop {
                    position: 0.5
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.85)
                }
            }
            startX: 0
            startY: 0

            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
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
    }

    // ---- La araña colgada de su hilo: baja y sube una vez por ciclo y se balancea ----
    // (los períodos dividen al ciclo de 24 s, así no salta cuando el ciclo vuelve a empezar)
    Item {
        visible: Themes.logoFile !== ""
        x: Math.round(root.width * (root.width > root.height ? 0.83 : 0.8))
        width: 1
        height: Math.round(root.height * 0.14 + root.height * 0.08 * (1 - Math.cos(2 * Math.PI * root.t / root.cycle)))
        rotation: 6 * Math.sin(2 * Math.PI * 5 * root.t / root.cycle)
        transformOrigin: Item.Top

        Rectangle {
            x: -1
            width: 2
            height: parent.height
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.5)
        }

        Image {
            x: -width / 2
            y: parent.height - 10
            width: 76
            height: 76
            source: Themes.logoFile
            sourceSize: Qt.size(152, 152)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // ---- Onomatopeyas: tres por ciclo, lejos del logo del centro ----
    readonly property var words: ["¡THWIP!", "¡ZAS!", "¡PUM!", "¡THWIP THWIP!", "¡SPIDEY-SENSE!", "¡KRAK!", "¡FIUUU!"]
    // Cuándo empieza cada una dentro del ciclo (entre el logo ya armado y su disolución) y cuánto dura
    readonly property var starts: [6.5, 11, 15]
    readonly property real span: 2.4
    readonly property int slot: {
        for (let i = 0; i < starts.length; i++)
            if (t >= starts[i] && t < starts[i] + span)
                return i;
        return -1;
    }
    readonly property real local: slot < 0 ? 0 : t - starts[slot]
    // Cambia en cada ciclo y en cada monitor (Date.now() se vuelve a leer en cada cuadro)
    readonly property real seed: Math.floor(Date.now() / (cycle * 1000)) * 3 + slot + Math.round(width) / 7
    // Rincones lejos del logo, en fracciones de la pantalla
    readonly property var zones: [[0.17, 0.2], [0.8, 0.22], [0.19, 0.8], [0.8, 0.8]]
    readonly property var zone: zones[Math.floor(rnd(seed) * zones.length)]

    Item {
        id: burst

        // Estrella de 16 puntas un poco irregular, como dibujada a mano
        readonly property var points: {
            const pts = [];
            const n = 16, cx = width / 2, cy = height / 2;
            for (let i = 0; i <= n * 2; i++) {
                const a = Math.PI * i / n;
                const r = (i % 2 === 0 ? 1 : 0.7) * (0.92 + 0.08 * root.rnd(i * 3.1 + 1));
                pts.push(Qt.point(cx + Math.cos(a) * r * width / 2, cy + Math.sin(a) * r * height / 2));
            }
            return pts;
        }

        visible: root.slot >= 0
        width: 280
        height: 160
        x: Math.round(root.width * (root.zone[0] + 0.06 * (root.rnd(root.seed + 1) - 0.5)) - width / 2)
        y: Math.round(root.height * (root.zone[1] + 0.06 * (root.rnd(root.seed + 2) - 0.5)) - height / 2)
        rotation: -12 + 24 * root.rnd(root.seed + 3)
        // Aparece de golpe con un rebote y se desvanece al final (a 12 cuadros por segundo: bien de historieta)
        scale: root.local < 0.17 ? 0.3 + 0.9 * root.local / 0.17 : (root.local < 0.34 ? 1.2 - 0.2 * (root.local - 0.17) / 0.17 : 1)
        opacity: root.local > root.span - 0.45 ? Math.max(0, (root.span - root.local) / 0.45) : 1

        // Sombra dura
        Shape {
            x: 7
            y: 7
            width: burst.width
            height: burst.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.shadow
                strokeColor: "transparent"

                PathPolyline {
                    path: burst.points
                }
            }
        }

        Shape {
            width: burst.width
            height: burst.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.accent
                strokeColor: Theme.ink
                strokeWidth: 3
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: burst.points
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: parent.height * 0.5
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.Fit
            minimumPixelSize: 14
            text: root.words[Math.floor(root.rnd(root.seed + 4) * root.words.length)]
            color: Theme.text
            style: Text.Outline
            styleColor: Theme.ink
            font.family: Theme.artFont
            font.pixelSize: 44
            font.letterSpacing: 1
        }
    }
}
