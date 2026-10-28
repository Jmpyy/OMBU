pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Suscripciones y pagos fijos: cuánto, qué día y quién paga. Cada una crea en el calendario un
// evento que se repite todos los meses, con aviso el día antes y el mismo día (en Google, para que
// llegue también al celular). Los datos quedan en ~/.local/share/ombu/suscripciones.json.
Singleton {
    id: root

    readonly property string dataDir: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu"
    // [{id, name, amount, currency ("ARS" | "USD"), day (1-31, o -1 = último día), payer ("yo" | "mama"),
    //   method, ref: {kind: "google" | "local", id}}]
    property var list: []

    // Pagos ordenados por el próximo vencimiento: [{sub, due, days}]
    readonly property var upcoming: {
        const base = Agenda.now;
        return list.map(s => {
            const due = nextDue(s, base);
            return {
                sub: s,
                due: due,
                days: Math.round((due - new Date(base.getFullYear(), base.getMonth(), base.getDate(), 12)) / 86400000)
            };
        }).sort((a, b) => a.days - b.days);
    }

    function daysInMonth(year: int, month: int): int {
        return new Date(year, month + 1, 0).getDate();
    }

    // Próxima fecha de pago (hoy cuenta); si el mes no tiene ese día, cae el último
    function nextDue(sub: var, from: date): date {
        const today = new Date(from.getFullYear(), from.getMonth(), from.getDate(), 12);
        for (let i = 0; i < 14; i++) {
            const first = new Date(today.getFullYear(), today.getMonth() + i, 1, 12);
            const last = daysInMonth(first.getFullYear(), first.getMonth());
            const d = new Date(first.getFullYear(), first.getMonth(), sub.day === -1 ? last : Math.min(sub.day, last), 12);
            if (d >= today)
                return d;
        }
        return today;
    }

    function money(amount: real, currency: string): string {
        const n = Qt.locale("es_AR").toString(amount, "f", Number.isInteger(amount) ? 0 : 2);
        return currency === "USD" ? "US$ " + n : "$" + n;
    }

    function whenText(days: int): string {
        if (days <= 0)
            return "Hoy";
        if (days === 1)
            return "Mañana";
        return "En " + days + " días";
    }

    // En el calendario de la familia el evento es para ella ("Pagar Netflix"); en el propio, un
    // recordatorio para vos ("Avisar a mamá: Netflix")
    function eventTitle(s: var, family: bool): string {
        const base = s.name + " — " + money(s.amount, s.currency);
        if (s.payer !== "mama")
            return "Pagar " + base;
        return family ? "Pagar " + base + (s.method !== "" ? " (" + s.method + ")" : "") : "Avisar a mamá: " + base;
    }

    function find(name: string): var {
        const n = name.trim().toLowerCase();
        return list.find(s => s.name.toLowerCase() === n) ?? null;
    }

    function save(): void {
        file.setText(JSON.stringify(list, null, 2) + "\n");
        // Son datos personales: solo los lee el usuario
        Quickshell.execDetached(["sh", "-c", "sleep 1; chmod 600 \"$1\"", "permisos", file.path]);
    }

    // Agrega un pago y su evento repetido. day: 1-31 o -1 (último día del mes)
    function add(name: string, amount: real, currency: string, day: int, payer: string, method: string): string {
        const n = name.trim();
        if (n === "" || !(amount > 0) || (day !== -1 && (day < 1 || day > 31)))
            return "datos inválidos";
        if (find(n))
            return "ya existe " + n;
        const sub = {
            id: Date.now().toString(36),
            name: n,
            amount: amount,
            currency: currency === "USD" ? "USD" : "ARS",
            day: day,
            payer: payer === "mama" ? "mama" : "yo",
            method: method ?? "",
            ref: null
        };
        list = list.concat([sub]);
        save();
        // El evento arranca en el próximo vencimiento, a las 9, con aviso el día antes y ese día
        const first = nextDue(sub, new Date());
        // Lo que paga mamá va al calendario de la familia (si hay) para que ella también lo vea
        const family = sub.payer === "mama" && Agenda.apiConnected && Agenda.createInGoogle && Agenda.familyCalendarId !== "";
        const note = [sub.method !== "" ? "Se paga con " + sub.method : "", sub.payer === "mama" ? "Lo paga mamá; Juan le avisa" : ""].filter(x => x !== "").join(". ");
        Agenda.add(Agenda.ymd(first), "09:00", eventTitle(sub, family), day === -1 || day === 31 ? "monthly-last" : "monthly", [1440, 0], {
            note: note,
            tag: "sub:" + sub.id,
            calendar: family ? Agenda.familyCalendarId : "",
            done: r => {
                if (r.error)
                    return;
                list = list.map(s => s.id === sub.id ? Object.assign({}, s, {
                        ref: {
                            kind: r.local ? "local" : "google",
                            id: r.id,
                            calendarId: r.calendarId ?? "primary"
                        }
                    }) : s);
                save();
            }
        });
        return "ok";
    }

    // Quita un pago y su evento repetido
    function remove(name: string): string {
        const s = find(name);
        if (!s)
            return "no existe " + name;
        list = list.filter(x => x.id !== s.id);
        save();
        if (s.ref?.kind === "google")
            Agenda.removeGoogle(s.ref.calendarId ?? "primary", s.ref.id);
        else if (s.ref?.kind === "local")
            Agenda.remove(s.ref.id);
        return "ok";
    }

    FileView {
        id: file

        path: root.dataDir + "/suscripciones.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            const saved = JSON.parse(file.text());
            if (Array.isArray(saved))
                list = saved;
        } catch (e) {}
    }
}
