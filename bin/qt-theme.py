#!/usr/bin/env python3
"""Pinta Dolphin, las demás apps Qt y la terminal (kitty) con los colores del tema de ombu.

Toma las plantillas de extras/ (que están en los colores del tema Ombú) y cambia cada color por
el del tema elegido; los tonos derivados (más claro, más oscuro) se calculan. Escribe:
  ~/.config/qt6ct/colors/ombu.conf        la paleta de qt6ct
  ~/.config/qt6ct/qss/ombu.qss            la hoja de estilos (bordes redondeados, selección)
  ~/.local/share/color-schemes/Ombu.colors  el esquema de colores de KDE
  ~/.config/kitty/themes/ombu.conf        los colores de la terminal (se recarga sola con SIGUSR1)
  ~/.config/starship.toml                 el prompt de la terminal (extras/starship/starship.toml, con el tema)
  ~/.config/vesktop/settings/quickCss.css  Discord (Vesktop), desde extras/vesktop/ombu.theme.css: Vesktop
                                          recarga el QuickCSS solo, así que cambia en vivo. Solo se escribe
                                          si está vacío o ya es el de ombu (no pisa un CSS propio)
  <perfil de Zen>/chrome/userChrome.css   Zen, desde extras/zen/userChrome.css (la interfaz) y userContent.css
                                          (sus páginas propias), más user.js (habilita el CSS
                                          y pone el acento). Zen lo lee al arrancar. No pisa archivos propios
  ~/.config/mpv/script-opts/uosc.conf   los colores de la interfaz de mpv (uosc), desde extras/mpv/uosc.conf
  ~/.local/share/ombu/icons/bar-logo.svg  el logo de la barra (araña o reactor, en los colores del tema;
                                          sin --logo se borra y la barra usa el de CachyOS)
y rehace las carpetas del tema de íconos Ombu en el color de Papirus que corresponda.
Los archivos de antes se guardan una vez como .pre-temas. Las ventanas abiertas no cambian: el
tema se nota en la siguiente que abras.

Uso: qt-theme.py --bg #14131a --surface #1d1c26 --track #2b2a38 --text #e8e8f0 --dim #8a8a9c
                 --accent #a78bfa --danger #f87171 --warn #fbbf24 --on-accent #14131a --folder violet
                 [--accent2 #5fb0ae] [--logo spider|reactor] [--out CARPETA]
  --out escribe en CARPETA en vez de en tu configuración (para probar)."""
import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXTRAS = os.path.join(HERE, "..", "extras")

# Colores base del tema Ombú: las plantillas están escritas con estos
DEFAULT = {"bg": "#14131a", "surface": "#1d1c26", "track": "#2b2a38", "text": "#e8e8f0",
           "dim": "#8a8a9c", "accent": "#a78bfa", "danger": "#f87171", "warn": "#fbbf24"}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in c)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


WHITE, BLACK = (255, 255, 255), (0, 0, 0)


def table(c):
    """De cada color de las plantillas al del tema nuevo (base y derivados), en RGB"""
    t = {k: rgb(v) for k, v in c.items()}
    d = {k: rgb(v) for k, v in DEFAULT.items()}
    out = {d[k]: t[k] for k in d}
    # Derivados: se calculan igual desde el tema Ombú (para encontrarlos) y desde el nuevo
    for src, dst in [(mix(d["track"], WHITE, 0.07), mix(t["track"], WHITE, 0.07)),
                     (mix(d["track"], WHITE, 0.04), mix(t["track"], WHITE, 0.04)),
                     (mix(d["accent"], WHITE, 0.35), mix(t["accent"], WHITE, 0.35)),
                     (mix(d["bg"], WHITE, 0.02), mix(t["bg"], WHITE, 0.02)),
                     (mix(d["bg"], BLACK, 0.25), mix(t["bg"], BLACK, 0.25)),
                     (mix(d["danger"], BLACK, 0.5), mix(t["danger"], BLACK, 0.5))]:
        out[tuple(round(v) for v in src)] = dst
    return out


