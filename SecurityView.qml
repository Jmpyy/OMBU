import QtQuick
import QtQuick.Layouts

// Parte de seguridad de la pestaña «Sistema» (datos de Seguridad.qml): estado general, actualizaciones
// y noticias de Arch, puertos abiertos (qué es cada uno y si acepta conexiones de la red), servicios
// caídos y los programas que más consumen, con botón para cerrarlos.
ColumnLayout {
    id: root

    property string procSort: "cpu"
    // Programa a confirmar antes de cerrarlo (dos clics: no se cierra nada por un roce)
    property string confirmClose: ""

    spacing: 6

    function ago(epoch: real): string {
        if (epoch <= 0)
            return "nunca";
        const h = Math.floor((Date.now() / 1000 - epoch) / 3600);
        if (h < 1)
            return "hace un rato";
        if (h < 24)
            return "hace " + h + " h";
        const d = Math.floor(h / 24);
        return d === 1 ? "ayer" : "hace " + d + " días";
    }

    function gb(bytes: real): string {
        return bytes >= 1073741824 ? (bytes / 1073741824).toFixed(1) + " GB" : Math.round(bytes / 1048576) + " MB";
    }

    Timer {
        interval: 4000
        running: root.confirmClose !== ""
        onTriggered: root.confirmClose = ""
    }

    // ---------------- Estado general ----------------
    ComicCard {
        Layout.fillWidth: true
        title: "Seguridad"
        tint: Theme.accent

        Text {
            visible: Seguridad.firewall === null
            text: "Revisando…"
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
        }

        Repeater {
            model: Seguridad.firewall === null ? [] : [
                {
                    ok: Seguridad.firewall.active,
                    level: Seguridad.firewall.active ? "ok" : "bad",
                    icon: "local_fire_department",
                    text: Seguridad.firewall.active ? "Firewall activo (" + Seguridad.firewall.name + ")" : "Sin firewall activo",
                    hint: Seguridad.firewall.active ? "Filtra lo que entra desde la red" : "Cualquier puerto «red» queda a la vista"
                },
                {
                    level: Seguridad.checking && Seguridad.updates.at === undefined ? "info" : (Seguridad.pending === 0 ? "ok" : (Seguridad.pending > 50 || (Date.now() / 1000 - Seguridad.upgradedAt) > 14 * 86400 ? "bad" : "warn")),
                    icon: "system_update",
                    text: Seguridad.updates.at === undefined ? "Buscando actualizaciones…" : (Seguridad.pending === 0 ? "Sistema al día" : Seguridad.pending + " actualizaciones pendientes"),
                    hint: "Última actualización completa: " + root.ago(Seguridad.upgradedAt)
                },
                {
                    level: Seguridad.failed.length === 0 ? "ok" : "bad",
                    icon: "dns",
                    text: Seguridad.failed.length === 0 ? "Ningún servicio caído" : Seguridad.failed.length + (Seguridad.failed.length === 1 ? " servicio caído" : " servicios caídos"),
                    hint: Seguridad.failed.length === 0 ? "systemd no reporta fallas" : "Mirá el log para saber por qué"
                },
                {
                    level: Seguridad.exposed.length === 0 ? "ok" : (Seguridad.firewall.active ? "info" : "warn"),
                    icon: "lan",
                    text: Seguridad.exposed.length === 0 ? "Nada escucha desde la red" : Seguridad.exposed.length + (Seguridad.exposed.length === 1 ? " puerto escucha desde la red" : " puertos escuchan desde la red"),
                    hint: Seguridad.exposed.length === 0 ? "Solo hay servicios locales" : (Seguridad.firewall.active ? "El firewall decide si pasan" : "Sin firewall: revisalos abajo")
                }
            ]

            RowLayout {
                required property var modelData
                readonly property color lc: modelData.level === "ok" ? "#5fb98a" : (modelData.level === "bad" ? Theme.danger : (modelData.level === "warn" ? Theme.warn : "#6f9bf0"))

                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 7
                    color: Qt.rgba(parent.lc.r, parent.lc.g, parent.lc.b, 0.16)

                    MIcon {
                        anchors.centerIn: parent
                        name: parent.parent.modelData.icon
                        font.pixelSize: Theme.iconSm
                        color: parent.parent.lc
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.text
                        elide: Text.ElideRight
                        color: Theme.text
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.hint
                        elide: Text.ElideRight
                        color: Theme.textDim
                        font.pixelSize: Theme.fontCaption
                    }
                }

                MIcon {
                    name: parent.modelData.level === "ok" ? "check_circle" : (parent.modelData.level === "info" ? "info" : "error")
                    font.pixelSize: Theme.iconSm
                    color: parent.lc
                }
            }
        }
    }

    // ---------------- Actualizaciones ----------------
    ComicCard {
        visible: Seguridad.pending > 0 || (Seguridad.updates.news ?? []).length > 0 || (Seguridad.updates.error ?? "") !== ""
        Layout.fillWidth: true
        title: "Actualizaciones"
        tint: Theme.warn

        Text {
            visible: (Seguridad.updates.error ?? "") !== ""
            Layout.fillWidth: true
            text: Seguridad.updates.error ?? ""
            wrapMode: Text.Wrap
            color: Theme.warn
            font.pixelSize: Theme.fontSmall
        }

        Text {
            visible: Seguridad.pending > 0
            Layout.fillWidth: true
            text: (Seguridad.updates.repo ?? []).length + " de los repositorios" + ((Seguridad.updates.aur ?? []).length > 0 ? " y " + Seguridad.updates.aur.length + " de AUR" : "")
            color: Theme.text
            font.pixelSize: Theme.fontSmall
        }

        Repeater {
            model: (Seguridad.updates.repo ?? []).concat(Seguridad.updates.aur ?? []).slice(0, 5)

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: Theme.fontCaption
                    font.family: "monospace"
                }

                Text {
                    text: modelData.old + " → " + modelData.new
                    elide: Text.ElideLeft
                    Layout.maximumWidth: 190
                    color: Theme.textDim
                    font.pixelSize: Theme.fontTiny
                    font.family: "monospace"
                }
            }
        }

        Text {
            visible: Seguridad.pending > 5
            text: "y " + (Seguridad.pending - 5) + " más"
            color: Theme.textDim
            font.pixelSize: Theme.fontCaption
        }

        // Noticias de Arch: las nuevas desde la última actualización pueden pedir algo a mano
        Text {
            visible: (Seguridad.updates.news ?? []).length > 0
            Layout.topMargin: 4
            text: "NOTICIAS DE ARCH"
            color: Theme.textDim
            font.pixelSize: Theme.fontTiny
            font.weight: Font.Bold
            font.letterSpacing: 1
        }

        Repeater {
            model: (Seguridad.updates.news ?? []).slice(0, 3)

            RowLayout {
                id: newsRow

                required property var modelData

                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: newsRow.modelData.unread ? Theme.warn : Theme.track
                }

                Text {
                    Layout.fillWidth: true
                    text: newsRow.modelData.title
                    elide: Text.ElideRight
                    color: newsRow.modelData.unread ? Theme.text : Theme.textDim
                    font.pixelSize: Theme.fontCaption
                    font.weight: newsRow.modelData.unread ? Font.DemiBold : Font.Normal
                    font.underline: newsHover.hovered

                    HoverHandler {
                        id: newsHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Qt.openUrlExternally(newsRow.modelData.link)
                    }
                }
            }
        }

        Text {
            visible: Seguridad.unreadNews.length > 0
            Layout.fillWidth: true
            text: "Las marcadas salieron después de tu última actualización: leelas antes de actualizar."
            wrapMode: Text.Wrap
            color: Theme.warn
            font.pixelSize: Theme.fontCaption
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: Seguridad.checking ? "Revisando…" : (Seguridad.updates.at ? "Revisado " + root.ago(Seguridad.updates.at) : "")
                color: Theme.textDim
                font.pixelSize: Theme.fontTiny
            }

            Rectangle {
                implicitWidth: refreshText.implicitWidth + 16
                implicitHeight: 24
                radius: Theme.controlRadius - 3
                color: refreshHover.hovered ? Theme.hover : Theme.track

                Text {
                    id: refreshText

                    anchors.centerIn: parent
                    text: "Revisar"
                    color: Theme.text
                    font.pixelSize: Theme.fontCaption
                }

                HoverHandler {
                    id: refreshHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: Seguridad.load(true)
                }
            }

            Rectangle {
                visible: Seguridad.pending > 0
                implicitWidth: upText.implicitWidth + 16
                implicitHeight: 24
                radius: Theme.controlRadius - 3
                color: Theme.accent
                border.width: Theme.comic ? 1.5 : 0
                border.color: Theme.ink

                Text {
                    id: upText

                    anchors.centerIn: parent
                    text: "Actualizar en la terminal"
                    color: Theme.accentText
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: Seguridad.upgradeInTerminal()
                }
            }
        }
    }

    // ---------------- Puertos ----------------
    ComicCard {
        visible: Seguridad.ports.length > 0
        Layout.fillWidth: true
        title: "Puertos abiertos"
        tint: "#6f9bf0"

        Text {
            Layout.fillWidth: true
            text: "«Red»: acepta conexiones de otras máquinas (si el firewall lo deja). «Local»: solo de esta PC."
            wrapMode: Text.Wrap
            color: Theme.textDim
            font.pixelSize: Theme.fontCaption
        }

        Repeater {
            model: Seguridad.ports.slice(0, 8)

            RowLayout {
                id: portRow

                required property var modelData

                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.preferredWidth: 72
                    text: portRow.modelData.proto + " " + portRow.modelData.port
                    color: Theme.text
                    font.pixelSize: Theme.fontCaption
                    font.family: "monospace"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: portRow.modelData.program !== "" ? portRow.modelData.program : "del sistema"
                        elide: Text.ElideRight
                        color: Theme.text
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Text {
                        visible: portRow.modelData.what !== ""
                        Layout.fillWidth: true
                        text: portRow.modelData.what
                        elide: Text.ElideRight
                        color: Theme.textDim
                        font.pixelSize: Theme.fontTiny
                    }
                }

                Rectangle {
                    implicitWidth: scopeText.implicitWidth + 12
                    implicitHeight: 18
                    radius: 5
                    readonly property color sc: portRow.modelData.exposed ? Theme.warn : "#5fb98a"
                    color: Qt.rgba(sc.r, sc.g, sc.b, 0.16)

                    Text {
                        id: scopeText

                        anchors.centerIn: parent
                        text: portRow.modelData.exposed ? "Red" : "Local"
                        color: parent.sc
                        font.pixelSize: Theme.fontTiny
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Text {
            visible: Seguridad.ports.length > 8
            text: "y " + (Seguridad.ports.length - 8) + " más (ss -tulnp en la terminal)"
            color: Theme.textDim
            font.pixelSize: Theme.fontCaption
        }

        Text {
            visible: Seguridad.outgoing.length > 0
            Layout.fillWidth: true
            text: "Conexiones salientes (no esperan que nadie entre): " + Seguridad.outgoing.map(o => o.program).join(", ")
            wrapMode: Text.Wrap
            color: Theme.textDim
            font.pixelSize: Theme.fontTiny
        }
    }

    // ---------------- Servicios caídos ----------------
    ComicCard {
        visible: Seguridad.failed.length > 0
        Layout.fillWidth: true
        title: "Servicios caídos"
        tint: Theme.danger

        Repeater {
            model: Seguridad.failed

            RowLayout {
                id: failRow

                required property var modelData

                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: failRow.modelData.unit + (failRow.modelData.scope === "user" ? " (usuario)" : "")
                        elide: Text.ElideRight
                        color: Theme.text
                        font.pixelSize: Theme.fontCaption
                        font.family: "monospace"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: failRow.modelData.desc
                        elide: Text.ElideRight
                        color: Theme.textDim
                        font.pixelSize: Theme.fontTiny
                    }
                }

                Rectangle {
                    implicitWidth: logText.implicitWidth + 14
                    implicitHeight: 22
                    radius: 5
                    color: logHover.hovered ? Theme.hover : Theme.track

                    Text {
                        id: logText

                        anchors.centerIn: parent
                        text: "Ver log"
                        color: Theme.text
                        font.pixelSize: Theme.fontTiny
                    }

                    HoverHandler {
                        id: logHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Seguridad.journal(failRow.modelData.unit, failRow.modelData.scope)
                    }
                }
            }
        }
    }

    // ---------------- Procesos ----------------
    ComicCard {
        visible: Seguridad.top.cpu.length > 0
        Layout.fillWidth: true
        title: "Procesos"
        tint: Themes.active.border2 ?? Theme.accent

        Segmented {
            Layout.fillWidth: true
            current: root.procSort
            model: [
                {
                    id: "cpu",
                    name: "Procesador"
                },
                {
                    id: "mem",
                    name: "Memoria"
                }
            ]
            onPicked: id => root.procSort = id
        }

        Repeater {
            model: Seguridad.top[root.procSort] ?? []

            RowLayout {
                id: procRow

                required property var modelData
                readonly property bool asking: root.confirmClose === modelData.name

                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: procRow.modelData.label
                        elide: Text.ElideRight
                        color: Theme.text
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: procRow.modelData.count + (procRow.modelData.count === 1 ? " proceso" : " procesos") + " · " + (root.procSort === "cpu" ? root.gb(procRow.modelData.mem) : procRow.modelData.cpu + " %")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontTiny
                    }
                }

                Text {
                    text: root.procSort === "cpu" ? procRow.modelData.cpu + " %" : root.gb(procRow.modelData.mem)
                    color: Theme.text
                    font.pixelSize: Theme.fontSmall
                    font.family: "monospace"
                }

                // Cerrar: el primer clic pregunta, el segundo cierra
                Rectangle {
                    visible: procRow.modelData.closable
                    implicitWidth: procRow.asking ? askText.implicitWidth + 14 : 24
                    implicitHeight: 24
                    radius: 6
                    color: procRow.asking ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25) : (killHover.hovered ? Theme.hover : "transparent")

                    MIcon {
                        visible: !procRow.asking
                        anchors.centerIn: parent
                        name: "close"
                        font.pixelSize: Theme.iconSm
                        color: Theme.textDim
                    }

                    Text {
                        id: askText

                        visible: procRow.asking
                        anchors.centerIn: parent
                        text: "¿Cerrar?"
                        color: Theme.danger
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: killHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            if (procRow.asking) {
                                Seguridad.close(procRow.modelData.name);
                                root.confirmClose = "";
                            } else {
                                root.confirmClose = procRow.modelData.name;
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: Seguridad.message !== ""
            text: Seguridad.message
            color: Theme.accent
            font.pixelSize: Theme.fontCaption
        }
    }
}
