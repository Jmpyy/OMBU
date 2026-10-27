import QtQuick
import QtQuick.Effects

// Fondo de la pantalla de bloqueo: el wallpaper desenfocado, con viñeteado y dos brillos de
// color que se desplazan muy despacio para darle profundidad.
//
// El desenfoque del wallpaper y de cada brillo se calcula una sola vez y queda guardado como
// textura (layer.enabled): de lo contrario se recalcularía en cada cuadro de la animación.
Item {
    id: root

    // Se detienen las animaciones cuando algo las tapa (el salvapantallas)
    property bool animating: true

    // Tiempo de la animación, en segundos. Los brillos se mueven con un temporizador a 12 cuadros
    // por segundo en lugar de con animaciones: estas harían redibujar toda la pantalla 60 veces
    // por segundo y subían mucho el uso de la GPU.
    property real t: 0

    Timer {
        interval: 83
        repeat: true
        running: root.animating && root.visible
        onTriggered: root.t += 0.083
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: "file://" + Walls.current
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        // Se desenfoca entero: a un cuarto de resolución se ve igual y ocupa 2 MB en vez de ~16
        // (el fondo actual es de 2666x1500)
        sourceSize: Qt.size(960, 540)
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.2
        saturation: -0.05
        layer.enabled: true
    }

    // Brillo grande, violeta, que deriva arriba a la izquierda
    Item {
        id: orbSourceA

        width: 1100
        height: 1100
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.centerIn: parent
            width: 620
            height: 620
            radius: 310
            color: Theme.accent
        }
    }

    MultiEffect {
        id: glowA

        width: 1100
        height: 1100
        x: -210 + 90 * Math.sin(root.t * 0.1208)
        y: -300 + 50 * Math.sin(root.t * 0.1496 + 1)
        source: orbSourceA
        blurEnabled: true
        blur: 1
        blurMax: 128
        opacity: 0.2
        layer.enabled: true
    }

    // Brillo más chico y frío, abajo a la derecha
    Item {
        id: orbSourceB

        width: 900
        height: 900
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.centerIn: parent
            width: 480
            height: 480
            radius: 240
            color: "#5b8def"
        }
    }

    MultiEffect {
        id: glowB

        width: 900
        height: 900
        x: root.width - 680 + 80 * Math.sin(root.t * 0.1047)
        y: root.height - 560
        source: orbSourceB
        blurEnabled: true
        blur: 1
        blurMax: 128
        opacity: 0.14
        layer.enabled: true
    }

    // Oscurece un poco todo y más en los bordes
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.4
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.3

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.5)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.34

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.6)
            }
        }
    }
}
