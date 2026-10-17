import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Calendario mensual: flechas para cambiar de mes, el mes/año vuelve a hoy,
// la rueda del mouse también cambia de mes.
DropPopup {
    id: root

    // Primer día del mes que se está mostrando
    property date viewDate: new Date(Chrono.date.getFullYear(), Chrono.date.getMonth(), 1)
    property date pendingDate: viewDate
    property int direction: 1
    // Animación del cambio de mes
    property real shiftX: 0
    property real fade: 1

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
    }

    onOpenChanged: if (open) {
        monthChange.stop();
        shiftX = 0;
        fade = 1;
        viewDate = new Date(Chrono.date.getFullYear(), Chrono.date.getMonth(), 1);
    }

    centered: true
    bodyWidth: 330
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

        // Fecha de hoy
        Text {
            Layout.fillWidth: true
            text: Chrono.capitalize(Chrono.date.toLocaleDateString(Chrono.locale, "dddd d 'de' MMMM"))
            color: Theme.text
            font.pixelSize: 15
            font.weight: Font.DemiBold
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

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 38
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

                    implicitWidth: 38
                    implicitHeight: 36

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        radius: 17
                        color: day.model.today ? Theme.accent : (dayHover.hovered && day.inMonth ? Theme.hover : "transparent")
                    }

                    Text {
                        anchors.centerIn: parent
                        text: day.model.day
                        font.pixelSize: 13
                        font.weight: day.model.today ? Font.Bold : Font.Normal
                        color: day.model.today ? "#14131a" : (!day.inMonth ? Theme.track : (day.isWeekend ? Theme.accent : Theme.text))
                    }

                    HoverHandler {
                        id: dayHover
                    }
                }
            }
        }
    }
}
