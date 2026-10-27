pragma Singleton

import QtQuick
import Quickshell

// Salvapantallas de la pantalla de bloqueo: lluvia de código con el logo OMBU que se
// descifra, se mantiene brillando y se disuelve, en bucle.
//
// Es una cuadrícula de caracteres. Cada nivel de brillo es una cadena de texto aparte
// (solo lleva los caracteres de ese nivel y espacios en el resto), así que la pantalla
// los superpone como capas de un color cada una; es mucho más liviano que colorear
// carácter por carácter.
Singleton {
    id: root

    // El salvapantallas está a la vista (se desvanece al tocar una tecla o mover el mouse)
    property bool active: false
    // Genera cuadros (sigue un rato tras ocultarse para completar el desvanecimiento)
    property bool animating: false

    // Cuánto se ve el salvapantallas, de 0 a 1. El desvanecimiento se anima acá y no en la
    // pantalla de bloqueo: una animación atada a la opacidad de un elemento que además se
    // oculta solo cuando vale 0 se queda trabada si la ventana aún no estaba visible.
    property real fade: active ? 1 : 0

    Behavior on fade {
        NumberAnimation {
            duration: 450
            easing.type: Easing.InOutQuad
        }
    }

    // Una cadena por nivel de brillo
    property string dim: ""
    property string mid: ""
    property string bright: ""
    property string head: ""
    property string logo: ""
    property string logoHi: ""

    property int cols: 0
    property int rows: 0

    // Con los temas de cómic llueven trazos de telaraña en lugar de hexadecimal
    readonly property string glyphs: Theme.comicArt ? "╱╲╳┼╌╎+x*/\\|-:·╱╲╳" : "0123456789ABCDEF<>{}[]()/\\|=+-*#$%&@;:^~?!"

    // Modo bienvenida (ver Welcome): el mismo efecto, pero el logo se descifra enseguida,
    // se queda y no se disuelve
    property bool welcome: false
    // Fila de la grilla donde queda la frase debajo del logo
    property int tagRow: 0
    readonly property string tagline: welcome ? (Theme.comicArt ? "B I E N V E N I D O ,   V E C I N O" : "B I E N V E N I D O") : "S E S I Ó N   B L O Q U E A D A"

    // Ciclo, en segundos: lluvia sola -> el logo se descifra -> brilla -> se disuelve
    readonly property real decryptStart: welcome ? 0.5 : 2.5
    readonly property real decryptEnd: welcome ? 2.2 : 5.3
    readonly property real dissolveStart: welcome ? 1000 : 18
    readonly property real dissolveEnd: welcome ? 1001 : 20.5
    readonly property real cycleLength: welcome ? 2000 : 24

    // Estado interno de la animación
    property var _inten: null
    property var _chars: null
    property var _mask: null
    property var _heads: null
    property var _speeds: null
    property var _bufs: null
    // Por capa, qué filas tienen algún carácter (las demás se saltean al armar el texto)
    property var _used: null
    property var _lr: []
    property var _lc: []
    property var _lch: []
    property var _lres: []
    property var _ldis: []
    property real _cycleT: 0
    // Segundos de animación desde que arrancó el ciclo (la bienvenida se guía por este reloj)
    readonly property real clock: _cycleT
    // La bienvenida ya mostró todo lo que tenía que mostrar
    signal welcomeDone
    readonly property real welcomeLength: 5
    property double _last: 0

    // Cada vista (una por monitor) informa cuántas columnas y filas le caben, y la lluvia se calcula con el
    // máximo de todas: cada monitor muestra la parte central que le entra (SaverView centra la grilla y
    // recorta). Con un monitor horizontal y un TV vertical, una grilla fijada por uno solo dejaba al otro
    // a medio llenar o con el logo fuera de pantalla.
    property var _sizes: ({})

    function report(key: string, c: int, r: int): void {
        _sizes[key] = [c, r];
        refit();
    }

    function forget(key: string): void {
        delete _sizes[key];
        refit();
    }

    function refit(): void {
        let c = 0, r = 0;
        for (const k in _sizes) {
            c = Math.max(c, _sizes[k][0]);
            r = Math.max(r, _sizes[k][1]);
        }
        if (c > 0)
            configure(c, r);
    }

    function configure(c: int, r: int): void {
        if (c < 24 || r < 12 || (c === cols && r === rows))
            return;
        cols = c;
        rows = r;
        const n = c * r;
        _inten = new Float32Array(n);
        _chars = new Uint8Array(n);
        _mask = new Uint8Array(n);
        _heads = new Float32Array(c);
        _speeds = new Float32Array(c);
        // Arreglos normales y no tipados: String.fromCharCode.apply() con un arreglo tipado
        // convierte todos los códigos en 0 (carácter nulo) en el motor de JS de Qt
        _bufs = [0, 1, 2, 3, 4, 5].map(() => new Array(n).fill(32));
        _used = [0, 1, 2, 3, 4, 5].map(() => new Uint8Array(r));
        for (let i = 0; i < n; i++)
            _chars[i] = Math.floor(Math.random() * glyphs.length);
        for (let x = 0; x < c; x++) {
            // Cada columna arranca en un momento distinto, ya con gotas a medio caer
            _heads[x] = Math.random() < 0.55 ? Math.random() * r : -Math.random() * 40;
            _speeds[x] = 7 + Math.random() * 22;
        }
        layoutLogo();
        shuffle();
    }

    // --- Logo -------------------------------------------------------------------------

    readonly property var letters: ({
            "O": [" ████ ", "██  ██", "██  ██", "██  ██", " ████ "],
            "M": ["██   ██", "███ ███", "██ █ ██", "██   ██", "██   ██"],
            "B": ["█████ ", "██  ██", "█████ ", "██  ██", "█████ "],
            "U": ["██  ██", "██  ██", "██  ██", "██  ██", " ████ "]
        })

    // La araña que corona el logo en los temas de cómic
    readonly property var spider: ["█     ███     █", " █   █████   █ ", "  ██ █████ ██  ", "████ █████ ████", "  ██ █████ ██  ", " █   █████   █ ", "█     ███     █"]

    function layoutLogo(): void {
        const C = cols, R = rows;
        const word = ["O", "M", "B", "U"];
        const gap = 2;
        let widthPx = 0;
        for (const ch of word)
            widthPx += letters[ch][0].length;
        widthPx += gap * (word.length - 1);

        const sx = C >= 110 ? 3 : 2;
        const sy = 2;
        const totalCols = widthPx * sx;
        const totalRows = 5 * sy;
        const left = Math.floor((C - totalCols) / 2);
        // Con la araña arriba, todo sube para que el conjunto siga centrado
        const spiderRows = Theme.comicArt ? spider.length * sy + 2 : 0;
        const top = Math.max(1, Math.floor(R / 2) - 7 - Math.floor(spiderRows / 2)) + spiderRows;

        const lr = [], lc = [], lch = [];
        if (spiderRows > 0) {
            const sLeft = Math.floor((C - spider[0].length * sx) / 2);
            for (let gy = 0; gy < spider.length; gy++) {
                for (let gx = 0; gx < spider[gy].length; gx++) {
                    if (spider[gy][gx] === " ")
                        continue;
                    for (let dy = 0; dy < sy; dy++) {
                        for (let dx = 0; dx < sx; dx++) {
                            lr.push(top - spiderRows + gy * sy + dy);
                            lc.push(sLeft + gx * sx + dx);
                            lch.push(0x2588);
                        }
                    }
                }
            }
        }
        let px = 0;
        for (const ch of word) {
            const glyph = letters[ch];
            for (let gy = 0; gy < glyph.length; gy++) {
                for (let gx = 0; gx < glyph[gy].length; gx++) {
                    if (glyph[gy][gx] === " ")
                        continue;
                    for (let dy = 0; dy < sy; dy++) {
                        for (let dx = 0; dx < sx; dx++) {
                            lr.push(top + gy * sy + dy);
                            lc.push(left + (px + gx) * sx + dx);
                            lch.push(0x2588);
                        }
                    }
                }
            }
            px += glyph[0].length + gap;
        }

        // Frase debajo del logo, letra por letra
        const tag = tagline;
        tagRow = top + totalRows + 3;
        const tagLeft = Math.floor((C - tag.length) / 2);
        for (let i = 0; i < tag.length; i++) {
            if (tag[i] === " ")
                continue;
            lr.push(tagRow);
            lc.push(tagLeft + i);
            lch.push(tag.charCodeAt(i));
        }

        _lr = lr;
        _lc = lc;
        _lch = lch;

        // Zona sin lluvia: el logo y un margen de una celda alrededor, para que se lea
        const mask = _mask;
        mask.fill(0);
        for (let k = 0; k < lr.length; k++) {
            for (let dy = -1; dy <= 1; dy++) {
                for (let dx = -1; dx <= 1; dx++) {
                    const y = lr[k] + dy, x = lc[k] + dx;
                    if (y >= 0 && y < R && x >= 0 && x < C)
                        mask[y * C + x] = 1;
                }
            }
        }
    }

    // La bienvenida: la lluvia arranca desde arriba, escalonada, y el logo se descifra enseguida
    function beginWelcome(): void {
        welcome = true;
        _cycleT = 0;
        _last = Date.now();
        if (cols > 0) {
            for (let x = 0; x < cols; x++)
                _heads[x] = -Math.random() * 6;
            _inten.fill(0);
            layoutLogo();
            shuffle();
        }
        animating = true;
    }

    function endWelcome(): void {
        welcome = false;
        if (cols > 0) {
            layoutLogo();
            shuffle();
        }
        if (!active)
            animating = false;
    }

    // Reparte al azar cuándo se descifra y cuándo se disuelve cada carácter del logo
    function shuffle(): void {
        const n = _lr.length;
        const res = new Array(n), dis = new Array(n);
        for (let k = 0; k < n; k++) {
            res[k] = decryptStart + 0.1 + Math.random() * (decryptEnd - decryptStart - 0.3);
            dis[k] = dissolveStart + Math.random() * (dissolveEnd - dissolveStart - 0.4);
        }
        _lres = res;
        _ldis = dis;
    }

    // --- Un cuadro --------------------------------------------------------------------

    // Arma el texto de una capa. Las filas sin caracteres quedan vacías (el salto de línea se
    // conserva, así que todo sigue alineado) y solo las filas usadas se copian y se limpian.
    function toText(b: int): string {
        const buf = _bufs[b], used = _used[b];
        const C = cols, R = rows;
        const lines = new Array(R);
        for (let y = 0; y < R; y++) {
            if (used[y] === 0) {
                lines[y] = "";
                continue;
            }
            lines[y] = String.fromCharCode.apply(null, buf.slice(y * C, (y + 1) * C));
            buf.fill(32, y * C, (y + 1) * C);
            used[y] = 0;
        }
        return lines.join("\n");
    }

    function tick(dt: real): void {
        if (cols === 0)
            return;
        const C = cols, R = rows, N = C * R;
        const inten = _inten, chars = _chars, mask = _mask;
        const G = glyphs, GL = glyphs.length;

        // Ciclo del logo
        _cycleT += dt;
        if (welcome && _cycleT >= welcomeLength)
            welcomeDone();
        if (_cycleT > cycleLength) {
            _cycleT -= cycleLength;
            shuffle();
        }
        const ct = _cycleT;
        const logoOn = ct >= decryptStart && ct < dissolveEnd;

        // 1. Las gotas caen: cada columna deja la estela de su "cabeza" en la grilla
        const heads = _heads, speeds = _speeds;
        for (let x = 0; x < C; x++) {
            const h = heads[x];
            if (h < -1) {
                heads[x] = h + dt * 6;
                continue;
            }
            const ny = h + speeds[x] * dt;
            for (let y = Math.floor(h) + 1; y <= Math.floor(ny); y++) {
                if (y >= 0 && y < R) {
                    inten[y * C + x] = 1.0;
                    chars[y * C + x] = Math.floor(Math.random() * GL);
                }
            }
            if (ny > R + 2) {
                heads[x] = -(4 + Math.random() * 60);
                speeds[x] = 7 + Math.random() * 22;
            } else {
                heads[x] = ny;
            }
        }

        // 2. La estela se apaga y algunos caracteres cambian mientras tanto
        const decay = Math.pow(0.147, dt);
        for (let i = 0; i < N; i++)
            inten[i] *= decay;
        const flips = Math.floor(N * 0.012);
        for (let f = 0; f < flips; f++)
            chars[Math.floor(Math.random() * N)] = Math.floor(Math.random() * GL);

        // 3. Se reparten los caracteres en las capas según su brillo
        const bufs = _bufs, used = _used;
        const bDim = bufs[0], bMid = bufs[1], bBright = bufs[2], bHead = bufs[3], bLogo = bufs[4], bHi = bufs[5];
        const uDim = used[0], uMid = used[1], uBright = used[2], uHead = used[3], uLogo = used[4], uHi = used[5];
        for (let y = 0; y < R; y++) {
            const base = y * C;
            for (let x = 0; x < C; x++) {
                const i = base + x;
                const v = inten[i];
                if (v < 0.07 || (logoOn && mask[i] === 1))
                    continue;
                const code = G.charCodeAt(chars[i]);
                if (v >= 0.93) {
                    bHead[i] = code;
                    uHead[y] = 1;
                } else if (v >= 0.55) {
                    bBright[i] = code;
                    uBright[y] = 1;
                } else if (v >= 0.25) {
                    bMid[i] = code;
                    uMid[y] = 1;
                } else {
                    bDim[i] = code;
                    uDim[y] = 1;
                }
            }
        }

        // 4. El logo: se descifra (caracteres al azar que se fijan), brilla con una franja
        //    de luz que lo recorre y se disuelve
        if (logoOn) {
            const lr = _lr, lc = _lc, lch = _lch, lres = _lres, ldis = _ldis;
            const band = (ct * 34) % (C + R * 3 + 60) - 20;
            const holding = ct >= decryptEnd && ct < dissolveStart;
            for (let k = 0; k < lr.length; k++) {
                let state = 0; // 0 nada, 1 caracteres al azar, 2 fijo
                if (ct < dissolveStart)
                    state = ct < lres[k] ? 1 : 2;
                else if (ct < ldis[k])
                    state = 2;
                else if (ct < ldis[k] + 0.3)
                    state = 1;
                if (state === 0)
                    continue;
                const i = lr[k] * C + lc[k];
                if (state === 1) {
                    bHi[i] = G.charCodeAt(Math.floor(Math.random() * GL));
                    uHi[lr[k]] = 1;
                } else if (holding && Math.abs(lc[k] + lr[k] * 3 - band) < 6) {
                    bHi[i] = lch[k];
                    uHi[lr[k]] = 1;
                } else {
                    bLogo[i] = lch[k];
                    uLogo[lr[k]] = 1;
                }
            }
        }
        dim = toText(0);
        mid = toText(1);
        bright = toText(2);
        head = toText(3);
        logo = toText(4);
        logoHi = toText(5);
    }

    // --- Cuándo se ve y cuándo se oculta ------------------------------------------------

    // Empieza al bloquear. Si el bloqueo fue por inactividad se ve de entrada; si fue manual,
    // aparece tras unos segundos sin actividad.
    // Al aparecer la ventana de bloqueo el puntero "entra" y genera eventos de movimiento que
    // no son del usuario: durante este margen, y mientras el mouse no se mueva de verdad,
    // no cuentan como actividad.
    property double _graceUntil: 0
    property real _px: -1
    property real _py: -1

    function begin(byIdle: bool): void {
        _graceUntil = Date.now() + 1500;
        _px = -1;
        _py = -1;
        _cycleT = 0;
        if (cols > 0)
            shuffle();
        active = byIdle;
        rearm.restart();
    }

    function end(): void {
        active = false;
        rearm.stop();
    }

    // Una tecla o un movimiento del mouse en la pantalla de bloqueo: se oculta el
    // salvapantallas y se vuelve a armar la cuenta para mostrarlo de nuevo
    // Posición del mouse sobre la pantalla de bloqueo: solo cuenta si se movió de verdad
    function pointer(x: real, y: real): void {
        if (_px < 0) {
            _px = x;
            _py = y;
            return;
        }
        if (Math.abs(x - _px) + Math.abs(y - _py) < 12)
            return;
        _px = x;
        _py = y;
        wake();
    }

    function wake(): void {
        if (!Ui.locked || Date.now() < _graceUntil)
            return;
        if (active)
            active = false;
        rearm.restart();
    }

    onActiveChanged: {
        if (active) {
            animating = true;
            _last = Date.now();
            fadeTail.stop();
        } else {
            fadeTail.restart();
        }
    }

    Connections {
        target: Ui

        function onLockedChanged(): void {
            if (Ui.locked)
                root.begin(Idle.lockedByIdle);
            else
                root.end();
        }
    }

    Timer {
        id: rearm

        interval: Theme.saverRewakeSeconds * 1000
        onTriggered: {
            if (Ui.locked)
                root.active = true;
        }
    }

    // Deja terminar el desvanecimiento antes de dejar de generar cuadros
    Timer {
        id: fadeTail

        interval: 700
        onTriggered: {
            if (!root.active)
                root.animating = false;
        }
    }

    Timer {
        interval: 1000 / Theme.saverFps
        repeat: true
        running: root.animating && (Ui.locked || root.welcome)
        onTriggered: {
            const now = Date.now();
            const dt = Math.min(0.1, (now - root._last) / 1000);
            root._last = now;
            root.tick(dt);
        }
    }
}
