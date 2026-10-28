import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Mezcladora, a la manera del menú de sonido de macOS: salida y entrada (volumen y lista de
// dispositivos) y un volumen por app, separados por líneas finas.
DropPopup {
    id: root

    readonly property var allNodes: Array.from(Pipewire.nodes.values)

    function mediaClass(n): string {
        return n.properties["media.class"] ?? "";
    }

    function appName(n): string {
        return n.properties["application.name"] ?? n.properties["node.name"] ?? "Aplicación";
    }

    // El ícono que trae el stream, el de su app o uno genérico. Con iconPath(nombre, respaldo) Qt no
    // encontraba ni uno ni otro para procesos sin app (paplay) y dejaba un aviso en el log por cada fila.
    function appIcon(n): string {
        const hint = n.properties["application.icon-name"];
        const entry = DesktopEntries.heuristicLookup(appName(n));
        return (hint ? Icons.themed(hint) : "") || Icons.forApp(appName(n), entry ? entry.icon : "") || Icons.themed("multimedia-volume-control");
    }

    readonly property var sinks: allNodes.filter(n => mediaClass(n) === "Audio/Sink")
    readonly property var sources: allNodes.filter(n => mediaClass(n) === "Audio/Source")
    readonly property var playing: allNodes.filter(n => mediaClass(n) === "Stream/Output/Audio")
    readonly property var recording: allNodes.filter(n => mediaClass(n) === "Stream/Input/Audio")

    // Una fila por aplicación: un navegador deja un stream de audio por cada video y pestaña
    // (Instagram crea uno por cada reel, casi todos pausados), y listarlos todos llenaba el menú.
    function groupApps(nodes: var): var {
        const groups = [];
        const byKey = {};
        for (const n of nodes) {
            const key = appName(n) + "|" + mediaClass(n);
            if (!byKey[key]) {
                byKey[key] = {
                    key: key,
                    nodes: []
                };
                groups.push(byKey[key]);
            }
            byKey[key].nodes.push(n);
        }
        return groups;
    }

    readonly property var apps: groupApps(playing.concat(recording))

    bodyWidth: 340
    bodyHeight: column.implicitHeight + 16

    ColumnLayout {
        id: column

        x: 8
        y: 4
        width: root.bodyWidth - 16
        spacing: 2

        DeviceSection {
            Layout.fillWidth: true
            title: "Salida"
            iconOn: "volume_up"
            iconOff: "volume_off"
            node: Pipewire.defaultAudioSink
            devices: root.sinks
            onSelected: d => Pipewire.preferredDefaultAudioSink = d
        }

        MenuSeparator {}

        DeviceSection {
            Layout.fillWidth: true
            title: "Entrada"
            iconOn: "mic"
            iconOff: "mic_off"
            node: Pipewire.defaultAudioSource
            devices: root.sources
            onSelected: d => Pipewire.preferredDefaultAudioSource = d
        }

        MenuSeparator {}

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            MenuSection {
                text: "Aplicaciones"
            }

            Text {
                visible: root.apps.length === 0
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.bottomMargin: 4
                text: "Ninguna app está usando audio ahora."
                color: Theme.textDim
                font.pixelSize: Theme.fontSmall
            }

            Repeater {
                model: ScriptModel {
                    values: root.apps
                    objectProp: "key"
                }

                RowLayout {
                    id: app

                    required property var modelData
                    // Los streams de la app: se muestra uno solo y el volumen se aplica a todos
                    readonly property var nodes: modelData.nodes
                    readonly property var node: nodes[0]
                    readonly property bool isMic: root.mediaClass(node) === "Stream/Input/Audio"
                    readonly property real volume: node.audio?.volume ?? 0
                    readonly property bool muted: nodes.every(n => n.audio?.muted ?? false)

                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 4
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        Image {
                            anchors.fill: parent
                            source: root.appIcon(app.node)
                            sourceSize: Qt.size(60, 60)
                            smooth: true
                        }

                        // Marca las apps que están usando el micrófono
                        Rectangle {
                            visible: app.isMic
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.accent

                            MIcon {
                                anchors.centerIn: parent
                                name: "mic"
                                font.pixelSize: Theme.iconXs
                                color: Theme.accentText
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: root.appName(app.node) + (app.isMic ? " (micrófono)" : "")
                                elide: Text.ElideRight
                                color: Theme.text
                                font.pixelSize: Theme.fontBody
                            }

                            Text {
                                text: Math.round(app.volume * 100) + " %"
                                color: app.muted ? Theme.textDim : Theme.text
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        MixerSlider {
                            Layout.fillWidth: true
                            value: app.volume
                            muted: app.muted
                            onMoved: v => {
                                for (const n of app.nodes) {
                                    if (n.audio)
                                        n.audio.volume = v;
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: appMuteHover.hovered ? Theme.hover : "transparent"

                        MIcon {
                            anchors.centerIn: parent
                            name: app.muted ? (app.isMic ? "mic_off" : "volume_off") : (app.isMic ? "mic" : "volume_up")
                            color: app.muted ? Theme.danger : Theme.textDim
                            font.pixelSize: Theme.iconSm
                        }

                        HoverHandler {
                            id: appMuteHover
                        }
                        TapHandler {
                            onTapped: {
                                const mute = !app.muted;
                                for (const n of app.nodes) {
                                    if (n.audio)
                                        n.audio.muted = mute;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