# Derivados que las plantillas traen escritos a mano (no salen exactos de la fórmula de arriba)
EXACT = {"#3a3950": ("track", 0.07), "#323146": ("track", 0.04), "#c4b5fd": ("accent", 0.35),
         "#18171f": ("bg", 0.02), "#0f0e14": ("bg", -0.25), "#7f1d1d": ("danger", -0.5)}
# Mezclas entre dos colores del tema: la selección de Dolphin y las demás apps Qt es el acento al 35 %
# sobre el fondo (como Finder), no el acento lleno
BLEND = {"#473d68": ("bg", "accent", 0.35)}


ON = "@@ON_ACCENT@@"


def protect_on_accent(text):
    """Marca el texto que va sobre un fondo de acento (qss: `color:`/`selection-color:`; kitty: cursor y
    pestaña activa) para que no se confunda con el fondo oscuro, que usa el mismo color"""
    text = re.sub(r"((?:selection-)?color: )#14131a", r"\1" + ON, text)
    return re.sub(r"^((?:cursor_text_color|active_tab_foreground)\s+)#14131a", r"\1" + ON, text, flags=re.M)


def recolor(text, c):
    on_accent = c.pop("on_accent", None)
    text = protect_on_accent(text)
    base = {k: rgb(v) for k, v in c.items()}
    direct = {DEFAULT[k]: hexc(base[k]) for k in DEFAULT}
    for h, (k, t) in EXACT.items():
        direct[h] = hexc(mix(base[k], WHITE if t > 0 else BLACK, abs(t)))
    for h, (a, b, t) in BLEND.items():
        direct[h] = hexc(mix(base[a], base[b], t))

    def hex_sub(m):
        return direct.get(m.group(0).lower(), m.group(0))

    text = re.sub(r"#[0-9a-fA-F]{6}\b", hex_sub, text)

    # Tripletas "r,g,b" (esquema de KDE) y "rgba(r, g, b, a)" (hoja de estilos)
    rgb_map = {rgb(h): rgb(v) for h, v in direct.items()}

    def trip_sub(m):
        key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        n = rgb_map.get(key)
        return "%d,%d,%d" % n if n else m.group(0)

    text = re.sub(r"(?<![0-9.])(\d{1,3}),(\d{1,3}),(\d{1,3})(?![0-9])", trip_sub, text)

    def rgba_sub(m):
        key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        n = rgb_map.get(key)
        return "rgba(%d, %d, %d," % n if n else m.group(0)

    text = re.sub(r"rgba\((\d{1,3}), (\d{1,3}), (\d{1,3}),", rgba_sub, text)
    return text.replace(ON, on_accent or "#14131a")


def logo_svg(kind, accent, accent2, text):
    """Logos dibujados a mano (formas propias, sin archivos de nadie) para la barra"""
    import math
    if kind == "spider":
        legs = [[(28, 22), (14, 8), (6, 14)], [(27, 27), (8, 22), (3, 32)], [(27, 34), (8, 38), (4, 50)], [(28, 42), (14, 54), (10, 62)]]
        paths = ""
        for leg in legs:
            for mirror in (False, True):
                pts = " ".join("%d,%d" % ((64 - x) if mirror else x, y) for x, y in leg)
                paths += '<polyline points="%s"/>' % pts
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
                '<g fill="none" stroke="%s" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">%s</g>'
                '<ellipse cx="32" cy="41" rx="8.5" ry="14" fill="%s"/><circle cx="32" cy="24" r="5.5" fill="%s"/></svg>\n') % (accent, paths, accent, accent)
    if kind == "reactor":
        seg = ""
        for k in range(10):
            a = math.radians(k * 36)
            x1, y1 = 32 + 13 * math.cos(a), 32 + 13 * math.sin(a)
            x2, y2 = 32 + 21 * math.cos(a), 32 + 21 * math.sin(a)
            seg += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>' % (x1, y1, x2, y2)
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
                '<circle cx="32" cy="32" r="29" fill="none" stroke="%s" stroke-width="4"/>'
                '<g stroke="%s" stroke-width="5" stroke-linecap="butt">%s</g>'
                '<circle cx="32" cy="32" r="10" fill="none" stroke="%s" stroke-width="3"/>'
                '<circle cx="32" cy="32" r="5.5" fill="%s"/></svg>\n') % (accent, accent2, seg, accent, text)
    return ""


