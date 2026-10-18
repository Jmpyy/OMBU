import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Mezcladora: dispositivo de salida, dispositivo de entrada y un volumen por app.
DropPopup {
    id: root

    readonly property var allNodes: Array.from(Pipewire.nodes.values)

    function mediaClass(n): string {
        return n.properties["media.class"] ?? "";
    }

    function appName(n): string {
        return n.properties["application.name"] ?? n.properties["node.name"] ?? "Aplicación";
    }

    function appIcon(n): string {
        const hint = n.properties["application.icon-name"];
        if (hint)
            return Quickshell.iconPath(hint, "application-x-executable");
        const entry = DesktopEntries.heuristicLookup(appName(n));
        return Quickshell.iconPath(entry ? entry.icon : appName(n).toLowerCase(), "application-x-executable");
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

    bodyWidth: 370
    bodyHeight: column.implicitHeight + 26

    ColumnLayout {
        id: column

        x: 16
        y: 2
        width: root.bodyWidth - 32
        spacing: 16

        DeviceSection {
            Layout.fillWidth: true
            title: "SALIDA"
            iconOn: "volume_up"
            iconOff: "volume_off"
            node: Pipewire.defaultAudioSink
            devices: root.sinks
            onSelected: d => Pipewire.preferredDefaultAudioSink = d
        }

        DeviceSection {
            Layout.fillWidth: true
            title: "ENTRADA"
            iconOn: "mic"
            iconOff: "mic_off"
            node: Pipewire.defaultAudioSource
            devices: root.sources
            onSelected: d => Pipewire.preferredDefaultAudioSource = d
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "APLICACIONES"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                visible: root.apps.length === 0
                Layout.fillWidth: true
                text: "Ninguna app está usando audio ahora."
                color: Theme.textDim
                font.pixelSize: 12
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
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

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
                                font.pixelSize: 10
                                color: "#14131a"
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
                                font.pixelSize: 12
                            }

                            Text {
                                text: Math.round(app.volume * 100) + "%"
                                color: app.muted ? Theme.textDim : Theme.text
                                font.pixelSize: 11
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
                            font.pixelSize: 16
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
