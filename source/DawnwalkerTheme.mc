import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Dawnwalker theme, the "Zaćmienie" (eclipse) look:
//!  - a segmented day ring (gap at the bottom = midnight, sun knob on the left = 06:00, moon knob on the right = 18:00, pin head on top):
//!    16 segments of 1.5 h, 8 day (gold) and 8 night (red); time left is lit, time gone is dim, the current segment is outlined;
//!  - an eclipse inside it: a black disc with a bright limb, and 48 long corona rays that are the step meter
//!    (from the top, clockwise; each ray = 1/48 of the goal);
//!  - the four data fields run along arcs between the corona and the ring (like ThemeBase), in the Pridi vector font;
//!  - in the disc: a STEPS tag, the time in a bitmap font (digits only, resources/fonts), the date and the battery as a BLOOD ribbon.
//! Geometry is given in 454 px units and multiplied by _scale.
class DawnwalkerTheme extends ThemeBase {

    // ── Palette ──────────────────────────────────────────────────────
    private const COLOR_INTERIOR    = 0x050407;
    private const COLOR_BRONZE      = 0xC98A3C;
    private const COLOR_BRONZE_DARK = 0x6B3F14;
    private const COLOR_BONE        = 0xE8DCC0;
    private const COLOR_TIME        = 0xF2C879;
    private const COLOR_TIME_SHADOW = 0x5E2A10;
    private const COLOR_AOD_TIME    = 0xA87420;
    private const COLOR_DATE        = 0x9A8F7C;
    private const COLOR_BLOOD_ON    = 0xA31E22;
    private const COLOR_BLOOD_OFF   = 0x2A0F10;
    private const COLOR_BLOOD_TEXT  = 0xD9CBB0;

    private const CORONA_LIT = 0xF08A2E;
    private const CORONA_DIM = 0x4A2A14;
    private const LIMB_HALO  = 0x241006;
    private const LIMB_MID   = 0x6A2E10;

    private const DAY_LIT   = 0xE3A23F;
    private const DAY_DIM   = 0x4A3516;
    private const DAY_NOW   = 0xF7D07A;
    private const NIGHT_LIT = 0xA32B2B;
    private const NIGHT_DIM = 0x3A1515;
    private const NIGHT_NOW = 0xE0503C;
    private const NOW_EDGE  = 0xF2E3C4;   // outline of the current segment
    private const SEAM      = 0x1A1008;   // gaps between segments

    private const KNOB_BG   = 0x120D08;
    private const SUN_COLOR = 0xF0A640;
    private const SUN_DIM   = 0x5E4116;   // the inactive knob is dimmed: the sun at night, the moon by day
    private const SUN_DIM_S = 0x3A2610;   // short sun rays when dimmed
    private const MOON_DIM  = 0x4C4839;
    private const PIN_HI    = 0xDFA759;

    // ── Layout, 454 px units ─────────────────────────────────────────
    private const DISC_R          = 126;   // black eclipse disc; the content (time, tag, date, ribbon) stays inside r = 120
    private const RAY_R0          = 142;   // rays start on the outer edge of the halo (disc + 16)
    private const TAG_BASELINE    = 172;
    private const TIME_BASELINE   = 247;
    private const TIME_SHADOW     = 2;
    private const DATE_BASELINE   = 283;
    private const RIBBON_BASELINE = 303;
    private const ARC_R_TOP       = 185;   // radial text radius of the two top fields (clockwise); measured text band 186..196
    private const ARC_R_BOTTOM    = 193;   // ... of the two bottom fields (counter-clockwise); measured text band 186..195
    private const KNOB_R          = 210;   // knob centres: 210 + radius 15 + outline 1.5 stays inside the 227 px screen edge
    private const AOD_SCALE       = 0.9;   // smaller in AOD so the burn-in shift never pushes the ring off screen
    private const FONT_EM_TO_SIZE = 1.35;  // Pridi: vector font size (line height) per em, measured on the simulator

    private var _fTime   = null;                                         // bitmap font (digits and colon) or the Pridi vector font, 66 px
    private var _fTag    as Graphics.VectorFont or Null = null;          // 15 px
    private var _fDate   as Graphics.VectorFont or Null = null;          // 19 px
    private var _fRibbon as Graphics.VectorFont or Null = null;          // 14 px