def kitty_comic(c, on_accent, logo, accent2):
    """Paleta de 16 colores para los temas de cómic: azul del traje (o del reactor), grises cálidos y
    blancos crema en vez de los fríos de Ombú; la estela del cursor lleva el segundo color del tema"""
    blue = {"spider": ("#4f86e8", "#8db0f5"), "reactor": ("#5fc4e8", "#a3e0f4")}.get(logo, ("#4f86e8", "#8db0f5"))
    t = rgb(c["text"])
    lines = ["", "# Paleta de cómic",
             "color0  " + c["track"], "color8  " + hexc(mix(rgb(c["track"]), t, 0.22)),
             "color4  " + blue[0], "color12 " + blue[1],
             "color7  " + hexc(mix(t, rgb(c["bg"]), 0.12)), "color15 " + hexc(mix(t, WHITE, 0.4))]
    if accent2:
        lines.append("cursor_trail_color " + accent2)
    return "\n".join(lines) + "\n"


def starship_text(text, c, on_accent, logo):
    """Prompt: colores del tema y, en los de cómic, el símbolo de la araña y la flecha doble"""
    accent = rgb(c["accent"])
    values = {"ACCENT": c["accent"], "LIGHT": hexc(mix(accent, WHITE, 0.35)), "DIM": c["dim"], "LINE": c["track"],
              "DANGER": c["danger"], "WARN": c["warn"], "OK": "#86efac", "DARK": on_accent}
    lead, prompt = "", "❯"
    if logo == "spider":
        lead, prompt = "[\U000F11EA ](fg:accent)", "❯❯"
    elif logo == "reactor":
        lead, prompt = "[◉ ](fg:accent)", "❯❯"
    values.update({"LEAD": lead, "PROMPT": prompt})
    return re.sub(r"@([A-Z]+)@", lambda m: values.get(m.group(1), m.group(0)), text)


def fill_template(text, c, on_accent, accent2):
    """Los @NOMBRE@ de una plantilla (Vesktop, Zen, uosc) por los colores del tema"""
    values = {"BG": c["bg"], "SURFACE": c["surface"], "TRACK": c["track"], "TEXT": c["text"], "DIM": c["dim"],
              "ACCENT": c["accent"], "ACCENT2": accent2 or c["accent"], "DANGER": c["danger"], "WARN": c["warn"],
              "ON_ACCENT": on_accent}
    return re.sub(r"@([A-Z_0-9]+)@", lambda m: values.get(m.group(1), m.group(0)), text)


def zen_profiles(root):
    """Carpetas de los perfiles de Zen que se usan (los «Default» de profiles.ini)"""
    base = os.path.join(root, ".config/zen")
    out = []
    try:
        with open(os.path.join(base, "profiles.ini"), encoding="utf-8") as f:
            for line in f:
                if line.startswith("Default=") and line.strip() != "Default=1":
                    p = os.path.join(base, line.split("=", 1)[1].strip())
                    if os.path.isdir(p) and p not in out:
                        out.append(p)
    except OSError:
        pass
    return out


ZEN_MARK = "ombu: Zen con los colores del tema"
ZEN_CONTENT_MARK = "ombu: las páginas propias de Zen"
ZEN_USERJS = """// ombu: lo escribe bin/qt-theme.py (habilita chrome/userChrome.css y pone el acento del tema)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("zen.theme.accent-color", "%s");
"""


