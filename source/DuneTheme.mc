import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Dune theme, "Zwoj" (coil) in the colours of the film: teal haze, pale dunes with cream crests, rusty sand and a wanderer in the foreground.
//!  - the sandworm coiled around the rim is the step meter: 36 slots, one per 1/36 of the step goal, thickness grows with the slot,
//!    lit slots are amber over rust, unlit ones a darker teal trench, the head stands at the progress;
//!  - the backdrop (haze, four dune layers, sand, wanderer) is replayed from resources/json/dune_bg.json, generated from the approved concept;
//!  - time is stacked (hours ink, minutes rust), the hour is a diamond and the minute a blue spark on the inner track;
//!  - the battery is five water drops filled from the bottom.
//! Geometry is given in 454 px units (the approved preview) and multiplied by _scale.
class DuneTheme extends ThemeBase {

    // ── Palette (measured on the film still) ────────────────────────
    private const COLOR_INK       = 0x0E2326;   // hours and field values
    private const COLOR_RUST      = 0x6E260B;   // minutes and labels
    private const COLOR_CREAM     = 0xFFF6E0;   // battery percentage
    private const COLOR_TRACK     = 0x4E7C77;   // inner ring and small ticks
    private const COLOR_TRACK_DK  = 0x24504F;   // 12, 3, 6 and 9 o'clock ticks
    private const COLOR_UNLIT     = 0x5F938E;   // worm slots not reached yet
    private const COLOR_HEAD_LIP  = 0xEBB562;
    private const COLOR_HEAD_EDGE = 0x6B3B12;
    private const COLOR_HEAD_MAW  = 0x1B0E06;
    private const COLOR_TEETH     = 0xF6EAD0;
    private const COLOR_SPARK_OUT = 0x0E2F52;
    private const COLOR_SPARK_MID = 0x2C8CE0;
    private const COLOR_SPARK_IN  = 0xEAF6FF;
    private const COLOR_DROP_ON   = 0xDDF3FF;
    private const COLOR_DROP_OFF  = 0x3F6E6C;
    private const COLOR_AOD_HOUR  = 0xC9C2A8;
    private const COLOR_AOD_MIN   = 0xB0762A;

    // Lit slot colours by parity: [outer band, inner band]
    private const LIT_EVEN = [0xE4953F, 0x8A4518];
    private const LIT_ODD  = [0xD0822F, 0x783B12];

    private const SLOTS = 36;
    private const WORM_R = 224;
    private const TRACK_R = 186;
    private const FONT_EM_TO_SIZE = 1.0;   // Swiss721 vector font: size = em, measured on the simulator (see the Hades theme)

    private var _fTime  as Graphics.VectorFont or Null = null;   // 120 px
    private var _fValue as Graphics.VectorFont or Null = null;   // 27 px
    private var _fLabel as Graphics.VectorFont or Null = null;   // 15 px
    private var _fPct   as Graphics.VectorFont or Null = null;   // 18 px

