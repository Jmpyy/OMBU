import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Calendario mensual con agenda: flechas para cambiar de mes (la rueda también), el mes/año
// vuelve a hoy, el número de semana a la izquierda, puntos de colores bajo los días (feriado,
// evento propio, Google, día de estudio) y debajo el detalle del día elegido, para anotar
// eventos con recordatorio, y lo que viene.
DropPopup {
    id: root

    // Primer día del mes que se está mostrando
    property date viewDate: new Date(Chrono.date.getFullYear(), Chrono.date.getMonth(), 1)
    property date pendingDate: viewDate
    property int direction: 1
    // Animación del cambio de mes
    property real shiftX: 0
    property real fade: 1

    // Día elegido ("yyyy-MM-dd")
    property string selected: Agenda.ymd(Chrono.date)
    property bool showSettings: false

    readonly property int month: viewDate.getMonth()
    readonly property int year: viewDate.getFullYear()
    readonly property bool isCurrentMonth: month === Chrono.date.getMonth() && year === Chrono.date.getFullYear()

    function goTo(date: date): void {
        pendingDate = new Date(date.getFullYear(), date.getMonth(), 1);
        direction = pendingDate > viewDate ? 1 : -1;
        monthChange.restart();
    }

    function shiftMonth(delta: int): void {
        const base = monthChange.running ? pendingDate : viewDate;
        goTo(new Date(base.getFullYear(), base.getMonth() + delta, 1));
    }

    function today(): void {
        goTo(Chrono.date);
        selected = Agenda.ymd(Chrono.date);
    }

    function pick(date: date): void {
        selected = Agenda.ymd(date);
        if (date.getMonth() !== month || date.getFullYear() !== year)
            goTo(date);
    }

    // Semana ISO de una fecha
    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        const start = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - start) / 86400000 + 1) / 7);
    }

    // Primer día que muestra la grilla (la semana en que cae el 1 del mes)
    function gridStart(): date {
        const first = new Date(year, month, 1);
        const fdow = Chrono.locale.firstDayOfWeek % 7;
        return new Date(year, month, 1 - (first.getDay() - fdow + 7) % 7);
    }

    function dayLabel(day: string): string {
        const d = Agenda.parseDay(day);
        const label = Chrono.capitalize(d.toLocaleDateString(Chrono.locale, "dddd d 'de' MMMM"));
        return day === Agenda.ymd(Chrono.date) ? label + " · hoy" : label;
    }

    function whenLabel(day: string): string {
        const diff = Math.round((Agenda.parseDay(day) - Agenda.parseDay(Agenda.ymd(Chrono.date))) / 86400000);
        if (diff === 0)
            return "Hoy";
        if (diff === 1)
            return "Mañana";
        return Chrono.capitalize(Agenda.parseDay(day).toLocaleDateString(Chrono.locale, "ddd d MMM")).replace(".", "");
    }

    function submitEvent(): void {
        Agenda.add(selected, timeInput.text, titleInput.text, "", [0], undefined);
        titleInput.text = "";
        timeInput.text = "";
    }

    onOpenChanged: if (open) {
        monthChange.stop();
        shiftX = 0;
        fade = 1;
        viewDate = new Date(Chrono.date.getFullYear(), Chrono.date.getMonth(), 1);
        selected = Agenda.ymd(Chrono.date);
        showSettings = false;
        Agenda.refreshApiStatus();
        Focus.recordHistory();
        Agenda.refreshGoogle(false);
    }

    centered: true
    bodyWidth: 372
    bodyHeight: column.implicitHeight + 24

    SequentialAnimation {
        id: monthChange

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "shiftX"
                to: -root.direction * 22
                duration: 90
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root
                property: "fade"
                to: 0
                duration: 90
            }
        }
        ScriptAction {
            script: {
                root.viewDate = root.pendingDate;
                root.shiftX = root.direction * 22;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "shiftX"
                to: 0
                duration: Theme.popupDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "fade"
                to: 1
                duration: Theme.popupDuration
            }
        }
    }

    // La rueda cambia de mes sin interferir con los clics
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => root.shiftMonth(wheel.angleDelta.y > 0 ? -1 : 1)
    }


    ColumnLayout {
        id: column

        x: 16
        y: 2
        width: root.bodyWidth - 32
        spacing: 8

        // Fecha de hoy y ajustes de Google Calendar
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: Chrono.capitalize(Chrono.date.toLocaleDateString(Chrono.locale, "dddd d 'de' MMMM"))
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Rectangle {
                visible: Agenda.googleOn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: syncHover.hovered ? Theme.hover : "transparent"

                MIcon {
                    id: syncIcon

                    anchors.centerIn: parent
                    name: "sync"
                    font.pixelSize: 18
                    color: Agenda.googleError !== "" ? Theme.danger : Theme.textDim

                    RotationAnimator on rotation {
                        running: Agenda.googleLoading
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }

                HoverHandler {
                    id: syncHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: Agenda.refreshGoogle(true)
                }
            }

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: root.showSettings ? Theme.surface : (gearHover.hovered ? Theme.hover : "transparent")

                MIcon {
                    anchors.centerIn: parent
                    name: "event_note"
                    font.pixelSize: 18
                    color: Agenda.googleOn ? Agenda.googleColor : Theme.textDim
                }

                HoverHandler {
                    id: gearHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.showSettings = !root.showSettings
                }
            }
        }

        // Conectar Google Calendar: por la API (lee y escribe) o por la dirección iCal (solo lectura)
        Rectangle {
            visible: root.showSettings
            Layout.fillWidth: true
            implicitHeight: googleBox.implicitHeight + 20
            radius: Theme.controlRadius
            color: Theme.surface

            ColumnLayout {
                id: googleBox

                readonly property bool icalOn: Agenda.googleUrl !== "" && !Agenda.apiConnected

                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: Agenda.apiConnected ? "Google Calendar conectado" : (googleBox.icalOn ? "Google Calendar conectado (solo lectura)" : "Conectar Google Calendar")
                    color: Agenda.googleOn ? Agenda.googleColor : Theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Agenda.apiError !== "" ? Agenda.apiError : Agenda.googleError
                    wrapMode: Text.Wrap
                    color: Theme.danger
                    font.pixelSize: 11
                }

                Text {
                    Layout.fillWidth: true
                    visible: Agenda.apiConnected
                    text: "Lo que anotes puede ir a Google y verse en tu celular. Los eventos de Google se actualizan cada 5 minutos."
                    wrapMode: Text.Wrap
                    color: Theme.textDim
                    font.pixelSize: 11
                }

                // Con credenciales guardadas: un botón abre el navegador para dar permiso
                Text {
                    Layout.fillWidth: true
                    visible: !Agenda.apiConnected && Agenda.apiClient
                    text: "Se abre el navegador para que des permiso. Después podés anotar eventos desde ombu y verlos en el celular."
                    wrapMode: Text.Wrap
                    color: Theme.textDim
                    font.pixelSize: 11
                }

                Rectangle {
                    visible: !Agenda.apiConnected && Agenda.apiClient
                    implicitWidth: connectText.implicitWidth + 28
                    implicitHeight: 30
                    radius: 15
                    color: Agenda.apiAuthing ? Theme.track : Theme.accent

                    Text {
                        id: connectText

                        anchors.centerIn: parent
                        text: Agenda.apiAuthing ? "Esperando el permiso en el navegador…" : "Conectar con Google"
                        color: Agenda.apiAuthing ? Theme.textDim : "#14131a"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    TapHandler {
                        onTapped: Agenda.connectApi()
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Sin credenciales: dónde conseguirlas
                Text {
                    Layout.fillWidth: true
                    visible: !Agenda.apiConnected && !Agenda.apiClient
                    text: "Para leer y escribir en tu Google Calendar hace falta crear unas credenciales en la consola de Google (pasos en docs/google-calendar.md) y guardar el archivo como ~/.local/share/ombu/google-client.json."
                    wrapMode: Text.Wrap
                    color: Theme.textDim
                    font.pixelSize: 11
                }

                Rectangle {
                    visible: Agenda.apiConnected
                    implicitWidth: disconnectText.implicitWidth + 24
                    implicitHeight: 28
                    radius: 14
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.danger

                    Text {
                        id: disconnectText

                        anchors.centerIn: parent
                        text: "Desconectar"
                        color: Theme.danger
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    TapHandler {
                        onTapped: {
                            Agenda.disconnectApi();
                            root.showSettings = false;
                        }
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Alternativa de solo lectura: la dirección secreta en formato iCal
                Text {
                    Layout.fillWidth: true
                    visible: !Agenda.apiConnected && Agenda.googleUrl === ""
                    text: "O, solo para ver: pegá la «dirección secreta en formato iCal» de tu calendario y Enter."
                    wrapMode: Text.Wrap
                    color: Theme.textDim
                    font.pixelSize: 11
                }

                Rectangle {
                    visible: !Agenda.apiConnected && Agenda.googleUrl === ""
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 10
                    color: Theme.bg

                    TextInput {
                        id: urlInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: "#14131a"
                        font.pixelSize: 12
                        clip: true
                        onAccepted: {
                            Agenda.setUrl(text);
                            text = "";
                        }

                        Text {
                            visible: urlInput.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "https://calendar.google.com/…/basic.ics"
                            color: Theme.textDim
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle {
                    visible: googleBox.icalOn
                    implicitWidth: disconnectIcalText.implicitWidth + 24
                    implicitHeight: 28
                    radius: 14
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.danger

                    Text {
                        id: disconnectIcalText

                        anchors.centerIn: parent
                        text: "Desconectar"
                        color: Theme.danger
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    TapHandler {
                        onTapped: {
                            Agenda.setUrl("");
                            root.showSettings = false;
                        }
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: prevHover.hovered ? Theme.hover : "transparent"

                MIcon {
                    anchors.centerIn: parent
                    name: "chevron_left"
                }

                HoverHandler {
                    id: prevHover
                }
                TapHandler {
                    onTapped: root.shiftMonth(-1)
                }
            }

            // Mes y año: un clic vuelve al mes actual
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: height / 2
                color: !root.isCurrentMonth && monthHover.hovered ? Theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    opacity: root.fade
                    transform: Translate {
                        x: root.shiftX
                    }
                    text: Chrono.capitalize(Chrono.locale.monthName(root.month, Locale.LongFormat)) + " " + root.year
                    color: Theme.accent
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                HoverHandler {
                    id: monthHover

                    cursorShape: root.isCurrentMonth ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
                TapHandler {
                    enabled: !root.isCurrentMonth
                    onTapped: root.today()
                }
            }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: nextHover.hovered ? Theme.hover : "transparent"

                MIcon {
                    anchors.centerIn: parent
                    name: "chevron_right"
                }

                HoverHandler {
                    id: nextHover
                }
                TapHandler {
                    onTapped: root.shiftMonth(1)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.preferredWidth: 26
                horizontalAlignment: Text.AlignHCenter
                text: "Sem"
                color: Theme.track
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: Chrono.locale

                delegate: Text {
                    required property var model

                    horizontalAlignment: Text.AlignHCenter
                    text: Chrono.capitalize(model.shortName).replace(".", "")
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    // Sábado y domingo
                    color: model.day === 0 || model.day === 6 ? Theme.accent : Theme.textDim
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 38
            spacing: 0

            // Número de semana de cada fila
            Column {
                Layout.preferredWidth: 26
                Layout.alignment: Qt.AlignTop
                spacing: 2
                opacity: root.fade

                Repeater {
                    model: 6

                    Text {
                        required property int index

                        width: 26
                        height: 36
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: {
                            const g = root.gridStart();
                            return root.isoWeek(new Date(g.getFullYear(), g.getMonth(), g.getDate() + index * 7 + 3));
                        }
                        color: Theme.track
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: root.fade
                transform: Translate {
                    x: root.shiftX
                }

                MonthGrid {
                    id: grid

                    anchors.fill: parent
                    month: root.month
                    year: root.year
                    locale: Chrono.locale
                    spacing: 2

                    delegate: Item {
                        id: day

                        required property var model
                        readonly property bool inMonth: model.month === grid.month
                        readonly property bool isWeekend: model.date.getDay() === 0 || model.date.getDay() === 6
                        readonly property string key: Agenda.ymd(model.date)
                        readonly property var marks: Agenda.byDay[key] ?? ({})
                        readonly property bool selected: key === root.selected

                        implicitWidth: 38
                        implicitHeight: 36

                        Rectangle {
                            anchors.centerIn: parent
                            width: 34
                            height: 34
                            radius: 17
                            color: day.model.today ? Theme.accent : (dayHover.hovered && day.inMonth ? Theme.hover : "transparent")
                            border.width: day.selected && !day.model.today ? 1.5 : 0
                            border.color: Theme.accent
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            text: day.model.day
                            font.pixelSize: 13
                            font.weight: day.model.today ? Font.Bold : Font.Normal
                            color: day.model.today ? "#14131a" : (!day.inMonth ? Theme.track : (day.marks.holiday ? Agenda.holidayColor : (day.isWeekend ? Theme.accent : Theme.text)))
                        }

                        // Puntos: evento propio, Google y día de estudio
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 25
                            spacing: 3
                            visible: day.inMonth

                            Repeater {
                                model: [
                                    {
                                        on: day.marks.local,
                                        color: Agenda.localColor
                                    },
                                    {
                                        on: day.marks.google,
                                        color: Agenda.googleColor
                                    },
                                    {
                                        on: day.marks.study,
                                        color: Agenda.studyColor
                                    }
                                ].filter(d => d.on)

                                Rectangle {
                                    required property var modelData

                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: day.model.today ? "#14131a" : modelData.color
                                }
                            }
                        }

                        HoverHandler {
                            id: dayHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: root.pick(day.model.date)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // El día elegido
        Text {
            Layout.fillWidth: true
            text: root.dayLabel(root.selected)
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Estudio del día (modo foco)
            RowLayout {
                visible: Agenda.studyMinutes(root.selected) >= 5
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Agenda.studyColor
                }

                Text {
                    Layout.fillWidth: true
                    text: "Estudiaste " + Focus.minutesText(Agenda.studyMinutes(root.selected) * 60)
                    color: Theme.textDim
                    font.pixelSize: 12
                }
            }

            Repeater {
                model: Agenda.itemsFor(root.selected).slice(0, 5)

                Rectangle {
                    id: item

                    required property var modelData
                    readonly property color tone: modelData.kind === "holiday" ? Agenda.holidayColor : (modelData.kind === "google" ? Agenda.googleColor : Agenda.localColor)

                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 9
                    color: itemHover.hovered ? Theme.surface : "transparent"

                    HoverHandler {
                        id: itemHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 8

                        // Los propios se tildan; el resto lleva un punto del color de su origen
                        Item {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16

                            Rectangle {
                                visible: item.modelData.kind !== "local"
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
                                color: item.tone
                            }

                            Rectangle {
                                visible: item.modelData.kind === "local"
                                anchors.fill: parent
                                radius: 8
                                color: item.modelData.done ? item.tone : "transparent"
                                border.width: 1.5
                                border.color: item.tone

                                MIcon {
                                    visible: item.modelData.done === true
                                    anchors.centerIn: parent
                                    name: "check"
                                    font.pixelSize: 12
                                    color: "#14131a"
                                }

                                TapHandler {
                                    onTapped: Agenda.toggle(item.modelData.id)
                                }
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }

                        Text {
                            visible: item.modelData.time !== ""
                            text: item.modelData.time
                            color: Theme.textDim
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.modelData.title
                            elide: Text.ElideRight
                            color: item.modelData.done ? Theme.textDim : Theme.text
                            font.pixelSize: 13
                            font.strikeout: item.modelData.done === true
                        }

                        // Entrar a la clase o reunión de Meet
                        MIcon {
                            visible: item.modelData.meet !== undefined && item.modelData.meet !== ""
                            name: "videocam"
                            font.pixelSize: 17
                            color: Agenda.googleColor

                            TapHandler {
                                onTapped: Quickshell.execDetached(["xdg-open", item.modelData.meet])
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        // Borrar: los propios y los que creó ombu en Google (los ajenos no)
                        MIcon {
                            visible: (item.modelData.kind === "local" || item.modelData.mine === true) && itemHover.hovered
                            name: "close"
                            font.pixelSize: 16
                            color: Theme.textDim

                            TapHandler {
                                onTapped: item.modelData.kind === "local" ? Agenda.remove(item.modelData.id) : Agenda.removeGoogle(item.modelData.calendarId, item.modelData.id)
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            Text {
                visible: Agenda.itemsFor(root.selected).length > 5
                text: "+" + (Agenda.itemsFor(root.selected).length - 5) + " más"
                color: Theme.textDim
                font.pixelSize: 11
                Layout.leftMargin: 4
            }

            Text {
                visible: Agenda.itemsFor(root.selected).length === 0 && Agenda.studyMinutes(root.selected) < 5
                text: "Nada anotado"
                color: Theme.textDim
                font.pixelSize: 12
                Layout.leftMargin: 4
            }
        }

        // Anotar algo para el día elegido: título, hora opcional y Enter
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.controlRadius
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 8

                MIcon {
                    name: "add"
                    font.pixelSize: 18
                    color: Theme.textDim
                }

                TextInput {
                    id: titleInput

                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: "#14131a"
                    font.pixelSize: 13
                    clip: true
                    onAccepted: root.submitEvent()

                    Text {
                        visible: titleInput.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Anotar algo para este día"
                        color: Theme.textDim
                        font.pixelSize: 13
                    }
                }

                // Destino: Google (se ve en el celular) o solo en ombu
                Rectangle {
                    visible: Agenda.apiConnected
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: Agenda.createInGoogle ? Qt.rgba(Agenda.googleColor.r, Agenda.googleColor.g, Agenda.googleColor.b, 0.2) : Theme.bg

                    MIcon {
                        anchors.centerIn: parent
                        name: Agenda.createInGoogle ? "cloud" : "cloud_off"
                        font.pixelSize: 16
                        color: Agenda.createInGoogle ? Agenda.googleColor : Theme.textDim
                    }

                    TapHandler {
                        onTapped: Agenda.setCreateInGoogle(!Agenda.createInGoogle)
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 26
                    radius: 8
                    color: Theme.bg

                    TextInput {
                        id: timeInput

                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: "#14131a"
                        font.pixelSize: 12
                        maximumLength: 5
                        clip: true
                        onAccepted: root.submitEvent()

                        Text {
                            visible: timeInput.text === ""
                            anchors.centerIn: parent
                            text: "hh:mm"
                            color: Theme.textDim
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // Lo que viene
        ColumnLayout {
            visible: upcomingList.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 2

            readonly property var upcomingList: Agenda.upcoming(4)

            Text {
                text: "PRÓXIMOS"
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Repeater {
                model: Agenda.upcoming(4)

                Rectangle {
                    id: next

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 9
                    color: nextItemHover.hovered ? Theme.surface : "transparent"

                    HoverHandler {
                        id: nextItemHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.pick(Agenda.parseDay(next.modelData.day))
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: next.modelData.kind === "google" ? Agenda.googleColor : Agenda.localColor
                        }

                        Text {
                            Layout.preferredWidth: 100
                            text: root.whenLabel(next.modelData.day) + (next.modelData.time !== "" ? " " + next.modelData.time : "")
                            color: Theme.textDim
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: next.modelData.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
