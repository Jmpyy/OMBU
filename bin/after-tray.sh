#!/usr/bin/env bash
# Lanza un programa recién cuando la bandeja de ombu está lista (hasta 30 s). Las apps que
# arrancan con la sesión (Vesktop...) registran su ícono una sola vez: si lo hacen antes de
# que exista la bandeja, no aparece. Uso: after-tray.sh COMANDO [ARGUMENTOS...]
for _ in $(seq 1 60); do
    busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
    sleep 0.5
done
exec "$@"
