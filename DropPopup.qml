import QtQuick
import Quickshell
import Quickshell.Hyprland

// Base de los menús que cuelgan de la barra: se funden con su silueta y crecen desde el
// botón que los abrió. El contenido se declara como hijo.
PopupWindow {
    id: root

    required property var barWindow
    required property Item anchorItem
    property bool open: false
    // Tamaño del cuerpo (sin contar la franja de esquinas cóncavas de arriba)
    property real bodyWidth: 320
    property real bodyHeight: 120
    // true = centrado bajo el botón; false = borde derecho alineado con el botón
    property bool centered: false
    // true = borde izquierdo alineado con el botón (el menú de la araña, a la izquierda de la barra)
    property bool alignLeft: false

    default property alias content: body.data

    signal dismissed

    readonly property real fullHeight: Theme.fillet + bodyHeight

    // La ventana del menú tarda ~150 ms en crearse y dibujar su primer cuadro. Si la animación
    // arrancara al pedir el menú, para cuando la ventana se ve ya habría pasado casi entera y
    // se vería como un salto. Por eso espera a que la ventana haya dibujado un primer cuadro.
    property bool ready: false

    // Ventana pre-creada: con el mouse sobre el botón se crea el menú (invisible y sin tomar
    // clics) para que, al hacer clic, ya esté dibujado y la animación arranque al instante.
    property bool warm: false

    // 0 = recogido en el botón, 1 = desplegado
    property real p: (open && ready) ? 1 : 0

    Behavior on p {
        NumberAnimation {
            duration: root.open ? Theme.animNormal : Theme.animFast
            easing.type: Theme.ease
        }
    }

    // El menú se ancla al borde inferior de un rectángulo de 1 px, y se sube para que quede
    // 1 px montado sobre la barra: sin esto queda un filo de 1 px entre ambos que deja ver el
    // fondo de pantalla y hace que se vean como dos piezas separadas.
    readonly property int seamFix: 2

    function place(): void {
        const y = Theme.barHeight - seamFix;
        if (centered) {
            const mid = anchorItem.mapToItem(barWindow.contentItem, anchorItem.width / 2, 0);
            anchor.rect = Qt.rect(mid.x, y, 1, 1);
            return;
        }
        if (alignLeft) {
            const left = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
            // El borde izquierdo del cuerpo queda alineado con el borde izquierdo del botón
            anchor.rect = Qt.rect(left.x - Theme.fillet, y, 1, 1);
            return;
        }
        const pos = anchorItem.mapToItem(barWindow.contentItem, anchorItem.width, 0);
        // El borde derecho del cuerpo queda alineado con el borde derecho del botón
        anchor.rect = Qt.rect(pos.x + Theme.fillet, y, 1, 1);
    }

    onOpenChanged: {
        if (open) {
            place();
            // Recién cuenta como «entró» cuando el mouse llega al cuerpo del menú: al abrirse, el menú
            // toma el mouse y la barra recibe un «salió» aunque no se haya movido, y con entered en
            // true desde el arranque el menú se cerraba solo a los 100 ms
            root.entered = false;
            leaveTimer.stop();
        } else {
            root.entered = false;
            leaveTimer.stop();
        }
    }

    onWarmChanged: if (warm)
        place()

    visible: open || p > 0.001 || warm
    // Mientras solo está pre-creado, no recibe clics: pasan al escritorio que está debajo
    mask: (open || p > 0.001) ? null : noInput

    Region {
        id: noInput
    }
    onVisibleChanged: if (!visible)
        ready = false

    color: "transparent"
    implicitWidth: bodyWidth + 2 * Theme.fillet
    implicitHeight: fullHeight
    anchor.window: barWindow
    anchor.edges: centered ? Edges.Bottom : (alignLeft ? (Edges.Bottom | Edges.Left) : (Edges.Bottom | Edges.Right))
    anchor.gravity: centered ? Edges.Bottom : (alignLeft ? (Edges.Bottom | Edges.Right) : (Edges.Bottom | Edges.Left))

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.dismissed()
    }

    // El mouse sobre el botón: tras 100 ms se pre-crea el menú; al irse se libera con demora
    Item {
        parent: root.anchorItem
        anchors.fill: parent

        HoverHandler {
            id: warmHover

            onHoveredChanged: {
                if (hovered) {
                    coolTimer.stop();
                    warmTimer.restart();
                } else {
                    warmTimer.stop();
                    coolTimer.restart();
                }
            }
        }

        Timer {
            id: warmTimer

            interval: 40
            onTriggered: root.warm = true
        }

        Timer {
            id: coolTimer

            interval: 1200
            onTriggered: if (!root.open)
                root.warm = false
        }
    }

    // El mouse está sobre el cuerpo del menú o sobre el botón de la barra que lo abrió
    readonly property bool pointerInside: popupHover.hovered || warmHover.hovered
    property bool entered: false

    onPointerInsideChanged: {
        if (!root.open)
            return;
        if (pointerInside) {
            if (popupHover.hovered)
                root.entered = true;
            leaveTimer.stop();
        } else if (root.entered) {
            leaveTimer.restart();
        }
    }


    // Al sacar el cursor del menú y de su botón, se cierra solo sin necesidad de hacer clic
    Timer {
        id: leaveTimer

        interval: 100
        onTriggered: {
            // No se cierra si hay algo escrito en un campo de texto del menú: se perdería el borrador
            const f = root.activeFocusItem;
            const typing = f && f.cursorPosition !== undefined && typeof f.text === "string" && f.text.length > 0;
            if (root.open && root.entered && !root.pointerInside && !typing)
                root.dismissed();
        }
    }

    // Avisa cuando la ventana ya dibujó su primer cuadro (ahí arranca la animación)
    Item {
        id: frameWatcher

        readonly property var win: Window.window

        Connections {
            target: frameWatcher.win
            enabled: root.visible && !root.ready

            function onFrameSwapped(): void {
                root.ready = true;
            }
        }

        // Respaldo por si la señal no llegara: no se deja el menú invisible
        Timer {
            interval: 450
            running: root.visible && !root.ready
            onTriggered: root.ready = true
        }
    }

    // La caja crece desde el botón (se achica hacia su borde de arriba, que sigue pegado a la
    // barra) y el contenido aparece un poco después. Al cerrar hace el camino inverso.
    Item {
        anchors.fill: parent

        HoverHandler {
            id: popupHover
            enabled: root.open
        }

        Item {
            id: animBox

            width: parent.width
            height: parent.height
            opacity: root.p
            scale: 0.95 + 0.05 * root.p
            transformOrigin: Item.Top
            transform: Translate {
                y: (1 - root.p) * -8
            }
            layer.enabled: root.p > 0.001 && root.p < 0.999
            layer.smooth: true

            DropShape {
                panelWidth: root.bodyWidth
                panelHeight: root.fullHeight
            }

            Item {
                id: body

                x: Theme.fillet
                y: Theme.fillet
                width: root.bodyWidth
                height: root.bodyHeight
            }
        }
    }
}
