pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Chat del panel lateral con Claude Code o Antigravity (bin/agent-chat.py). Cada mensaje es un turno
// del agente en modo no interactivo que retoma la misma conversación (session/conversation id).
// Gasta del cupo del plan como la terminal: el modelo por defecto es el más liviano que sirve.
// Desde acá el agente lee pero no cambia nada; para eso, «Seguir en la terminal».
// La conversación de cada agente se guarda en ~/.local/share/ombu/chat.json (privado, no va al repo).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string dataFile: home + "/.local/share/ombu/chat.json"
    readonly property int keep: 80

    readonly property var agents: [
        {
            id: "claude",
            name: "Claude"
        },
        {
            id: "agy",
            name: "Antigravity"
        }
    ]
    // Claude se elige por alias (siempre apunta al último de cada línea); la versión real la informa
    // cada turno (evento «model») y se recuerda en `resolved`. Fable no está: el plan lo cobra aparte.
    readonly property var claudeAliases: [
        {
            id: "haiku",
            desc: "Rápido y liviano: preguntas cortas"
        },
        {
            id: "sonnet",
            desc: "Equilibrado: el de todos los días"
        },
        {
            id: "opus",
            desc: "El más capaz; gasta bastante más cupo"
        }
    ]
    property var resolved: ({
            haiku: "claude-haiku-5-5",
            sonnet: "claude-sonnet-5-5",
            opus: "claude-opus-5-5"
        })
    // Los de Antigravity salen de `agy models` (bin/agent-chat.py models); estos son de respaldo
    property var agyModels: [
        {
            id: "gemini-3.8-flash-medium",
            name: "Gemini 3.8 Flash (Medium)"
        }
    ]

    readonly property var models: ({
            claude: claudeAliases.map(m => ({
                        id: m.id,
                        name: prettyClaude(resolved[m.id] ?? m.id),
                        desc: m.desc
                    })),
            agy: agyModels.map(m => ({
                        id: m.id,
                        name: m.name,
                        desc: agyDesc(m.id)
                    }))
        })

    // "claude-sonnet-5-5" → "Sonnet 5.5"
    function prettyClaude(id: string): string {
        const parts = id.replace(/^claude-/, "").split("-");
        const name = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
        const ver = parts.slice(1).filter(x => /^\d+$/.test(x)).join(".");
        return ver !== "" ? name + " " + ver : name;
    }

    function agyDesc(id: string): string {
        if (id.includes("flash-low"))
            return "Lo más rápido; piensa poco";
        if (id.includes("flash-medium"))
            return "Rápido y barato: el de todos los días";
        if (id.includes("flash-high"))
            return "Flash pensando más";
        if (id.includes("opus"))
            return "Claude, el más capaz; más lento";
        if (id.includes("sonnet"))
            return "Claude a través de Antigravity";
        if (id.includes("gpt-oss"))
            return "Modelo abierto de OpenAI";
        return "";
    }

    property string agent: "claude"
    property var model: ({
            claude: "sonnet",
            agy: "gemini-3.8-flash-medium"
        })
    // Por agente: {session, cwd, messages: [{role: user|assistant|note, text, tools}]}
    property var convs: ({
            claude: {
                session: "",
                cwd: "",
                messages: []
            },
            agy: {
                session: "",
                cwd: "",
                messages: []
            }
        })
    property var dirs: []

    // Lo que se ve: la conversación del agente elegido
    readonly property var conv: convs[agent] ?? {
        session: "",
        cwd: "",
        messages: []
    }
    readonly property var messages: conv.messages ?? []
    readonly property string cwd: conv.cwd !== "" ? conv.cwd : (dirs[0]?.path ?? home)
    readonly property string cwdName: {
        const d = dirs.find(x => x.path === cwd);
        return d ? d.name : cwd.replace(home, "~");
    }
    readonly property string modelName: (models[agent] ?? []).find(m => m.id === model[agent])?.name ?? model[agent]
    readonly property string agentName: agentLabel(agent)

    function agentLabel(a: string): string {
        return a === "agy" ? "Antigravity" : "Claude";
    }

    function setModel(id: string): void {
        if (busy || !(models[agent] ?? []).some(m => m.id === id))
            return;
        const m = Object.assign({}, model);
        m[agent] = id;
        model = m;
        save();
    }

    // Turno en curso
    property bool busy: false
    property string busyAgent: ""
    property string busyModel: ""
    property string streamText: ""
    property var streamTools: []
    property var denied: []
    property string pendingError: ""

    // Adjuntos del próximo mensaje: [{kind: text|image|file, label, text | path}] (bin/chat-attach.sh)
    property var attachments: []
    property bool attaching: false
    property string attachError: ""

    // Conversaciones anteriores (las dos agentes): [{agent, cwd, session, title, at, messages}]. Se archivan
    // al empezar una nueva o al cambiar de carpeta; «retomar» las vuelve a poner con su sesión.
    property var history: []
    readonly property int keepHistory: 30

    // Modo estudio en marcha: el hook agent-study.sh le pasa al agente las reglas de enseñar sin resolver
    readonly property bool studying: Focus.mode === "estudio" && Focus.running

    // Uso: tokens del último turno y cupo del plan de Claude (0..1, de rate_limit_event)
    property int lastTokens: 0
    property var limits: null

    function setConv(a: string, patch: var): void {
        const all = Object.assign({}, convs);
        all[a] = Object.assign({}, all[a] ?? {}, patch);
        convs = all;
    }

    function push(a: string, msg: var): void {
        const list = (convs[a]?.messages ?? []).concat([msg]);
        setConv(a, {
            messages: list.slice(-keep)
        });
    }

    function setAgent(a: string): void {
        if (busy || !convs[a])
            return;
        agent = a;
        save();
    }

    // Guarda la conversación actual del agente en el historial (si tiene algo)
    function archive(a: string): void {
        const c = convs[a];
        if (!c || (c.messages ?? []).length === 0)
            return;
        const first = c.messages.find(m => m.role === "user");
        const entry = {
            agent: a,
            cwd: c.cwd !== "" ? c.cwd : cwd,
            session: c.session ?? "",
            title: first ? first.text.split("\n")[0].slice(0, 80) : "Conversación",
            at: c.messages[c.messages.length - 1].at ?? Date.now(),
            messages: c.messages
        };
        // La misma sesión no se repite: queda la versión más nueva arriba
        history = [entry].concat(history.filter(h => !(h.session !== "" && h.session === entry.session && h.agent === a))).slice(0, keepHistory);
    }

    function resume(i: int): void {
        const h = history[i];
        if (busy || !h)
            return;
        archive(h.agent);
        history = history.filter((_, k) => k !== i);
        setConv(h.agent, {
            cwd: h.cwd,
            session: h.session,
            messages: h.messages
        });
        agent = h.agent;
        lastTokens = 0;
        save();
    }

    function forget(i: int): void {
        history = history.filter((_, k) => k !== i);
        save();
    }

    // Otra carpeta = otra conversación (las sesiones de los agentes van atadas a la carpeta)
    function setCwd(path: string): void {
        if (busy || path === cwd)
            return;
        archive(agent);
        setConv(agent, {
            cwd: path,
            session: "",
            messages: []
        });
        save();
    }

    function reset(): void {
        if (busy)
            stop();
        archive(agent);
        attachments = [];
        setConv(agent, {
            session: "",
            messages: []
        });
        lastTokens = 0;
        save();
    }

    // kind: clip | shot | file. La captura cierra el panel para elegir la región y lo vuelve a abrir.
    function attach(kind: string): void {
        if (attaching || busy)
            return;
        attaching = true;
        attachError = "";
        if (kind === "shot")
            Ui.sideOpen = false;
        attachProc.reopen = kind === "shot";
        attachProc.command = [Quickshell.shellPath("bin/chat-attach.sh"), kind].concat(kind === "file" ? [cwd] : []);
        attachProc.running = true;
    }

    function removeAttachment(i: int): void {
        attachments = attachments.filter((_, k) => k !== i);
    }

    // El mensaje que recibe el agente: lo escrito y los adjuntos (el texto pegado va adentro; las
    // imágenes y archivos, por su ruta, que el agente lee con su herramienta)
    function promptWith(text: string, list: var): string {
        let out = text;
        for (const at of list) {
            if (at.kind === "text")
                out += "\n\nAdjunto (" + at.label + "):\n```\n" + at.text + "\n```";
            else if (at.kind === "image")
                out += "\n\nAdjunto una imagen: " + at.path + " (leela con tu herramienta para leer archivos).";
            else if (at.kind === "file")
                out += "\n\nAdjunto el archivo: " + at.path;
        }
        return out.trim();
    }

    function send(text: string): bool {
        text = text.trim();
        if ((text === "" && attachments.length === 0) || busy || attaching)
            return false;
        const list = attachments;
        attachments = [];
        const prompt = promptWith(text !== "" ? text : "Mirá lo que te adjunto.", list);
        const dirs = [];
        for (const at of list)
            if (at.path) {
                const d = at.path.slice(0, at.path.lastIndexOf("/"));
                if (d !== "" && !dirs.includes(d))
                    dirs.push(d);
            }
        push(agent, {
            role: "user",
            text: text,
            files: list.map(x => x.label),
            at: Date.now()
        });
        busy = true;
        busyAgent = agent;
        busyModel = modelName;
        streamText = "";
        streamTools = [];
        denied = [];
        pendingError = "";
        proc.environment = {
            OMBU_CHAT_PROMPT: prompt
        };
        const args = [Quickshell.shellPath("bin/agent-chat.py"), "run", "--agent", agent, "--model", model[agent], "--cwd", cwd].concat(conv.session ? ["--session", conv.session] : []);
        for (const d of dirs)
            args.push("--add-dir", d);
        proc.command = args;
        proc.running = true;
        return true;
    }

    function copy(text: string): void {
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "copiar", text]);
    }

    function stop(): void {
        if (proc.running)
            proc.running = false;
    }

    // La misma conversación en kitty, con permisos de verdad (ahí sí se le puede dejar cambiar cosas)
    function openTerminal(): void {
        const a = agent;
        const s = conv.session;
        const exe = a === "claude" ? home + "/.local/bin/claude" : home + "/.local/bin/agy";
        const args = s === "" ? [] : (a === "claude" ? ["--resume", s] : ["--conversation=" + s]);
        Quickshell.execDetached(["kitty", "--directory", cwd, exe].concat(args));
        Ui.sideOpen = false;
    }

    function read(line: string): void {
        let e;
        try {
            e = JSON.parse(line);
        } catch (err) {
            return;
        }
        const a = busyAgent;
        switch (e.t) {
        case "model":
            if (a === "claude" && e.id && resolved[model.claude] !== e.id) {
                const r = Object.assign({}, resolved);
                r[model.claude] = e.id;
                resolved = r;
            }
            if (e.id)
                busyModel = a === "claude" ? prettyClaude(e.id) : ((agyModels.find(m => m.id === e.id)?.name) ?? e.id);
            break;
        case "session":
            if (e.id && e.id !== convs[a]?.session)
                setConv(a, {
                    session: e.id
                });
            break;
        case "text":
            streamText += e.d;
            break;
        case "tool":
            streamTools = streamTools.concat([e.name + (e.detail ? " · " + e.detail : "")]);
            break;
        case "denied":
            if (!denied.includes(e.name))
                denied = denied.concat([e.name]);
            break;
        case "limits":
            limits = e;
            break;
        case "done":
            lastTokens = e.tokens ?? 0;
            break;
        case "error":
            pendingError = e.msg ?? "error";
            break;
        }
    }

    function finish(): void {
        const a = busyAgent;
        const text = streamText.trim();
        if (text !== "" || streamTools.length > 0)
            push(a, {
                role: "assistant",
                text: text,
                tools: streamTools.join("\n"),
                model: busyModel,
                at: Date.now()
            });
        if (denied.length > 0)
            push(a, {
                role: "note",
                text: "Desde acá no puedo usar " + denied.join(", ") + ". Si querés que lo haga, seguí en la terminal."
            });
        else if (pendingError !== "" && text === "") {
            // Si falló sin responder nada, la próxima vez arranca una conversación nueva (la guardada
            // puede no existir más)
            const lost = (convs[a]?.session ?? "") !== "";
            setConv(a, {
                session: ""
            });
            push(a, {
                role: "note",
                text: pendingError + (lost ? "\nEl próximo mensaje empieza una conversación nueva." : "")
            });
        }
        busy = false;
        streamText = "";
        streamTools = [];
        save();
    }

    function save(): void {
        file.setText(JSON.stringify({
            agent: agent,
            model: model,
            resolved: resolved,
            agyModels: agyModels,
            history: history,
            convs: convs
        }) + "\n");
    }

    Process {
        id: proc

        stdout: SplitParser {
            onRead: line => root.read(line)
        }
        onRunningChanged: if (!running && root.busy)
            root.finish()
    }

    Process {
        id: attachProc

        property bool reopen: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.attaching = false;
                if (attachProc.reopen) {
                    Ui.sideTab = "chat";
                    Ui.sideOpen = true;
                }
                try {
                    const r = JSON.parse(text);
                    if (r.error)
                        root.attachError = r.error;
                    else if (r.kind && r.kind !== "none")
                        root.attachments = root.attachments.concat([r]).slice(-5);
                } catch (e) {
                    root.attachError = "No se pudo adjuntar";
                }
            }
        }
    }

    Process {
        id: dirsProc

        command: [Quickshell.shellPath("bin/agent-chat.py"), "dirs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.dirs = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    function refreshDirs(): void {
        if (!dirsProc.running)
            dirsProc.running = true;
    }

    // Lista de modelos de Antigravity (tarda un par de segundos: pregunta al servidor)
    function refreshModels(): void {
        if (!modelsProc.running)
            modelsProc.running = true;
    }

    Process {
        id: modelsProc

        command: [Quickshell.shellPath("bin/agent-chat.py"), "models"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if ((r.agy ?? []).length > 0) {
                        root.agyModels = r.agy;
                        if (!r.agy.some(m => m.id === root.model.agy)) {
                            const m = Object.assign({}, root.model);
                            m.agy = r.agy[0].id;
                            root.model = m;
                        }
                        root.save();
                    }
                } catch (e) {}
            }
        }
    }

    FileView {
        id: file

        path: root.dataFile
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        // Las conversaciones son privadas: solo las lee el usuario
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && touch \"$2\" && chmod 600 \"$2\"", "chat", home + "/.local/share/ombu", dataFile]);
        try {
            const s = JSON.parse(file.text());
            if (s.convs?.claude && s.convs?.agy)
                convs = s.convs;
            if (s.model?.claude && s.model?.agy)
                model = s.model;
            if (Array.isArray(s.history))
                history = s.history;
            if (s.resolved)
                resolved = Object.assign({}, resolved, s.resolved);
            if (Array.isArray(s.agyModels) && s.agyModels.length > 0)
                agyModels = s.agyModels;
            if (s.agent === "claude" || s.agent === "agy")
                agent = s.agent;
        } catch (e) {}
        refreshDirs();
        refreshModels();
    }
}
