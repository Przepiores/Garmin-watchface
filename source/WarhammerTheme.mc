import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! Warhammer 40,000 theme, Carcharodons ("Space Sharks") "Jaws + auspex" look:
//!  - the bezel is two interlocking rows of shark teeth; the outer 36 teeth are the step meter (from the top, clockwise; each tooth = 1/36 of the goal);
//!  - inside is an auspex scanner (range rings, bearings, a sweep trail); the four data fields are contacts on it;
//!  - above the time sits the chapter badge (a shark curled into a crescent), below it the battery as a BLOOD TIDE bar.
//! Geometry is given in 454 px units and multiplied by _scale.
class WarhammerTheme extends ThemeBase {

    // ── Palette ──────────────────────────────────────────────────────
    private const COLOR_RING       = 0x0A0B10;
    private const COLOR_VOID       = 0x030305;
    private const COLOR_ASH        = 0x8D99AE;   // void-ash ceramite grey
    private const COLOR_ASH_DK     = 0x3A4052;
    private const COLOR_CHALK      = 0xEDEDED;
    private const COLOR_CRIM       = 0xBA181B;   // bloody tide crimson (progress)
    private const COLOR_CRIM_DK    = 0x7E0F12;
    private const COLOR_CRIM_HI    = 0xE4393C;
    private const COLOR_CRIM_OFF   = 0x2A1215;
    private const COLOR_TOOTH_OFF  = 0x2B2F3E;   // teeth not yet reached: light and dark face
    private const COLOR_TOOTH_OFF2 = 0x1B1E29;
    private const COLOR_TOOTH_IN   = 0x7C879B;   // the inner, ornamental row
    private const COLOR_TOOTH_IN2  = 0x4A5266;
    private const COLOR_GREEN      = 0x2BFF7A;   // auspex scanner green
    private const COLOR_SCAN_RING  = 0x10612E;
    private const COLOR_SCAN_DASH  = 0x0C4722;
    private const COLOR_SCAN_CORE  = 0x09381B;
    private const COLOR_SCAN_CROSS = 0x082E16;
    private const COLOR_SCAN_LINE  = 0x188C43;
    private const COLOR_TIME_SHD   = 0x2A0C0E;
    private const COLOR_AOD_TIME   = 0x5B6377;

    // Sweep trail: nine 4 degree slices behind the sweep line, fading from 15% to under 2% of the scanner green
    private const SWEEP = [0x062612, 0x062210, 0x051E0E, 0x041A0C, 0x04150A, 0x031108, 0x020D06, 0x010804, 0x010402];

    // ── Layout, 454 px units ─────────────────────────────────────────
    private const TEETH_BASE      = 223;   // outer row: 36 teeth from r 223 inwards to r 196
    private const TEETH_TIP       = 196;
    private const INNER_BASE      = 205;   // inner row: 36 small teeth in the gaps between the outer ones
    private const INNER_TIP       = 187;
    private const OUT_HW          = 4.8;   // tooth half-width at the base, degrees
    private const IN_HW           = 2.7;
    private const INTERIOR_R      = 186;
    private const SCAN_R          = 160;
    private const CONTACT_R       = 118;
    private const LOGO_Y          = 99;    // centre of the chapter badge
    private const LOGO_WIDTH      = 84;
    private const TAG_BASELINE    = 150;
    private const TIME_BASELINE   = 262;
    private const BAT_BASELINE    = 306;
    private const BAT_BAR_Y       = 313;
    private const AOD_SCALE       = 0.9;   // smaller in AOD so the burn-in shift never pushes the ring off screen
    private const FONT_EM_TO_SIZE = 1.172; // Roboto: vector font size (line height) per em, measured on the simulator

    // Chapter badge: resources/json/warhammer_logo.json holds the polygons as flat x, y pairs on a 400 x 331 grid, traced from the badge artwork
    // (a great white shark curled into a crescent). fillPolygon drops the vertices of long polygons, so the shark is split into small convex pieces (chalk);
    // the last LOGO_HOLES polygons are the eye and gill slits (void).
    private const LOGO_W      = 400;
    private const LOGO_H      = 331;
    private const LOGO_HOLES  = 4;

    private var _fTime as Graphics.VectorFont or Null = null;   // 112 em
    private var _fVal  as Graphics.VectorFont or Null = null;   // 16 em
    private var _fLab  as Graphics.VectorFont or Null = null;   // 10 em
    private var _fTag  as Graphics.VectorFont or Null = null;   // 12 em

