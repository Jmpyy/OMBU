import QtQuick
import QtTest
import "Logic.js" as Logic

// Lógica pura de Logic.js. Lo importante son los bordes: el horario que cruza la medianoche, lo que la
// calculadora tiene que rechazar (inyección, división por cero) y las conversiones que no tienen sentido.
TestCase {
    name: "Logic"

    // ---- Horario de la luz nocturna: de 20:00 (1200) a 7:00 (420) ----
    function test_tramo_que_cruza_la_medianoche_data() {
        return [
            { tag: "19:59, todavía no", m: 1199, out: false },
            { tag: "20:00 justo, empieza", m: 1200, out: true },
            { tag: "23:59", m: 1439, out: true },
            { tag: "00:00, pasó la medianoche", m: 0, out: true },
            { tag: "06:59", m: 419, out: true },
            { tag: "07:00 justo, ya terminó", m: 420, out: false },
            { tag: "mediodía", m: 720, out: false }
        ];
    }
    function test_tramo_que_cruza_la_medianoche(d) {
        compare(Logic.inRange(d.m, 1200, 420), d.out);
    }

    function test_tramo_dentro_del_dia() {
        verify(Logic.inRange(540, 540, 1020), "9:00 entra en 9 a 17");
        verify(!Logic.inRange(1020, 540, 1020), "17:00 ya no entra");
        verify(!Logic.inRange(300, 540, 1020), "5:00 no entra");
    }

    function test_tramo_vacio() {
        verify(!Logic.inRange(600, 600, 600), "inicio igual a fin no prende nunca");
    }

    // ---- Calculadora ----
    function test_cuentas_data() {
        return [
            { tag: "precedencia", e: "2+3*4", out: 14 },
            { tag: "paréntesis", e: "(2+3)*4", out: 20 },
            { tag: "potencia con ^", e: "2^10", out: 1024 },
            { tag: "coma decimal", e: "1,5*2", out: 3 },
            { tag: "x como por", e: "6x7", out: 42 },
            { tag: "módulo", e: "10 % 3", out: 1 },
            { tag: "negativo", e: "-5+2", out: -3 }
        ];
    }
    function test_cuentas(d) {
        compare(Logic.calc(d.e), d.out);
    }

    // Todo esto tiene que dar null: la lista blanca no deja pasar letras, y lo que no es un número finito
    // no es un resultado
    function test_calculadora_rechaza_data() {
        return [
            { tag: "vacío", e: "" },
            { tag: "solo operadores", e: "+-*/" },
            { tag: "llamar una función", e: "alert(1)" },
            { tag: "objeto global", e: "Math.PI" },
            { tag: "constructor de Function", e: "constructor.constructor('return 1')()" },
            { tag: "comillas", e: "'1'+1" },
            { tag: "división por cero (infinito)", e: "1/0" },
            { tag: "cero sobre cero (NaN)", e: "0/0" },
            { tag: "desborde", e: "9^9^9" },
            { tag: "sintaxis rota", e: "(1+2" }
        ];
    }
    function test_calculadora_rechaza(d) {
        compare(Logic.calc(d.e), null);
    }

    function test_formato() {
        compare(Logic.fmt(0.1 + 0.2), "0.3", "sin dígitos usa 12 cifras y limpia el error de coma flotante");
        compare(Logic.fmt(1 / 3, 4), "0.3333");
        compare(Logic.fmt(1e21, 3), "1e+21");
    }

    // ---- Conversiones ----
    function test_conversiones_data() {
        return [
            { tag: "km a millas", t: "10 km a mi", out: "6.213712" },
            { tag: "con 'to'", t: "5 kg to lb", out: "11.02311" },
            { tag: "celsius a fahrenheit", t: "30 c en f", out: "86" },
            { tag: "con símbolo de grado", t: "100 °c a °f", out: "212" },
            { tag: "cero absoluto", t: "0 k a c", out: "-273.15" },
            { tag: "-40 es igual en las dos", t: "-40 f a c", out: "-40" },
            { tag: "datos binarios", t: "1 gib a mib", out: "1024" },
            { tag: "coma decimal", t: "1,5 km a m", out: "1500" }
        ];
    }
    function test_conversiones(d) {
        compare(Logic.convert(d.t)?.value, d.out);
    }

    function test_conversiones_sin_sentido() {
        compare(Logic.convert("10 km a kg"), null, "largo a masa");
        compare(Logic.convert("10 c a km"), null, "temperatura a largo");
        compare(Logic.convert("10 parsec a km"), null, "unidad desconocida");
        compare(Logic.convert("hola"), null, "no es una conversión");
    }

    // ---- Búsqueda del launcher ----
    readonly property var zen: ({ name: "Zen Browser", genericName: "Navegador web", keywords: ["firefox", "internet"], comment: "Navegá con privacidad" })

    function test_puntaje_por_tipo_de_coincidencia() {
        compare(Logic.score(zen, "zen"), 100, "empieza igual");
        compare(Logic.score(zen, "brow"), 80, "empieza una palabra");
        compare(Logic.score(zen, "owse"), 60, "está adentro del nombre");
        compare(Logic.score(zen, "naveg"), 40, "en el nombre genérico");
        compare(Logic.score(zen, "firef"), 35, "en las palabras clave");
        compare(Logic.score(zen, "privac"), 20, "en la descripción");
        compare(Logic.score(zen, "zbr"), 15, "abreviatura");
        compare(Logic.score(zen, "qqq"), 0, "nada que ver");
    }

    function test_abreviaturas() {
        verify(Logic.subsequence("loc", "libreoffice calc"));
        verify(!Logic.subsequence("ltc", "libreoffice calc"), "no tiene ninguna t (el ejemplo viejo del comentario estaba mal)");
        verify(Logic.subsequence("zn", "zen"));
        verify(!Logic.subsequence("nz", "zen"), "el orden importa");
        verify(!Logic.subsequence("zenn", "zen"), "no alcanzan las letras");
    }

    function test_una_letra_no_es_abreviatura() {
        // Con una sola letra cualquier app coincidiría: tiene que ser 0, no 15
        compare(Logic.score({ name: "Steam" }, "x"), 0);
    }
}