    private var _steps    as Number = 0;
    private var _goal     as Number = 10000;
    private var _litCount as Number = -1;   // worm slots currently lit in the static buffer

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_INK;
        _colorSecondary = COLOR_AOD_MIN;
        _colorAccent    = COLOR_RUST;
        _colorDim       = COLOR_TRACK;
        _colorAlert     = COLOR_RUST;
        _colorTime      = COLOR_INK;
    }

    // ================================================================
    //  RESOURCES - fonts exist only while the theme is active
    // ================================================================

    public function loadResources() as Void {
        readSteps();
        _litCount = litSlots();
        _fTime  = makeFont(120);
        _fValue = makeFont(27);
        _fLabel = makeFont(15);
        _fPct   = makeFont(18);
        ThemeBase.loadResources();
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _fTime = null;
        _fValue = null;
        _fLabel = null;
        _fPct = null;
        _litCount = -1;
    }

    private function makeFont(px as Number) as Graphics.VectorFont or Null {
        if (Graphics has :getVectorFont) {
            try {
                return Graphics.getVectorFont({
                    :face => ["Swiss721Bold", "Swiss721Regular", "RobotoCondensedBold"],
                    :size => (px * FONT_EM_TO_SIZE * _scale + 0.5).toNumber()
                });
            } catch (e) {}
        }
        return null;
    }

    // ================================================================
    //  STEP METER - the number of lit slots lives in the static buffer
    // ================================================================

    private function readSteps() as Void {
        var info = ActivityMonitor.getInfo();
        _steps = 0;
        _goal = 10000;
        if (info != null) {
            if (info.steps != null) { _steps = info.steps; }
            if (info.stepGoal != null) { _goal = info.stepGoal; }
        }
        if (_goal <= 0) { _goal = 10000; }
    }

    private function litSlots() as Number {
        var n = _steps * SLOTS / _goal;
        return (n > SLOTS) ? SLOTS : n;
    }

    //! Re-render the static buffer only when the number of lit slots changes (at most 36 times a day).
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        readSteps();
        var lit = litSlots();
        if (lit != _litCount) {
            _litCount = lit;
            renderStaticBuffer();
        }
        ThemeBase.drawStaticLayer(dc);
    }

    //! The worm replaces the progress arc of ThemeBase.
    public function drawProgressArc(dc as Graphics.Dc) as Void {}

    // ================================================================
    //  STATIC LAYER - backdrop, worm, inner track
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        drawBackdrop(dc);
        drawWorm(dc);
        drawTrack(dc);
    }

    //! The backdrop is two resources (back to front) so that only about 5 kB of ops sit on the heap at a time.
    private function drawBackdrop(dc as Graphics.Dc) as Void {
        replayOps(dc, Rez.JsonData.DuneBgA);
        replayOps(dc, Rez.JsonData.DuneBgB);
    }

    //! Replays the ops of a dune_bg_*.json: [type, colour, pen width, ...coordinates]; type 0 = rectangle (x, y, w, h), 1 = convex polygon,
    //! 2 = polyline, 3 = arc (centre x, y, radius, start and end degrees, clockwise). Shapes run past the screen edge on purpose.
    private function replayOps(dc as Graphics.Dc, resource as Lang.ResourceId) as Void {
        var s = _scale;
        var data = WatchUi.loadResource(resource) as Dictionary;
        var ops = data["ops"] as Array;
        for (var i = 0; i < ops.size(); i++) {
            var op = ops[i] as Array<Numeric>;
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
                dc.setPenWidth(px(op[2]));
                dc.drawArc(op[3] * s, op[4] * s, op[5] * s, Graphics.ARC_CLOCKWISE, op[6], op[7]);
            }
        }
    }

    //! Point at radius r (454 px units) and clock angle a (degrees, 0 = 12 o'clock, clockwise) around (cx, cy).
    private function pt(r as Numeric, a as Numeric, cx as Numeric, cy as Numeric) as [Float, Float] {
        var rad = a * Math.PI / 180.0;
        return [cx + r * _scale * Math.sin(rad), cy - r * _scale * Math.cos(rad)] as [Float, Float];
    }

    //! Slot k spans 10 degrees with a 0.9 degree gap each side; its radial thickness is 6 px growing to 26 px.
    private function drawWorm(dc as Graphics.Dc) as Void {
        var cx = _centerX.toFloat();
        var cy = _centerY.toFloat();
        dc.setColor(COLOR_UNLIT, Graphics.COLOR_TRANSPARENT);
        for (var k = _litCount + 1; k < SLOTS; k++) {
            var w = 6.0 + 20.0 * k / 35.0;
            dc.fillPolygon([pt(WORM_R, 10 * k + 0.9, cx, cy), pt(WORM_R, 10 * k + 9.1, cx, cy),
                pt(WORM_R - w, 10 * k + 9.1, cx, cy), pt(WORM_R - w, 10 * k + 0.9, cx, cy)]);
        }
        for (var k = 0; k < _litCount; k++) {
            var w = 6.0 + 20.0 * k / 35.0;
            var m = WORM_R - w * 0.46;
            var colors = (k % 2 == 0) ? LIT_EVEN : LIT_ODD;
            dc.setColor(colors[0], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([pt(WORM_R, 10 * k + 0.9, cx, cy), pt(WORM_R, 10 * k + 9.1, cx, cy),
                pt(m, 10 * k + 9.1, cx, cy), pt(m, 10 * k + 0.9, cx, cy)]);
            dc.setColor(colors[1], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([pt(m, 10 * k + 0.9, cx, cy), pt(m, 10 * k + 9.1, cx, cy),
                pt(WORM_R - w, 10 * k + 9.1, cx, cy), pt(WORM_R - w, 10 * k + 0.9, cx, cy)]);
        }
        drawHead(dc, cx, cy);
    }

    //! Head: lip disc, black maw, nine small teeth.
    private function drawHead(dc as Graphics.Dc, cx as Float, cy as Float) as Void {
        var s = _scale;
        var hr = 17.5;
        var hc = pt(WORM_R - hr + 0.5, 10 * _litCount + 4, cx, cy);
        var hx = hc[0];
        var hy = hc[1];
        dc.setColor(COLOR_HEAD_LIP, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx, hy, hr * s);
        dc.setColor(COLOR_HEAD_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(1.5));
        dc.drawCircle(hx, hy, (hr - 0.8) * s);
        dc.setColor(COLOR_HEAD_MAW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx, hy, 11.8 * s);
        dc.setColor(COLOR_TEETH, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < 9; j++) {
            var a = 40 * j;
            dc.fillPolygon([pt(11.6, a - 11, hx, hy), pt(11.6, a + 11, hx, hy), pt(4.2, a, hx, hy)]);
        }
    }

    //! Inner track with the twelve hour ticks, and the ARRAKIS tag above the hours.
    private function drawTrack(dc as Graphics.Dc) as Void {
        var cx = _centerX.toFloat();
        var cy = _centerY.toFloat();
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, TRACK_R * _scale);
        for (var h = 0; h < 12; h++) {
            var major = (h % 3 == 0);
            dc.setColor(major ? COLOR_TRACK_DK : COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(major ? px(2) : 1);
            var p0 = pt(181, 30 * h, cx, cy);
            var p1 = pt(191, 30 * h, cx, cy);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        }
        dc.setColor(COLOR_RUST, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, 102 * _scale, pick(_fLabel, Graphics.FONT_XTINY), "ARRAKIS", Graphics.TEXT_JUSTIFY_CENTER, 5);
    }

    // ================================================================
    //  DYNAMIC LAYER - hands, time, data fields, battery drops
    // ================================================================

    //! The hour is a diamond on the inner track, the minute a blue spark.
    public function drawCenterElement(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var cx = _centerX.toFloat();
        var cy = _centerY.toFloat();
        var hA = (time.hour % 12 + time.min / 60.0) * 30;
        dc.setColor(COLOR_INK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([pt(179, hA, cx, cy), pt(TRACK_R, hA - 2.6, cx, cy), pt(193, hA, cx, cy), pt(TRACK_R, hA + 2.6, cx, cy)]);
        var sp = pt(TRACK_R, 6 * time.min, cx, cy);
        dc.setColor(COLOR_SPARK_OUT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sp[0], sp[1], 8.5 * _scale);
        dc.setColor(COLOR_SPARK_MID, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sp[0], sp[1], 5 * _scale);
        dc.setColor(COLOR_SPARK_IN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sp[0], sp[1], 2 * _scale);
    }

    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var font = pick(_fTime, Graphics.FONT_NUMBER_HOT);
        dc.setColor(COLOR_INK, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, 210 * _scale, font, time.hour.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_RUST, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, 330 * _scale, font, time.min.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER, 0);
    }

    public function drawDataFields(dc as Graphics.Dc) as Void {
        drawField(dc, 104, 192, _fieldTopLeft);
        drawField(dc, 349, 192, _fieldTopRight);
        drawField(dc, 104, 294, _fieldBottomLeft);
        drawField(dc, 349, 294, _fieldBottomRight);
    }

    //! Label above the value, both centred on x; the value baseline is y. A date without a label gets the weekday, altitude gets an "m".
    private function drawField(dc as Graphics.Dc, x as Number, y as Number, type as Number) as Void {
        if (type == FIELD_OFF) { return; }
        var data = getFieldDataStr(type);
        var value = data[1] as String;
        if (value.length() == 0) { return; }
        var label = data[0] as String;
        if (label.length() == 0 && type == FIELD_DATE) {
            label = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week.toUpper();
        }
        var fValue = pick(_fValue, Graphics.FONT_SMALL);
        var fLabel = pick(_fLabel, Graphics.FONT_XTINY);

        if (label.length() > 0) {
            dc.setColor(COLOR_RUST, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, x * _scale, (y - 30) * _scale, fLabel, label, Graphics.TEXT_JUSTIFY_CENTER, 2);
        }
        if (type == FIELD_ALTITUDE) {
            var gap = 5 * _scale;
            var valueW = dc.getTextWidthInPixels(value, fValue);
            var unitW = dc.getTextWidthInPixels("m", fLabel);
            var left = x * _scale - (valueW + gap + unitW) / 2;
            dc.setColor(COLOR_INK, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, left, y * _scale, fValue, value, Graphics.TEXT_JUSTIFY_LEFT, 0);
            dc.setColor(COLOR_RUST, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, left + valueW + gap, y * _scale, fLabel, "m", Graphics.TEXT_JUSTIFY_LEFT, 0);
        } else {
            dc.setColor(COLOR_INK, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, x * _scale, y * _scale, fValue, value, Graphics.TEXT_JUSTIFY_CENTER, 0);
        }
    }

    //! Battery as five water drops, filled from the bottom, and the percentage.
    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var bat = 0;
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            bat = stats.battery.toNumber();
        }
        var level = bat / 100.0 * 5;
        for (var i = 0; i < 5; i++) {
            var p = level - i;
            drawDrop(dc, (168 + 21 * i) * _scale, 367 * _scale, (p > 1) ? 1.0 : ((p < 0) ? 0.0 : p));
        }
        dc.setColor(COLOR_CREAM, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, 266 * _scale, 374 * _scale, pick(_fPct, Graphics.FONT_XTINY), bat.toString() + "%", Graphics.TEXT_JUSTIFY_LEFT, 0);
    }

    //! Drop of bulb radius 6: round bulb plus a pointed top. Partly filled drops are clipped to the part above the water line.
    private function drawDrop(dc as Graphics.Dc, cx as Float, cy as Float, p as Float) as Void {
        var r = 6 * _scale;
        dc.setColor(COLOR_DROP_OFF, Graphics.COLOR_TRANSPARENT);
        dropShape(dc, cx, cy, r);
        if (p <= 0) { return; }
        dc.setColor(COLOR_DROP_ON, Graphics.COLOR_TRANSPARENT);
        if (p >= 1) {
            dropShape(dc, cx, cy, r);
            return;
        }
        var bot = cy + r;
        var top = cy - 2.25 * r;
        var y = bot - p * (bot - top);
        dc.setClip((cx - r - 1).toNumber(), y.toNumber(), (2 * r + 2).toNumber(), (bot + 2 - y).toNumber());
        dropShape(dc, cx, cy, r);
        dc.clearClip();
    }

    private function dropShape(dc as Graphics.Dc, cx as Float, cy as Float, r as Float) as Void {
        dc.fillCircle(cx, cy, r);
        dc.fillPolygon([[cx, cy - 2.25 * r], [cx - 0.89583 * r, cy - 0.44444 * r], [cx + 0.89583 * r, cy - 0.44444 * r]]);
    }

    // ================================================================
    //  AOD - the stacked time and four hour ticks, shifted every minute against burn-in
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var time = System.getClockTime();
        var dx = (time.min % 5) * 5 - 10;
        var dy = (time.min % 7) * 5 - 15;
        var font = pick(_fTime, Graphics.FONT_NUMBER_HOT);
        dc.setColor(COLOR_AOD_HOUR, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX + dx, 210 * _scale + dy, font, time.hour.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_AOD_MIN, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX + dx, 330 * _scale + dy, font, time.min.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2));
        var cx = _centerX.toFloat() + dx;
        var cy = _centerY.toFloat() + dy;
        for (var h = 0; h < 4; h++) {
            var p0 = pt(181, 90 * h, cx, cy);
            var p1 = pt(191, 90 * h, cx, cy);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        }
    }

    // ================================================================
    //  HELPERS
    // ================================================================

    private function px(v as Numeric) as Number {
        var p = (v * _scale + 0.5).toNumber();
        return (p < 1) ? 1 : p;
    }

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
        var left = x.toNumber();
        var total = spacedWidth(dc, text, font, step);
        if (justify == Graphics.TEXT_JUSTIFY_CENTER) {
            left -= total / 2;
        } else if (justify == Graphics.TEXT_JUSTIFY_RIGHT) {
            left -= total;
        }
        var n = text.length();
        for (var i = 0; i < n; i++) {
            var ch = text.substring(i, i + 1);
            dc.drawText(left, y, font, ch, Graphics.TEXT_JUSTIFY_LEFT);
            left += dc.getTextWidthInPixels(ch, font) + step;
        }
    }
}
