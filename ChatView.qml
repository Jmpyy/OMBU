import QtQuick
import QtQuick.Layouts

// Pestaña «Chat» del panel lateral (estado en Chat.qml). Arriba: el agente y la carpeta de trabajo.
// En el medio la conversación: tus mensajes a la derecha, las respuestas en tarjetas (ChatBubble).
// Abajo: el campo (Enter manda, Shift+Enter baja de línea) y una barra con el modelo, el uso y
// «Seguir en la terminal».
ColumnLayout {
    id: root

    // Hay texto escrito o un turno en marcha: el panel no se cierra solo al sacar el mouse
    readonly property bool holding: input.text !== "" || Chat.busy
    property bool pickingDir: false
    property bool pickingModel: false
    property bool showHistory: false
    property bool pickingAttach: false

    // Acciones rápidas: completan el campo (y algunas adjuntan el portapapeles) para que lo ajustes
    readonly property var actions: [
        {
            icon: "bug_report",
            name: "Explicar error",
            prompt: "Explicame este error: qué significa, por qué pasa y cómo lo encuentro yo la próxima vez.",
            clip: true
        },
        {
            icon: "shield",
            name: "Fugas y desbordes",
            prompt: "Revisá este código C buscando fugas de memoria, desbordes de buffer y punteros colgantes. Marcá la línea y explicá el riesgo, sin reescribirlo entero.",
            clip: true
        },
        {
            icon: "checklist",
            name: "Casos de prueba",
            prompt: "Armá casos de prueba para esto: normales, de borde y de error, en una tabla (entrada, salida esperada y por qué).",
            clip: true
        },
        {
            icon: "school",
            name: "Paso a paso",
            prompt: "Explicámelo paso a paso con preguntas para que lo razone yo; no me des la solución completa.",
            clip: false
        }
    ]

    function useAction(a: var): void {
        input.text = a.prompt;
        input.cursorPosition = input.text.length;
        if (a.clip)
            Chat.attach("clip");
        focusInput();
    }

    // "hace 5 min", "ayer", "12/10"
    function when(ms: real): string {
        const m = Math.floor((Date.now() - ms) / 60000);
        if (m < 60)
            return m <= 1 ? "recién" : "hace " + m + " min";
        if (m < 24 * 60)
            return "hace " + Math.floor(m / 60) + " h";
        return m < 48 * 60 ? "ayer" : Qt.formatDate(new Date(ms), "d/M");
    }

    spacing: 8

    function focusInput(): void {
        input.forceActiveFocus();
    }

    function pct(v: var): string {
        return v === null || v === undefined ? "—" : Math.round(v * 100) + " %";
    }

    function tilde(path: string): string {
        return path.replace(Chat.home, "~");
    }

    Segmented {
        Layout.fillWidth: true
        current: Chat.agent
        model: Chat.agents
        opacity: Chat.busy ? 0.5 : 1
        onPicked: id => {
            Chat.setAgent(id);
            root.pickingModel = false;
        }
    }

    // Carpeta de trabajo (el agente lee los archivos de acá) y conversación nueva
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Theme.controlRadius
            color: dirHover.hovered || root.pickingDir ? Theme.hover : Theme.surface
            border.width: Theme.comic ? 1.5 : 1
            border.color: Theme.comic ? Theme.ink : Theme.border
            opacity: Chat.busy ? 0.5 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                MIcon {
                    name: "folder"
                    font.pixelSize: 16
                    color: Theme.accent
                }

                Text {
                    text: Chat.cwdName
                    color: Theme.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.tilde(Chat.cwd)
                    elide: Text.ElideMiddle
                    color: Theme.textDim
                    font.pixelSize: 11
                    font.family: "monospace"
                }

                MIcon {
                    name: root.pickingDir ? "expand_less" : "expand_more"
                    font.pixelSize: 16
                    color: Theme.textDim
                }
            }

            HoverHandler {
                id: dirHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: if (!Chat.busy) {
                    Chat.refreshDirs();
                    root.pickingDir = !root.pickingDir;
                }
            }
        }

        // Conversaciones anteriores
        Rectangle {
            implicitWidth: 34
            implicitHeight: 34
            radius: Theme.controlRadius
            color: root.showHistory ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (histHover.hovered ? Theme.hover : Theme.surface)
            border.width: Theme.comic ? 1.5 : 1
            border.color: Theme.comic ? Theme.ink : Theme.border

            MIcon {
                anchors.centerIn: parent
                name: "history"
                font.pixelSize: 17
                color: root.showHistory ? Theme.accent : (Chat.history.length > 0 ? Theme.text : Theme.textDim)
            }

            HoverHandler {
                id: histHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: {
                    root.showHistory = !root.showHistory;
                    root.pickingDir = false;
                }
            }
        }

        // Conversación nueva
        Rectangle {
            implicitWidth: 34
            implicitHeight: 34
            radius: Theme.controlRadius
            color: newHover.hovered ? Theme.hover : Theme.surface
            border.width: Theme.comic ? 1.5 : 1
            border.color: Theme.comic ? Theme.ink : Theme.border

            MIcon {
                anchors.centerIn: parent
                name: "edit_square"
                font.pixelSize: 16
                color: Chat.messages.length > 0 ? Theme.text : Theme.textDim
            }

            HoverHandler {
                id: newHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Chat.reset()
            }
        }
    }

    // Lista de carpetas: cambiar de carpeta empieza otra conversación
    Rectangle {
        visible: root.pickingDir
        Layout.fillWidth: true
        implicitHeight: dirList.implicitHeight + 8
        radius: Theme.controlRadius
        color: Theme.surface
        border.width: Theme.comic ? 1.5 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border

        Column {
            id: dirList

            x: 4
            y: 4
            width: parent.width - 8

            Repeater {
                model: Chat.dirs

                Rectangle {
                    id: dirRow

                    required property var modelData
                    readonly property bool current: modelData.path === Chat.cwd

                    width: dirList.width
                    height: 30
                    radius: Theme.controlRadius - 3
                    color: rowHover.hovered ? Theme.hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MIcon {
                            name: dirRow.current ? "check" : "folder_open"
                            font.pixelSize: 15
                            color: dirRow.current ? Theme.accent : Theme.textDim
                        }

                        Text {
                            text: dirRow.modelData.name
                            color: dirRow.current ? Theme.accent : Theme.text
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.tilde(dirRow.modelData.path)
                            elide: Text.ElideMiddle
                            color: Theme.textDim
                            font.pixelSize: 11
                            font.family: "monospace"
                        }
                    }

                    HoverHandler {
                        id: rowHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            Chat.setCwd(dirRow.modelData.path);
                            root.pickingDir = false;
                        }
                    }
                }
            }
        }
    }

    // Modo estudio: el agente recibe las reglas de enseñar sin resolver (bin/agent-study.sh)
    Rectangle {
        visible: Chat.studying
        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.controlRadius
        color: Qt.rgba(0.435, 0.608, 0.941, 0.14)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            MIcon {
                name: "school"
                font.pixelSize: 15
                color: "#6f9bf0"
            }

            Text {
                Layout.fillWidth: true
                text: "Modo estudio: te guía para que lo resuelvas vos"
                elide: Text.ElideRight
                color: "#6f9bf0"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    // Conversaciones anteriores
    Rectangle {
        visible: root.showHistory
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.controlRadius
        color: Theme.surface
        border.width: Theme.comic ? 1.5 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border

        Text {
            visible: Chat.history.length === 0
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "Todavía no hay conversaciones guardadas. Se guardan al empezar una nueva o al cambiar de carpeta."
            color: Theme.textDim
            font.pixelSize: 12
        }

        ListView {
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: Chat.history
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: hrow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 48
                radius: Theme.controlRadius - 3
                color: hrowHover.hovered ? Theme.hover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8

                    MIcon {
                        name: hrow.modelData.agent === "agy" ? "rocket_launch" : "auto_awesome"
                        font.pixelSize: 15
                        color: Theme.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: hrow.modelData.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Chat.agentLabel(hrow.modelData.agent) + " · " + root.tilde(hrow.modelData.cwd) + " · " + root.when(hrow.modelData.at)
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font.pixelSize: 11
                        }
                    }

                    // Olvidar
                    Rectangle {
                        visible: hrowHover.hovered
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 6
                        color: delHover.hovered ? Theme.hover : "transparent"

                        MIcon {
                            anchors.centerIn: parent
                            name: "close"
                            font.pixelSize: 14
                            color: Theme.textDim
                        }

                        HoverHandler {
                            id: delHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            // Se queda con el clic: si no, también lo recibe la fila que lo contiene
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: Chat.forget(hrow.index)
                        }
                    }
                }

                HoverHandler {
                    id: hrowHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    // Primero cerrar la lista: retomar saca la fila del historial y la destruye
                    onTapped: {
                        const i = hrow.index;
                        root.showHistory = false;
                        Chat.resume(i);
                    }
                }
            }
        }
    }

    // Conversación
    ListView {
        id: list

        visible: !root.showHistory
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 12
        boundsBehavior: Flickable.StopAtBounds
        model: Chat.messages
        // Siempre pegado al final mientras llega la respuesta
        onCountChanged: Qt.callLater(positionViewAtEnd)
        onContentHeightChanged: if (Chat.busy)
            positionViewAtEnd()

        // Vacío: qué se puede hacer acá
        Column {
            visible: list.count === 0 && !Chat.busy
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 8

            MIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "forum"
                font.pixelSize: 32
                color: Theme.textDim
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Chat.agentName + " · " + Chat.modelName
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Lee y explica lo que hay en " + Chat.cwdName + ". Para que cambie archivos o corra comandos, seguí en la terminal."
                color: Theme.textDim
                font.pixelSize: 12
                lineHeight: 1.15
            }
        }

        delegate: Item {
            id: msg

            required property var modelData
            readonly property string role: modelData.role

            width: ListView.view.width
            height: role === "user" ? userBubble.height : (role === "note" ? noteRow.implicitHeight : reply.implicitHeight)

            // Tu mensaje: burbuja a la derecha
            Rectangle {
                id: userBubble

                visible: msg.role === "user"
                anchors.right: parent.right
                width: Math.min(parent.width * 0.85, Math.max(measure.implicitWidth, filesRow.implicitWidth) + 24)
                height: userText.implicitHeight + (filesRow.visible ? filesRow.implicitHeight + (userText.text !== "" ? 6 : 0) : 0) + 16
                radius: Theme.controlRadius
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                border.width: Theme.comic ? 1.5 : 0
                border.color: Theme.ink

                // Ancho del texto sin cortar, para que la burbuja no ocupe más de lo que necesita
                Text {
                    id: measure

                    visible: false
                    text: msg.role === "user" ? msg.modelData.text : ""
                    font.pixelSize: 13
                }

                TextEdit {
                    id: userText

                    x: 12
                    y: 8
                    width: parent.width - 24
                    text: msg.role === "user" ? msg.modelData.text : ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.pixelSize: 13
                }

                Flow {
                    id: filesRow

                    visible: (msg.modelData.files ?? []).length > 0
                    x: 12
                    y: userText.text !== "" ? userText.y + userText.implicitHeight + 6 : 8
                    width: parent.width - 24
                    spacing: 4

                    Repeater {
                        model: msg.modelData.files ?? []

                        Rectangle {
                            required property string modelData

                            width: fileLabel.implicitWidth + 26
                            height: 20
                            radius: 5
                            color: Qt.rgba(0, 0, 0, 0.2)

                            MIcon {
                                x: 5
                                anchors.verticalCenter: parent.verticalCenter
                                name: "attach_file"
                                font.pixelSize: 12
                                color: Theme.textDim
                            }

                            Text {
                                id: fileLabel

                                x: 20
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData
                                color: Theme.text
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // Respuesta del agente
            ChatBubble {
                id: reply

                visible: msg.role === "assistant"
                width: parent.width
                agent: Chat.agent
                model: msg.modelData.model ?? ""
                at: msg.modelData.at ?? 0
                text: msg.role === "assistant" ? msg.modelData.text : ""
                tools: msg.modelData.tools ?? ""
            }

            // Aviso (permiso negado, error)
            Row {
                id: noteRow

                visible: msg.role === "note"
                width: parent.width
                spacing: 6

                MIcon {
                    name: "info"
                    font.pixelSize: 15
                    color: Theme.warn
                }

                Text {
                    width: parent.width - 21
                    text: msg.role === "note" ? msg.modelData.text : ""
                    wrapMode: Text.Wrap
                    color: Theme.warn
                    font.pixelSize: 12
                }
            }
        }

        // La respuesta que está llegando
        footer: Item {
            width: ListView.view.width
            height: Chat.busy && Chat.busyAgent === Chat.agent ? live.implicitHeight + 12 : 0
            visible: height > 0

            ChatBubble {
                id: live

                y: 12
                width: parent.width
                agent: Chat.busyAgent
                model: Chat.busyModel
                text: Chat.streamText
                tools: Chat.streamTools.join("\n")
                live: true
            }
        }
    }

    // Elegir modelo (se abre desde la barra de abajo)
    Rectangle {
        visible: root.pickingModel
        Layout.fillWidth: true
        implicitHeight: modelList.implicitHeight + 8
        radius: Theme.controlRadius
        color: Theme.surface
        border.width: Theme.comic ? 1.5 : 1
        border.color: Theme.comic ? Theme.ink : Theme.border

        Column {
            id: modelList

            x: 4
            y: 4
            width: parent.width - 8

            Repeater {
                model: Chat.models[Chat.agent] ?? []

                Rectangle {
                    id: modelRow

                    required property var modelData
                    readonly property bool current: modelData.id === Chat.model[Chat.agent]

                    width: modelList.width
                    height: 40
                    radius: Theme.controlRadius - 3
                    color: modelHover.hovered ? Theme.hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modelRow.modelData.name
                                color: modelRow.current ? Theme.accent : Theme.text
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelRow.modelData.desc ?? ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.pixelSize: 11
                            }
                        }

                        MIcon {
                            visible: modelRow.current
                            name: "check"
                            font.pixelSize: 16
                            color: Theme.accent
                        }
                    }

                    HoverHandler {
                        id: modelHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            Chat.setModel(modelRow.modelData.id);
                            root.pickingModel = false;
                        }
                    }
                }
            }
        }
    }

    // Acciones rápidas (con el campo vacío)
    Flow {
        visible: input.text === "" && !Chat.busy && !root.showHistory && !root.pickingModel
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: root.actions

            Rectangle {
                id: act

                required property var modelData

                width: actRow.implicitWidth + 16
                height: 26
                radius: Theme.controlRadius - 3
                color: actHover.hovered ? Theme.hover : Theme.surface
                border.width: 1
                border.color: Theme.border

                Row {
                    id: actRow

                    anchors.centerIn: parent
                    spacing: 5

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: act.modelData.icon
                        font.pixelSize: 14
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: act.modelData.name
                        color: Theme.text
                        font.pixelSize: 11
                    }
                }

                HoverHandler {
                    id: actHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.useAction(act.modelData)
                }
            }
        }
    }

    // Qué adjuntar
    Row {
        visible: root.pickingAttach
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                {
                    kind: "clip",
                    icon: "content_paste",
                    name: "Portapapeles"
                },
                {
                    kind: "shot",
                    icon: "screenshot_region",
                    name: "Captura"
                },
                {
                    kind: "file",
                    icon: "description",
                    name: "Archivo"
                }
            ]

            Rectangle {
                id: opt

                required property var modelData

                width: optRow.implicitWidth + 18
                height: 30
                radius: Theme.controlRadius - 2
                color: optHover.hovered ? Theme.hover : Theme.surface
                border.width: Theme.comic ? 1.5 : 1
                border.color: Theme.comic ? Theme.ink : Theme.border

                Row {
                    id: optRow

                    anchors.centerIn: parent
                    spacing: 6

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: opt.modelData.icon
                        font.pixelSize: 15
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: opt.modelData.name
                        color: Theme.text
                        font.pixelSize: 12
                    }
                }

                HoverHandler {
                    id: optHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        root.pickingAttach = false;
                        Chat.attach(opt.modelData.kind);
                    }
                }
            }
        }
    }

    // Lo adjuntado al próximo mensaje
    Flow {
        visible: Chat.attachments.length > 0 || Chat.attaching || Chat.attachError !== ""
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: Chat.attachments

            Rectangle {
                id: att

                required property var modelData
                required property int index

                width: attRow.implicitWidth + 14
                height: 26
                radius: Theme.controlRadius - 3
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)

                Row {
                    id: attRow

                    anchors.centerIn: parent
                    spacing: 5

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: att.modelData.kind === "image" ? "image" : (att.modelData.kind === "file" ? "description" : "content_paste")
                        font.pixelSize: 14
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: att.modelData.label
                        color: Theme.text
                        font.pixelSize: 11
                    }

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "close"
                        font.pixelSize: 13
                        color: attX.hovered ? Theme.text : Theme.textDim

                        HoverHandler {
                            id: attX

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Chat.removeAttachment(att.index)
                        }
                    }
                }
            }
        }

        Text {
            visible: Chat.attaching
            height: 26
            verticalAlignment: Text.AlignVCenter
            text: "Adjuntando…"
            color: Theme.textDim
            font.pixelSize: 11
        }

        Text {
            visible: Chat.attachError !== ""
            height: 26
            verticalAlignment: Text.AlignVCenter
            text: Chat.attachError
            color: Theme.warn
            font.pixelSize: 11
        }
    }

    // Campo para escribir
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.min(140, Math.max(42, input.implicitHeight + 20))
        radius: Theme.controlRadius
        color: Theme.surface
        border.width: Theme.comic ? 2 : 1
        border.color: Theme.comic ? Theme.ink : (input.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : Theme.border)

        // Adjuntar
        Rectangle {
            id: attachBtn

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 7
            width: 28
            height: 28
            radius: Theme.controlRadius - 3
            color: root.pickingAttach ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (attachHover.hovered ? Theme.hover : "transparent")

            MIcon {
                anchors.centerIn: parent
                name: "attach_file"
                font.pixelSize: 18
                color: root.pickingAttach ? Theme.accent : Theme.textDim
            }

            HoverHandler {
                id: attachHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: if (!Chat.busy)
                    root.pickingAttach = !root.pickingAttach
            }
        }

        Flickable {
            id: inputFlick

            anchors.left: attachBtn.right
            anchors.right: sendBtn.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 4
            anchors.rightMargin: 6
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            contentHeight: input.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: input

                width: inputFlick.width
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.pixelSize: 13
                onCursorRectangleChanged: if (cursorRectangle.y + cursorRectangle.height > inputFlick.contentY + inputFlick.height)
                    inputFlick.contentY = cursorRectangle.y + cursorRectangle.height - inputFlick.height

                Keys.onPressed: event => {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                        if (Chat.send(input.text))
                            input.text = "";
                        event.accepted = true;
                    } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                        Chat.reset();
                        event.accepted = true;
                    }
                }

                Text {
                    visible: input.text === ""
                    text: Chat.busy ? "Respondiendo…" : "Preguntale a " + Chat.agentName + "… (Ctrl+L: nueva)"
                    color: Theme.textDim
                    font.pixelSize: 13
                }
            }
        }

        // Mandar, o cortar la respuesta en curso
        Rectangle {
            id: sendBtn

            readonly property bool active: Chat.busy || input.text.trim() !== "" || Chat.attachments.length > 0

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 7
            width: 28
            height: 28
            radius: Theme.controlRadius - 3
            color: Chat.busy ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25) : (active ? Theme.accent : Theme.track)
            border.width: Theme.comic && active ? 1.5 : 0
            border.color: Theme.ink

            MIcon {
                anchors.centerIn: parent
                name: Chat.busy ? "stop" : "arrow_upward"
                font.pixelSize: 17
                color: Chat.busy ? Theme.danger : (sendBtn.active ? Theme.accentText : Theme.textDim)
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: {
                    if (Chat.busy)
                        Chat.stop();
                    else if (Chat.send(input.text))
                        input.text = "";
                }
            }
        }
    }

    // Modelo, uso y terminal
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            implicitWidth: modelChip.implicitWidth + 16
            implicitHeight: 26
            radius: Theme.controlRadius - 3
            color: root.pickingModel ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (modelChipHover.hovered ? Theme.hover : "transparent")
            opacity: Chat.busy ? 0.5 : 1

            Row {
                id: modelChip

                anchors.centerIn: parent
                spacing: 4

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "neurology"
                    font.pixelSize: 15
                    color: Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Chat.modelName
                    color: Theme.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.pickingModel ? "expand_more" : "expand_less"
                    font.pixelSize: 15
                    color: Theme.textDim
                }
            }

            HoverHandler {
                id: modelChipHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: if (!Chat.busy) {
                    if (!root.pickingModel && Chat.agent === "agy")
                        Chat.refreshModels();
                    root.pickingModel = !root.pickingModel;
                }
            }
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            color: Theme.textDim
            font.pixelSize: 11
            text: {
                const parts = [];
                if (Chat.lastTokens > 0)
                    parts.push((Chat.lastTokens / 1000).toFixed(Chat.lastTokens < 10000 ? 1 : 0) + " k tokens");
                if (Chat.agent === "claude" && Chat.limits)
                    parts.push("5 h " + root.pct(Chat.limits.five) + " · sem. " + root.pct(Chat.limits.week));
                return parts.join(" · ");
            }
        }

        Rectangle {
            implicitWidth: termRow.implicitWidth + 14
            implicitHeight: 26
            radius: Theme.controlRadius - 3
            color: termHover.hovered ? Theme.hover : "transparent"

            Row {
                id: termRow

                anchors.centerIn: parent
                spacing: 4

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "terminal"
                    font.pixelSize: 15
                    color: Theme.textDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Terminal"
                    color: Theme.textDim
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            HoverHandler {
                id: termHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Chat.openTerminal()
            }
        }
    }
}
