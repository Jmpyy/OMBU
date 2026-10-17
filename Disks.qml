pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Discos y unidades del equipo, leídos con lsblk. Se actualiza solo cuando udev avisa que
// algo se conectó, desconectó o cambió (no consulta de más), y al abrir el menú.
Singleton {
    id: root

    // Cada volumen: { path, disk, name, model, fs, size, used, avail, mount, mounted, removable }
    property var volumes: []
    readonly property var internal: volumes.filter(v => !v.removable)
    readonly property var removable: volumes.filter(v => v.removable)
    // Ruta del volumen al que se le está haciendo una acción (monta, expulsa)
    property string busyPath: ""

    function refresh(): void {
        if (!lsblk.running)
            lsblk.running = true;
    }

    // Abre el volumen en el explorador; si no está montado, lo monta primero
    function open(v: var): void {
        if (v.mounted) {
            Quickshell.execDetached(["env", "QT_QPA_PLATFORMTHEME=qt6ct", "dolphin", "--new-window", v.mount]);
            return;
        }
        run(v, [Quickshell.shellPath("bin/mount-open.sh"), v.path]);
    }

    // Desmonta y, si es una unidad extraíble, la apaga para poder sacarla sin riesgo
    function eject(v: var): void {
        const script = v.removable ? 'udisksctl unmount -b "$1" && udisksctl power-off -b "$2"' : 'udisksctl unmount -b "$1"';
        run(v, ["sh", "-c", script, "sh", v.path, "/dev/" + v.disk]);
    }

    function run(v: var, command: var): void {
        if (action.running)
            return;
        busyPath = v.path;
        action.command = command;
        action.running = true;
    }

    // 1 GB = 1024 MB, como lo muestra Windows
    function format(bytes: real): string {
        if (!(bytes >= 0))
            return "—";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        let n = bytes;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i++;
        }
        const text = n >= 100 || i === 0 ? Math.round(n).toString() : n.toFixed(1);
        return text.replace(".", ",") + " " + units[i];
    }

    function parse(text: string): void {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            console.warn("ombu: no pude leer lsblk:", e);
            return;
        }
        const out = [];
        const visit = (node, disk) => {
            const mounts = (node.mountpoints ?? []).filter(m => m);
            const hidden = mounts.some(m => m.startsWith("/boot") || m === "[SWAP]");
            const real = node.fstype && node.fstype !== "swap" && node.fstype !== "crypto_LUKS" && node.fstype !== "LVM2_member" && node.fstype !== "linux_raid_member";
            if (real && !hidden && node.type !== "loop") {
                const mount = mounts.includes("/") ? "/" : (mounts[0] ?? "");
                const removable = !!(node.rm || node.hotplug || disk?.rm || disk?.hotplug);
                const used = node.fsused === null || node.fsused === undefined ? -1 : Number(node.fsused);
                const avail = node.fsavail === null || node.fsavail === undefined ? -1 : Number(node.fsavail);
                out.push({
                    path: node.path,
                    disk: disk ? disk.name : node.name,
                    name: node.label || (mount === "/" ? "Sistema" : (disk?.model ?? node.model ?? node.name).trim()),
                    model: (disk?.model ?? node.model ?? "").trim(),
                    fs: node.fstype,
                    size: Number(node.size),
                    used: used,
                    avail: avail,
                    mount: mount,
                    mounted: mount !== "",
                    removable: removable
                });
            }
            for (const child of node.children ?? [])
                visit(child, node.type === "disk" ? node : disk);
        };
        for (const node of data.blockdevices ?? [])
            if (!node.name.startsWith("zram"))
                visit(node, node.type === "disk" ? node : null);
        // El sistema primero, luego el resto por nombre
        out.sort((a, b) => (b.mount === "/") - (a.mount === "/") || a.name.localeCompare(b.name));
        volumes = out;
    }

    Process {
        id: lsblk

        command: ["lsblk", "-b", "-J", "-o", "NAME,PATH,TYPE,LABEL,SIZE,FSTYPE,MOUNTPOINTS,FSUSED,FSAVAIL,RM,HOTPLUG,MODEL"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // Monta, desmonta o expulsa; al terminar se vuelve a leer todo
    Process {
        id: action

        onExited: {
            root.busyPath = "";
            root.refresh();
        }
    }

    // udev avisa cada vez que se conecta, desconecta o cambia una unidad
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]

        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce

        interval: 600
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
