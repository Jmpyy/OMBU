import QtQuick
import QtTest

// Los controles reales de los menús, manejados con el teclado simulado (con Theme de mentira, ver stub/).
// Prueba lo que no se puede probar a mano sin teclado: Enter, Espacio y las flechas.
Item {
    width: 400
    height: 400

    MenuRow {
        id: row

        width: 300
        text: "Fila"
        property int clicks: 0
        onClicked: clicks++
    }

    ToggleSwitch {
        id: sw

        y: 40
        property int toggles: 0
        onToggled: toggles++
    }

    Segmented {
        id: seg

        y: 80
        width: 300
        current: "a"
        model: [{ id: "a", name: "A" }, { id: "b", name: "B" }, { id: "c", name: "C" }]
        onPicked: id => current = id
    }

    PillSlider {
        id: slider

        y: 120
        width: 300
        label: "Volumen"
        value: 0.5
        onMoved: v => value = v
    }

    MixerSlider {
        id: mix

        y: 170
        width: 300
        value: 0.98
        onMoved: v => value = v
    }

    TestCase {
        name: "Controles"
        when: windowShown

        function test_fila_se_activa_con_enter_y_espacio() {
            row.forceActiveFocus();
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Space);
            keyClick(Qt.Key_Enter);
            compare(row.clicks, 3);
        }

        function test_fila_enfocada_se_resalta() {
            row.forceActiveFocus();
            compare(row.color, Theme.surface);
        }

        function test_fila_entra_en_el_recorrido_con_tab() {
            verify(row.activeFocusOnTab);
            verify(sw.activeFocusOnTab);
            verify(seg.activeFocusOnTab);
            verify(slider.activeFocusOnTab);
        }

        function test_interruptor() {
            sw.forceActiveFocus();
            keyClick(Qt.Key_Space);
            keyClick(Qt.Key_Return);
            compare(sw.toggles, 2);
        }

        function test_segmentado_con_flechas_y_sus_bordes() {
            seg.current = "a";
            seg.forceActiveFocus();
            keyClick(Qt.Key_Left);
            compare(seg.current, "a", "en el primero, ← no hace nada");
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Right);
            compare(seg.current, "c");
            keyClick(Qt.Key_Right);
            compare(seg.current, "c", "en el último, → no hace nada");
        }

        function test_slider_de_a_cinco_por_ciento() {
            slider.value = 0.5;
            slider.forceActiveFocus();
            keyClick(Qt.Key_Right);
            fuzzyCompare(slider.value, 0.55, 1e-9);
            keyClick(Qt.Key_Left);
            keyClick(Qt.Key_Left);
            fuzzyCompare(slider.value, 0.45, 1e-9);
        }

        function test_slider_no_se_pasa_de_los_limites() {
            mix.value = 0.98;
            mix.forceActiveFocus();
            keyClick(Qt.Key_Right);
            compare(mix.value, 1, "no pasa de 100 %");
            slider.value = 0.02;
            slider.forceActiveFocus();
            keyClick(Qt.Key_Left);
            compare(slider.value, 0, "no baja de 0 %");
        }
    }
}