    private var _steps   as Number = 0;
    private var _goal    as Number = 10000;
    private var _litRays as Number = -1;   // corona rays lit in the static buffer
    private var _daySeg  as Number = -1;   // current 1.5 h segment of the day ring (0 = 00:00..01:30), as drawn in the static buffer

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_BONE;
        _colorSecondary = COLOR_AOD_TIME;
        _colorAccent    = CORONA_LIT;
        _colorDim       = COLOR_BRONZE_DARK;
        _colorAlert     = 0xA32B2B;
        _colorTime      = COLOR_TIME;
    }

    //! The arc text of the data fields uses Pridi instead of the default radial font.
    public function init(dc as Graphics.Dc) as Void {
        ThemeBase.init(dc);
        var f = makeFont(17);
        if (f != null) { _radialFont = f; }
    }

    // ================================================================
    //  RESOURCES - fonts exist only while the theme is active
    // ================================================================

    public function loadResources() as Void {
        refreshState();
        // The bitmap font is rasterised for the 454 px face and does not scale: smaller screens get the Pridi vector font instead
        _fTime = null;
        if (_scale > 0.99) {
            try {
                _fTime = WatchUi.loadResource(Rez.Fonts.DawnTime);
            } catch (e) {
                _fTime = null;
            }
        }
        if (_fTime == null) { _fTime = makeFont(66); }
        _fTag    = makeFont(18);
        _fDate   = makeFont(22);
        _fRibbon = makeFont(17);
        ThemeBase.loadResources();
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _fTime = null;
        _fTag = null;
        _fDate = null;
        _fRibbon = null;
        _litRays = -1;
        _daySeg = -1;
    }

    //! px is the em size; a Garmin vector font is sized by line height, which is 1.35 em for Pridi.
    private function makeFont(px as Number) as Graphics.VectorFont or Null {
        if (Graphics has :getVectorFont) {
            try {
                return Graphics.getVectorFont({
                    :face => ["PridiRegularGarmin", "RobotoCondensedBold"],
                    :size => (px * FONT_EM_TO_SIZE * _scale + 0.5).toNumber()
                });
            } catch (e) {}
        }
        return null;
    }

    // ================================================================
    //  STEP METER - the number of lit rays lives in the static buffer
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
        var rays = _steps * 48 / _goal;
        _litRays = (rays > 48) ? 48 : rays;
        var t = System.getClockTime();
        _daySeg = (t.hour * 60 + t.min) / 90;
    }

    //! Re-render the static buffer only when the number of lit rays or the day segment changes (at most 48 + 16 times a day).
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        var previous = _litRays;
        var previousSeg = _daySeg;
        refreshState();
        if (_litRays != previous || _daySeg != previousSeg) {
            renderStaticBuffer();
        }
        ThemeBase.drawStaticLayer(dc);
    }

    //! The corona replaces the bottom progress arc of ThemeBase.
    public function drawProgressArc(dc as Graphics.Dc) as Void {}

    // ================================================================
    //  STATIC LAYER - eclipse with corona, day ring
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var s  = _scale;
        var cx = _centerX;
        var cy = _centerY;

        dc.setColor(COLOR_INTERIOR, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 206 * s);

        // Eclipse: halo, thin bright limb, black disc
        dc.setColor(LIMB_HALO, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (DISC_R + 16) * s);
        dc.setColor(LIMB_MID, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (DISC_R + 10) * s);
        dc.setColor(CORONA_LIT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (DISC_R + 4) * s);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (DISC_R + 1) * s);

        // Corona: 48 long rays from the top, clockwise; longest every 4th ray, medium every 2nd; lit = steps reached
        dc.setPenWidth(px(3));
        for (var i = 0; i < 48; i++) {
            var len = (i % 4 == 0) ? 34 : ((i % 2 == 0) ? 24 : 14);
            var a = (90.0 - 7.5 * i) * Math.PI / 180.0;
            var c = Math.cos(a);
            var n = Math.sin(a);
            dc.setColor((i < _litRays) ? CORONA_LIT : CORONA_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx + RAY_R0 * s * c, cy - RAY_R0 * s * n, cx + (RAY_R0 + len) * s * c, cy - (RAY_R0 + len) * s * n);
        }
    }

    public function drawOuterRing(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var s  = _scale;
        var cx = _centerX;
        var cy = _centerY;

        // Day ring r = 206..224: 16 segments of 22.5 degrees, midnight in the 12 degree gap at 6 o'clock, then clockwise.
        // Segment k is 1.5 h; 06:00..18:00 (k = 4..11) is day. Elapsed = dim, current = bright with an outline, rest = lit.
        var nowA0 = 0.0;
        var nowA1 = 0.0;
        dc.setPenWidth(px(18));
        for (var k = 0; k < 16; k++) {
            var a1 = (k == 0) ? 264.0 : 270.0 - 22.5 * k;
            var a0 = (k == 15) ? 276.0 : 270.0 - 22.5 * (k + 1);
            if (a1 < 0) { a1 += 360.0; }
            if (a0 < 0) { a0 += 360.0; }
            var day = (k >= 4 && k < 12);
            var color;
            if (k < _daySeg) {
                color = day ? DAY_DIM : NIGHT_DIM;
            } else if (k == _daySeg) {
                color = day ? DAY_NOW : NIGHT_NOW;
                nowA0 = a0;
                nowA1 = a1;
            } else {
                color = day ? DAY_LIT : NIGHT_LIT;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, 215 * s, Graphics.ARC_COUNTER_CLOCKWISE, a0, a1);
        }

        // Seams between the segments (and at the ends of the gap), then the thin bronze rim
        dc.setColor(SEAM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2));
        radial(dc, 276.0, 206 * s, 224 * s);
        for (var k = 0; k < 16; k++) {
            var seam = (k == 0) ? 264.0 : 270.0 - 22.5 * k;
            radial(dc, (seam < 0) ? seam + 360.0 : seam, 206 * s, 224 * s);
        }
        dc.setColor(COLOR_BRONZE_DARK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(cx, cy, 206 * s, Graphics.ARC_COUNTER_CLOCKWISE, 276, 264);
        dc.drawArc(cx, cy, 224 * s, Graphics.ARC_COUNTER_CLOCKWISE, 276, 264);

        if (_daySeg >= 0) {
            dc.setColor(NOW_EDGE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(px(2));
            dc.drawArc(cx, cy, 206 * s, Graphics.ARC_COUNTER_CLOCKWISE, nowA0, nowA1);
            dc.drawArc(cx, cy, 224 * s, Graphics.ARC_COUNTER_CLOCKWISE, nowA0, nowA1);
            radial(dc, nowA0, 206 * s, 224 * s);
            radial(dc, nowA1, 206 * s, 224 * s);
        }

        drawKnobs(dc);

        // Pin head over the top of the ring
        dc.setColor(COLOR_BRONZE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px(223), px(1), px(8), px(34), px(3));
        dc.setColor(COLOR_BRONZE_DARK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(px(223), px(1), px(8), px(34), px(3));
        dc.setColor(PIN_HI, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px(226), px(3), px(2), px(29));
    }

    //! Sun knob at 9 o'clock (heraldic sun, bronze rim), moon knob at 3 o'clock (crescent with a star, bone-white rim).
    //! The knob of the current half of the day is bright, the other one dimmed (06:00..18:00 = day, like the ring).
    private function drawKnobs(dc as Graphics.Dc) as Void {
        var s  = _scale;
        var sx = _centerX - KNOB_R * s;
        var mx = _centerX + KNOB_R * s;
        var cy = _centerY;
        var day = (_daySeg >= 4 && _daySeg < 12);

        dc.setColor(KNOB_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, cy, 15 * s);
        dc.fillCircle(mx, cy, 15 * s);

        // Sun: 8 long rays, 8 short bronze rays between them, a disc with a hole
        dc.setColor(day ? SUN_COLOR : SUN_DIM, Graphics.COLOR_TRANSPARENT);
        fillStar(dc, sx, cy, 8, 13, 4.5, 0.0);
        dc.setColor(day ? COLOR_BRONZE : SUN_DIM_S, Graphics.COLOR_TRANSPARENT);
        fillStar(dc, sx, cy, 8, 9.2, 4.5, Math.PI / 8);
        dc.setColor(day ? SUN_COLOR : SUN_DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, cy, 4.6 * s);
        dc.setColor(KNOB_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, cy, 2 * s);

        // Moon: crescent opening to the left, with a four-point star in the hollow
        var moon = day ? MOON_DIM : COLOR_BONE;
        dc.setColor(moon, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, cy, 10.5 * s);
        dc.setColor(KNOB_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx - 4.8 * s, cy - 1 * s, 8.6 * s);
        dc.setColor(moon, Graphics.COLOR_TRANSPARENT);
        fillStar(dc, mx - 4.5 * s, cy - 1.5 * s, 4, 3.4, 1, 0.0);

        // Rims go last: they also cover the edge of the crescent cut-out
        dc.setPenWidth(px(3));
        dc.setColor(day ? COLOR_BRONZE : COLOR_BRONZE_DARK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sx, cy, 15 * s);
        dc.setColor(moon, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(mx, cy, 15 * s);
    }

    //! Filled star with n long points (2n vertices); radii in 454 px units, rot in radians clockwise from the top.
    private function fillStar(dc as Graphics.Dc, x as Numeric, y as Numeric, n as Number, ro as Numeric, ri as Numeric,
            rot as Numeric) as Void {
        var pts = [];
        for (var i = 0; i < 2 * n; i++) {
            var r = ((i % 2 == 0) ? ro : ri) * _scale;
            var a = rot + i * Math.PI / n;
            pts.add([x + r * Math.sin(a), y - r * Math.cos(a)]);
        }
        dc.fillPolygon(pts);
    }

    private function radial(dc as Graphics.Dc, deg as Float, r0 as Float, r1 as Float) as Void {
        var a = deg * Math.PI / 180.0;
        var c = Math.cos(a);
        var n = Math.sin(a);
        dc.drawLine(_centerX + r0 * c, _centerY - r0 * n, _centerX + r1 * c, _centerY - r1 * n);
    }

    //! A length in 454 px units as device pixels, never below 1.
    private function px(v as Numeric) as Number {
        var p = (v * _scale + 0.5).toNumber();
        return (p < 1) ? 1 : p;
    }

    // ================================================================
    //  DYNAMIC LAYER - fields on arcs, tag, time, date, BLOOD ribbon
    // ================================================================

    //! The four fields run along arcs: top ones clockwise at 140 and 40 degrees, bottom ones counter-clockwise at 240 and 300.
    public function drawDataFields(dc as Graphics.Dc) as Void {
        drawArcField(dc, _fieldTopLeft, 140.0, -1, ARC_R_TOP);
        drawArcField(dc, _fieldTopRight, 40.0, -1, ARC_R_TOP);
        drawArcField(dc, _fieldBottomLeft, 240.0, 1, ARC_R_BOTTOM);
        drawArcField(dc, _fieldBottomRight, 300.0, 1, ARC_R_BOTTOM);
    }

    private function drawArcField(dc as Graphics.Dc, type as Number, angle as Float, direction as Number, radius as Number) as Void {
        if (type == FIELD_OFF) { return; }
        var data = getFieldDataStr(type);
        var value = data[1] as String;
        if (value.length() == 0) { return; }
        var label = data[0] as String;
        var text = (label.length() > 0) ? label + " " + value : value;
        drawTextAlongArc(dc, text, radius * _scale, angle, direction, COLOR_BONE, Graphics.FONT_XTINY);
    }

    public function drawCenterElement(dc as Graphics.Dc) as Void {
        var pct = _steps * 100 / _goal;
        if (pct > 999) { pct = 999; }   // keeps the text inside the disc
        var text = (WatchUi.loadResource(Rez.Strings.LabelSteps) as String) + " " + pct.toString() + "%";
        dc.setColor(CORONA_LIT, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, TAG_BASELINE * _scale, pick(_fTag, Graphics.FONT_XTINY), text,
            Graphics.TEXT_JUSTIFY_CENTER, 2);
    }

    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        var font = pick(_fTime, Graphics.FONT_NUMBER_HOT);
        var base = TIME_BASELINE * _scale;
        var off  = TIME_SHADOW * _scale;
        dc.setColor(COLOR_TIME_SHADOW, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX + off, base + off, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_TIME, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, base, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
    }

    //! Date (day of week and day) and the battery as a BLOOD ribbon: label with the percentage and a 10-notch bar.
    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = info.day_of_week.toUpper() + " " + info.day.format("%d");
        dc.setColor(COLOR_DATE, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, DATE_BASELINE * _scale, pick(_fDate, Graphics.FONT_XTINY), dateStr,
            Graphics.TEXT_JUSTIFY_CENTER, 2);

        var bat = 0;
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            bat = stats.battery.toNumber();
        }
        dc.setColor(COLOR_BLOOD_TEXT, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, RIBBON_BASELINE * _scale, pick(_fRibbon, Graphics.FONT_XTINY),
            "BLOOD " + bat.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER, 2);

        // 10 notches, 70 px wide with 2 px gaps (5.2 px each), 5 px high
        var filled = (bat + 5) / 10;
        var y = px(309);
        var h = px(5);
        for (var i = 0; i < 10; i++) {
            var x0 = ((192 + i * 7.2) * _scale + 0.5).toNumber();
            var x1 = ((192 + i * 7.2 + 5.2) * _scale + 0.5).toNumber();
            dc.setColor((i < filled) ? COLOR_BLOOD_ON : COLOR_BLOOD_OFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0, y, x1 - x0, h);
        }
    }

    // ================================================================
    //  AOD - outline of the ring band and the time, shifted every minute against burn-in
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var time = System.getClockTime();
        var cx = _centerX + (time.min % 5) * 5 - 10;
        var cy = _centerY + (time.min % 7) * 5 - 15;
        var k  = AOD_SCALE * _scale;

        dc.setColor(COLOR_BRONZE_DARK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(cx, cy, 206 * k, Graphics.ARC_COUNTER_CLOCKWISE, 276, 264);
        dc.drawArc(cx, cy, 224 * k, Graphics.ARC_COUNTER_CLOCKWISE, 276, 264);

        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(COLOR_AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, pick(_fTime, Graphics.FONT_NUMBER_HOT), timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ================================================================
    //  TEXT HELPERS (same as in ResidentEvilTheme, the Umbrella theme)
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
