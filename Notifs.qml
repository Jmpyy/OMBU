pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Servidor de notificaciones (org.freedesktop.Notifications). Reemplaza a swaync.
// Mantiene el historial y decide qué avisos emergentes se muestran.
Singleton {
    id: root

    // No molestar: no hay avisos emergentes (las críticas igual se muestran)
    property bool dnd: false

    // Historial, de la más nueva a la más vieja. Cada elemento es un Entry.
    property var history: []
    // Avisos emergentes en pantalla (incluye los que se están yendo)
    property var toasts: []

    readonly property int count: history.length
    readonly property var latest: history.length > 0 ? history[0] : null

    // Llegó una notificación nueva (la campana de la barra reacciona)
    signal received(var entry)

    // Un aviso: la notificación más su estado de aviso emergente.
    // La Notification se destruye apenas se cierra, pero la tarjeta sigue en pantalla
    // mientras se desvanece: por eso se guarda una copia de lo que se muestra.
    component Entry: QtObject {
        id: entry

        required property var n
        property date time: new Date()
        property bool shown: false
        property bool hovered: false
        // Se cerró deslizándola hacia la derecha: sale con ese movimiento
        property bool swiped: false
        // Tiempo que le queda al aviso, de 1 (recién llegó) a 0 (se va)
        property real remaining: 1

        // Copia de los datos que dibuja la tarjeta
        property string appName: ""
        property string summary: ""
        property string body: ""
        property string image: ""
        property string appIcon: ""
        property string desktopEntry: ""
        property bool critical: false
        property real expireSeconds: 0
        property var actionList: []

        Component.onCompleted: {
            appName = n.appName;
            summary = n.summary;
            body = n.body;
            image = n.image;
            appIcon = n.appIcon;
            desktopEntry = n.desktopEntry;
            critical = n.urgency === NotificationUrgency.Critical;
            expireSeconds = n.expireTimeout;
            actionList = Array.from(n.actions).map(a => ({
                        identifier: a.identifier,
                        text: a.text
                    }));
        }

        function hide(): void {
            shown = false;
            leave.restart();
        }

        // Segundos que indica la app; sin indicación, 6. Las críticas no se van solas.
        readonly property bool hasTimer: expireSeconds > 0 || !critical

        // La cuenta regresiva es una animación: se pausa con el mouse encima y la barra
        // de progreso de la tarjeta la sigue sin desfasarse.
        readonly property NumberAnimation countdown: NumberAnimation {
            target: entry
            property: "remaining"
            from: 1
            to: 0
            duration: entry.expireSeconds > 0 ? entry.expireSeconds * 1000 : 6000
            running: entry.shown && entry.hasTimer
            paused: entry.hovered
            onFinished: entry.hide()
        }

        // Deja terminar la animación de salida antes de sacarlo de la lista
        readonly property Timer leave: Timer {
            interval: 380
            onTriggered: root.dropToast(entry)
        }
    }

    function dropToast(entry): void {
        toasts = toasts.filter(e => e !== entry);
        if (!history.includes(entry))
            entry.destroy();
    }

    function add(n): void {
        // Hay que marcarla como "tracked" para que el servidor no la descarte
        n.tracked = true;
        // Avisos de algo que ya tenés a la vista (ver NotifRules): se descartan sin mostrar
        if (NotifRules.shouldDrop(n)) {
            n.dismiss();
            return;
        }
        for (const old of history.filter(e => e.n && e.n.id === n.id))
            remove(old);

        const entry = entryComponent.createObject(root, {
            n: n
        });
        // Pasa el texto a español si hay una regla para esta app
        entry.summary = NotifRules.translate(n, entry.summary);
        entry.body = NotifRules.translate(n, entry.body);
        history = [entry, ...history];
        n.closed.connect(() => root.remove(entry));
        received(entry);

        if (!dnd || entry.critical) {
            toasts = [entry, ...toasts];
            entry.shown = true;
            // Máximo 5 avisos a la vez; los más viejos se van (siguen en el historial)
            for (const old of toasts.slice(5))
                old.hide();
        }
    }

    function remove(entry): void {
        history = history.filter(e => e !== entry);
        if (toasts.includes(entry))
            entry.hide();
        else
            entry.destroy(500);
    }

    function dismiss(entry): void {
        // Si la app ya la cerró, la notificación original ya no existe
        if (entry.n)
            entry.n.dismiss();
        else
            remove(entry);
    }

    function dismissLatest(): void {
        if (latest)
            dismiss(latest);
    }

    function dismissAll(): void {
        for (const e of history.slice())
            dismiss(e);
    }

    // Ejecuta una acción por su identificador y cierra la notificación
    function invokeAction(entry, identifier: string): void {
        const n = entry.n;
        if (!n)
            return;
        const action = Array.from(n.actions).find(a => a.identifier === identifier);
        if (action)
            action.invoke();
        if (!n.resident)
            dismiss(entry);
    }

    // Acción principal ("default" o la primera) y cerrar
    function invoke(entry): void {
        const actions = entry.actionList;
        const action = actions.find(a => a.identifier === "default") ?? actions[0];
        if (action)
            invokeAction(entry, action.identifier);
        else
            dismiss(entry);
    }

    function invokeLatest(): void {
        if (latest)
            invoke(latest);
    }

    Component {
        id: entryComponent

        Entry {}
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => root.add(n)
    }
}
