import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Panel lateral del monitor principal: se abre pegando el mouse al borde izquierdo (SideEdge) o con
// Super+A. Dos pestañas: Resumen (hoy, pagos, música) y Sistema. Todo lo que mide o baja lo hace solo mientras está abierto; cerrado no consume nada.
PanelWindow {
    id: win

    required property var modelData

    property string tab: "resumen"
    // El mouse entró alguna vez al panel desde que se abrió: recién ahí empieza a valer «salir cierra»
    property bool entered: false

    readonly property int panelWidth: 420

    function gb(bytes: real): string {
        return (bytes / 1073741824).toFixed(bytes >= 10 * 1073741824 ? 0 : 1) + " GB";
    }

    function rate(bytesPerSecond: real): string {
        const kb = bytesPerSecond / 1024;
        return kb >= 1024 ? (kb / 1024).toFixed(1) + " MB/s" : Math.round(kb) + " KB/s";
    }

    function ago(epoch: real): string {
        const m = Math.max(0, Math.floor((Date.now() / 1000 - epoch) / 60));
        if (m < 1)
            return "ahora";
        if (m < 60)
            return m + " min";
        const h = Math.floor(m / 60);
        return h < 24 ? h + " h" : Math.floor(h / 24) + " d";
    }

    function uptimeText(seconds: real): string {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        return h >= 24 ? Math.floor(h / 24) + " d " + (h % 24) + " h" : h + " h " + m + " min";
    }

    // Lo que se mide o se baja depende de la pestaña abierta
    Binding {
        target: SysStat
        property: "full"
        value: Ui.sideOpen && win.tab === "sistema"
        when: win.activeOnScreen
    }

    Binding {
        target: Seguridad
        property: "active"
        value: Ui.sideOpen && win.tab === "sistema"
        when: win.activeOnScreen
    }

    onTabChanged: {
        if (Ui.sideOpen && tab === "sistema")
            Seguridad.load(false);
    }

    property real p: Ui.sideOpen ? 1 : 0

    // Entra con calma y se va rápido
    Behavior on p {
        NumberAnimation {
            duration: Ui.sideOpen ? Theme.popupDuration + 20 : Theme.animQuick
            easing.type: Theme.ease
        }
    }

    property bool activeOnScreen: false

    Connections {
        target: Ui

        function onSideOpenChanged() {
            if (!Ui.sideOpen)
                return;
            win.activeOnScreen = true;
            win.entered = false;
            // Una pestaña que ya no existe (un atajo viejo pide «chat») abre el panel donde estaba
            if (Ui.sideTab === "resumen" || Ui.sideTab === "sistema")
                win.tab = Ui.sideTab;
            Ui.sideTab = "";
            if (win.tab === "sistema")
                Seguridad.load(false);
            Focus.recordHistory();
            Facu.refreshSubjects();
            Estacion.load();
            summaryFlick.contentY = 0;
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    // Pedir otra pestaña con el panel ya abierto
    Connections {
        target: Ui

        function onSideTabChanged() {
            if (Ui.sideOpen && Ui.sideTab !== "") {
                win.tab = Ui.sideTab;
                Ui.sideTab = "";
            }
        }
    }

    screen: modelData
    visible: p > 0.001 || Ui.sideOpen
    color: "transparent"
    anchors {
        left: true
        top: true
        bottom: true
    }
    // Sale del borde izquierdo y se funde con la barra y con el borde inferior (SideShape). Arranca un
    // pixel dentro de la barra para tapar el filo que ella trae abajo.
    margins.top: Theme.barHeight - 1
    margins.bottom: 0
    implicitWidth: panelWidth + Theme.fillet + 2
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-side"
    // Toma el teclado solo al hacer clic
    WlrLayershell.keyboardFocus: Ui.sideOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Salir con el mouse cierra el panel casi enseguida (la pausa evita que un roce al borde lo cierre)
    Timer {
        id: leave

        interval: 150
        onTriggered: if (win.entered && !hover.hovered)
            Ui.sideOpen = false
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                win.entered = true;
                leave.stop();
            } else if (win.entered) {
                leave.restart();
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.sideOpen = false

        Item {
            id: card

            x: -(1 - win.p) * (win.panelWidth + 20)
            width: win.panelWidth
            height: parent.height
            opacity: Math.min(1, win.p * 1.6)

            SideShape {
                panelWidth: win.panelWidth
                panelHeight: card.height
            }

            Halftone {
                anchors.rightMargin: 10
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Segmented {
                    Layout.fillWidth: true
                    current: win.tab
                    model: [
                        {
                            id: "resumen",
                            name: "Resumen"
                        },
                        {
                            id: "sistema",
                            name: "Sistema"
                        }
                    ]
                    onPicked: id => win.tab = id
                }

                // ---------------- Resumen ----------------
                Flickable {
                    id: summaryFlick

                    visible: win.tab === "resumen"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: summary.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: summary

                        width: parent.width
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: Estacion.greeting(Chrono.date) + ", " + Estacion.displayName
                                    color: Theme.comic ? Theme.accent : Theme.textDim
                                    font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
                                    font.pixelSize: Theme.comic ? 17 : 13
                                    font.letterSpacing: Theme.comic ? 1.5 : 0
                                    font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: Qt.formatTime(Chrono.date, "HH:mm")
                                    color: Theme.text
                                    font.family: Theme.displayFont || Qt.application.font.family
                                    font.pixelSize: Theme.comic ? 52 : 44
                                    font.weight: Theme.comic ? Font.Normal : Font.Light
                                    font.letterSpacing: Theme.comic ? 2 : 0
                                }

                                Text {
                                    text: Chrono.capitalize(Chrono.date.toLocaleDateString(Chrono.locale, "dddd d 'de' MMMM"))
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontBody
                                }
                            }

                            // Clima
                            ColumnLayout {
                                visible: Estacion.weather !== null
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                spacing: 0

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 4

                                    MIcon {
                                        name: Estacion.weather?.icon ?? "cloud"
                                        color: Theme.warn
                                        font.pixelSize: 26
                                    }

                                    Text {
                                        text: (Estacion.weather?.temp ?? 0) + "°"
                                        color: Theme.text
                                        font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
                                        font.pixelSize: Theme.comic ? 30 : 24
                                        font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: Estacion.weather?.desc ?? ""
                                    color: Theme.text
                                    font.pixelSize: Theme.fontSmall
                                }

                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: (Estacion.weather?.min ?? 0) + "° / " + (Estacion.weather?.max ?? 0) + "°"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontCaption
                                }

                                Text {
                                    visible: (Estacion.weather?.rain ?? 0) >= 40
                                    Layout.alignment: Qt.AlignRight
                                    text: "Lluvia " + (Estacion.weather?.rain ?? 0) + " %"
                                    color: Theme.warn
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        readonly property var todays: Agenda.itemsFor(Agenda.ymd(Chrono.date), true)
                        // Sin los pagos: tienen su tarjeta
                        readonly property var later: Agenda.upcoming(14).filter(x => x.day !== Agenda.ymd(Agenda.now) && !x.tag.startsWith("sub:")).slice(0, 4)

                        // Anotar como en el papel (abre AnotarMenu)
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.controlRadius
                            color: noteHover.hovered ? Theme.hover : Theme.surface
                            border.width: Theme.comic ? 2 : 1
                            border.color: Theme.comic ? Theme.ink : Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                MIcon {
                                    name: "edit_note"
                                    font.pixelSize: Theme.iconMd
                                    color: Theme.accent
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Anotar parcial, entrega o nota…"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontBody
                                }

                                Rectangle {
                                    implicitWidth: keyHint.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 5
                                    color: Theme.track

                                    Text {
                                        id: keyHint

                                        anchors.centerIn: parent
                                        text: "Super Alt N"
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontTiny
                                    }
                                }
                            }

                            HoverHandler {
                                id: noteHover

                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: Ui.noteOpen = true
                            }
                        }

                        NowCard {
                            Layout.fillWidth: true
                        }

                        FacuCard {
                            Layout.fillWidth: true
                        }

                        // Agenda: lo que queda de hoy y los próximos días
                        ComicCard {
                            Layout.fillWidth: true
                            title: "Agenda"
                            tint: Themes.active.border2 ?? Theme.accent

                            Text {
                                text: "Hoy"
                                color: Theme.textDim
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                            }

                            Text {
                                visible: summary.todays.length === 0
                                text: Agenda.googleLoading ? "Cargando agenda…" : "Nada agendado para hoy"
                                color: Theme.textDim
                                font.pixelSize: Theme.fontSmall
                            }

                            Repeater {
                                model: summary.todays.slice(0, 5)

                                AgendaRow {
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                visible: summary.later.length > 0
                                Layout.topMargin: 4
                                text: "Próximos días"
                                color: Theme.textDim
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: summary.later

                                AgendaRow {
                                    Layout.fillWidth: true
                                    showDay: true
                                }
                            }
                        }

                        // Estudio
                        ComicCard {
                            Layout.fillWidth: true
                            title: "Estudio"
                            tint: "#6f9bf0"

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Column {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1

                                    Text {
                                        text: Focus.minutesText(Focus.studyToday)
                                        color: Theme.text
                                        font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
                                        font.pixelSize: Theme.comic ? 24 : 16
                                        font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                                        font.letterSpacing: Theme.comic ? 1 : 0
                                    }

                                    Text {
                                        text: "estudiado hoy"
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1

                                    Text {
                                        text: String(Focus.streak)
                                        color: Theme.text
                                        font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
                                        font.pixelSize: Theme.comic ? 24 : 16
                                        font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                                        font.letterSpacing: Theme.comic ? 1 : 0
                                    }

                                    Text {
                                        text: Focus.streak === 1 ? "día de racha" : "días de racha"
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }

                            StatBar {
                                readonly property int mins: Math.floor(Focus.studyToday / 60)

                                Layout.fillWidth: true
                                tint: "#6f9bf0"
                                label: mins >= Estacion.goal ? "Meta cumplida" : "Meta de hoy"
                                value: mins + " / " + Estacion.goal + " min"
                                fraction: Math.min(1, mins / Estacion.goal)
                            }

                            // Los últimos 7 días
                            Row {
                                id: week

                                readonly property var days: {
                                    const out = [];
                                    for (let i = 6; i >= 0; i--) {
                                        const d = new Date(Chrono.date);
                                        d.setDate(d.getDate() - i);
                                        const m = i === 0 ? Math.max(Math.floor(Focus.studyToday / 60), Focus.history[Agenda.ymd(d)] ?? 0) : (Focus.history[Agenda.ymd(d)] ?? 0);
                                        out.push({
                                            letter: ["D", "L", "M", "M", "J", "V", "S"][d.getDay()],
                                            mins: m,
                                            today: i === 0
                                        });
                                    }
                                    return out;
                                }
                                readonly property real peak: Math.max(Estacion.goal, ...days.map(x => x.mins))

                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: week.days

                                    Column {
                                        required property var modelData

                                        width: (week.width - 36) / 7
                                        spacing: 3

                                        Item {
                                            width: parent.width
                                            height: 34

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                width: parent.width
                                                height: Math.max(3, parent.height * modelData.mins / week.peak)
                                                radius: Theme.comic ? 2 : 3
                                                color: modelData.today ? Theme.accent : (modelData.mins >= Estacion.goal ? Qt.rgba(1, 1, 1, 0.45) : Theme.track)
                                                border.width: Theme.comic ? 1.5 : 0
                                                border.color: Theme.ink
                                            }
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.letter
                                            color: modelData.today ? Theme.text : Theme.textDim
                                            font.pixelSize: Theme.fontTiny
                                            font.weight: modelData.today ? Font.Bold : Font.Normal
                                        }
                                    }
                                }
                            }
                        }

                        // Pagos que se vienen
                        ComicCard {
                            visible: Subs.upcoming.length > 0
                            Layout.fillWidth: true
                            title: "Pagos"
                            tint: Theme.warn

                            Repeater {
                                model: Subs.upcoming.slice(0, 3)

                                RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.sub.name
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.pixelSize: Theme.fontBody
                                    }

                                    Text {
                                        text: Subs.whenText(modelData.days)
                                        color: modelData.days <= 1 ? Theme.warn : Theme.textDim
                                        font.pixelSize: Theme.fontSmall
                                    }

                                    Text {
                                        text: Subs.money(modelData.sub.amount, modelData.sub.currency)
                                        color: Theme.text
                                        font.pixelSize: Theme.fontBody
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }

                        // Proyectos: lo último que tocaste
                        ComicCard {
                            visible: Estacion.projects.length > 0
                            Layout.fillWidth: true
                            title: "Proyectos"
                            tint: "#ee8b4f"

                            Repeater {
                                model: Estacion.projects

                                ColumnLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.name
                                            color: Theme.text
                                            font.pixelSize: Theme.fontBody
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            visible: modelData.dirty > 0
                                            text: "● " + modelData.dirty + " sin guardar"
                                            color: Theme.warn
                                            font.pixelSize: Theme.fontCaption
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: win.ago(modelData.when) === "ahora" ? "ahora" : "hace " + win.ago(modelData.when)
                                            color: Theme.textDim
                                            font.pixelSize: Theme.fontCaption
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.subject
                                        elide: Text.ElideRight
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontSmall
                                    }
                                }
                            }
                        }

                        // Cajón de ideas
                        ComicCard {
                            visible: Focus.ideas.length > 0
                            Layout.fillWidth: true
                            title: "Cajón de ideas"
                            tint: Themes.active.border2 ?? Theme.accent

                            Repeater {
                                model: Focus.ideas.slice(0, 3)

                                RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.date.slice(8) + "/" + modelData.date.slice(5, 7)
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontCaption
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.pixelSize: Theme.fontBody
                                    }
                                }
                            }

                            Text {
                                visible: Focus.ideas.length > 3
                                text: "y " + (Focus.ideas.length - 3) + " más…"
                                color: Theme.textDim
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        // Dólar
                        ComicCard {
                            visible: Estacion.dolar !== null
                            Layout.fillWidth: true
                            title: "Dólar"
                            tint: "#5fb98a"

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [
                                        {
                                            key: "oficial",
                                            name: "Oficial"
                                        },
                                        {
                                            key: "blue",
                                            name: "Blue"
                                        },
                                        {
                                            key: "cripto",
                                            name: "Cripto"
                                        }
                                    ]

                                    Column {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1

                                        Text {
                                            text: Estacion.dolar?.[modelData.key] ? Estacion.money(Estacion.dolar[modelData.key].venta) : "—"
                                            color: Theme.text
                                            font.family: Theme.comic && Theme.displayFont ? Theme.displayFont : Qt.application.font.family
                                            font.pixelSize: Theme.comic ? 22 : 15
                                            font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                                            font.letterSpacing: Theme.comic ? 1 : 0
                                        }

                                        Text {
                                            text: modelData.name
                                            color: Theme.textDim
                                            font.pixelSize: Theme.fontCaption
                                        }
                                    }
                                }
                            }

                            // El próximo pago en dólares, en pesos al blue
                            Text {
                                readonly property var usd: Subs.upcoming.find(u => u.sub.currency === "USD") ?? null

                                visible: usd !== null && !!Estacion.dolar?.blue
                                Layout.fillWidth: true
                                text: usd && Estacion.dolar?.blue ? usd.sub.name + " (" + Subs.money(usd.sub.amount, "USD") + ") ≈ " + Estacion.money(usd.sub.amount * Estacion.dolar.blue.venta) + " al blue" : ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        MediaCard {
                            Layout.fillWidth: true
                        }
                    }
                }

                // ---------------- Sistema ----------------
                Flickable {
                    visible: win.tab === "sistema"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: stats.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: stats

                        readonly property var d: SysStat.data

                        width: parent.width
                        spacing: 6

                        SecurityView {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: stats.d.cpu === undefined
                            text: "Midiendo…"
                            color: Theme.textDim
                            font.pixelSize: Theme.fontBody
                        }

                        ComicCard {
                            visible: stats.d.cpu !== undefined
                            Layout.fillWidth: true
                            title: "Procesador y memoria"
                            tint: Theme.accent

                            StatBar {
                                Layout.fillWidth: true
                                label: "Procesador"
                                value: Math.round(stats.d.cpu ?? 0) + " %"
                                detail: stats.d.cpuTemp ? Math.round(stats.d.cpuTemp) + " °C" : ""
                                fraction: (stats.d.cpu ?? 0) / 100
                            }

                            StatBar {
                                visible: stats.d.memTotal !== undefined
                                Layout.fillWidth: true
                                label: "Memoria"
                                value: win.gb(stats.d.memUsed ?? 0)
                                detail: "de " + win.gb(stats.d.memTotal ?? 0)
                                fraction: (stats.d.memTotal ?? 0) > 0 ? stats.d.memUsed / stats.d.memTotal : 0
                            }
                        }

                        ComicCard {
                            visible: !!stats.d.gpu
                            Layout.fillWidth: true
                            title: "Video"
                            tint: Theme.warn

                            StatBar {
                                Layout.fillWidth: true
                                tint: Theme.warn
                                label: "Placa de video"
                                value: Math.round(stats.d.gpu?.usage ?? 0) + " %"
                                detail: Math.round(stats.d.gpu?.temp ?? 0) + " °C" + (stats.d.gpu?.power ? " · " + Math.round(stats.d.gpu.power) + " W" : "")
                                fraction: (stats.d.gpu?.usage ?? 0) / 100
                            }

                            StatBar {
                                Layout.fillWidth: true
                                tint: Theme.warn
                                label: "Memoria de video"
                                value: win.gb(stats.d.gpu?.memUsed ?? 0)
                                detail: "de " + win.gb(stats.d.gpu?.memTotal ?? 0)
                                fraction: (stats.d.gpu?.memTotal ?? 0) > 0 ? stats.d.gpu.memUsed / stats.d.gpu.memTotal : 0
                            }
                        }

                        ComicCard {
                            visible: (stats.d.disks ?? []).length > 0
                            Layout.fillWidth: true
                            title: "Almacenamiento"
                            tint: "#6f9bf0"

                            Repeater {
                                model: stats.d.disks ?? []

                                StatBar {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    tint: "#6f9bf0"
                                    label: modelData.name
                                    value: win.gb(modelData.used)
                                    detail: "de " + win.gb(modelData.total)
                                    fraction: modelData.total > 0 ? modelData.used / modelData.total : 0
                                }
                            }
                        }

                        ComicCard {
                            visible: stats.d.netDown !== undefined || stats.d.uptime !== undefined
                            Layout.fillWidth: true
                            title: "Red y tiempo"
                            tint: Themes.active.border2 ?? Theme.accent

                            StatBar {
                                visible: stats.d.netDown !== undefined
                                Layout.fillWidth: true
                                label: "Red"
                                value: "↓ " + win.rate(stats.d.netDown ?? 0)
                                detail: "↑ " + win.rate(stats.d.netUp ?? 0)
                            }

                            StatBar {
                                visible: stats.d.uptime !== undefined
                                Layout.fillWidth: true
                                label: "Encendida hace"
                                value: win.uptimeText(stats.d.uptime ?? 0)
                            }
                        }
                    }
                }
            }
        }
    }
}
