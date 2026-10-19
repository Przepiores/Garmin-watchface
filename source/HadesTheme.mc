import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Hades theme (the first game), "Zagreus": a huge hour on the left, the minutes in a gold obol on the right.
//!  - the step meter is a laurel branch up the left edge: 15 stations with two leaves each, lit gold in turn (each station = 1/15 of the goal);
//!  - the battery is Zagreus' HP bar on the right edge: red on a dark track in a gold frame, filled from the bottom;
//!  - a red bead rides the obol on the current minute;
//!  - the background is a flat, cel-shaded Underworld: stepped sky, two rock ridges, a Greek tower, a lava lake with veins and a few embers.
//!    It lives in resources/json/hades_bg.json as ordered draw ops (rectangles, convex polygon pieces, polylines, dots).
//! Geometry is given in 454 px units and multiplied by _scale.
class HadesTheme extends ThemeBase {

    // ── Palette ──────────────────────────────────────────────────────
    private const COLOR_RED       = 0xE0323F;
    private const COLOR_RED_HI    = 0xFF6B73;
    private const COLOR_RED_M     = 0x9E1B27;   // blood: the hour's shadow
    private const COLOR_RED_DD    = 0x230A0E;   // HP track
    private const COLOR_GOLD      = 0xE8B551;
    private const COLOR_GOLD_HEAD = 0xFFD982;   // the newest lit leaf
    private const COLOR_GOLD_M    = 0xB8862F;
    private const COLOR_GOLD_D    = 0x6B4E1C;
    private const COLOR_CREAM     = 0xF6EAD0;
    private const COLOR_INK       = 0x1E0E08;
    private const COLOR_LEAF_OFF  = 0x3A1319;
    private const COLOR_AOD_HOUR  = 0x8A7C66;
    private const COLOR_AOD_RING  = 0x8A6A28;
    private const COLOR_AOD_MIN   = 0xA27C2C;
    private const COLOR_AOD_LAUR  = 0x4A3610;
    private const COLOR_AOD_HP    = 0x5A1B20;

    // ── Layout, 454 px units ─────────────────────────────────────────
    private const LAUREL_R        = 196;
    private const LAUREL_N        = 15;
    private const LAUREL_A0       = 262;   // first station (bottom), watch angle: 0 = 3 o'clock, counter-clockwise
    private const LAUREL_A1       = 118;   // last station (top left)
    private const HP_R            = 204;
    private const HP_FROM         = 314;   // -46 degrees
    private const HP_TO           = 46;
    private const HOUR_X          = 160;
    private const HOUR_BASELINE   = 262;
    private const OBOL_X          = 330;
    private const OBOL_Y          = 262;
    private const AOD_SCALE       = 0.9;   // smaller in AOD so the burn-in shift never pushes the ring off screen
    private const EM_PRIDI        = 1.35;  // vector font size (line height) per em, measured on the simulator
    private const EM_CONDENSED    = 1.172;
    private const EM_SWISS        = 1.0;

    private var _fHour as Graphics.VectorFont or Null = null;   // Pridi, 156 em
    private var _fMin  as Graphics.VectorFont or Null = null;   // Roboto Condensed Bold, 52 em
    private var _fVal  as Graphics.VectorFont or Null = null;   // 30 em
    private var _fLab  as Graphics.VectorFont or Null = null;   // 14 em
    private var _fSm   as Graphics.VectorFont or Null = null;   // 16 em

