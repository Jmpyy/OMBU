import QtQuick

// Sombra dura de viñeta de cómic: una copia sólida del rectángulo, corrida unos píxeles hacia abajo y
// a la derecha. Solo se ve en los temas que definen `shadow` (Spider-Man, Iron Man). Va declarada
// antes del rectángulo al que acompaña, en el mismo padre, y lo sigue en posición, tamaño, escala y
// opacidad (las tarjetas se animan).
Rectangle {
    required property Item target
    property int offset: 5

    visible: Theme.shadow.a > 0 && target.visible
    x: target.x + offset
    y: target.y + offset
    width: target.width
    height: target.height
    radius: target.radius
    scale: target.scale
    rotation: target.rotation
    transformOrigin: target.transformOrigin
    opacity: target.opacity
    color: Theme.shadow
}
