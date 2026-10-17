pragma Singleton

import QtQuick
import Quickshell

// Fecha actual e idioma de la interfaz (Qt dibujaba todo en inglés por defecto).
Singleton {
    readonly property var locale: Qt.locale("es_AR")
    readonly property date date: clock.date

    function capitalize(text: string): string {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