    private var _steps as Number = 0;
    private var _goal  as Number = 10000;
    private var _lit   as Number = -1;   // laurel stations lit in the static buffer

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_GOLD_M;
        _colorSecondary = COLOR_CREAM;
        _colorAccent    = COLOR_GOLD;
        _colorDim       = COLOR_GOLD_D;
        _colorAlert     = COLOR_RED;
        _colorTime      = COLOR_CREAM;
    }

    // ================================================================
    //  RESOURCES - fonts exist only while the theme is active
    // ================================================================

    public function loadResources() as Void {
        refreshState();
        _fHour = makeFont(156, ["PridiRegularGarmin", "RobotoCondensedBold"], EM_PRIDI);
        _fMin  = makeFont(52, ["RobotoCondensedBold", "Swiss721Bold"], EM_CONDENSED);
        _fVal  = makeFont(30, ["Swiss721Regular", "RobotoCondensedBold"], EM_SWISS);
        _fLab  = makeFont(14, ["Swiss721Regular", "RobotoCondensedBold"], EM_SWISS);
        _fSm   = makeFont(16, ["Swiss721Regular", "RobotoCondensedBold"], EM_SWISS);
        ThemeBase.loadResources();
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _fHour = null;
        _fMin = null;
        _fVal = null;
        _fLab = null;
        _fSm = null;
        _lit = -1;
    }

    //! px is the em size; a Garmin vector font is sized by line height, which is `factor` em for the face.
    private function makeFont(px as Number, faces as Array, factor as Float) as Graphics.VectorFont or Null {
        if (Graphics has :getVectorFont) {
            try {
                return Graphics.getVectorFont({
                    :face => faces,
                    :size => (px * factor * _scale + 0.5).toNumber()
                });
            } catch (e) {}
        }
        return null;
    }

    // ================================================================
    //  STEP METER - the number of lit laurel stations lives in the static buffer
    // ================================================================

    private function refreshState() as Void {
        var info = ActivityMonitor.getInfo();
        _steps = 0;
        _goal = 10000;
        if (info != null) {
            if (info.steps != null) { _steps = info.steps; }
            if (info.stepGoal != null) { _goal = info.stepGoal; }
        }
        if (_goal <= 0) { _goal = 10000; }
        var stations = (_steps * LAUREL_N + _goal / 2) / _goal;
        _lit = (stations > LAUREL_N) ? LAUREL_N : stations;
    }

    //! Re-render the static buffer only when the number of lit stations changes (at most 15 times a day).
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        var previous = _lit;
        refreshState();
        if (_lit != previous) {
            renderStaticBuffer();
        }
        ThemeBase.drawStaticLayer(dc);
    }

    //! The laurel replaces the progress arc of ThemeBase.
    public function drawProgressArc(dc as Graphics.Dc) as Void {}

    // ================================================================
    //  STATIC LAYER - Underworld backdrop, laurel, HP frame, obol
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        drawBackdrop(dc);
        drawLaurel(dc);
        drawHpFrame(dc);
        drawObol(dc);
    }

    //! Replays the ops of hades_bg.json: [type, colour, pen width, ...coordinates]; type 0 = rectangle (x, y, w, h), 1 = convex polygon,
    //! 2 = polyline, 3 = dot (x, y, radius * 10). Shapes run past the screen edge on purpose; the display clips them.
    private function drawBackdrop(dc as Graphics.Dc) as Void {
        var s = _scale;
        var data = WatchUi.loadResource(Rez.JsonData.HadesBg) as Dictionary;
        var ops = data["ops"] as Array;
        for (var i = 0; i < ops.size(); i++) {
            var op = ops[i] as Array<Number>;
            var type = op[0];
            dc.setColor(op[1], Graphics.COLOR_TRANSPARENT);
            if (type == 0) {
                dc.fillRectangle(op[3] * s, op[4] * s, op[5] * s, op[6] * s);
            } else if (type == 1) {
                var pts = [];
                for (var j = 3; j + 1 < op.size(); j += 2) {
                    pts.add([op[j] * s, op[j + 1] * s]);
                }
                dc.fillPolygon(pts);
            } else if (type == 2) {
                dc.setPenWidth(px(op[2]));
                for (var j = 3; j + 3 < op.size(); j += 2) {
                    dc.drawLine(op[j] * s, op[j + 1] * s, op[j + 2] * s, op[j + 3] * s);
                }
            } else {
                dc.fillCircle(op[3] * s, op[4] * s, op[5] / 10.0 * s);
            }
        }
    }

    //! Laurel branch: a track along the left edge and, at each station, an outer and an inner leaf; lit stations are gold.
    private function drawLaurel(dc as Graphics.Dc) as Void {
        var s = _scale;
        var step = (LAUREL_A0 - LAUREL_A1) / (LAUREL_N - 1.0);
        dc.setPenWidth(px(2));
        dc.setColor(COLOR_GOLD_D, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, LAUREL_R * s, Graphics.ARC_CLOCKWISE, 268, 112);
        if (_lit > 0) {
            dc.setColor(COLOR_GOLD_M, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(_centerX, _centerY, LAUREL_R * s, Graphics.ARC_CLOCKWISE, 268, LAUREL_A0 - (_lit - 1) * step);
        }
        var ca = 0.76604444;   // cos 40 degrees: the leaves leave the branch at 40 degrees
        var sa = 0.64278761;
        for (var k = 0; k < LAUREL_N; k++) {
            var ar = (LAUREL_A0 - k * step) * Math.PI / 180.0;
            var x = _centerX + LAUREL_R * s * Math.cos(ar);
            var y = _centerY - LAUREL_R * s * Math.sin(ar);
            var tx = Math.sin(ar);
            var ty = Math.cos(ar);
            var nx = Math.cos(ar);
            var ny = -Math.sin(ar);
            var len = (29 - 9 * k / (LAUREL_N - 1.0)) * s;
            var wid = (12 - 3 * k / (LAUREL_N - 1.0)) * s;
            var color = COLOR_LEAF_OFF;
            if (k < _lit) { color = (k == _lit - 1) ? COLOR_GOLD_HEAD : COLOR_GOLD; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            leaf(dc, x, y, tx * ca + nx * sa, ty * ca + ny * sa, len, wid);
            leaf(dc, x, y, tx * ca - nx * sa, ty * ca - ny * sa, len, wid);
        }
    }

    //! Kite-shaped leaf from (x, y) along the unit vector (dx, dy): length len, width wid.
    private function leaf(dc as Graphics.Dc, x as Float, y as Float, dx as Float, dy as Float, len as Float, wid as Float) as Void {
        var qx = -dy * wid / 2;
        var qy = dx * wid / 2;
        var mx = x + dx * 0.42 * len;
        var my = y + dy * 0.42 * len;
        dc.fillPolygon([[x, y], [mx + qx, my + qy], [x + dx * len, y + dy * len], [mx - qx, my - qy]]);
    }

    //! HP bar frame on the right edge: dark track, two thin gold rails and a gold rhombus at each end. The red fill is dynamic.
    private function drawHpFrame(dc as Graphics.Dc) as Void {
        var s = _scale;
        dc.setPenWidth(px(11));
        dc.setColor(COLOR_RED_DD, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, HP_R * s, Graphics.ARC_COUNTER_CLOCKWISE, HP_FROM, HP_TO);
        dc.setPenWidth(1);
        dc.setColor(COLOR_GOLD_M, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, (HP_R + 6.8) * s, Graphics.ARC_COUNTER_CLOCKWISE, HP_FROM - 1, HP_TO + 1);
        dc.drawArc(_centerX, _centerY, (HP_R - 6.8) * s, Graphics.ARC_COUNTER_CLOCKWISE, HP_FROM - 1, HP_TO + 1);
        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        rhomb(dc, -49);
        rhomb(dc, 49);
    }

    //! Rhombus 14 x 9 on the HP track at watch angle `deg`, long axis along the angle.
    private function rhomb(dc as Graphics.Dc, deg as Number) as Void {
        var s = _scale;
        var a = deg * Math.PI / 180.0;
        var x = _centerX + HP_R * s * Math.cos(a);
        var y = _centerY - HP_R * s * Math.sin(a);
        var ux = Math.cos(a) * 7 * s;
        var uy = -Math.sin(a) * 7 * s;
        var vx = -uy * 4.5 / 7;
        var vy = ux * 4.5 / 7;
        dc.fillPolygon([[x + ux, y + uy], [x + vx, y + vy], [x - ux, y - uy], [x - vx, y - vy]]);
    }

    //! The gold obol that holds the minutes: rim, face, inner ring and 12 hour dots around it.
    private function drawObol(dc as Graphics.Dc) as Void {
        var s = _scale;
        var cx = OBOL_X * s;
        var cy = OBOL_Y * s;
        dc.setColor(COLOR_GOLD_M, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 52 * s);
        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 47 * s);
        dc.setPenWidth(px(1.5));
        dc.setColor(COLOR_GOLD_D, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, 47 * s);
        dc.setPenWidth(1);
        dc.setColor(COLOR_GOLD_M, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, 40 * s);
        dc.setColor(COLOR_GOLD_D, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var a = (90 - 30 * i) * Math.PI / 180.0;
            dc.fillCircle(cx + 62 * s * Math.cos(a), cy - 62 * s * Math.sin(a), 1.8 * s);
        }
    }

    //! A length in 454 px units as device pixels, never below 1.
    private function px(v as Numeric) as Number {
        var p = (v * _scale + 0.5).toNumber();
        return (p < 1) ? 1 : p;
    }

    // ================================================================
    //  DYNAMIC LAYER - time, fields, HP fill
    // ================================================================

    //! Hour on the left with a blood shadow; minutes in the obol; a red bead on the obol at the current minute.
    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var s = _scale;
        var hourStr = time.hour.format("%02d");
        var minStr = time.min.format("%02d");
        var font = pick(_fHour, Graphics.FONT_NUMBER_HOT);
        dc.setColor(COLOR_RED_M, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, (HOUR_X + 4) * s, (HOUR_BASELINE + 4) * s, font, hourStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_CREAM, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, HOUR_X * s, HOUR_BASELINE * s, font, hourStr, Graphics.TEXT_JUSTIFY_CENTER, 0);

        dc.setColor(COLOR_INK, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, OBOL_X * s, (OBOL_Y + 17) * s, pick(_fMin, Graphics.FONT_NUMBER_MEDIUM), minStr, Graphics.TEXT_JUSTIFY_CENTER, 0);

        var a = (90 - 6 * time.min) * Math.PI / 180.0;
        var bx = (OBOL_X + 62 * Math.cos(a)) * s;
        var by = (OBOL_Y - 62 * Math.sin(a)) * s;
        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 8 * s);
        dc.setColor(COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 6.5 * s);
    }

    //! The four fields: temperature and altitude on top, steps and date below.
    public function drawDataFields(dc as Graphics.Dc) as Void {
        drawField(dc, _fieldTopLeft, 124, 104);
        drawField(dc, _fieldTopRight, 318, 104);
        drawField(dc, _fieldBottomLeft, 140, 338);
        drawField(dc, _fieldBottomRight, 298, 342);
    }

    //! Icon and label side by side, centred on x at baseline y, with the value (and a small unit) below.
    private function drawField(dc as Graphics.Dc, type as Number, x as Number, y as Number) as Void {
        if (type == FIELD_OFF) { return; }
        var data = getFieldDataStr(type);
        var value = data[1] as String;
        if (value.length() == 0) { return; }
        var label = data[0] as String;
        if (type == FIELD_DATE) {
            label = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week.toUpper();
        }
        var unit = (type == FIELD_ALTITUDE) ? " m" : "";

        var s = _scale;
        var x0 = x - (21 + label.length() * 9.4) / 2;
        drawIcon(dc, type, x0 + 8, y - 4);
        dc.setColor(COLOR_GOLD_M, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, (x0 + 21) * s, y * s, pick(_fLab, Graphics.FONT_XTINY), label, Graphics.TEXT_JUSTIFY_LEFT, 1);

        var valueFont = pick(_fVal, Graphics.FONT_XTINY);
        var unitFont = pick(_fSm, Graphics.FONT_XTINY);
        var wv = dc.getTextWidthInPixels(value, valueFont);
        var wu = (unit.length() > 0) ? dc.getTextWidthInPixels(unit, unitFont) : 0;
        var start = x * s - (wv + wu) / 2;
        dc.setColor(COLOR_CREAM, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, start, (y + 30) * s, valueFont, value, Graphics.TEXT_JUSTIFY_LEFT, 0);
        if (wu > 0) {
            dc.setColor(COLOR_GOLD_M, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, start + wv, (y + 30) * s, unitFont, unit, Graphics.TEXT_JUSTIFY_LEFT, 0);
        }
    }

    //! A 14 px icon centred on (x, y) in 454 px units: thermometer, mountains, footprints or calendar; any other field gets a dot.
    private function drawIcon(dc as Graphics.Dc, type as Number, x as Numeric, y as Numeric) as Void {
        var s = _scale;
        dc.setColor(COLOR_GOLD_M, Graphics.COLOR_TRANSPARENT);
        if (type == FIELD_WEATHER) {
            dc.setPenWidth(px(3));
            dc.drawLine(x * s, (y - 6) * s, x * s, (y + 1) * s);
            dc.fillCircle(x * s, (y + 4) * s, 3.4 * s);
        } else if (type == FIELD_ALTITUDE) {
            dc.setPenWidth(px(1.6));
            dc.drawLine((x - 8) * s, (y + 5) * s, (x - 2) * s, (y - 5) * s);
            dc.drawLine((x - 2) * s, (y - 5) * s, (x + 1) * s, y * s);
            dc.drawLine((x + 1) * s, y * s, (x + 4) * s, (y - 3) * s);
            dc.drawLine((x + 4) * s, (y - 3) * s, (x + 9) * s, (y + 5) * s);
        } else if (type == FIELD_STEPS) {
            dc.fillCircle((x - 3) * s, (y - 2) * s, 2.6 * s);
            dc.fillCircle((x + 3.5) * s, (y + 3) * s, 2.6 * s);
        } else if (type == FIELD_DATE) {
            dc.setPenWidth(px(1.6));
            dc.drawRectangle((x - 6) * s, (y - 5) * s, 12 * s, 11 * s);
            dc.drawLine((x - 6) * s, (y - 1) * s, (x + 6) * s, (y - 1) * s);
            dc.drawLine((x - 3) * s, (y - 7) * s, (x - 3) * s, (y - 4) * s);
            dc.drawLine((x + 3) * s, (y - 7) * s, (x + 3) * s, (y - 4) * s);
        } else {
            dc.fillCircle(x * s, y * s, 2.4 * s);
        }
    }

    //! The battery as Zagreus' HP: the red fill of the bar (from the bottom) and "HP 78%".
    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var bat = 0;
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            bat = stats.battery.toNumber();
        }
        var s = _scale;
        if (bat > 0) {
            var fill = -46 + 92 * bat / 100.0;
            var end = (fill < 0) ? fill + 360 : fill;
            dc.setPenWidth(px(11));
            dc.setColor(COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(_centerX, _centerY, HP_R * s, Graphics.ARC_COUNTER_CLOCKWISE, HP_FROM, end);
            dc.setPenWidth(1);
            dc.setColor(COLOR_RED_HI, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(_centerX, _centerY, (HP_R + 3) * s, Graphics.ARC_COUNTER_CLOCKWISE, HP_FROM, end);
        }
        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, 396 * s, 186 * s, pick(_fSm, Graphics.FONT_XTINY), "HP " + bat.toString() + "%", Graphics.TEXT_JUSTIFY_RIGHT, 1);
    }

    // ================================================================
    //  AOD - dim laurel and HP arcs, the hour and the obol outline, shifted every minute against burn-in
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var time = System.getClockTime();
        var cx = _centerX + (time.min % 5) * 5 - 10;
        var cy = _centerY + (time.min % 7) * 5 - 15;
        var k  = AOD_SCALE * _scale;

        dc.setPenWidth(px(2));
        dc.setColor(COLOR_AOD_LAUR, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, LAUREL_R * k, Graphics.ARC_CLOCKWISE, LAUREL_A0, LAUREL_A1);
        dc.setColor(COLOR_AOD_HP, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, HP_R * k, Graphics.ARC_COUNTER_CLOCKWISE, HP_FROM, HP_TO);

        var hourX = cx + (HOUR_X - 227) * k;
        var baseY = cy + (HOUR_BASELINE - 227) * k;
        dc.setColor(COLOR_AOD_HOUR, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, hourX, baseY, pick(_fHour, Graphics.FONT_NUMBER_HOT), time.hour.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER, 0);

        var obolX = cx + (OBOL_X - 227) * k;
        var obolY = cy + (OBOL_Y - 227) * k;
        dc.setColor(COLOR_AOD_RING, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(obolX, obolY, 46 * k);
        dc.setColor(COLOR_AOD_MIN, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, obolX, obolY + 16 * k, pick(_fMin, Graphics.FONT_NUMBER_MEDIUM), time.min.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER, 0);
    }

    // ================================================================
    //  TEXT HELPERS (same as in AssassinTheme)
    // ================================================================

    private function pick(font, fallback) {
        return (font != null) ? font : fallback;
    }

    //! Letter-spacing in device pixels: scaled like the layout but never below 1 px.
    private function spacingPx(spacing as Number) as Number {
        var p = (spacing * _scale + 0.5).toNumber();
        return (p < 1) ? 1 : p;
    }

    //! Width of a string with `spacing` extra pixels between glyphs (spacing 0 = plain width).
    private function spacedWidth(dc as Graphics.Dc, text as String, font, spacing as Number) as Number {
        if (spacing == 0) { return dc.getTextWidthInPixels(text, font); }
        var n = text.length();
        var total = spacing * (n - 1);
        for (var i = 0; i < n; i++) {
            total += dc.getTextWidthInPixels(text.substring(i, i + 1), font);
        }
        return total;
    }

    //! Draw text with its baseline at `baseline`. spacing > 0 lays the glyphs out one by one (Dc has no letter-spacing).
    private function drawBaselineText(dc as Graphics.Dc, x as Numeric, baseline as Numeric, font, text as String,
            justify as Number, spacing as Number) as Void {
        var y = (baseline - Graphics.getFontAscent(font)).toNumber();
        if (spacing == 0) {
            dc.drawText(x.toNumber(), y, font, text, justify);
            return;
        }
        var step = spacingPx(spacing);
        var pxx = x.toNumber();
        var total = spacedWidth(dc, text, font, step);
        if (justify == Graphics.TEXT_JUSTIFY_CENTER) {
            pxx -= total / 2;
        } else if (justify == Graphics.TEXT_JUSTIFY_RIGHT) {
            pxx -= total;
        }
        var n = text.length();
        for (var i = 0; i < n; i++) {
            var ch = text.substring(i, i + 1);
            dc.drawText(pxx, y, font, ch, Graphics.TEXT_JUSTIFY_LEFT);
            pxx += dc.getTextWidthInPixels(ch, font) + step;
        }
    }
}
