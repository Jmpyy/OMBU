import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Panel lateral del monitor principal: se abre pegando el mouse al borde izquierdo (SideEdge) o con
// Super+A. Tres pestañas: Resumen (hoy, pagos, música), Noticias y Sistema. Todo lo que mide o baja
// lo hace solo mientras está abierto; cerrado no consume nada.
PanelWindow {
    id: win

    required property var modelData

    property string tab: "resumen"
    property string newsCategory: "todo"
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

    readonly property var newsItems: {
        if (newsCategory === "todo")
            return News.all;
        const c = News.categories.find(x => x.id === newsCategory);
        return c ? c.items.map(it => Object.assign({}, it, {
                category: c.name,
                categoryId: c.id
            })) : [];
    }

    // Cada categoría de noticias tiene su color (el sticker de cada titular y su botón)
    function catColor(id: string): color {
        switch (id) {
        case "argentina":
            return Theme.accent;
        case "economia":
            return Theme.warn;
        case "tecnologia":
            return Themes.active.border2 ?? "#5fb0ae";
        case "seguridad":
            return Theme.danger;
        case "programacion":
            return "#6f9bf0";
        default:
            return Theme.accent;
        }
    }

    // Texto legible sobre un color: tinta sobre los claros, crema sobre los oscuros
    function onColor(c: color): color {
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.5 ? Theme.ink : Theme.accentText;
    }

    // Lo que se mide o se baja depende de la pestaña abierta
    Binding {
        target: SysStat
        property: "full"
        value: Ui.sideOpen && win.tab === "sistema"
        when: win.activeOnScreen
    }

    onTabChanged: if (Ui.sideOpen && tab === "noticias")
        News.load(false)

    property real p: Ui.sideOpen ? 1 : 0

    // Entra con calma y se va rápido
    Behavior on p {
        NumberAnimation {
            duration: Ui.sideOpen ? Theme.popupDuration + 20 : 120
            easing.type: Easing.OutCubic
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
            if (Ui.sideTab !== "") {
                win.tab = Ui.sideTab;
                Ui.sideTab = "";
            }
            if (win.tab === "noticias")
                News.load(false);
            Focus.recordHistory();
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
                            id: "noticias",
                            name: "Noticias"
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
                                    color: Theme.accent
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
                                    font.pixelSize: 14
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
                                    font.pixelSize: 12
                                }

                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: (Estacion.weather?.min ?? 0) + "° / " + (Estacion.weather?.max ?? 0) + "°"
                                    color: Theme.textDim
                                    font.pixelSize: 11
                                }

                                Text {
                                    visible: (Estacion.weather?.rain ?? 0) >= 40
                                    Layout.alignment: Qt.AlignRight
                                    text: "Lluvia " + (Estacion.weather?.rain ?? 0) + " %"
                                    color: Theme.warn
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        readonly property var todays: Agenda.itemsFor(Agenda.ymd(Chrono.date))
                        readonly property var next: Agenda.upcoming(4)

                        // Hoy
                        ComicCard {
                            Layout.fillWidth: true
                            title: "Hoy"
                            tint: Theme.accent

                            Text {
                                visible: summary.todays.length === 0
                                text: Agenda.googleLoading ? "Cargando agenda…" : "Nada agendado para hoy"
                                color: Theme.textDim
                                font.pixelSize: 13
                            }

                            Repeater {
                                model: summary.todays.slice(0, 5)

                                RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 6
                                        Layout.preferredHeight: 6
                                        radius: 3
                                        color: modelData.kind === "holiday" ? Agenda.holidayColor : (modelData.kind === "google" ? Agenda.googleColor : Agenda.localColor)
                                    }

                                    Text {
                                        visible: modelData.time !== ""
                                        text: modelData.time
                                        color: Theme.textDim
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }

                        // Lo que viene
                        ComicCard {
                            visible: summary.next.length > 0
                            Layout.fillWidth: true
                            title: "Próximos"
                            tint: Themes.active.border2 ?? Theme.accent

                            Repeater {
                                model: summary.next

                                RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.preferredWidth: 96
                                        text: Chrono.capitalize(Agenda.parseDay(modelData.day).toLocaleDateString(Chrono.locale, "ddd d MMM")) + (modelData.time !== "" ? " " + modelData.time : "")
                                        color: Theme.textDim
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.pixelSize: 13
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
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: Subs.whenText(modelData.days)
                                        color: modelData.days <= 1 ? Theme.warn : Theme.textDim
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: Subs.money(modelData.sub.amount, modelData.sub.currency)
                                        color: Theme.text
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                }
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
                                            font.pixelSize: 11
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
                                font.pixelSize: 11
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
                                        font.pixelSize: 11
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
                                        font.pixelSize: 11
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
                                                color: modelData.today ? Theme.accent : (modelData.mins >= Estacion.goal ? "#6f9bf0" : Theme.track)
                                                border.width: Theme.comic ? 1.5 : 0
                                                border.color: Theme.ink
                                            }
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.letter
                                            color: modelData.today ? Theme.text : Theme.textDim
                                            font.pixelSize: 10
                                            font.weight: modelData.today ? Font.Bold : Font.Normal
                                        }
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
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        font.pixelSize: 13
                                    }
                                }
                            }

                            Text {
                                visible: Focus.ideas.length > 3
                                text: "y " + (Focus.ideas.length - 3) + " más…"
                                color: Theme.textDim
                                font.pixelSize: 11
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
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            visible: modelData.dirty > 0
                                            text: "● " + modelData.dirty + " sin guardar"
                                            color: Theme.warn
                                            font.pixelSize: 11
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: win.ago(modelData.when) === "ahora" ? "ahora" : "hace " + win.ago(modelData.when)
                                            color: Theme.textDim
                                            font.pixelSize: 11
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.subject
                                        elide: Text.ElideRight
                                        color: Theme.textDim
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }

                        MediaCard {
                            Layout.fillWidth: true
                        }
                    }
                }

                // ---------------- Noticias ----------------
                ColumnLayout {
                    visible: win.tab === "noticias"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                {
                                    id: "todo",
                                    name: "Todo"
                                }
                            ].concat(News.categories.map(c => ({
                                        id: c.id,
                                        name: c.name
                                    })))

                            Rectangle {
                                id: chip

                                required property var modelData
                                readonly property bool on: win.newsCategory === modelData.id

                                readonly property color cc: win.catColor(modelData.id)

                                width: chipText.implicitWidth + 20
                                height: 28
                                radius: Theme.comic ? 5 : 8
                                color: on ? (Theme.comic ? cc : Qt.rgba(cc.r, cc.g, cc.b, 0.22)) : (chipHover.hovered ? Theme.hover : Theme.surface)
                                border.width: Theme.comic ? 1.5 : 0
                                border.color: Theme.comic ? (on ? Theme.ink : Qt.rgba(chip.cc.r, chip.cc.g, chip.cc.b, 0.55)) : "transparent"

                                Text {
                                    id: chipText

                                    anchors.centerIn: parent
                                    text: chip.modelData.name
                                    color: chip.on ? (Theme.comic ? win.onColor(chip.cc) : chip.cc) : Theme.textDim
                                    font.family: Theme.displayFont && Theme.comic ? Theme.displayFont : Qt.application.font.family
                                    font.pixelSize: Theme.comic ? 14 : 12
                                    font.letterSpacing: Theme.comic ? 1 : 0
                                    font.weight: Theme.comic ? Font.Normal : Font.DemiBold
                                }

                                HoverHandler {
                                    id: chipHover

                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: win.newsCategory = chip.modelData.id
                                }
                            }
                        }
                    }

                    Text {
                        visible: News.loading && win.newsItems.length === 0
                        text: "Buscando noticias…"
                        color: Theme.textDim
                        font.pixelSize: 13
                    }

                    Text {
                        visible: !News.loading && win.newsItems.length === 0
                        Layout.fillWidth: true
                        text: News.error !== "" ? News.error : "Sin noticias por ahora"
                        wrapMode: Text.Wrap
                        color: Theme.textDim
                        font.pixelSize: 13
                    }

                    ListView {
                        id: newsList

                        visible: win.newsItems.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 0
                        model: win.newsItems
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property color cc: win.catColor(modelData.categoryId ?? "")
                            readonly property bool seen: News.seen[modelData.link] === true
                            readonly property bool lead: index === 0

                            width: ListView.view.width
                            height: card.height + 10

                            // Sombra dura de viñeta (solo temas de cómic)
                            Rectangle {
                                visible: Theme.comic
                                x: card.x + 3
                                y: card.y + 3
                                width: card.width
                                height: card.height
                                radius: card.radius
                                color: Theme.shadow
                                opacity: row.seen ? 0.5 : 1
                            }

                            Rectangle {
                                id: card

                                x: 0
                                width: parent.width - 4
                                height: body.implicitHeight + 20
                                radius: Theme.comic ? 6 : 10
                                color: rowHover.hovered ? Qt.lighter(Theme.surface, 1.25) : Theme.surface
                                border.width: Theme.comic ? 2 : 1
                                border.color: Theme.comic ? Theme.ink : Theme.border
                                opacity: row.seen ? 0.55 : 1

                                // Franja del color de la categoría
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: Theme.comic ? 2 : 1
                                    width: 4
                                    radius: 2
                                    color: row.cc
                                }

                                Column {
                                    id: body

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 10
                                    anchors.topMargin: 9
                                    spacing: 6

                                    Row {
                                        width: parent.width
                                        spacing: 8

                                        // Sticker de la categoría
                                        Sticker {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: (row.modelData.category ?? "") !== ""
                                            text: row.modelData.category ?? ""
                                            tint: row.cc
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - (parent.children[0].visible ? parent.children[0].width + 8 : 0)
                                            text: row.modelData.source + " · " + win.ago(row.modelData.time)
                                            elide: Text.ElideRight
                                            color: Theme.textDim
                                            font.pixelSize: 11
                                        }
                                    }

                                    Text {
                                        id: titleText

                                        width: parent.width
                                        text: row.modelData.title
                                        wrapMode: Text.Wrap
                                        maximumLineCount: row.lead ? 4 : 3
                                        elide: Text.ElideRight
                                        color: row.seen ? Theme.textDim : Theme.text
                                        font.pixelSize: row.lead ? 15 : 13
                                        font.weight: row.lead ? Font.DemiBold : Font.Medium
                                    }
                                }
                            }

                            HoverHandler {
                                id: rowHover

                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: {
                                    News.markSeen(row.modelData.link);
                                    Quickshell.execDetached(["xdg-open", row.modelData.link]);
                                    Ui.sideOpen = false;
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: News.updated > 0 ? "Actualizado hace " + win.ago(News.updated) + (News.error !== "" ? " · " + News.error : "") : ""
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font.pixelSize: 11
                        }

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 8
                            color: refreshHover.hovered ? Theme.hover : "transparent"

                            MIcon {
                                id: refreshIcon

                                anchors.centerIn: parent
                                name: "refresh"
                                font.pixelSize: 17
                                color: Theme.textDim

                                RotationAnimator on rotation {
                                    running: News.loading
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                }
                            }

                            HoverHandler {
                                id: refreshHover

                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: News.load(true)
                            }
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

                        Text {
                            visible: stats.d.cpu === undefined
                            text: "Midiendo…"
                            color: Theme.textDim
                            font.pixelSize: 13
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
