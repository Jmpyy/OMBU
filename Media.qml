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

    // El reproductor elegido, que se mantiene aunque se pause. Reglas:
    //  - el que acaba de ponerse a sonar pasa a ser el elegido;
    //  - si el elegido se pausa y otro sigue sonando, pasa a ese;
    //  - si ninguno suena, se queda el último que se pausó, así «play» lo reanuda a él.
    // (Antes se elegía «el que suena o, si ninguno, el primero»: al pausar Sung saltaba a Zen. Y con
    // «el último que arrancó», al pausar dos reproductores «play» siempre volvía al mismo.)
    // Con cycle() se elige a mano y la elección vale hasta que alguno se ponga a sonar.
    property var selected: null
    property bool pinned: false

    readonly property var player: all.includes(selected) ? selected : (all.find(p => p.isPlaying) ?? all[0] ?? null)
    readonly property bool playing: player?.isPlaying ?? false
    readonly property int count: all.length
    readonly property int index: Math.max(0, all.indexOf(player))

    // Se llama cada vez que un reproductor empieza o deja de sonar
    function reselect(started: var): void {
        if (started) {
            selected = started;
            pinned = false;
            return;
        }
        if (pinned && all.includes(selected))
            return;
        const sounding = all.filter(p => p.isPlaying);
        if (!all.includes(selected))
            selected = sounding[0] ?? all[0] ?? null;
        else if (!selected.isPlaying && sounding.length > 0)
            selected = sounding[0];
    }

    // Pasa al siguiente reproductor (para controlar el otro cuando hay más de uno)
    function cycle(): void {
        if (all.length < 2)
            return;
        selected = all[(index + 1) % all.length];
        pinned = true;
    }

    Instantiator {
        model: Mpris.players

        QtObject {
            required property var modelData
            readonly property bool sounding: modelData.isPlaying

            onSoundingChanged: root.reselect(sounding ? modelData : null)
            Component.onCompleted: if (sounding && root.selected === null)
                root.selected = modelData
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
        return (index + 1) + "/" + count + " " + player.identity + " [" + busName() + "]: reproduciendo=" + player.isPlaying + " canControl=" + player.canControl + " canPlay=" + player.canPlay + " canPause=" + player.canPause + " canTogglePlaying=" + player.canTogglePlaying + " canGoNext=" + player.canGoNext;
    }
}
