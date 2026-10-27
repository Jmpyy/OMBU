"""Prueba de bin/anotar.py: frases como las del papel -> fecha, hora, tipo, materia y título.
Uso: python3 -I tests/anotar_test.py"""
import datetime as dt
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("anotar", os.path.join(HERE, "..", "bin", "anotar.py"))
an = importlib.util.module_from_spec(spec)
spec.loader.exec_module(an)

# Sin materias.json propio: siempre las de la carrera
an.DATA = tempfile.mkdtemp()

NOW = dt.datetime(2026, 10, 23, 10, 0)  # viernes

# frase -> lo que tiene que entender (solo las claves que se nombran)
CASES = [
    ("parcial eda jueves 18hs", dict(kind="parcial", subject="eda1", date="2026-10-29", time="18:00", title="Parcial · EDA1")),
    ("Parcial 2 de EDA1 el 15/11 a las 9", dict(kind="parcial", date="2026-11-15", time="09:00", title="Parcial 2 · EDA1")),
    ("TP2 testing 15/11 23:59", dict(kind="entrega", subject="testing", date="2026-11-15", time="23:59", title="Entrega TP2 · Testing")),
    ("entrega tp 3 sistemas operativos viernes", dict(kind="entrega", subject="so", date="2026-10-30", time="23:59", title="Entrega TP3 · Sistemas Operativos")),
    ("trabajo práctico 1 de mate el lunes", dict(kind="entrega", subject="mate1", date="2026-10-26", title="Entrega Trabajo práctico 1 · Matemática 1")),
    ("recu mate 1 3/12 14:30", dict(kind="recuperatorio", subject="mate1", date="2026-12-03", time="14:30")),
    ("final de so 20 de febrero", dict(kind="final", subject="so", date="2027-02-20", time="", title="Final · Sistemas Operativos")),
    ("clase de consulta testing mañana 19hs", dict(kind="clase", date="2026-10-24", time="19:00")),
    ("consulta eda pasado mañana a las 6 de la tarde", dict(kind="consulta", date="2026-10-25", time="18:00")),
    ("dentista hoy 17:15", dict(kind="evento", date="2026-10-23", time="17:15", title="Dentista", tag="")),
    ("cumple de Lucas 4 nov", dict(kind="evento", date="2026-11-04", time="", title="Cumple Lucas")),
    ("parcial eda en 2 semanas", dict(kind="parcial", date="2026-11-06")),
    ("entrega testing la semana que viene", dict(kind="entrega", date="2026-10-26")),
    ("parcial eda el viernes", dict(kind="parcial", date="2026-10-30")),  # hoy es viernes: el que viene
    ("parcial eda 22/10", dict(date="2027-10-22")),  # ya pasó este año
    ("reunión 8pm", dict(kind="evento", date="2026-10-23", time="20:00")),
    ("llamar 9am", dict(kind="evento", date="2026-10-24", time="09:00")),  # ya pasó: mañana
    ("repasar punteros dobles eda", dict(kind="nota", subject="eda1", date="", title="Repasar punteros dobles")),
    ("nota: el parcial es el 15/11", dict(kind="nota", date="")),
    ("comprar yerba", dict(kind="nota", title="Comprar yerba")),
    ("parcial eda", dict(kind="parcial", needsDate=True)),
    ("parcial eda 31/02", dict(date="", needsDate=True)),
    ("parcial testing 18.30 jueves", dict(time="18:30", date="2026-10-29")),
]


def main():
    fails = 0
    for text, want in CASES:
        got = an.parse(text, NOW)
        flat = dict(got, subject=(got["subject"] or {}).get("id"))
        bad = {k: (flat.get(k), v) for k, v in want.items() if flat.get(k) != v}
        if bad:
            fails += 1
            print("FALLA", repr(text))
            for k, (g, w) in bad.items():
                print("   ", k, "dio", repr(g), "esperaba", repr(w))
    # Avisos: parcial con hora 3 días, 1 día y 2 h antes; entrega 1 día y 3 h
    assert an.parse("parcial eda jueves 18hs", NOW)["reminders"] == [4320, 1440, 120]
    assert an.parse("tp2 testing viernes", NOW)["reminders"] == [1440, 180]
    assert an.parse("parcial eda jueves 18hs", NOW)["tag"] == "facu:parcial:eda1"

    # Notas: van a ~/Universidad/<materia>/notas.md (acá, a una carpeta temporal)
    an.UNI = tempfile.mkdtemp()
    r = an.save_note("repasar  punteros", "eda1", NOW)
    with open(r["path"]) as f:
        body = f.read()
    assert r["path"].endswith("EDA1/notas.md"), r
    assert body == "# EDA1\n\n- 23/10 10:00 · repasar punteros\n", repr(body)

    print("%d de %d frases bien" % (len(CASES) - fails, len(CASES)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
