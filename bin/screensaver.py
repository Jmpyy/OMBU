#!/usr/bin/env python3
"""Atiende org.freedesktop.ScreenSaver para que los videos no dejen bloquear la sesión.

Zen/Firefox (y otros reproductores) piden «no bloquees» mientras reproducen un video por esta interfaz de
D-Bus, directo o a través del portal. En Hyprland nadie la atendía (el portal decía «el proxy no tiene
dueño para un nombre org.freedesktop.ScreenSaver») y ombu bloqueaba a los 5 minutos aunque estuvieras
mirando algo. Este servicio anota cada pedido y escribe el estado en $XDG_RUNTIME_DIR/ombu-inhibit.json,
que Idle.qml lee:

    {"apps": ["Zen"], "at": 1761062400}

Seguridad: un pedido sin liberar dejaría la sesión sin bloquearse nunca. Por eso se borran los pedidos
de los programas que se cierran (aunque no avisen) y, mientras haya alguno, se reescribe la hora cada
minuto: si este proceso muere, el archivo envejece y ombu deja de respetarlo a los 3 minutos.

Lo arranca Idle.qml; si ya hay uno corriendo (el nombre está tomado), este sale sin hacer nada.
"""
import json
import os
import signal
import sys
import time

from gi.repository import Gio, GLib

NAME = "org.freedesktop.ScreenSaver"
PATHS = ("/org/freedesktop/ScreenSaver", "/ScreenSaver")
STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "ombu-inhibit.json")

XML = """
<node>
  <interface name="org.freedesktop.ScreenSaver">
    <method name="Inhibit">
      <arg name="application_name" type="s" direction="in"/>
      <arg name="reason_for_inhibit" type="s" direction="in"/>
      <arg name="cookie" type="u" direction="out"/>
    </method>
    <method name="UnInhibit">
      <arg name="cookie" type="u" direction="in"/>
    </method>
    <method name="GetActive">
      <arg type="b" direction="out"/>
    </method>
    <method name="SimulateUserActivity"/>
  </interface>
</node>
"""

inhibitors = {}  # cookie -> (app, sender)
next_cookie = 1


def write_state():
    apps = sorted({app for app, _ in inhibitors.values()})
    data = json.dumps({"apps": apps, "at": int(time.time())}) + "\n"
    # Se escribe en el mismo archivo (no se reemplaza): el FileView de ombu vigila ese archivo
    try:
        with open(STATE, "a+") as f:
            f.seek(0)
            f.truncate()
            f.write(data)
    except OSError:
        pass


def drop_sender(sender):
    gone = [c for c, (_, s) in inhibitors.items() if s == sender]
    for c in gone:
        del inhibitors[c]
    if gone:
        write_state()


def on_call(conn, sender, path, iface, method, params, invocation):
    global next_cookie
    if method == "Inhibit":
        app, reason = params.unpack()
        cookie = next_cookie
        next_cookie += 1
        inhibitors[cookie] = (app or "una app", sender)
        write_state()
        invocation.return_value(GLib.Variant("(u)", (cookie,)))
    elif method == "UnInhibit":
        (cookie,) = params.unpack()
        if inhibitors.pop(cookie, None) is not None:
            write_state()
        invocation.return_value(None)
    elif method == "GetActive":
        invocation.return_value(GLib.Variant("(b)", (False,)))
    else:
        invocation.return_value(None)


def on_owner_changed(conn, sender, path, iface, signal_name, params):
    name, old, new = params.unpack()
    # Un programa se desconectó del bus: sus pedidos se van con él
    if old and not new and name == old:
        drop_sender(old)


def heartbeat():
    if inhibitors:
        write_state()
    return True


def main():
    loop = GLib.MainLoop()
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    info = Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0]
    for path in PATHS:
        bus.register_object(path, info, on_call, None, None)
    bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                         "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE, on_owner_changed)

    def lost(*_):
        # Otro proceso ya atiende el nombre (otra copia de este servicio): no hace falta otro
        loop.quit()

    def acquired(*_):
        write_state()

    Gio.bus_own_name_on_connection(bus, NAME, Gio.BusNameOwnerFlags.DO_NOT_QUEUE, acquired, lost)
    GLib.timeout_add_seconds(60, heartbeat)

    def stop(*_):
        inhibitors.clear()
        write_state()
        loop.quit()

    try:
        from gi.repository import GLibUnix
        add_signal = GLibUnix.signal_add
    except ImportError:
        add_signal = GLib.unix_signal_add
    add_signal(GLib.PRIORITY_DEFAULT, signal.SIGTERM, stop)
    add_signal(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)
    loop.run()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("screensaver.py:", e, file=sys.stderr)
        sys.exit(1)
