import QtQuick

// Avisa (ready) cuando la ventana que lo contiene dibujó su primer cuadro. Las ventanas que se crean
// recién al abrirse (LazyLoader en shell.qml) tardan ~100-150 ms en aparecer: si la animación de entrada
// arrancara al crearlas, para cuando se ven ya habría pasado casi entera y se vería como un salto.
// Mismo truco que DropPopup (ready). Si la señal no llega (ventana invisible), avisa igual a los 400 ms.
Item {
    id: root

    signal ready

    property bool done: false
    readonly property var win: Window.window

    function finish(): void {
        if (done)
            return;
        done = true;
        ready();
    }

    Connections {
        target: root.win
        enabled: !root.done

        function onFrameSwapped(): void {
            root.finish();
        }
    }

    Timer {
        interval: 400
        running: !root.done
        onTriggered: root.finish()
    }
}
