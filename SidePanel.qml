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

                        ColumnLayout {
                            spacing: 0

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
                                        text: Qt.formatDate(Agenda.parseDay(modelData.day), "ddd d MMM") + (modelData.time !== "" ? " " + modelData.time : "")
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
