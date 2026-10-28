import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Launcher estilo Spotlight: una barra de búsqueda. Vacía muestra tus apps de siempre (favoritas
// y las más usadas); al escribir aparecen apps y acciones de ombu (Actions.qml: «apagar», «tema»,
// «captura»...) mezcladas por relevancia. Aparece en el monitor con foco.
//   Enter abre o enfoca · Shift+Enter ventana nueva · flechas mueven · Ctrl+P fija o suelta · Esc cierra
PanelWindow {
    id: win

    required property var modelData

    readonly property int columns: 8
    readonly property int cell: 84

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
        // Abreviatura: las letras en orden aunque falten otras («zn» → Zen, «ltc» → LibreOffice Calc)
        if (q.length >= 2 && subsequence(q, name))
            return 15;
        return 0;
    }

    function subsequence(q: string, text: string): bool {
        let i = 0;
        for (const c of text)
            if (c === q[i] && ++i === q.length)
                return true;
        return false;
    }

    // Acción que pidió confirmación (apagar, reiniciar): se ejecuta con un segundo Enter
    property string armed: ""

    Timer {
        id: disarm

        interval: 3000
        onTriggered: win.armed = ""
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
        return out.sort((a, b) => b.rank - a.rank || a.entry.name.localeCompare(b.entry.name));
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
        // Con el parámetro tipado `int`, omitirlo llega como 0 (no como undefined): `??` no alcanzaba
        return String(Number(v.toPrecision(digits > 0 ? digits : 12)));
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
                    group: "Archivos",
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
                    group: "Web",
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
                    group: "Cálculo",
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
                group: "Cálculo",
                name: c.text,
                sub: "Enter copia el resultado",
                icon: "straighten",
                value: c.value
            });
        // Apps y acciones juntas, por relevancia (a igual puntaje, la app primero)
        const mixed = appEntries.map(x => ({
                    rank: x.rank,
                    row: {
                        kind: "app",
                        entry: x.entry,
                        id: x.entry.id,
                        name: x.entry.name,
                        sub: x.entry.genericName || x.entry.comment || ""
                    }
                }));
        if (r.length >= 2)
            for (const n of Actions.search(r).slice(0, 6))
                mixed.push({
                    // A igual coincidencia gana la app: una acción tiene que coincidir mejor para pasarla
                    rank: Actions.score(n, r.toLowerCase()) - 10.5,
                    row: {
                        kind: "action",
                        action: n,
                        name: n.name,
                        icon: n.swatch ? "palette" : n.icon,
                        sub: [n.crumb, n.hint].filter(x => x).join(" · ")
                    }
                });
        // El mejor de todos arriba («Mejor resultado») y después cada tipo en su grupo, por relevancia
        mixed.sort((a, b) => b.rank - a.rank);
        if (mixed.length > 0)
            out.push(Object.assign({}, mixed[0].row, {
                group: "Mejor resultado"
            }));
        for (const m of mixed.slice(1).filter(m => m.row.kind === "app"))
            out.push(Object.assign({}, m.row, {
                group: "Aplicaciones"
            }));
        for (const m of mixed.slice(1).filter(m => m.row.kind === "action"))
            out.push(Object.assign({}, m.row, {
                group: "Acciones"
            }));
        // Sin nada que mostrar: ofrecer buscarlo en la web
        if (out.length === 0)
            out.push({
                kind: "web",
                group: "Web",
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
        if (row.kind === "action") {
            const a = row.action;
            if (a.confirm && armed !== a.name) {
                armed = a.name;
                disarm.restart();
                return;
            }
            armed = "";
            if (a.keepOpen) {
                a.run();
                return;
            }
            Ui.launcherOpen = false;
            Actions.runLater(a.run);
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
        armed = "";
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

    HardShadow {
        target: card
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2
        width: 760
        height: column.implicitHeight + 16
        radius: Theme.cardRadius
        color: Theme.bg
        border.width: Theme.comic ? 2 : 1
        border.color: Theme.comic ? Theme.ink : Theme.outline
        opacity: win.p
        scale: 0.96 + 0.04 * win.p
        transformOrigin: Item.Top

        // Evita que un clic dentro de la tarjeta cierre el launcher
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            x: 8
            y: 8
            width: parent.width - 16
            spacing: 0

            // Barra de búsqueda
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Layout.leftMargin: 14
                Layout.rightMargin: 12
                spacing: 12

                MIcon {
                    name: "search"
                    color: Theme.textDim
                    font.pixelSize: Theme.iconLg
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.pixelSize: Theme.fontHeading
                    font.weight: Font.Light
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
                        text: "Buscar en ombu"
                        color: Theme.textDim
                        font.pixelSize: Theme.fontHeading
                        font.weight: Font.Light
                    }
                }

                // Qué se puede escribir
                Text {
                    visible: !win.searching
                    text: "= cuentas   / archivos   ? web"
                    color: Theme.textDim
                    font.pixelSize: Theme.fontCaption
                    font.family: "monospace"
                }
            }

            Rectangle {
                visible: !win.searching ? win.tiles.length > 0 : true
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // ---------------- Vacío: tus apps de siempre ----------------
            Text {
                visible: !win.searching && win.tiles.length > 0
                Layout.leftMargin: 14
                Layout.topMargin: 10
                text: "FAVORITAS Y MÁS USADAS"
                color: Theme.textDim
                font.pixelSize: Theme.fontTiny
                font.weight: Font.Bold
                font.letterSpacing: 1
            }

            GridView {
                id: grid

                visible: !win.searching && win.tiles.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.ceil(win.tiles.length / win.columns) * win.cell
                Layout.topMargin: 4
                Layout.bottomMargin: 4
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
                        radius: Theme.controlRadius
                        color: tile.current ? Theme.surface : (tileHover.hovered ? Theme.hover : "transparent")
                        border.width: Theme.comic && tile.current ? 1.5 : 0
                        border.color: Theme.ink
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 40
                            height: 40

                            Image {
                                id: tileImage

                                anchors.fill: parent
                                visible: tile.icon !== "" && status !== Image.Error
                                source: tile.icon
                                sourceSize: Qt.size(80, 80)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MIcon {
                                anchors.centerIn: parent
                                visible: !tileImage.visible
                                name: "apps"
                                color: Theme.textDim
                                font.pixelSize: 30
                            }
                        }

                        Text {
                            width: grid.cellWidth - 12
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: Theme.fontCaption
                        }
                    }

                    HoverHandler {
                        id: tileHover

                        cursorShape: Qt.PointingHandCursor
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

            // ---------------- Al escribir: resultados y detalle ----------------
            Text {
                visible: win.searching && win.results.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 18
                Layout.bottomMargin: 18
                horizontalAlignment: Text.AlignHCenter
                text: "Sin resultados para “" + input.text + "”"
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
            }

            RowLayout {
                visible: win.searching && win.results.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(240, Math.min(list.contentHeight + 12, 420))
                spacing: 0

                ListView {
                    id: list

                    Layout.preferredWidth: 420
                    Layout.fillHeight: true
                    Layout.topMargin: 6
                    model: win.results
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    section.property: "group"
                    section.criteria: ViewSection.FullString
                    section.delegate: Text {
                        required property string section

                        width: ListView.view.width
                        leftPadding: 14
                        topPadding: 8
                        bottomPadding: 4
                        text: section.toUpperCase()
                        color: Theme.textDim
                        font.pixelSize: Theme.fontTiny
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }

                    delegate: Rectangle {
                        id: item

                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem
                        readonly property string icon: modelData.kind === "app" ? win.iconFor(modelData.entry) : ""
                        readonly property bool armed: modelData.kind === "action" && win.armed === modelData.name

                        x: 6
                        width: ListView.view.width - 12
                        height: 40
                        radius: Theme.controlRadius - 2
                        color: item.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.comic ? 0.9 : 0.22) : (itemHover.hovered ? Theme.hover : "transparent")
                        border.width: Theme.comic && item.current ? 1.5 : 0
                        border.color: Theme.ink

                        // En el tema de cómic la fila elegida es acento lleno: el texto va en su color de contraste
                        readonly property color fg: item.current && Theme.comic ? Theme.accentText : Theme.text
                        readonly property color fgDim: item.current && Theme.comic ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.75) : Theme.textDim

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24

                                Image {
                                    id: rowImage

                                    anchors.fill: parent
                                    visible: item.icon !== "" && status !== Image.Error
                                    source: item.icon
                                    sourceSize: Qt.size(48, 48)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                MIcon {
                                    anchors.centerIn: parent
                                    visible: !rowImage.visible
                                    name: item.modelData.icon ?? "apps"
                                    color: item.armed ? Theme.danger : (item.current && Theme.comic ? Theme.accentText : Theme.accent)
                                    font.pixelSize: Theme.iconMd
                                }
                            }

                            Text {
                                text: item.armed ? item.modelData.name + ": Enter otra vez" : item.modelData.name
                                elide: Text.ElideRight
                                Layout.maximumWidth: 260
                                color: item.armed ? Theme.danger : item.fg
                                font.pixelSize: item.modelData.kind === "calc" || item.modelData.kind === "convert" ? 16 : 14
                                font.weight: item.armed ? Font.DemiBold : Font.Normal
                            }

                            Text {
                                Layout.fillWidth: true
                                text: item.modelData.kind === "app" ? (item.modelData.sub ?? "") : ""
                                elide: Text.ElideRight
                                color: item.fgDim
                                font.pixelSize: Theme.fontCaption
                            }

                            MIcon {
                                visible: item.modelData.kind === "app" && Launch.isFavorite(item.modelData.id)
                                name: "push_pin"
                                color: item.current && Theme.comic ? Theme.accentText : Theme.accent
                                font.pixelSize: Theme.iconXs
                            }
                        }

                        HoverHandler {
                            id: itemHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                list.currentIndex = item.index;
                                win.activate(item.modelData, false);
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Theme.border
                }

                // Detalle de lo elegido
                Item {
                    id: detail

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property var row: win.current

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 6

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 10
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64

                            Image {
                                id: bigImage

                                anchors.fill: parent
                                readonly property string src: detail.row?.kind === "app" ? win.iconFor(detail.row.entry) : ""
                                visible: src !== "" && status !== Image.Error
                                source: src
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Rectangle {
                                visible: !bigImage.visible
                                anchors.fill: parent
                                radius: Theme.cardRadius
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)

                                MIcon {
                                    anchors.centerIn: parent
                                    name: detail.row?.icon ?? "apps"
                                    color: Theme.accent
                                    font.pixelSize: 34
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            horizontalAlignment: Text.AlignHCenter
                            text: detail.row?.name ?? ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: detail.row?.kind === "calc" || detail.row?.kind === "convert" ? 22 : 17
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                const r = detail.row;
                                if (!r)
                                    return "";
                                if (r.kind === "app")
                                    return r.entry.comment || r.entry.genericName || "Aplicación";
                                return r.sub ?? "";
                            }
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font.pixelSize: Theme.fontSmall
                        }

                        // Datos de la app: favorita y cuántas veces la abriste
                        Text {
                            visible: detail.row?.kind === "app"
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                const r = detail.row;
                                if (r?.kind !== "app")
                                    return "";
                                const n = Launch.usage[r.id] ?? 0;
                                return (Launch.isFavorite(r.id) ? "Favorita · " : "") + (n > 0 ? "abierta " + n + (n === 1 ? " vez" : " veces") : "sin abrir desde ombu");
                            }
                            color: Theme.textDim
                            font.pixelSize: Theme.fontCaption
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        // Qué hace Enter
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: {
                                    const r = detail.row;
                                    if (!r)
                                        return [];
                                    switch (r.kind) {
                                    case "app":
                                        return [["↩", "Abrir o ir a la ventana"], ["⇧↩", "Ventana nueva"], ["Ctrl P", Launch.isFavorite(r.id) ? "Quitar de favoritas" : "Fijar en favoritas"]];
                                    case "file":
                                        return [["↩", "Abrir"], ["⇧↩", "Abrir la carpeta"], ["Ctrl Y", "Vista previa"]];
                                    case "action":
                                        return [["↩", r.action.confirm ? "Ejecutar (pide confirmar)" : "Ejecutar"]];
                                    case "calc":
                                    case "convert":
                                        return [["↩", "Copiar el resultado"]];
                                    default:
                                        return [["↩", "Abrir en el navegador"]];
                                    }
                                }

                                RowLayout {
                                    required property var modelData

                                    width: parent.width
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: Math.max(26, keyText.implicitWidth + 10)
                                        Layout.preferredHeight: 20
                                        radius: 5
                                        color: Theme.surface
                                        border.width: 1
                                        border.color: Theme.border

                                        Text {
                                            id: keyText

                                            anchors.centerIn: parent
                                            text: parent.parent.modelData[0]
                                            color: Theme.text
                                            font.pixelSize: Theme.fontTiny
                                            font.family: "monospace"
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: parent.modelData[1]
                                        elide: Text.ElideRight
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }
                        }
                    }
                }
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
                    font.pixelSize: Theme.iconMd
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 120
                    text: win.current?.name ?? ""
                    elide: Text.ElideMiddle
                    color: Theme.text
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ctrl+Y cierra"
                    color: Theme.textDim
                    font.pixelSize: Theme.fontCaption
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
                        font.pixelSize: Theme.fontBody
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: win.previewKind === "other" && (win.previewLines[1] ?? "") !== ""
                        text: Math.round(parseInt(win.previewLines[1] ?? "0") / 1024) + " KB"
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
        }
    }
}
