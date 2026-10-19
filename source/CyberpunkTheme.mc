import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! Cyberpunk theme, variant F of the approved concepts: the yellow cover-art face.
//!  - the whole face is yellow; only the sides carry towers in a light neon style (thin teal outline and a soft halo), so they never run under the time;
//!  - a readout strip with the four data fields sits above the time, on a thin rail with cyan end caps;
//!  - the step meter is the city skyline at the bottom: 24 buildings, black up to the progress, pink for the next one;
//!  - the battery is ten notches on the black base under the skyline.
//! Geometry is given in 454 px units (the approved preview) and multiplied by _scale.
class CyberpunkTheme extends ThemeBase {

    // ── Palette: cover-art yellow, blue-black, cyan and pink neon ───
    private const COLOR_YELLOW   = 0xFCF604;
    private const COLOR_BLACK    = 0x000211;   // the blue-black of the cover art bar
    private const COLOR_CYAN     = 0x19C9DD;
    private const COLOR_PINK     = 0xF04C7C;
    private const COLOR_BG_TOWER = 0xEDE600;   // near tower fill
    private const COLOR_FAR      = 0xF3EC00;   // far tower fill
    private const COLOR_UNBUILT  = 0xD2CA00;   // skyline buildings not reached yet
    private const COLOR_LINE     = 0x12A1B5;   // neon outline of the near towers
    private const COLOR_HALO_OUT = 0xE2F23C;
    private const COLOR_HALO_IN  = 0xB9EC5A;
    private const COLOR_RAIL     = 0x0F7E8A;   // rail, strip outline and dividers
    private const COLOR_NOTCH_OFF = 0x3A3700;
    private const COLOR_AOD      = 0xA8A200;
    private const COLOR_AOD_ARC  = 0x5A5600;

    // Background towers, x / top / width. The far row is a flat tint, the near row has the neon outline.
    private const FAR_TOWERS  = [18, 214, 34, 52, 168, 26, 92, 244, 16, 366, 236, 16, 386, 176, 28, 418, 220, 26];
    // x / top / width / roof: 0 flat, 1 stepped crown, 2 flat with an antenna, 3 slanted
    private const NEAR_TOWERS = [22, 262, 24, 0, 46, 176, 26, 2, 74, 234, 24, 1, 356, 240, 24, 1, 382, 160, 28, 2, 412, 256, 20, 3];
    private const GROUND = 420;   // baseline of the towers and the skyline
    private const HEIGHTS = [14, 22, 12, 30, 18, 26, 34, 16, 24, 12, 28, 20, 32, 14, 26, 18, 30, 12, 24, 34, 16, 22, 28, 14];

    private const FONT_EM_TO_SIZE = 1.172;   // RobotoCondensedBold: vector font size (line height) per em

    // Layout, 454 px units
    private const STRIP_X = 77;
    private const STRIP_Y = 116;
    private const CELL_W  = 75;

    private var _fTime  as Graphics.VectorFont or Null = null;   // 104 px
    private var _fValue as Graphics.VectorFont or Null = null;   // 19 px
    private var _fLabel as Graphics.VectorFont or Null = null;   // 10 px
    private var _fTitle as Graphics.VectorFont or Null = null;   // 16 px
    private var _fSmall as Graphics.VectorFont or Null = null;   // 13 px

