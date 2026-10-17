pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Estado del indicador de volumen: aparece cuando cambia el volumen o el mute
// de la salida principal, y se oculta solo.
Singleton {
    id: root

    property bool shown: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string icon: muted || volume <= 0 ? "volume_off" : (volume < 0.5 ? "volume_down" : "volume_up")

    // Ignora los cambios del arranque (Pipewire reporta los valores recién ahí)
    property bool ready: false
    property double quietUntil: 0

    function poke(): void {
        // Con la mezcladora abierta ya se ve el slider: no hace falta avisar
        if (!ready || Date.now() < quietUntil || Ui.popup.startsWith("mixer@"))
            return;
        shown = true;
        hide.restart();
    }

    onVolumeChanged: poke()
    onMutedChanged: poke()
    // Al cambiar de dispositivo el volumen "salta" solo: no es una acción del usuario
    onSinkChanged: quietUntil = Date.now() + 800

    Timer {
        running: true
        interval: 2500
        onTriggered: root.ready = true
    }

    Timer {
        id: hide

        interval: 1600
        onTriggered: root.shown = false
    }
}