    private var _steps     as Number = 0;
    private var _goal      as Number = 10000;
    private var _litTeeth  as Number = -1;   // outer teeth lit in the static buffer

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_ASH;
        _colorSecondary = COLOR_CHALK;
        _colorAccent    = COLOR_GREEN;
        _colorDim       = COLOR_ASH_DK;
        _colorAlert     = COLOR_CRIM;
        _colorTime      = COLOR_CHALK;
    }

    // ================================================================
    //  RESOURCES - fonts exist only while the theme is active
    // ================================================================

    public function loadResources() as Void {
        refreshState();
        _fTime = makeFont(112);
        _fVal  = makeFont(16);
        _fLab  = makeFont(10);
        _fTag  = makeFont(12);
        ThemeBase.loadResources();
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _fTime = null;
        _fVal = null;
        _fLab = null;
        _fTag = null;
        _litTeeth = -1;
    }

    //! px is the em size; a Garmin vector font is sized by line height, which is 1.172 em for Roboto.
    private function makeFont(px as Number) as Graphics.VectorFont or Null {
        if (Graphics has :getVectorFont) {
            try {
                return Graphics.getVectorFont({
                    :face => ["RobotoCondensedBold", "Swiss721Regular", "RobotoRegular"],
                    :size => (px * FONT_EM_TO_SIZE * _scale + 0.5).toNumber()
                });
            } catch (e) {}
        }
        return null;
    }

    // ================================================================
    //  STEP METER - the number of lit teeth lives in the static buffer
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
        var teeth = _steps * 36 / _goal;
        _litTeeth = (teeth > 36) ? 36 : teeth;
    }

    //! Re-render the static buffer only when the number of lit teeth changes (at most 36 times a day).
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        var previous = _litTeeth;
        refreshState();
        if (_litTeeth != previous) {
            renderStaticBuffer();
        }
        ThemeBase.drawStaticLayer(dc);
    }

    //! The teeth replace the progress arc of ThemeBase.
    public function drawProgressArc(dc as Graphics.Dc) as Void {}

    // ================================================================
    //  STATIC LAYER - jaws bezel, auspex scanner, chapter badge
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var s  = _scale;
        var cx = _centerX;
        var cy = _centerY;

        dc.setColor(COLOR_RING, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 226 * s);
        dc.setColor(COLOR_ASH, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2));
        dc.drawCircle(cx, cy, 226 * s);

        // Outer row: step meter, from the top clockwise. Inner row: ornament, offset by half a tooth.
        for (var k = 0; k < 36; k++) {
            var on = k < _litTeeth;
            tooth(dc, 90 - 10 * k, TEETH_BASE, TEETH_TIP, OUT_HW,
                on ? COLOR_CRIM : COLOR_TOOTH_OFF, on ? COLOR_CRIM_DK : COLOR_TOOTH_OFF2);
        }
        for (var k = 0; k < 36; k++) {
            tooth(dc, 85 - 10 * k, INNER_BASE, INNER_TIP, IN_HW, COLOR_TOOTH_IN, COLOR_TOOTH_IN2);
        }

        dc.setColor(COLOR_VOID, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, INTERIOR_R * s);
        dc.setColor(COLOR_ASH_DK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, 183 * s);

        drawScanner(dc);
        drawLogo(dc);
    }

    //! One tooth pointing inwards: base at radius rb, tip at rt, centred on watch angle `deg`; two faces, light and dark.
    private function tooth(dc as Graphics.Dc, deg as Number, rb as Number, rt as Number, hw as Float,
            light as Number, dark as Number) as Void {
        var s = _scale;
        var a0 = (deg + hw) * Math.PI / 180.0;
        var a1 = deg * Math.PI / 180.0;
        var a2 = (deg - hw) * Math.PI / 180.0;
        var rbs = rb * s;
        var rts = rt * s;
        var sin1 = Math.sin(a1);
        var cos1 = Math.cos(a1);
        var p0 = [_centerX + rbs * Math.cos(a0), _centerY - rbs * Math.sin(a0)];
        var p1 = [_centerX + rbs * cos1, _centerY - rbs * sin1];
        var p2 = [_centerX + rbs * Math.cos(a2), _centerY - rbs * Math.sin(a2)];
        var tip = [_centerX + rts * cos1, _centerY - rts * sin1];
        dc.setColor(light, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([p0, p1, tip]);
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([p1, p2, tip]);
    }

    //! Range rings, crosshair, sweep trail with its leading line, and the N / E / S / W bearings.
    private function drawScanner(dc as Graphics.Dc) as Void {
        var s  = _scale;
        var cx = _centerX;
        var cy = _centerY;
        var r  = SCAN_R * s;

        dc.setPenWidth(1);
        dc.setColor(COLOR_SCAN_RING, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        dc.setColor(COLOR_SCAN_CORE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, 40 * s);
        dc.setColor(COLOR_SCAN_DASH, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < 18; j++) {
            dc.drawArc(cx, cy, 120 * s, Graphics.ARC_COUNTER_CLOCKWISE, j * 20, j * 20 + 10);
            dc.drawArc(cx, cy, 80 * s, Graphics.ARC_COUNTER_CLOCKWISE, j * 20, j * 20 + 10);
        }

        dc.setColor(COLOR_SCAN_CROSS, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, cy - r, cx, cy + r);
        dc.drawLine(cx - r, cy, cx + r, cy);

        for (var i = 0; i < 9; i++) {
            var a0 = (38 + 4 * i) * Math.PI / 180.0;
            var am = (40 + 4 * i) * Math.PI / 180.0;
            var a1 = (42 + 4 * i) * Math.PI / 180.0;
            dc.setColor(SWEEP[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx, cy],
                [cx + r * Math.cos(a0), cy - r * Math.sin(a0)],
                [cx + r * Math.cos(am), cy - r * Math.sin(am)],
                [cx + r * Math.cos(a1), cy - r * Math.sin(a1)]]);
        }
        var sweep = 38 * Math.PI / 180.0;
        dc.setColor(COLOR_SCAN_LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, cy, cx + r * Math.cos(sweep), cy - r * Math.sin(sweep));

        var font = pick(_fTag, Graphics.FONT_XTINY);
        var letters = ["N", "E", "S", "W"];
        for (var i = 0; i < 4; i++) {
            var a = (90 - 90 * i) * Math.PI / 180.0;
            dc.setColor((i == 0) ? COLOR_CRIM_HI : COLOR_ASH, Graphics.COLOR_TRANSPARENT);
            dc.drawText((cx + 175 * s * Math.cos(a)).toNumber(), (cy - 175 * s * Math.sin(a)).toNumber(), font,
                letters[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Chapter badge: the traced shark, LOGO_WIDTH px wide (454 px units) and centred on (centre, LOGO_Y).
    private function drawLogo(dc as Graphics.Dc) as Void {
        var k  = LOGO_WIDTH * _scale / LOGO_W;
        var x0 = _centerX - LOGO_W * k / 2;
        var y0 = LOGO_Y * _scale - LOGO_H * k / 2;
        var data = WatchUi.loadResource(Rez.JsonData.WarhammerLogo) as Dictionary;
        var polys = data["polys"] as Array;
        var holeFrom = polys.size() - LOGO_HOLES;
        var shapes = [];
        for (var i = 0; i < polys.size(); i++) {
            var flat = polys[i] as Array<Number>;
            var pts = [];
            for (var j = 0; j + 1 < flat.size(); j += 2) {
                pts.add([x0 + flat[j] * k, y0 + flat[j + 1] * k]);
            }
            shapes.add(pts);
        }
        // The anti-aliased edges of neighbouring pieces leave faint seams; drawing the chalk pieces three times closes them.
        dc.setColor(COLOR_CHALK, Graphics.COLOR_TRANSPARENT);
        for (var pass = 0; pass < 3; pass++) {
            for (var i = 0; i < holeFrom; i++) {
                dc.fillPolygon(shapes[i]);
            }
        }
        dc.setColor(COLOR_VOID, Graphics.COLOR_TRANSPARENT);
        for (var i = holeFrom; i < shapes.size(); i++) {
            dc.fillPolygon(shapes[i]);
        }
    }

    //! A length in 454 px units as device pixels, never below 1.
    private function px(v as Numeric) as Number {
        var p = (v * _scale + 0.5).toNumber();
        return (p < 1) ? 1 : p;
    }

    // ================================================================
    //  DYNAMIC LAYER - contacts, tag, time, BLOOD TIDE
    // ================================================================

    //! The four fields are contacts on the scanner at 128, 52, 232 and 308 degrees: a blip with the value beside it.
    public function drawDataFields(dc as Graphics.Dc) as Void {
        drawContact(dc, _fieldTopLeft, 128.0, true);
        drawContact(dc, _fieldTopRight, 52.0, false);
        drawContact(dc, _fieldBottomLeft, 232.0, true);
        drawContact(dc, _fieldBottomRight, 308.0, false);
    }

    private function drawContact(dc as Graphics.Dc, type as Number, angle as Float, left as Boolean) as Void {
        if (type == FIELD_OFF) { return; }
        var data = getFieldDataStr(type);
        var value = data[1] as String;
        if (value.length() == 0) { return; }
        var label = data[0] as String;

        var s = _scale;
        var a = angle * Math.PI / 180.0;
        var x = _centerX + CONTACT_R * s * Math.cos(a);
        var y = _centerY - CONTACT_R * s * Math.sin(a);
        var dir = left ? -1 : 1;

        dc.setColor(COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2));
        dc.drawCircle(x, y, 6 * s);
        dc.fillCircle(x, y, 2.4 * s);
        dc.setPenWidth(1);
        dc.drawLine(x + dir * 6 * s, y, x + dir * 12 * s, y);

        var tx = x + dir * 15 * s;
        var just = left ? Graphics.TEXT_JUSTIFY_RIGHT : Graphics.TEXT_JUSTIFY_LEFT;
        var valueBase = y + 5 * s;
        if (label.length() > 0) {
            drawBaselineText(dc, tx, y - 3 * s, pick(_fLab, Graphics.FONT_XTINY), label, just, 1);
            valueBase = y + 13 * s;
        }
        dc.setColor(COLOR_CHALK, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, tx, valueBase, pick(_fVal, Graphics.FONT_XTINY), value, just, 0);
    }

    public function drawCenterElement(dc as Graphics.Dc) as Void {
        var pct = _steps * 100 / _goal;
        if (pct > 999) { pct = 999; }   // keeps the text between the contacts
        var text = (WatchUi.loadResource(Rez.Strings.LabelSteps) as String) + " " + pct.toString() + "%";
        dc.setColor(COLOR_CRIM_HI, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, TAG_BASELINE * _scale, pick(_fTag, Graphics.FONT_XTINY), text,
            Graphics.TEXT_JUSTIFY_CENTER, 3);
    }

    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        var font = pick(_fTime, Graphics.FONT_NUMBER_HOT);
        var base = TIME_BASELINE * _scale;
        var off  = 3 * _scale;
        dc.setColor(COLOR_TIME_SHD, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX + off, base + off, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_CHALK, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, base, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
    }

    //! The battery as BLOOD TIDE: a label with the percentage and a 10-notch bar (the date is one of the contacts).
    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var bat = 0;
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            bat = stats.battery.toNumber();
        }
        dc.setColor(COLOR_CRIM_HI, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, BAT_BASELINE * _scale, pick(_fTag, Graphics.FONT_XTINY),
            "BLOOD TIDE " + bat.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER, 3);

        // 10 notches, 120 px wide with 2 px gaps (10.2 px each), 6 px high
        var filled = (bat + 5) / 10;
        var y = px(BAT_BAR_Y);
        var h = px(6);
        for (var i = 0; i < 10; i++) {
            var x0 = ((167 + i * 12.2) * _scale + 0.5).toNumber();
            var x1 = ((167 + i * 12.2 + 10.2) * _scale + 0.5).toNumber();
            dc.setColor((i < filled) ? COLOR_CRIM : COLOR_CRIM_OFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0, y, x1 - x0, h);
        }
    }

    // ================================================================
    //  AOD - ring outline, scanner crosshair and the time, shifted every minute against burn-in
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var time = System.getClockTime();
        var cx = _centerX + (time.min % 5) * 5 - 10;
        var cy = _centerY + (time.min % 7) * 5 - 15;
        var k  = AOD_SCALE * _scale;

        dc.setColor(COLOR_ASH_DK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, 224 * k);
        dc.setColor(COLOR_SCAN_CORE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 60 * k, cy, cx + 60 * k, cy);
        dc.drawLine(cx, cy - 60 * k, cx, cy + 60 * k);

        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(COLOR_AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, pick(_fTime, Graphics.FONT_NUMBER_HOT), timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ================================================================
    //  TEXT HELPERS (same as in DawnwalkerTheme)
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