def write_zen(root, css, content_css, accent):
    for prof in zen_profiles(root):
        # La interfaz (userChrome) y las páginas propias de Zen (userContent). Un archivo escrito a mano
        # (sin la marca de ombu) no se toca
        for name, text, mark in (("userChrome.css", css, ZEN_MARK), ("userContent.css", content_css, ZEN_CONTENT_MARK)):
            path = os.path.join(prof, "chrome", name)
            try:
                with open(path, encoding="utf-8") as f:
                    current = f.read()
            except OSError:
                current = ""
            if current.strip() == "" or mark in current:
                write(path, text, backup=False)
        # user.js: el bloque de ombu va al final y se reemplaza solo él; lo demás (ajustes propios) queda
        userjs = os.path.join(prof, "user.js")
        try:
            with open(userjs, encoding="utf-8") as f:
                old = f.read()
        except OSError:
            old = ""
        start = "// ombu: lo escribe"
        keep = old.split(start)[0].rstrip("\n")
        new = (keep + "\n\n" if keep else "") + ZEN_USERJS % accent
        if new != old:
            write(userjs, new, backup=bool(old) and start not in old)


def gtk_css(colors, on_accent):
    return (
        f"@define-color accent_color {colors['accent']};\n"
        f"@define-color accent_fg_color {on_accent};\n"
        f"@define-color accent_bg_color {colors['accent']};\n"
        f"@define-color window_bg_color {colors['bg']};\n"
        f"@define-color window_fg_color {colors['text']};\n"
        f"@define-color headerbar_bg_color {colors['surface']};\n"
        f"@define-color headerbar_fg_color {colors['text']};\n"
        f"@define-color popover_bg_color {colors['surface']};\n"
        f"@define-color popover_fg_color {colors['text']};\n"
        f"@define-color view_bg_color {colors['bg']};\n"
        f"@define-color view_fg_color {colors['text']};\n"
        f"@define-color card_bg_color {colors['surface']};\n"
        f"@define-color card_fg_color {colors['text']};\n"
        f"@define-color sidebar_bg_color {colors['bg']};\n"
        f"@define-color sidebar_fg_color {colors['text']};\n"
        f"@define-color sidebar_border_color {colors['surface']};\n"
        f"@define-color sidebar_backdrop_color {colors['bg']};\n"
        f"@define-color theme_selected_bg_color {colors['accent']};\n"
        f"@define-color theme_selected_fg_color {on_accent};\n\n"
        "@import \"thunar.css\";\n"
    )


