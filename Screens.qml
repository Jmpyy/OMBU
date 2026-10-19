pragma Singleton

import QtQuick
import Quickshell

// Los monitores de verdad. Un puerto con un cable que no devuelve su identificación (EDID) aparece como
// «conectado» pero solo ofrece las resoluciones de emergencia (1024x768 o menos): nadie lo ve y ombu le
// armaba barra, fondo y avisos para nada. Aquí se descartan los que no tienen modelo y son así de
// chicos; si el monitor sin identificación sí muestra una resolución normal, se conserva. Si todos
// parecieran falsos se usan todos, para no quedarse sin ventanas.
Singleton {
    id: root

    function phantom(s): bool {
        return (s.model ?? "") === "" && s.width <= 1024;
    }

    readonly property var list: {
        const real = Quickshell.screens.filter(s => !phantom(s));
        return real.length > 0 ? real : Quickshell.screens;
    }

    // El de más a la izquierda (arriba, si empatan): es el principal
    readonly property var primary: list.length > 0 ? list.reduce((a, b) => (b.x < a.x || (b.x === a.x && b.y < a.y)) ? b : a) : null

    Component.onCompleted: console.log("SCREENS:", Quickshell.screens.map(s => s.name + "[" + s.model + " " + s.width + "x" + s.height + (phantom(s) ? " falso" : "") + "]").join(" "))
}