    private var _steps    as Number = 0;
    private var _goal     as Number = 10000;
    private var _litCount as Number = -1;   // skyline buildings currently black in the static buffer

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_BLACK;
        _colorSecondary = COLOR_AOD;
        _colorAccent    = COLOR_CYAN;
        _colorDim       = COLOR_AOD_ARC;
        _colorAlert     = COLOR_PINK;
        _colorTime      = COLOR_BLACK;
    }

    // ================================================================
    //  RESOURCES - fonts exist only while the theme is active
    // ================================================================

    public function loadResources() as Void {
        readSteps();
        _litCount = litBuildings();
        _fTime  = makeFont(104);
        _fValue = makeFont(19);
        _fLabel = makeFont(10);
        _fTitle = makeFont(16);
        _fSmall = makeFont(13);
        ThemeBase.loadResources();
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _fTime = null;
        _fValue = null;
        _fLabel = null;
        _fTitle = null;
        _fSmall = null;
        _litCount = -1;
    }

    //! px is the em size of the preview font; a Garmin vector font is sized by line height, which for Roboto is 1.172 em.
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
    //  STEP METER - the number of black buildings lives in the static buffer
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

    private function litBuildings() as Number {
        var n = _steps * HEIGHTS.size() / _goal;
        return (n > HEIGHTS.size()) ? HEIGHTS.size() : n;
    }

    //! Re-render the static buffer only when the number of black buildings changes (at most 24 times a day).
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        readSteps();
        var lit = litBuildings();
        if (lit != _litCount) {
            _litCount = lit;
            renderStaticBuffer();
        }
        ThemeBase.drawStaticLayer(dc);
    }

    //! The skyline replaces the progress arc of ThemeBase.
    public function drawProgressArc(dc as Graphics.Dc) as Void {}

    // ================================================================
    //  STATIC LAYER - yellow face, towers, readout strip, skyline
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX, _centerY, _screenWidth / 2);

        dc.setColor(COLOR_FAR, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < FAR_TOWERS.size(); i += 3) {
            dc.fillRectangle(s(FAR_TOWERS[i]), s(FAR_TOWERS[i + 1]), s(FAR_TOWERS[i + 2]), s(GROUND - FAR_TOWERS[i + 1]));
        }
        for (var i = 0; i < NEAR_TOWERS.size(); i += 4) {
            drawTower(dc, NEAR_TOWERS[i], NEAR_TOWERS[i + 1], NEAR_TOWERS[i + 2], NEAR_TOWERS[i + 3]);
        }

        drawTitle(dc);
        drawStrip(dc);
        drawSkyline(dc);
    }

    private function s(v as Numeric) as Number {
        return (v * _scale + 0.5).toNumber();
    }

    //! Near tower: two halo passes (outer, inner) a few pixels wider than the body, the body, then the thin neon outline,
    //! the antenna and a few rows of dashed windows.
    private function drawTower(dc as Graphics.Dc, x as Number, top as Number, w as Number, roof as Number) as Void {
        towerShape(dc, x, top, w, roof, 3.5, COLOR_HALO_OUT);
        towerShape(dc, x, top, w, roof, 1.75, COLOR_HALO_IN);
        towerShape(dc, x, top, w, roof, 0, COLOR_BG_TOWER);

        var o = towerOutline(x, top, w, roof);
        dc.setColor(COLOR_LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i + 3 < o.size(); i += 2) {
            dc.drawLine(s(o[i]), s(o[i + 1]), s(o[i + 2]), s(o[i + 3]));
        }
        if (roof == 2) {
            var ax = x + w / 2.0;
            dc.drawLine(s(ax), s(top), s(ax), s(top - 18));
            dc.setColor(COLOR_PINK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(s(ax), s(top - 18), 2 * _scale);
            dc.setColor(COLOR_LINE, Graphics.COLOR_TRANSPARENT);
        }
        for (var y = top + 20; y < 330; y += 14) {
            for (var xx = x + 4; xx < x + w - 4; xx += 7) {
                dc.fillRectangle(s(xx), s(y), s(2), 1);
            }
        }
    }

    //! Flat x,y list of the roof line from the bottom left corner to the bottom right corner.
    private function towerOutline(x as Number, top as Number, w as Number, roof as Number) as Array<Numeric> {
        var r = x + w;
        if (roof == 1) {
            return [x, GROUND, x, top + 10, x + w * 0.2, top + 10, x + w * 0.2, top, x + w * 0.8, top, x + w * 0.8, top + 10, r, top + 10, r, GROUND];
        }
        if (roof == 3) {
            return [x, GROUND, x, top + 8, r, top, r, GROUND];
        }
        return [x, GROUND, x, top, r, top, r, GROUND];
    }

    //! Filled tower grown by `pad` px on the sides and the top (the stepped crown is two rectangles, so every piece stays convex).
    private function towerShape(dc as Graphics.Dc, x as Number, top as Number, w as Number, roof as Number, pad as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (roof == 1) {
            dc.fillRectangle(s(x - pad), s(top + 10 - pad), s(w + 2 * pad), s(GROUND - top - 10 + pad));
            dc.fillRectangle(s(x + w * 0.2 - pad), s(top - pad), s(w * 0.6 + 2 * pad), s(10 + pad));
        } else if (roof == 3) {
            dc.fillPolygon([[s(x - pad), s(GROUND)], [s(x - pad), s(top + 8 - pad)], [s(x + w + pad), s(top - pad)], [s(x + w + pad), s(GROUND)]]);
        } else {
            dc.fillRectangle(s(x - pad), s(top - pad), s(w + 2 * pad), s(GROUND - top + pad));
        }
    }

    //! NIGHT CITY between two short bars, above the strip.
    private function drawTitle(dc as Graphics.Dc) as Void {
        dc.setColor(COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, 86 * _scale, pick(_fTitle, Graphics.FONT_XTINY), "NIGHT CITY", Graphics.TEXT_JUSTIFY_CENTER, 5);
        dc.setPenWidth(px(2));
        dc.drawLine(s(104), s(81), s(146), s(81));
        dc.drawLine(s(308), s(81), s(350), s(81));
    }

    //! Rail with cyan end caps, the chamfered bar (top left and bottom right corners cut), dividers and the yellow cell marks.
    private function drawStrip(dc as Graphics.Dc) as Void {
        dc.setColor(COLOR_RAIL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(s(104), s(102), s(350), s(102));
        dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(s(96), s(99), s(10), s(6));
        dc.fillRectangle(s(348), s(99), s(10), s(6));

        var x0 = STRIP_X;
        var y0 = STRIP_Y;
        var x1 = STRIP_X + 4 * CELL_W;
        var y1 = STRIP_Y + 44;
        var pts = [[s(x0 + 10), s(y0)], [s(x1), s(y0)], [s(x1), s(y1 - 10)], [s(x1 - 10), s(y1)], [s(x0), s(y1)], [s(x0), s(y0 + 10)]];
        dc.setColor(COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(COLOR_RAIL, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < pts.size(); i++) {
            var p = pts[i] as Array<Number>;
            var q = pts[(i + 1) % pts.size()] as Array<Number>;
            dc.drawLine(p[0], p[1], q[0], q[1]);
        }
        for (var i = 1; i < 4; i++) {
            var dx = s(STRIP_X + CELL_W * i);
            dc.drawLine(dx, s(y0 + 8), dx, s(y0 + 36));
        }
        dc.setColor(COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            dc.fillRectangle(s(STRIP_X + CELL_W * i + CELL_W / 2.0 - 7), s(y0), s(14), s(3));
        }
    }

    //! Skyline: black up to the progress, pink for the next one, pale yellow for the rest, then the black base.
    private function drawSkyline(dc as Graphics.Dc) as Void {
        for (var i = 0; i < HEIGHTS.size(); i++) {
            var color = COLOR_UNBUILT;
            if (i < _litCount) {
                color = COLOR_BLACK;
            } else if (i == _litCount) {
                color = COLOR_PINK;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(s(108 + i * 9.92), s(GROUND - HEIGHTS[i]), s(8.4), s(HEIGHTS[i]));
        }
        dc.setColor(COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, s(GROUND), _screenWidth, _screenHeight - s(GROUND));
    }

    // ================================================================
    //  DYNAMIC LAYER - steps label, time, strip values, battery
    // ================================================================

    public function drawCenterElement(dc as Graphics.Dc) as Void {
        dc.setColor(COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, 336 * _scale, pick(_fSmall, Graphics.FONT_XTINY),
            (WatchUi.loadResource(Rez.Strings.LabelSteps) as String) + " " + (_steps * 100 / _goal).toString() + "%", Graphics.TEXT_JUSTIFY_CENTER, 3);
    }

    //! Black time with a cyan shadow 5 px right and 4 px down, like the shadow of the game logo.
    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        var font = pick(_fTime, Graphics.FONT_NUMBER_HOT);
        dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX + 5 * _scale, 262 * _scale, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, 258 * _scale, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
    }

    public function drawDataFields(dc as Graphics.Dc) as Void {
        drawCell(dc, 0, _fieldTopLeft);
        drawCell(dc, 1, _fieldTopRight);
        drawCell(dc, 2, _fieldBottomLeft);
        drawCell(dc, 3, _fieldBottomRight);
    }

    //! One strip cell: the label (cyan) over the value (yellow), both centred; without a label the value sits lower, in the middle.
    private function drawCell(dc as Graphics.Dc, index as Number, type as Number) as Void {
        if (type == FIELD_OFF) { return; }
        var data = getFieldDataStr(type);
        var value = data[1] as String;
        if (value.length() == 0) { return; }
        var label = data[0] as String;
        var cx = (STRIP_X + CELL_W * index + CELL_W / 2.0) * _scale;
        if (label.length() > 0) {
            dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, cx, (STRIP_Y + 16) * _scale, pick(_fLabel, Graphics.FONT_XTINY), label, Graphics.TEXT_JUSTIFY_CENTER, 1);
        }
        dc.setColor(COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, cx, (STRIP_Y + ((label.length() > 0) ? 37 : 30)) * _scale, pick(_fValue, Graphics.FONT_XTINY), value,
            Graphics.TEXT_JUSTIFY_CENTER, 0);
    }

    //! Battery: ten notches on the black base and POWER with the percentage under them.
    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var bat = 0;
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            bat = stats.battery.toNumber();
        }
        var filled = (bat + 5) / 10;
        for (var i = 0; i < 10; i++) {
            dc.setColor((i < filled) ? COLOR_YELLOW : COLOR_NOTCH_OFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(s(153.5 + i * 15), s(429), s(12), s(6));
        }
        dc.setColor(COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, 449 * _scale, pick(_fSmall, Graphics.FONT_XTINY), "POWER " + bat.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER, 2);
    }

    // ================================================================
    //  AOD - a yellow face would burn in, so only the time and three rim arcs, shifted every minute
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var time = System.getClockTime();
        var cx = _centerX + (time.min % 5) * 5 - 10;
        var cy = _centerY + (time.min % 7) * 5 - 15;

        dc.setColor(COLOR_AOD_ARC, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(px(2));
        var r = 224 * _scale;
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 35, 145);
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 155, 265);
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 275, 25);

        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(COLOR_AOD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, pick(_fTime, Graphics.FONT_NUMBER_HOT), timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ================================================================
    //  TEXT HELPERS
    // ================================================================

    private function px(v as Numeric) as Number {
        var p = (v * _scale + 0.5).toNumber();
        return (p < 1) ? 1 : p;
    }

    private function pick(font, fallback) {
        return (font != null) ? font : fallback;
    }

    //! Letter-spacing in device pixels: scaled like the layout but never below 1 px (0 would drop the spacing on small screens).
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
