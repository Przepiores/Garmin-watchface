import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Assassin's Creed theme, "Animus": a hexagonal bezel, a stacked time, a DNA strand and a column of data.
//!  - the bezel is 36 hexagonal cells; the step meter lights them from the top, clockwise (each cell = 1/36 of the goal), the next one is red;
//!  - a red dot rides the bezel on the current minute and a cyan one on the hour position;
//!  - inside is a honeycomb pattern, the Brotherhood insignia on top, the time stacked on the left (hours white, minutes cyan),
//!    a vertical DNA strand that lights from the bottom with the steps, and the four data fields as a column on the right;
//!  - the battery is the ANIMUS bar under the column.
//! Geometry is given in 454 px units and multiplied by _scale.
class AssassinTheme extends ThemeBase {

    // ── Palette ──────────────────────────────────────────────────────
    private const COLOR_WHITE      = 0xEAF6FF;
    private const COLOR_CYAN       = 0x7FD0FF;
    private const COLOR_RED        = 0xC21F38;
    private const COLOR_RED_HI     = 0xFF4D66;
    private const COLOR_RED_OFF    = 0x1A0F14;
    private const COLOR_MUTED      = 0x5E7F96;
    private const COLOR_HEX_OFF    = 0x04070A;   // bezel cells not yet reached: face and edge
    private const COLOR_HEX_EDGE   = 0x1C3345;
    private const COLOR_CELL_IN    = 0x112433;   // honeycomb lines, quiet in the middle and brighter toward the rim
    private const COLOR_CELL_MID   = 0x183247;
    private const COLOR_CELL_OUT   = 0x1E3D55;
    private const COLOR_CELL_LIT   = 0x0A2231;   // a few cells are filled
    private const COLOR_CELL_RED   = 0x2C0B14;
    private const COLOR_DNA_OFF    = 0x2A4A60;
    private const COLOR_RUNG_OFF   = 0x1E3A4F;
    private const COLOR_RUNG_ON    = 0x5AA6CC;
    private const COLOR_NODE_GLOW  = 0x1B4A66;
    private const COLOR_DOT_RING   = 0x04070A;
    private const COLOR_AOD_RING   = 0x1C3345;
    private const COLOR_AOD_TIME   = 0x6B8CA3;

    // ── Layout, 454 px units ─────────────────────────────────────────
    private const BEZEL_R         = 207;   // centres of the 36 bezel cells
    private const HEX_R           = 16;    // bezel cell circumradius, a vertex points along the radius
    private const HAIR_R          = 186;   // hairline closing the honeycomb
    private const HONEY_R         = 30;    // honeycomb cell circumradius; only whole cells inside HONEY_FIT are drawn
    private const HONEY_FIT       = 184;
    private const LOGO_Y          = 84;    // centre of the insignia
    private const LOGO_H_PX       = 46;    // insignia height
    private const TIME_X          = 92;    // left edge of the stacked time
    private const HOUR_BASELINE   = 212;
    private const MIN_BASELINE    = 320;
    private const DNA_X           = 240;
    private const DNA_Y0          = 130;
    private const DNA_Y1          = 320;
    private const DNA_AMP         = 8;
    private const DNA_PERIOD      = 44;
    private const COL_X           = 266;   // left edge of the data column
    private const ROW_LABEL_Y     = [138, 188, 238, 288];   // label baselines; the value baseline is 27 below
    private const BAT_BASELINE    = 344;
    private const BAT_BAR_Y       = 351;
    private const BAT_BAR_W       = 84;
    private const AOD_SCALE       = 0.9;   // smaller in AOD so the burn-in shift never pushes the ring off screen
    private const FONT_EM_TO_SIZE = 1.0;   // Swiss721 (the face that resolves here): vector font size equals the em, measured on the simulator

    // Insignia: resources/json/assassin_logo.json holds the convex pieces as flat x, y pairs on a 348 x 408 grid
    // (the A body with its flared feet, then the crescent). fillPolygon drops the vertices of long polygons, hence the small pieces.
    private const LOGO_W = 348;
    private const LOGO_H = 408;

    private var _fTime as Graphics.VectorFont or Null = null;   // 120 em
    private var _fAod  as Graphics.VectorFont or Null = null;   // 88 em
    private var _fVal  as Graphics.VectorFont or Null = null;   // 26 em
    private var _fLab  as Graphics.VectorFont or Null = null;   // 10 em

