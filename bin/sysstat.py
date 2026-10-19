#!/usr/bin/env python3
"""Estado de la PC para el panel lateral de ombu: una línea de JSON cada tanto con procesador,
memoria, placa de video, discos, red y tiempo encendida.

Uso: sysstat.py [--watch SEGUNDOS]   (sin --watch imprime una sola medición y termina)
Solo mide mientras está corriendo: el panel lo lanza al abrirse y lo cierra al cerrarse, así que
cerrado no consume nada. Solo biblioteca estándar (y nvidia-smi si hay placa NVIDIA)."""
import glob
import json
import os
import subprocess
import sys
import time

DISKS = [("Sistema", "/"), ("Almacenamiento", "/mnt/almacenamiento")]


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def cpu_times():
    vals = [int(x) for x in read("/proc/stat").split("\n")[0].split()[1:8]]
    idle = vals[3] + vals[4]
    return idle, sum(vals)


def meminfo():
    m = {}
    for line in read("/proc/meminfo").split("\n"):
        if ":" in line:
            k, v = line.split(":", 1)
            m[k] = int(v.split()[0]) * 1024
    return m


def cpu_temp():
    best = None
    for hw in glob.glob("/sys/class/hwmon/hwmon*"):
        name = read(hw + "/name").strip()
        if name in ("k10temp", "coretemp", "zenpower"):
            for f in sorted(glob.glob(hw + "/temp*_input")):
                try:
                    c = int(read(f)) / 1000
                except ValueError:
                    continue
                if best is None or c > best:
                    best = c
    return best


def net_bytes():
    rx = tx = 0
    for line in read("/proc/net/dev").split("\n")[2:]:
        if ":" not in line:
            continue
        iface, data = line.split(":", 1)
        if iface.strip() == "lo":
            continue
        f = data.split()
        rx += int(f[0])
        tx += int(f[8])
    return rx, tx


def gpu():
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw",
                              "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=3).stdout.strip()
        n, u, t, mu, mt, p = [x.strip() for x in out.split(",")]
        return {"name": n, "usage": float(u), "temp": float(t), "memUsed": float(mu) * 2**20, "memTotal": float(mt) * 2**20,
                "power": float(p) if p not in ("[N/A]", "") else None}
    except Exception:
        return None


def disks():
    out = []
    for name, path in DISKS:
        try:
            st = os.statvfs(path)
        except OSError:
            continue
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        if total:
            out.append({"name": name, "used": total - free, "total": total})
    return out


class Sampler:
    def __init__(self):
        self.idle, self.total = cpu_times()
        self.rx, self.tx = net_bytes()
        self.t = time.time()

    def sample(self):
        idle, total = cpu_times()
        now = time.time()
        rx, tx = net_bytes()
        dt = max(now - self.t, 0.001)
        dtotal = total - self.total
        cpu = 100 * (1 - (idle - self.idle) / dtotal) if dtotal > 0 else 0
        m = meminfo()
        up = float(read("/proc/uptime").split()[0] or 0)
        out = {
            "cpu": round(cpu, 1), "cpuTemp": cpu_temp(),
            "memUsed": m.get("MemTotal", 0) - m.get("MemAvailable", 0), "memTotal": m.get("MemTotal", 0),
            "gpu": gpu(), "disks": disks(),
            "netDown": (rx - self.rx) / dt, "netUp": (tx - self.tx) / dt,
            "uptime": up, "load": [float(x) for x in read("/proc/loadavg").split()[:3]],
        }
        self.idle, self.total, self.rx, self.tx, self.t = idle, total, rx, tx, now
        return out


def main():
    s = Sampler()
    if "--watch" in sys.argv:
        every = float(sys.argv[sys.argv.index("--watch") + 1])
        while True:
            time.sleep(every)
            print(json.dumps(s.sample()), flush=True)
    else:
        time.sleep(0.5)
        print(json.dumps(s.sample()))


if __name__ == "__main__":
    main()
