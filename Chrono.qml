pragma Singleton

import QtQuick
import Quickshell

// Fecha actual e idioma de la interfaz (Qt dibujaba todo en inglés por defecto).
Singleton {
    readonly property var locale: Qt.locale("es_AR")
    // Al cargar, el reloj del sistema tarda un instante en tener fecha (aviso «Unable to assign [undefined]»)
    readonly property date date: clock.date ?? new Date()

    function capitalize(text: string): string {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
