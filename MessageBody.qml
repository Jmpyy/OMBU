import QtQuick

// Cuerpo de una respuesta del chat: los pasos del agente plegados en una línea («3 pasos», un clic los
// muestra; mientras llega la respuesta se ve el último), el texto en Markdown (seleccionable, los
// enlaces se abren afuera) con los bloques de código aparte (CodeBlock, con «Copiar») y, mientras
// llega, «Pensando…».
Column {
    id: root

    property string text
    property string tools
    property bool note: false
    property bool thinking: false
    property bool expanded: false

    readonly property var toolList: tools === "" ? [] : tools.split("\n")

    // El texto partido en trozos de Markdown y bloques de código (```lenguaje ... ```); un bloque sin
    // cerrar (la respuesta todavía llega) va hasta el final
    readonly property var segments: {
        if (note)
            return [{
                    code: false,
                    text: text
                }];
        const out = [];
        const re = /```([\w+#.-]*)[^\n]*\n([\s\S]*?)(```|$)/g;
        let last = 0;
        let m;
        while ((m = re.exec(text)) !== null) {
            if (m.index > last)
                out.push({
                    code: false,
                    text: text.slice(last, m.index)
                });
            out.push({
                code: true,
                lang: m[1],
                text: m[2].replace(/\n$/, ""),
                open: m[3] === ""
            });
            last = re.lastIndex;
            if (m[0].length === 0)
                break;
        }
        if (last < text.length)
            out.push({
                code: false,
                text: text.slice(last)
            });
        return out.filter(x => x.code || x.text.trim() !== "");
    }

    spacing: 8

    // Resumen de los pasos
    Rectangle {
        visible: root.toolList.length > 0
        width: Math.min(root.width, stepsRow.implicitWidth + 16)
        height: 24
        radius: 6
        color: stepsHover.hovered ? Theme.hover : Theme.track

        Row {
            id: stepsRow

            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: 6

            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "build"
                font.pixelSize: 13
                color: Theme.textDim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width - 60)
                elide: Text.ElideMiddle
                text: root.thinking && !root.expanded ? (root.toolList[root.toolList.length - 1] ?? "") : root.toolList.length + (root.toolList.length === 1 ? " paso" : " pasos")
                color: Theme.textDim
                font.pixelSize: 11
                font.family: root.thinking && !root.expanded ? "monospace" : Qt.application.font.family
            }

            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.expanded ? "expand_less" : "expand_more"
                font.pixelSize: 15
                color: Theme.textDim
            }
        }

        HoverHandler {
            id: stepsHover

            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.expanded = !root.expanded
        }
    }

    // Los pasos, uno por línea
    Column {
        visible: root.expanded
        width: root.width
        spacing: 3

        Repeater {
            model: root.expanded ? root.toolList : []

            Text {
                required property string modelData

                width: root.width
                text: "› " + modelData
                elide: Text.ElideMiddle
                color: Theme.textDim
                font.pixelSize: 11
                font.family: "monospace"
            }
        }
    }

    Repeater {
        model: root.segments

        Item {
            id: seg

            required property var modelData

            width: root.width
            height: modelData.code ? block.implicitHeight : prose.implicitHeight

            TextEdit {
                id: prose

                visible: !seg.modelData.code
                width: parent.width
                text: seg.modelData.code ? "" : seg.modelData.text.trim()
                textFormat: root.note ? TextEdit.PlainText : TextEdit.MarkdownText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                color: root.note ? Theme.warn : Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.pixelSize: 13
                onLinkActivated: link => Qt.openUrlExternally(link)

                HoverHandler {
                    cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
                }
            }

            CodeBlock {
                id: block

                visible: seg.modelData.code
                width: parent.width
                height: implicitHeight
                lang: seg.modelData.lang ?? ""
                code: seg.modelData.code ? seg.modelData.text : ""
                open: seg.modelData.open ?? false
            }
        }
    }

    Row {
        visible: root.thinking
        spacing: 6

        MIcon {
            name: "progress_activity"
            font.pixelSize: 15
            color: Theme.accent

            RotationAnimator on rotation {
                running: root.thinking && root.visible
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }

        Text {
            text: root.text === "" ? "Pensando…" : "Escribiendo…"
            color: Theme.textDim
            font.pixelSize: 12
        }
    }
}
