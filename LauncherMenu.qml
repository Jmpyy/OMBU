import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Launcher estilo Spotlight: una barra de búsqueda. Vacía muestra tus apps de siempre (favoritas
// y las más usadas); al escribir aparecen los resultados. Aparece en el monitor con foco.
//   Enter abre o enfoca · Shift+Enter ventana nueva · flechas mueven · Ctrl+P fija o suelta · Esc cierra
PanelWindow {
    id: win

    required property var modelData

    readonly property int columns: 6
    readonly property int cell: 92
    readonly property int rowHeight: 50
    readonly property int maxRows: 6

    readonly property string query: input.text.trim().toLowerCase()
    readonly property bool searching: query !== ""

    readonly property var allApps: Array.from(DesktopEntries.applications.values).filter(e => !e.noDisplay)
    readonly property var tiles: Launch.tiles(allApps)

    // Puntaje de coincidencia de una app con lo escrito (0 = no coincide)
    function score(entry, q: string): int {
        const name = entry.name.toLowerCase();
        if (name.startsWith(q))
            return 100;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 80;
        if (name.includes(q))
            return 60;
        if ((entry.genericName ?? "").toLowerCase().includes(q))
            return 40;
        if (Array.from(entry.keywords ?? []).some(k => k.toLowerCase().includes(q)))
            return 35;
        if ((entry.comment ?? "").toLowerCase().includes(q))
            return 20;
        return 0;
    }

    // Apps que coinciden: primero las de siempre; las del sistema ocultas solo si escribís 3 letras o más
    readonly property var appEntries: {
        // Con un prefijo de modo (=, /, ?) no se busca entre las apps
        const q = modePrefix ? "" : query;
        if (!q)
            return [];
        const out = [];
        for (const e of allApps) {
            const s = score(e, q);
            if (s <= 0)
                continue;
            const hidden = Launch.isHidden(e);
            if (hidden && q.length < 3)
                continue;
            // Lo que más abrís sube un poco; lo oculto va al final
            out.push({
                entry: e,
                rank: s + Math.min(Launch.usage[e.id] ?? 0, 20) * 0.5 + (Launch.isFavorite(e.id) ? 5 : 0) - (hidden ? 1000 : 0)
            });
        }
        return out.sort((a, b) => b.rank - a.rank || a.entry.name.localeCompare(b.entry.name)).map(x => x.entry);
    }

    // ---- Modos: =cuenta o 10 km a mi · /archivo · ?búsqueda web ----
    readonly property string raw: input.text.trim()
    readonly property bool modePrefix: raw.startsWith("/") || raw.startsWith("?")

    // Cuenta: "=2+3*4" o una expresión con operadores. Solo se aceptan números y + - * / ( ) . ^ %
    function calc(text: string): var {
        let e = text.replace(/,/g, ".").replace(/[x×]/gi, "*").replace(/÷/g, "/").replace(/\^/g, "**").trim();
        if (e === "" || !/^[0-9+\-*/().%\s]+$/.test(e) || !/[0-9]/.test(e))
            return null;
        try {
            const v = Function("\"use strict\"; return (" + e + ");")();
            return typeof v === "number" && isFinite(v) ? v : null;
        } catch (err) {
            return null;
        }
    }

    function fmt(v: real, digits: int): string {
        return String(Number(v.toPrecision(digits ?? 12)));
    }

    // Unidades: factor a la unidad base de cada tipo (la temperatura se resuelve aparte)
    readonly property var units: ({
            "mm": ["largo", 0.001], "cm": ["largo", 0.01], "m": ["largo", 1], "km": ["largo", 1000],
            "in": ["largo", 0.0254], "ft": ["largo", 0.3048], "yd": ["largo", 0.9144], "mi": ["largo", 1609.344],
            "g": ["masa", 0.001], "kg": ["masa", 1], "lb": ["masa", 0.45359237], "oz": ["masa", 0.028349523], "t": ["masa", 1000],
            "ml": ["volumen", 0.001], "l": ["volumen", 1], "gal": ["volumen", 3.785411784],
            "m/s": ["velocidad", 1], "km/h": ["velocidad", 0.277777778], "mph": ["velocidad", 0.44704],
            "b": ["datos", 1], "kb": ["datos", 1000], "mb": ["datos", 1e6], "gb": ["datos", 1e9], "tb": ["datos", 1e12],
            "kib": ["datos", 1024], "mib": ["datos", 1048576], "gib": ["datos", 1073741824], "tib": ["datos", 1099511627776]
        })

    // "10 km a mi", "5 kg to lb", "30 c en f": devuelve {text, value} o null
    function convert(text: string): var {
        const m = text.toLowerCase().replace(/,/g, ".").match(/^(-?[0-9]*\.?[0-9]+)\s*([a-z°\/]+)\s+(?:to|a|en|in|->|→)\s+([a-z°\/]+)$/);
        if (!m)
            return null;
        const n = parseFloat(m[1]);
        const from = m[2].replace("°", "");
        const to = m[3].replace("°", "");
        const temps = ["c", "f", "k"];
        if (temps.includes(from) && temps.includes(to)) {
            const c = from === "c" ? n : (from === "f" ? (n - 32) * 5 / 9 : n - 273.15);
            const out = to === "c" ? c : (to === "f" ? c * 9 / 5 + 32 : c + 273.15);
            return {
                text: fmt(out, 6) + " °" + to.toUpperCase(),
                value: fmt(out, 6)
            };
        }
        const a = units[from];
        const b = units[to];
        if (!a || !b || a[0] !== b[0])
            return null;
        const out = n * a[1] / b[1];
        return {
            text: fmt(out, 7) + " " + to,
            value: fmt(out, 7)
        };
    }

    // Archivos: "/texto" busca por nombre en tu carpeta personal (con una pausa para no buscar en cada tecla)
    property string fileTerm: ""
    property var fileHits: []
    readonly property string homeDir: Quickshell.env("HOME") ?? ""

    onRawChanged: {
        if (raw.startsWith("/") && raw.length > 1)
            fileDebounce.restart();
        else {
            fileDebounce.stop();
            fileTerm = "";
            fileHits = [];
        }
    }

    Timer {
        id: fileDebounce

        interval: 180
        onTriggered: win.fileTerm = win.raw.slice(1).trim()
    }

    onFileTermChanged: {
        finder.running = false;
        if (fileTerm.length >= 2) {
            finder.command = ["fd", "-i", "-F", "--max-results", "40", "-t", "f", "-t", "d", "-E", ".cache", "-E", "node_modules", "-E", ".git", "--", fileTerm, homeDir];
            finder.running = true;
        } else {
            fileHits = [];
        }
    }

    Process {
        id: finder

        stdout: StdioCollector {
            onStreamFinished: {
                // Lo más cerca de la raíz primero, y a igual profundidad lo más corto
                const lines = text.split("\n").filter(l => l !== "");
                const depth = p => p.replace(/\/$/, "").split("/").length;
                lines.sort((a, b) => depth(a) - depth(b) || a.length - b.length);
                win.fileHits = lines.slice(0, 25);
            }
        }
    }

    // Lo que se muestra: primero las filas de los modos y después las apps
    readonly property var results: {
        const out = [];
        const r = raw;
        if (r === "")
            return out;
        if (r.startsWith("/")) {
            for (const path of fileHits) {
                const isDir = path.endsWith("/");
                const clean = path.replace(/\/$/, "");
                const slash = clean.lastIndexOf("/");
                out.push({
                    kind: "file",
                    path: clean,
                    isDir: isDir,
                    name: clean.slice(slash + 1),
                    sub: (homeDir !== "" && clean.startsWith(homeDir) ? "~" + clean.slice(homeDir.length, slash) : clean.slice(0, slash)) || "/",
                    icon: isDir ? "folder" : "description"
                });
            }
            return out;
        }
        if (r.startsWith("?")) {
            const term = r.slice(1).trim();
            if (term !== "")
                out.push({
                    kind: "web",
                    name: "Buscar «" + term + "» en la web",
                    sub: "Enter abre el navegador",
                    icon: "travel_explore",
                    url: "https://www.google.com/search?q=" + encodeURIComponent(term)
                });
            return out;
        }
        // Cuenta: con "=" o si parece una cuenta con operadores
        const looksMath = /^[-+]?[0-9(][0-9\s.,()]*[-+*/^%x×÷][0-9\s.,()+\-*/^%x×÷]*$/i.test(r);
        if (r.startsWith("=") || looksMath) {
            const v = calc(r.startsWith("=") ? r.slice(1) : r);
            if (v !== null)
                out.push({
                    kind: "calc",
                    name: "= " + fmt(v),
                    sub: "Enter copia el resultado",
                    icon: "calculate",
                    value: fmt(v)
                });
        }
        const c = convert(r);
        if (c)
            out.push({
                kind: "convert",
                name: c.text,
                sub: "Enter copia el resultado",
                icon: "straighten",
                value: c.value
            });
        for (const e of appEntries)
            out.push({
                kind: "app",
                entry: e,
                id: e.id,
                name: e.name
            });
        // Sin nada que mostrar: ofrecer buscarlo en la web
        if (out.length === 0)
            out.push({
                kind: "web",
                name: "Buscar «" + r + "» en la web",
                sub: "Enter abre el navegador",
                icon: "travel_explore",
                url: "https://www.google.com/search?q=" + encodeURIComponent(r)
            });
        return out;
    }

    // La fila elegida: en la vista inicial es la app del ícono resaltado
    readonly property var current: {
        if (searching)
            return results[list.currentIndex] ?? null;
        const e = tiles[grid.currentIndex] ?? null;
        return e ? {
            kind: "app",
            entry: e,
            id: e.id,
            name: e.name
        } : null;
    }

    // ---- Vista previa (Quick Look): Ctrl+Y sobre un archivo ----
    property bool previewOpen: false
    property string previewKind: ""
    property var previewLines: []
    property string previewImage: ""

    function togglePreview(): void {
        if (previewOpen) {
            previewOpen = false;
            return;
        }
        const row = current;
        if (!row || row.kind !== "file")
            return;
        previewKind = "";
        previewLines = [];
        previewImage = "";
        previewProc.command = [Quickshell.shellPath("bin/ql.sh"), row.path];
        previewProc.running = true;
        previewOpen = true;
    }

    // La vista previa se cierra sola al cambiar de fila o de búsqueda
    onCurrentChanged: if (previewOpen)
        togglePreview()
    onSearchingChanged: previewOpen = false

    Process {
        id: previewProc

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                win.previewKind = lines[0] ?? "";
                const rest = lines.slice(1);
                if (win.previewKind === "image")
                    win.previewImage = "file://" + (rest[0] ?? "");
                else
                    win.previewLines = rest;
            }
        }
    }

    // Ícono de una app; "" si el tema no lo tiene (así no sale el cuadro magenta de error)
    function iconFor(entry): string {
        if (!entry)
            return "";
        const own = Icons.override(entry.id);
        if (own)
            return own;
        const icon = entry.icon ?? "";
        if (!icon)
            return "";
        return icon.startsWith("/") ? "file://" + icon : Icons.themed(icon);
    }

    // Ejecuta una fila: abrir la app, copiar un resultado, abrir un archivo o buscar en la web
    function activate(row: var, forceNew: bool): void {
        if (!row)
            return;
        if (row.kind === "app") {
            Launch.open(row.entry, forceNew);
            return;
        }
        Ui.launcherOpen = false;
        if (row.kind === "calc" || row.kind === "convert") {
            Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy; notify-send -a Launcher -h string:x-ombu-kind:note \"Copiado: $1\"", "copiar", row.value]);
        } else if (row.kind === "file") {
            // Shift+Enter abre la carpeta que lo contiene
            const target = forceNew && !row.isDir ? row.path.slice(0, row.path.lastIndexOf("/")) : row.path;
            Quickshell.execDetached(["xdg-open", target]);
        } else if (row.kind === "web") {
            Quickshell.execDetached(["xdg-open", row.url]);
        }
    }

    onQueryChanged: {
        list.currentIndex = 0;
        grid.currentIndex = 0;
    }
    onTilesChanged: grid.currentIndex = Math.min(grid.currentIndex, Math.max(0, tiles.length - 1))

    property real p: Ui.launcherOpen ? 1 : 0

    Behavior on p {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    // Guarda el monitor en el que se abrió para completar la animación de cierre
    property bool activeOnScreen: false

    Connections {
        target: Ui

        function onLauncherOpenChanged() {
            if (!Ui.launcherOpen)
                return;
            if (Hyprland.focusedMonitor?.name === win.modelData.name)
                win.activeOnScreen = true;
            input.text = Ui.launcherPrefill;
            Icons.rescan();
            list.currentIndex = 0;
            grid.currentIndex = 0;
            Qt.callLater(() => input.forceActiveFocus());
        }

        // Pide la vista previa de la fila elegida (también sirve para probarla sin teclado)
        function onLauncherPreviewTickChanged() {
            if (Ui.launcherOpen)
                win.togglePreview();
        }

        // Precargar un texto con el launcher ya abierto
        function onLauncherPrefillChanged() {
            if (Ui.launcherOpen)
                input.text = Ui.launcherPrefill;
        }
    }

    onPChanged: if (p <= 0.001)
        activeOnScreen = false

    screen: modelData
    visible: (p > 0.001 && activeOnScreen) || (Ui.launcherOpen && Hyprland.focusedMonitor?.name === modelData.name)
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-launcher"
    WlrLayershell.keyboardFocus: Ui.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.launcherOpen = false
        }
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        width: win.columns * win.cell + 28
        height: column.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.p
        scale: 0.92 + 0.08 * win.p
        transformOrigin: Item.Top

        // Evita que un clic dentro de la tarjeta cierre el launcher
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 14
            y: 12
            width: parent.width - 28
            spacing: 4

            // Barra de búsqueda
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 12

                MIcon {
                    name: "search"
                    color: Theme.textDim
                    font.pixelSize: 24
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: "#14131a"
                    font.pixelSize: 19
                    clip: true
                    focus: true


                    // Esc cierra primero la vista previa y después el launcher
                    Keys.onEscapePressed: {
                        if (win.previewOpen)
                            win.previewOpen = false;
                        else
                            Ui.launcherOpen = false;
                    }
                    // Enter abre o enfoca la app; Shift+Enter abre una ventana nueva (o la carpeta de un archivo)
                    Keys.onReturnPressed: event => {
                        win.activate(win.current, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: event => {
                        win.activate(win.current, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                    Keys.onUpPressed: {
                        if (win.searching)
                            list.currentIndex = Math.max(0, list.currentIndex - 1);
                        else
                            grid.moveCurrentIndexUp();
                    }
                    Keys.onDownPressed: {
                        if (win.searching)
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
                        else
                            grid.moveCurrentIndexDown();
                    }
                    // Con la búsqueda vacía las flechas laterales se mueven por los íconos
                    Keys.onLeftPressed: event => {
                        if (win.searching)
                            event.accepted = false;
                        else
                            grid.moveCurrentIndexLeft();
                    }
                    Keys.onRightPressed: event => {
                        if (win.searching)
                            event.accepted = false;
                        else
                            grid.moveCurrentIndexRight();
                    }
                    Keys.onPressed: event => {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P && win.current?.kind === "app") {
                            Launch.toggleFavorite(win.current.id);
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) {
                            win.togglePreview();
                            event.accepted = true;
                        }
                    }

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar apps · = cuentas · / archivos · ? web…"
                        color: Theme.textDim
                        font.pixelSize: 19
                    }
                }
            }

            Rectangle {
                visible: !win.searching ? win.tiles.length > 0 : win.results.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // Vista inicial: tus apps de siempre
            GridView {
                id: grid

                visible: !win.searching && win.tiles.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.ceil(win.tiles.length / win.columns) * win.cell
                Layout.topMargin: 4
                cellWidth: width / win.columns
                cellHeight: win.cell
                model: win.tiles
                interactive: false
                currentIndex: 0
                highlightMoveDuration: 0

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    readonly property string icon: win.iconFor(modelData)

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 16
                        color: tile.current ? Theme.surface : (tileHover.hovered ? Theme.hover : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: 90
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 7

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 46
                            height: 46

                            Image {
                                id: tileImage

                                anchors.fill: parent
                                visible: tile.icon !== "" && status !== Image.Error
                                source: tile.icon
                                sourceSize: Qt.size(92, 92)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MIcon {
                                anchors.centerIn: parent
                                visible: !tileImage.visible
                                name: "apps"
                                color: Theme.textDim
                                font.pixelSize: 34
                            }
                        }

                        Text {
                            width: grid.cellWidth - 14
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    // Marca de favorita
                    MIcon {
                        visible: Launch.isFavorite(tile.modelData.id) && (tile.current || tileHover.hovered)
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        name: "push_pin"
                        color: Theme.accent
                        font.pixelSize: 13
                    }

                    HoverHandler {
                        id: tileHover
                    }
                    TapHandler {
                        onTapped: win.activate({
                            kind: "app",
                            entry: tile.modelData,
                            id: tile.modelData.id,
                            name: tile.modelData.name
                        }, false)
                    }
                }
            }

            Text {
                visible: !win.searching && win.tiles.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 10
                horizontalAlignment: Text.AlignHCenter
                text: "Escribí para buscar una aplicación"
                color: Theme.textDim
                font.pixelSize: 14
            }

            // Al escribir: resultados
            Text {
                visible: win.searching && win.results.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 14
                horizontalAlignment: Text.AlignHCenter
                text: "Sin resultados para “" + input.text + "”"
                color: Theme.textDim
                font.pixelSize: 14
            }

            ListView {
                id: list

                visible: win.searching && win.results.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(count, win.maxRows) * win.rowHeight
                model: win.results
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: item

                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property string icon: modelData.kind === "app" ? win.iconFor(modelData.entry) : ""

                    width: ListView.view.width
                    height: win.rowHeight
                    radius: 14
                    color: current ? Theme.surface : (itemHover.hovered ? Theme.hover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: 90
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 14

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32

                            Image {
                                id: rowImage

                                anchors.fill: parent
                                visible: item.icon !== "" && status !== Image.Error
                                source: item.icon
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MIcon {
                                anchors.centerIn: parent
                                visible: !rowImage.visible
                                name: item.modelData.icon ?? "apps"
                                color: item.modelData.kind === "app" ? Theme.textDim : Theme.accent
                                font.pixelSize: 24
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                width: parent.width
                                text: item.modelData.name
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: item.modelData.kind === "calc" || item.modelData.kind === "convert" ? 20 : 15
                                font.weight: Font.Medium
                            }

                            Text {
                                width: parent.width
                                visible: (item.modelData.sub ?? "") !== ""
                                text: item.modelData.sub ?? ""
                                elide: Text.ElideMiddle
                                color: Theme.textDim
                                font.pixelSize: 11
                            }
                        }

                        MIcon {
                            visible: item.modelData.kind === "app" && Launch.isFavorite(item.modelData.id)
                            name: "push_pin"
                            color: Theme.accent
                            font.pixelSize: 15
                        }

                        MIcon {
                            visible: item.current
                            name: "keyboard_return"
                            color: Theme.textDim
                            font.pixelSize: 18
                        }
                    }

                    HoverHandler {
                        id: itemHover
                    }
                    TapHandler {
                        onTapped: win.activate(item.modelData, false)
                    }
                }
            }

            // Ayuda de teclas
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 2
                Layout.bottomMargin: 4
                text: win.current?.kind === "file" ? "Enter abre  ·  Shift+Enter abre la carpeta  ·  Ctrl+Y vista previa" : "Enter abre o enfoca  ·  Shift+Enter ventana nueva  ·  Ctrl+P fija o suelta"
                color: Theme.textDim
                font.pixelSize: 11
            }
        }
    }

    // Vista previa de un archivo (Quick Look): imagen, primeras líneas de texto, contenido de una carpeta
    Rectangle {
        id: ql

        visible: win.previewOpen
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.y + card.height + 10
        width: card.width
        height: 360
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.outline
        opacity: win.p

        // Evita que un clic dentro de la vista previa cierre el launcher
        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Row {
                width: parent.width
                spacing: 8

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: win.current?.icon ?? "description"
                    color: Theme.accent
                    font.pixelSize: 18
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 120
                    text: win.current?.name ?? ""
                    elide: Text.ElideMiddle
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ctrl+Y cierra"
                    color: Theme.textDim
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Item {
                width: parent.width
                height: parent.height - 40

                Image {
                    anchors.fill: parent
                    visible: win.previewKind === "image"
                    source: win.previewKind === "image" ? win.previewImage : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    sourceSize: Qt.size(1200, 800)
                }

                Flickable {
                    anchors.fill: parent
                    visible: win.previewKind === "text" || win.previewKind === "dir"
                    contentHeight: previewText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: previewText

                        width: parent.width
                        text: win.previewLines.join("\n")
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        color: Theme.text
                        font.family: win.previewKind === "text" ? "CaskaydiaCove Nerd Font Mono" : ""
                        font.pixelSize: win.previewKind === "text" ? 12 : 13
                        lineHeight: 1.15
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: win.previewKind === "other" || win.previewKind === "none"
                    spacing: 6

                    MIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "draft"
                        color: Theme.textDim
                        font.pixelSize: 40
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.previewKind === "none" ? "El archivo ya no existe" : (win.previewLines[0] ?? "")
                        color: Theme.textDim
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: win.previewKind === "other" && (win.previewLines[1] ?? "") !== ""
                        text: Math.round(parseInt(win.previewLines[1] ?? "0") / 1024) + " KB"
                        color: Theme.textDim
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
