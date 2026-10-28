.pragma library

// Lógica pura de ombu: sin ventanas ni servicios, así se puede probar sola (tests/qml, con qmltestrunner).
// La usan LauncherMenu (búsqueda, cuentas y conversiones) y NightLight (horario).

// ---------------- Búsqueda del launcher ----------------

// Puntaje de coincidencia de una app con lo escrito (0 = no coincide)
function score(entry, q) {
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
    // Abreviatura: las letras en orden aunque falten otras («zn» → Zen, «loc» → LibreOffice Calc)
    if (q.length >= 2 && subsequence(q, name))
        return 15;
    return 0;
}

function subsequence(q, text) {
    let i = 0;
    for (const c of text)
        if (c === q[i] && ++i === q.length)
            return true;
    return false;
}

// ---------------- Cuentas y conversiones ----------------

// Solo se evalúa lo que pasa la lista blanca (dígitos, operadores, paréntesis y espacios): sin letras no
// se puede nombrar ninguna función ni variable, así que no hay forma de inyectar código
function calc(text) {
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

// Sin `digits` (o con 0) usa 12 cifras significativas
function fmt(v, digits) {
    return String(Number(v.toPrecision(digits > 0 ? digits : 12)));
}

// Factor a la unidad base de cada tipo (la temperatura se resuelve aparte)
const units = {
    "mm": ["largo", 0.001], "cm": ["largo", 0.01], "m": ["largo", 1], "km": ["largo", 1000],
    "in": ["largo", 0.0254], "ft": ["largo", 0.3048], "yd": ["largo", 0.9144], "mi": ["largo", 1609.344],
    "g": ["masa", 0.001], "kg": ["masa", 1], "lb": ["masa", 0.45359237], "oz": ["masa", 0.028349523], "t": ["masa", 1000],
    "ml": ["volumen", 0.001], "l": ["volumen", 1], "gal": ["volumen", 3.785411784],
    "m/s": ["velocidad", 1], "km/h": ["velocidad", 0.277777778], "mph": ["velocidad", 0.44704],
    "b": ["datos", 1], "kb": ["datos", 1000], "mb": ["datos", 1e6], "gb": ["datos", 1e9], "tb": ["datos", 1e12],
    "kib": ["datos", 1024], "mib": ["datos", 1048576], "gib": ["datos", 1073741824], "tib": ["datos", 1099511627776]
};

// "10 km a mi", "5 kg to lb", "30 c en f": devuelve {text, value} o null
function convert(text) {
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

// ---------------- Horarios ----------------

// ¿El minuto del día `m` (0..1439) cae en el tramo de `start` a `end`? Si start > end el tramo cruza la
// medianoche (20:00 → 7:00). start === end es un tramo vacío.
function inRange(m, start, end) {
    return start > end ? (m >= start || m < end) : (m >= start && m < end);
}
