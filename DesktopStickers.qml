import QtQuick
import Quickshell
import Quickshell.Hyprland

// Stickers del escritorio vacío: cuando el escritorio que se ve en este monitor no tiene ventanas, abajo a
// la derecha aparecen la hora, el clima, lo próximo de la agenda y la racha de estudio, como stickers
// pegados sobre el collage del fondo. Al abrir una ventana se desvanecen. Van en la capa del fondo
// (Wallpaper): nunca tapan nada ni reciben clics.
Item {
    id: root

    required property string screenName
    property bool enabled: true

    // Escritorio que se ve en este monitor y si tiene alguna ventana
    readonly property int activeId: Hyprland.monitors.values.find(m => m.name === screenName)?.activeWorkspace?.id ?? -9999
    readonly property bool empty: !Apps.windows.some(t => t.workspace?.id === activeId)
    readonly property bool show: enabled && empty && !Ui.locked

    // Lo próximo de la agenda (sin feriados ni calendarios en silencio)
    readonly property var next: {
        Agenda.now;
        const u = Agenda.upcoming(1);
        return u.length > 0 ? u[0] : null;
    }

    function whenText(it: var): string {
        const today = Agenda.ymd(Agenda.now);
        const tomorrow = Agenda.ymd(new Date(Agenda.now.getFullYear(), Agenda.now.getMonth(), Agenda.now.getDate() + 1, 12));
        const day = it.day === today ? "Hoy" : (it.day === tomorrow ? "Mañana" : Agenda.parseDay(it.day).toLocaleString(Chrono.locale, "ddd d").replace(/\./g, ""));
        return it.time ? day + " · " + it.time : day;
    }

    opacity: show ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    // El clima se baja solo si la copia tiene más de 30 minutos
    onShowChanged: if (show)
        Estacion.refreshNet()

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 70
        anchors.bottomMargin: 70
        spacing: 22

        Row {
            anchors.right: parent.right
            spacing: 26

            DeskSticker {
                label: Chrono.date.toLocaleString(Chrono.locale, "dddd d MMM").replace(/\./g, "")
                value: Chrono.date.toLocaleString(Chrono.locale, "HH:mm")
                tint: Theme.text
                tilt: -3
                valueSize: 46
            }

            DeskSticker {
                visible: Estacion.weather !== null
                label: Estacion.weather?.desc ?? ""
                value: (Estacion.weather?.temp ?? 0) + "°"
                icon: Estacion.weather?.icon ?? "cloud"
                // El segundo color del tema (el verde azulado con Spider-Man)
                tint: Themes.active.border2 ?? Theme.accent
                tilt: 4
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 40
            spacing: 26

            DeskSticker {
                visible: root.next !== null
                label: root.next ? root.whenText(root.next) : ""
                value: root.next?.title ?? ""
                icon: "event"
                tint: Theme.accent
                tilt: 2
                valueSize: 30
            }

            DeskSticker {
                label: Focus.streak > 0 ? "Racha de estudio" : "Estudio de hoy"
                value: Focus.streak > 0 ? Focus.streak + (Focus.streak === 1 ? " día" : " días") : Focus.minutesText(Focus.studyToday)
                icon: "local_fire_department"
                tint: Theme.warn
                tilt: -4
                valueSize: 32
            }
        }
    }
}