def write(path, content, backup):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if backup and os.path.exists(path) and not os.path.exists(path + ".pre-temas"):
        shutil.copy2(path, path + ".pre-temas")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def main():
    ap = argparse.ArgumentParser()
    for k in DEFAULT:
        ap.add_argument("--" + k, default=DEFAULT[k])
    ap.add_argument("--on-accent", dest="on_accent", default="#14131a")
    ap.add_argument("--folder", default="violet")
    ap.add_argument("--accent2", default="")
    ap.add_argument("--logo", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    colors = {k: getattr(a, k) for k in DEFAULT}
    on_accent = a.on_accent
    home = os.path.expanduser("~")
    root = a.out or home
    targets = [
        (os.path.join(EXTRAS, "qt6ct", "colors", "ombu.conf"), os.path.join(root, ".config/qt6ct/colors/ombu.conf")),
        (os.path.join(EXTRAS, "qt6ct", "ombu.qss"), os.path.join(root, ".config/qt6ct/qss/ombu.qss")),
        (os.path.join(EXTRAS, "kde", "Ombu.colors"), os.path.join(root, ".local/share/color-schemes/Ombu.colors")),
        (os.path.join(EXTRAS, "kitty", "themes", "ombu.conf"), os.path.join(root, ".config/kitty/themes/ombu.conf")),
    ]
    for src, dst in targets:
        with open(src, encoding="utf-8") as f:
            text = f.read()
        # Con el tema Ombú las plantillas ya están en sus colores: se copian sin tocar
        same = colors == DEFAULT and on_accent == "#14131a"
        out = text if same else recolor(text, dict(colors, on_accent=on_accent))
        if dst.endswith("kitty/themes/ombu.conf") and a.logo:
            out += kitty_comic(colors, on_accent, a.logo, a.accent2)
        write(dst, out, backup=not a.out)
    # GTK 3 & GTK 4: hoja de estilos para aplicaciones GTK
    gtk_text = gtk_css(colors, on_accent)
    for gdir in [".config/gtk-3.0", ".config/gtk-4.0"]:
        gpath = os.path.join(root, gdir, "gtk.css")
        if os.path.exists(os.path.join(root, gdir)):
            write(gpath, gtk_text, backup=not a.out)
    # Prompt (starship): lee el archivo en cada línea nueva, así que cambia sin reiniciar nada
    with open(os.path.join(EXTRAS, "starship", "starship.toml"), encoding="utf-8") as f:
        write(os.path.join(root, ".config/starship.toml"), starship_text(f.read(), colors, on_accent, a.logo), backup=not a.out)
    # Discord (Vesktop): en el QuickCSS, que se recarga en vivo. Un QuickCSS escrito a mano no se toca
    vesk = os.path.join(root, ".config/vesktop/settings")
    if os.path.isdir(vesk) or a.out:
        with open(os.path.join(EXTRAS, "vesktop", "ombu.theme.css"), encoding="utf-8") as f:
            css = fill_template(f.read(), colors, on_accent, a.accent2)
        qpath = os.path.join(vesk, "quickCss.css")
        try:
            with open(qpath, encoding="utf-8") as f:
                current = f.read()
        except OSError:
            current = ""
        if current.strip() == "" or "@name Ombu" in current:
            write(qpath, css, backup=False)

    # mpv (uosc): los colores de su interfaz, sin el # que uosc no acepta. mpv lo lee al abrir
    mpv = os.path.join(root, ".config/mpv")
    if os.path.isdir(mpv) or a.out:
        with open(os.path.join(EXTRAS, "mpv", "uosc.conf"), encoding="utf-8") as f:
            uosc = re.sub(r"#([0-9a-fA-F]{6})\b", r"\1", fill_template(f.read(), colors, on_accent, a.accent2))
        write(os.path.join(mpv, "script-opts", "uosc.conf"), uosc, backup=False)

    # Zen: lo lee al arrancar
    with open(os.path.join(EXTRAS, "zen", "userChrome.css"), encoding="utf-8") as f:
        chrome_css = fill_template(f.read(), colors, on_accent, a.accent2)
    with open(os.path.join(EXTRAS, "zen", "userContent.css"), encoding="utf-8") as f:
        content_css = fill_template(f.read(), colors, on_accent, a.accent2)
    write_zen(root, chrome_css, content_css, colors["accent"])

    # Logo de la barra: se escribe si el tema tiene uno y se borra si no (la barra vuelve al de CachyOS)
    logo_path = os.path.join(root, ".local/share/ombu/icons/bar-logo.svg")
    svg = logo_svg(a.logo, colors["accent"], a.accent2 or colors["accent"], colors["text"]) if a.logo else ""
    if svg:
        write(logo_path, svg, backup=False)
    elif os.path.exists(logo_path):
        os.remove(logo_path)
    if not a.out:
        # kitty vuelve a leer su configuración al recibir SIGUSR1: las terminales abiertas cambian de color
        subprocess.run(["pkill", "-USR1", "-x", "kitty"], check=False)
        subprocess.run([sys.executable, os.path.join(EXTRAS, "icons", "make-ombu-icons.py"), a.folder, "--accent", colors["accent"]],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    print("tema aplicado a las apps Qt y GTK" + (" (prueba en %s)" % root if a.out else ""))


if __name__ == "__main__":
    main()