    private var _steps as Number = 0;
    private var _goal  as Number = 10000;
    private var _lit   as Number = -1;   // bezel cells lit in the static buffer

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_CYAN;
        _colorSecondary = COLOR_WHITE;
        _colorAccent    = COLOR_CYAN;
        _colorDim       = COLOR_MUTED;
        _colorAlert     = COLOR_RED;
        _colorTime      = COLOR_WHITE;
    }

    // ================================================================
    //  RESOURCES - fonts exist only while the theme is active
    // ================================================================

    public function loadResources() as Void {
        refreshState();
        _fTime = makeFont(120, true);
        _fAod  = makeFont(88, true);
        _fVal  = makeFont(28, false);
        _fLab  = makeFont(14, false);
        ThemeBase.loadResources();
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _fTime = null;
        _fAod = null;
        _fVal = null;
        _fLab = null;
        _lit = -1;
    }

    //! px is the em size; `light` asks for the light cut first (used by the time), the first face that exists wins.
    private function makeFont(px as Number, light as Boolean) as Graphics.VectorFont or Null {
        if (Graphics has :getVectorFont) {
            try {
                return Graphics.getVectorFont({
                    :face => light ? ["Swiss721Light", "Swiss721Regular", "RobotoRegular"] : ["Swiss721Regular", "RobotoRegular"],
                    :size => (px * FONT_EM_TO_SIZE * _scale + 0.5).toNumber()
                });
            } catch (e) {}
        }
        return null;
    }

    // ================================================================
    //  STEP METER - the number of lit cells lives in the static buffer
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
        var cells = _steps * 36 / _goal;
        _lit = (cells > 36) ? 36 : cells;
    }

    //! Re-render the static buffer only when the number of lit cells changes (at most 36 times a day).
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        var previous = _lit;
        refreshState();
        if (_lit != previous) {
            renderStaticBuffer();
        }
        ThemeBase.drawStaticLayer(dc);
    }

    // ================================================================
    //  STATIC LAYER - honeycomb, bezel, DNA strand, insignia
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        drawHoneycomb(dc);
        drawBezel(dc);
        drawStrand(dc);
        drawLogo(dc);
    }

    //! Six vertices of a hexagon with circumradius r; a vertex points along rotDeg (90 = pointy top).
    private function hexPts(cx as Numeric, cy as Numeric, r as Numeric, rotDeg as Numeric) as Array {
        var a = rotDeg * Math.PI / 180.0;
        var c = r * Math.cos(a);
        var s = r * Math.sin(a);
        var pts = [];
        for (var i = 0; i < 6; i++) {
            pts.add([cx + c, cy - s]);
            var next = c * 0.5 - s * 0.8660254;   // rotate the vertex by 60 degrees: one sin/cos per hexagon instead of six
            s = s * 0.5 + c * 0.8660254;
            c = next;
        }
        return pts;
    }

    //! Honeycomb of pointy-top cells, one cell on the centre. Lines get brighter toward the rim; a few cells are filled (picked by a fixed pattern).
    private function drawHoneycomb(dc as Graphics.Dc) as Void {
        var s = _scale;
        var w = 1.7320508 * HONEY_R * s;
        var rowH = 1.5 * HONEY_R * s;
        var fit = (HONEY_FIT - HONEY_R) * s;
        dc.setPenWidth(1);
        for (var row = -4; row <= 4; row++) {
            for (var col = -4; col <= 4; col++) {
                var cx = _centerX + (col + (((row & 1) == 0) ? 0.0 : 0.5)) * w;
                var cy = _centerY + row * rowH;
                var dx = cx - _centerX;
                var dy = cy - _centerY;
                var d = Math.sqrt(dx * dx + dy * dy);
                if (d > fit) { continue; }
                var pts = hexPts(cx, cy, HONEY_R * s, 90);

                var fillKind = ((row + 7) * 31 + (col + 7) * 17) % 11;
                if (d > 110 * s && fillKind == 0) {
                    dc.setColor(COLOR_CELL_LIT, Graphics.COLOR_TRANSPARENT);
                    dc.fillPolygon(hexPts(cx, cy, (HONEY_R - 1) * s, 90));
                } else if (d > 140 * s && fillKind == 5) {
                    dc.setColor(COLOR_CELL_RED, Graphics.COLOR_TRANSPARENT);
                    dc.fillPolygon(hexPts(cx, cy, (HONEY_R - 1) * s, 90));
                }

                dc.setColor((d < 70 * s) ? COLOR_CELL_IN : ((d < 120 * s) ? COLOR_CELL_MID : COLOR_CELL_OUT), Graphics.COLOR_TRANSPARENT);
                // Each side is shared with a neighbour: sides 3, 4, 5 are always drawn, sides 0, 1, 2 only when the upper-left, left or lower-left cell is missing.
                for (var i = 0; i < 6; i++) {
                    if (i < 3) {
                        var nx = (i == 1) ? cx - w : cx - w / 2;
                        var ny = (i == 0) ? cy - rowH : ((i == 1) ? cy : cy + rowH);
                        if (isCell(nx, ny, fit)) { continue; }
                    }
                    var p = pts[i] as Array;
                    var q = pts[(i + 1) % 6] as Array;
                    dc.drawLine(p[0], p[1], q[0], q[1]);
                }
            }
        }
        dc.setColor(COLOR_CELL_OUT, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_centerX, _centerY, HAIR_R * s);
    }

    //! True when a honeycomb cell centred on (x, y) is drawn, i.e. lies within `fit` of the screen centre.
    private function isCell(x as Float, y as Float, fit as Float) as Boolean {
        var dx = x - _centerX;
        var dy = y - _centerY;
        return Math.sqrt(dx * dx + dy * dy) <= fit;
    }

    //! 36 hexagonal cells; the step meter lights them from the top, clockwise. The next cell to fill is red.
    private function drawBezel(dc as Graphics.Dc) as Void {
        var s = _scale;
        for (var k = 0; k < 36; k++) {
            var deg = 90 - 10 * k;
            var a = deg * Math.PI / 180.0;
            var x = _centerX + BEZEL_R * s * Math.cos(a);
            var y = _centerY - BEZEL_R * s * Math.sin(a);
            var edge = COLOR_HEX_EDGE;
            var face = COLOR_HEX_OFF;
            if (k < _lit) {
                edge = COLOR_CYAN;
                face = COLOR_WHITE;
            } else if (k == _lit) {
                edge = COLOR_RED_HI;
                face = COLOR_RED;
            }
            dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(hexPts(x, y, HEX_R * s, deg));
            dc.setColor(face, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(hexPts(x, y, (HEX_R - 1.4) * s, deg));
        }
    }

    //! Vertical DNA strand: two sine strands with rungs, lit from the bottom in proportion to the steps, a bright node at the lit end.
    private function drawStrand(dc as Graphics.Dc) as Void {
        var s = _scale;
        var x0 = DNA_X * s;
        var litY = DNA_Y1 - _lit * (DNA_Y1 - DNA_Y0) / 36.0;

        dc.setPenWidth(1);
        for (var y = DNA_Y0 + 4; y <= DNA_Y1; y += 8) {
            var a = DNA_AMP * Math.sin(2.0 * Math.PI * (y - DNA_Y0) / DNA_PERIOD);
            if (a.abs() > 2) {
                dc.setColor((y >= litY) ? COLOR_RUNG_ON : COLOR_RUNG_OFF, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(x0 - a * s, y * s, x0 + a * s, y * s);
            }
        }

        dc.setPenWidth(px(2));
        for (var strand = 0; strand < 2; strand++) {
            var phase = strand * Math.PI;
            var prevX = 0.0;
            var prevY = 0.0;
            for (var y = DNA_Y0; y <= DNA_Y1; y += 5) {
                var xx = x0 + DNA_AMP * s * Math.sin(2.0 * Math.PI * (y - DNA_Y0) / DNA_PERIOD + phase);
                var yy = y * s;
                if (y > DNA_Y0) {
                    dc.setColor((y > litY) ? COLOR_WHITE : COLOR_DNA_OFF, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(prevX, prevY, xx, yy);
                }
                prevX = xx;
                prevY = yy;
            }
        }

        if (_lit > 0) {
            dc.setColor(COLOR_NODE_GLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x0, litY * s, 8.5 * s);
            dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x0, litY * s, 4 * s);
        }
    }

    //! The insignia, LOGO_H_PX tall (454 px units) and centred on (centre, LOGO_Y).
    private function drawLogo(dc as Graphics.Dc) as Void {
        var k  = LOGO_H_PX * _scale / LOGO_H;
        var x0 = _centerX - LOGO_W * k / 2;
        var y0 = LOGO_Y * _scale - LOGO_H * k / 2;
        var data = WatchUi.loadResource(Rez.JsonData.AssassinLogo) as Dictionary;
        var polys = data["polys"] as Array;
        var shapes = [];
        for (var i = 0; i < polys.size(); i++) {
            var flat = polys[i] as Array<Number>;
            var pts = [];
            for (var j = 0; j + 1 < flat.size(); j += 2) {
                pts.add([x0 + flat[j] * k, y0 + flat[j + 1] * k]);
            }
            shapes.add(pts);
        }
        // The anti-aliased edges of neighbouring pieces leave faint seams; drawing the pieces twice closes them.
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var pass = 0; pass < 2; pass++) {
            for (var i = 0; i < shapes.size(); i++) {
                dc.fillPolygon(shapes[i]);
            }
        }
    }

    //! A length in 454 px units as device pixels, never below 1.
    private function px(v as Numeric) as Number {
        var p = (v * _scale + 0.5).toNumber();
        return (p < 1) ? 1 : p;
    }

    // ================================================================
    //  DYNAMIC LAYER - minute and hour markers, time, data column, ANIMUS bar
    // ================================================================

    //! The step meter lives in the bezel, so this hook draws the two markers riding on it: red = minute, cyan = hour.
    public function drawProgressArc(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        dot(dc, 90 - ((time.hour % 12) * 30 + time.min * 0.5), 3.6, COLOR_CYAN);
        dot(dc, 90 - 6 * time.min, 4.6, COLOR_RED_HI);
    }

    private function dot(dc as Graphics.Dc, deg as Numeric, r as Float, color as Number) as Void {
        var a = deg * Math.PI / 180.0;
        var x = _centerX + BEZEL_R * _scale * Math.cos(a);
        var y = _centerY - BEZEL_R * _scale * Math.sin(a);
        dc.setColor(COLOR_DOT_RING, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r + 1.6) * _scale);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r * _scale);
    }

    //! Hours white on top, minutes cyan below, both left-aligned at TIME_X.
    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var font = pick(_fTime, Graphics.FONT_NUMBER_HOT);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, TIME_X * _scale, HOUR_BASELINE * _scale, font, time.hour.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT, 0);
        dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, TIME_X * _scale, MIN_BASELINE * _scale, font, time.min.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT, 0);
    }

    //! The four fields as a column, top to bottom: top left, top right, bottom left, bottom right.
    public function drawDataFields(dc as Graphics.Dc) as Void {
        drawRow(dc, _fieldTopLeft, ROW_LABEL_Y[0]);
        drawRow(dc, _fieldTopRight, ROW_LABEL_Y[1]);
        drawRow(dc, _fieldBottomLeft, ROW_LABEL_Y[2]);
        drawRow(dc, _fieldBottomRight, ROW_LABEL_Y[3]);
    }

    private function drawRow(dc as Graphics.Dc, type as Number, labelY as Number) as Void {
        if (type == FIELD_OFF) { return; }
        var data = getFieldDataStr(type);
        var value = data[1] as String;
        if (value.length() == 0) { return; }
        var label = data[0] as String;
        if (type == FIELD_DATE) {
            label = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week.toUpper();
        }

        var s = _scale;
        drawIcon(dc, type, COL_X + 7, labelY - 3);
        if (label.length() > 0) {
            dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, (COL_X + 22) * s, labelY * s, pick(_fLab, Graphics.FONT_XTINY), label, Graphics.TEXT_JUSTIFY_LEFT, 2);
        }
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, COL_X * s, (labelY + 27) * s, pick(_fVal, Graphics.FONT_XTINY), value, Graphics.TEXT_JUSTIFY_LEFT, 0);
    }

    //! A 14 px icon centred on (x, y) in 454 px units: thermometer, mountains, footprints or calendar; any other field gets a dot.
    private function drawIcon(dc as Graphics.Dc, type as Number, x as Number, y as Number) as Void {
        var s = _scale;
        dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
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

    //! The battery as the ANIMUS bar under the data column.
    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var bat = 0;
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            bat = stats.battery.toNumber();
        }
        var s = _scale;
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, COL_X * s, BAT_BASELINE * s, pick(_fLab, Graphics.FONT_XTINY),
            "ANIMUS " + bat.toString() + "%", Graphics.TEXT_JUSTIFY_LEFT, 2);

        var y = BAT_BAR_Y * s;
        var h = px(5);
        dc.setColor(COLOR_RED_OFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(COL_X * s, y, BAT_BAR_W * s, h);
        if (bat > 0) {
            dc.setColor(COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(COL_X * s, y, BAT_BAR_W * s * bat / 100.0, h);
        }
    }

    // ================================================================
    //  AOD - ring outline and the time, shifted every minute against burn-in
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var time = System.getClockTime();
        var cx = _centerX + (time.min % 5) * 5 - 10;
        var cy = _centerY + (time.min % 7) * 5 - 15;
        var k  = AOD_SCALE * _scale;

        dc.setColor(COLOR_AOD_RING, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, 224 * k);

        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(COLOR_AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, pick(_fAod, Graphics.FONT_NUMBER_HOT), timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ================================================================
    //  TEXT HELPERS (same as in WarhammerTheme)
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
