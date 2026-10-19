pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Reproductor que se controla desde ombu (la tarjeta de música del centro de control): el que está
// sonando, o si ninguno suena, el primero. Los controles tienen un respaldo: si el reproductor
// avisa mal lo que puede hacer (Sung no actualiza CanPlay/CanPause al llenarse la cola), se llama
// directo al método de D-Bus, que es lo que hace playerctl y siempre funcionó.
Singleton {
    id: root

    readonly property var all: Array.from(Mpris.players.values)

    // El último que se puso a sonar. Antes se elegía «el que suena o, si ninguno, el primero»: al
    // pausar Sung la tarjeta saltaba a otro reproductor (Zen con YouTube) y los botones dejaban de
    // controlarlo; y con dos sonando a la vez controlaba el que no era.
    property var lastActive: null

    // Si suena alguno, el que suena (el último que arrancó si suenan varios); si ninguno suena, el
    // último que sonó, aunque esté en pausa, para poder reanudarlo
    readonly property var player: {
        const sounding = all.filter(p => p.isPlaying);
        if (sounding.length > 0)
            return sounding.includes(lastActive) ? lastActive : sounding[0];
        return all.includes(lastActive) ? lastActive : (all[0] ?? null);
    }
    readonly property bool playing: player?.isPlaying ?? false

    Instantiator {
        model: Mpris.players

        QtObject {
            required property var modelData
            readonly property bool sounding: modelData.isPlaying

            onSoundingChanged: if (sounding)
                root.lastActive = modelData
            Component.onCompleted: if (sounding && root.lastActive === null)
                root.lastActive = modelData
        }
    }

    // Nombre de bus del reproductor ("org.mpris.MediaPlayer2.sung")
    function busName(): string {
        return player?.dbusName ?? "";
    }

    function call(method: string): void {
        if (!player)
            return;
        Quickshell.execDetached(["busctl", "--user", "call", busName(), "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", method]);
    }

    // Play/pausa: por Quickshell si el reproductor dice que se puede; si no, directo por D-Bus
    function toggle(): void {
        if (!player)
            return;
        if (player.canTogglePlaying)
            player.togglePlaying();
        else
            call("PlayPause");
    }

    function next(): void {
        if (!player)
            return;
        if (player.canGoNext)
            player.next();
        else
            call("Next");
    }

    function previous(): void {
        if (!player)
            return;
        if (player.canGoPrevious)
            player.previous();
        else
            call("Previous");
    }

    // Para depurar (ipc call media status)
    function describe(): string {
        if (!player)
            return "sin reproductor (" + all.length + " en total)";
        return player.identity + " [" + busName() + "]: reproduciendo=" + player.isPlaying + " canControl=" + player.canControl + " canPlay=" + player.canPlay + " canPause=" + player.canPause + " canTogglePlaying=" + player.canTogglePlaying + " canGoNext=" + player.canGoNext;
    }
}
