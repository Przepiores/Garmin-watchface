import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! Umbrella theme (class keeps the name ResidentEvilTheme).
//! Variant B of the approved W4 Outbreak x W5 Save Room mix, amber on warm black:
//!  - the Umbrella logo is the bezel and the step meter: 8 segments, one per 12.5% of the step goal;
//!    reached segments are lit, the rest sit halfway between the lit colour and the old dark level;
//!  - a huge time with a rust shadow, four inventory frames for the data fields,
//!    a STEPS tag, and the battery as an INK RIBBON.
//! Geometry is given in 454 px units (the approved preview) and multiplied by _scale.
class ResidentEvilTheme extends ThemeBase {

    // ── Palette: Save Room amber on warm black ──────────────────────
    private const COLOR_AMBER      = 0xE8A33D;
    private const COLOR_AMBER_AOD  = 0xA87420;
    private const COLOR_AMBER_EDGE = 0x7A5518;   // inner frame line
    private const COLOR_AMBER_DARK = 0x3B2910;   // empty INK RIBBON notches
    private const COLOR_PAPER      = 0xD9CBA6;   // values and the INK RIBBON label
    private const COLOR_LABEL      = 0xA98A52;
    private const COLOR_SHADOW     = 0x7A3A12;   // time shadow
    private const COLOR_FRAME_BG   = 0x120E08;
    private const COLOR_FRAME_EDGE = 0x8A6420;
    private const COLOR_BORDER     = 0x5A3A12;   // line around the face, outline in AOD

    // ── Logo colours: lit = steps reached, dim = not reached yet ────
    private const LOGO_RED        = 0xB3161F;
    private const LOGO_RED_EDGE   = 0x47090E;
    private const LOGO_PAPER      = 0xE0D2AE;
    private const LOGO_PAPER_EDGE = 0x8A7D62;
    private const DIM_RED         = 0x771218;
    private const DIM_RED_EDGE    = 0x32080B;
    private const DIM_PAPER       = 0x8F856C;
    private const DIM_PAPER_EDGE  = 0x564E3C;

    // Face vignette: 10 concentric discs, radius 150 down to 15 px in 15 px steps
    private const VIGNETTE = [0x070504, 0x0A0705, 0x0D0805, 0x100A06, 0x130C06,
                              0x160D07, 0x190F07, 0x1C1108, 0x1F1208, 0x221409];

    // Logo segment outlines from the official SVG (300 px logo, centre at 150,150), offsets from the centre.
    // Seven x,y points of two joined cubic Beziers (points 0-3 and 3-6), then the apex.
    private const RED_SHAPE = [56, -145, 56, -145, 28, -131, 0, -131, -28, -131, -56, -145, -56, -145, 0, -10];
    private const WHT_SHAPE = [-63, -142, -63, -142, -73, -112, -93, -92, -112, -73, -142, -63, -142, -63, -7, -7];

    private const LOGO_SCALE     = 1.4608;   // segment tips land on the screen edge (454 px face)
    private const AOD_LOGO_SCALE = 0.9;      // smaller in AOD so the burn-in shift never pushes the tips off screen
    private const CURVE_STEPS    = 8;        // line segments per Bezier
    private const FONT_EM_TO_SIZE = 1.172;   // Roboto: vector font size (line height) per em, see makeFont()

    // ── Layout, 454 px units. Time, both frame rows and INK RIBBON are 22 px higher than the first B draft. ──
    private const TAG_BASELINE    = 126;
    private const TIME_BASELINE   = 236;
    private const TIME_SHADOW     = 5;
    private const RIBBON_BASELINE = 334;

    private var _fTime   as Graphics.VectorFont or Null = null;   // 116 px
    private var _fTag    as Graphics.VectorFont or Null = null;   // 13 px
    private var _fLabel  as Graphics.VectorFont or Null = null;   // 10 px
    private var _fValue  as Graphics.VectorFont or Null = null;   // 15 px
    private var _fRibbon as Graphics.VectorFont or Null = null;   // 12 px

    private var _steps    as Number = 0;
    private var _goal     as Number = 10000;
    private var _litCount as Number = -1;   // segments currently lit in the static buffer

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_PAPER;
        _colorSecondary = COLOR_AMBER_AOD;
        _colorAccent    = COLOR_AMBER;
        _colorDim       = COLOR_BORDER;
        _colorAlert     = LOGO_RED;
        _colorTime      = COLOR_AMBER;
    }

    // ================================================================
    //  RESOURCES - fonts exist only while the theme is active
    // ================================================================

    public function loadResources() as Void {
        readSteps();
        _litCount = litSegments();
        _fTime   = makeFont(116);
        _fTag    = makeFont(13);
        _fLabel  = makeFont(10);
        _fValue  = makeFont(15);
        _fRibbon = makeFont(12);
        ThemeBase.loadResources();
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _fTime = null;
        _fTag = null;
        _fLabel = null;
        _fValue = null;
        _fRibbon = null;
        _litCount = -1;
    }

    //! px is the em size of the preview font; a Garmin vector font is sized by line height (ascent + descent),
    //! which for Roboto is 1.172 em (measured: size 116 -> ascent 92 + descent 24 -> "19:42" 227 px wide, preview 266 px at em 116).
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
    //  STEP METER - the number of lit segments lives in the static buffer
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

    //! One segment per 12.5% of the goal, 0..8
    private function litSegments() as Number {
        var n = _steps * 8 / _goal;
        return (n > 8) ? 8 : n;
    }

    //! Re-render the static buffer only when the number of lit segments changes (at most 8 times a day).
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        readSteps();
        var lit = litSegments();
        if (lit != _litCount) {
            _litCount = lit;
            renderStaticBuffer();
        }
        ThemeBase.drawStaticLayer(dc);
    }

    //! The logo ring replaces the bottom progress arc of ThemeBase.
    public function drawProgressArc(dc as Graphics.Dc) as Void {}

    // ================================================================
    //  STATIC LAYER - logo ring, vignette, inventory frames, face line
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // Whole segments first; the vignette disc below then covers their centres (the visible ring is r > 150)
        var k  = LOGO_SCALE * _scale;
        var cx = _centerX.toFloat();
        var cy = _centerY.toFloat();
        var red = shapeOffsets(RED_SHAPE, k);
        var wht = shapeOffsets(WHT_SHAPE, k);
        for (var i = 0; i < 8; i++) {
            var isRed = (i % 2 == 0);
            var lit = (i < _litCount);
            var fill = isRed ? (lit ? LOGO_RED : DIM_RED) : (lit ? LOGO_PAPER : DIM_PAPER);
            var edge = isRed ? (lit ? LOGO_RED_EDGE : DIM_RED_EDGE) : (lit ? LOGO_PAPER_EDGE : DIM_PAPER_EDGE);
            drawWedge(dc, isRed ? red : wht, cx, cy, isRed ? i * 45 : i * 45 + 45, fill, edge);
        }

        for (var i = 0; i < VIGNETTE.size(); i++) {
            dc.setColor(VIGNETTE[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_centerX, _centerY, (150 - i * 15) * _scale);
        }

        drawFrame(dc, 177, 108, 100, 26);   // STEPS tag
        drawFrame(dc, 130, 258, 90, 26);    // data field frames
        drawFrame(dc, 234, 258, 90, 26);
        drawFrame(dc, 130, 290, 90, 26);
        drawFrame(dc, 234, 290, 90, 26);
    }

    public function drawOuterRing(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(COLOR_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(_centerX, _centerY, 150 * _scale);
    }

    //! Flat x,y offsets (already scaled by k) of one segment: start point, two Beziers, apex.
    private function shapeOffsets(src as Array<Number>, k as Float) as Array<Float> {
        var out = [] as Array<Float>;
        out.add(k * src[0]);
        out.add(k * src[1]);
        for (var c = 0; c < 2; c++) {
            var b = c * 6;
            for (var j = 1; j <= CURVE_STEPS; j++) {
                var t = j.toFloat() / CURVE_STEPS;
                var u = 1.0 - t;
                var w0 = u * u * u;
                var w1 = 3.0 * u * u * t;
                var w2 = 3.0 * u * t * t;
                var w3 = t * t * t;
                out.add(k * (w0 * src[b]     + w1 * src[b + 2] + w2 * src[b + 4] + w3 * src[b + 6]));
                out.add(k * (w0 * src[b + 1] + w1 * src[b + 3] + w2 * src[b + 5] + w3 * src[b + 7]));
            }
        }
        out.add(k * src[14]);
        out.add(k * src[15]);
        return out;
    }

    //! Rotate a segment by deg (clockwise) around (cx, cy); fill it unless fill is COLOR_TRANSPARENT, then outline it.
    private function drawWedge(dc as Graphics.Dc, off as Array<Float>, cx as Float, cy as Float,
            deg as Number, fill as Number, edge as Number) as Void {
        var a  = deg * Math.PI / 180.0;
        var cs = Math.cos(a);
        var sn = Math.sin(a);
        var pts = [];
        for (var i = 0; i < off.size(); i += 2) {
            pts.add([cx + off[i] * cs - off[i + 1] * sn, cy + off[i] * sn + off[i + 1] * cs]);
        }
        if (fill != Graphics.COLOR_TRANSPARENT) {
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(pts);
        }
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var p = pts[i] as [Float, Float];
            var q = pts[(i + 1) % n] as [Float, Float];
            dc.drawLine(p[0], p[1], q[0], q[1]);
        }
    }

    //! Inventory frame: filled box, 2 px outer line, 1 px inner line 3 px inside.
    private function drawFrame(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number) as Void {
        var xs = (x * _scale).toNumber();
        var ys = (y * _scale).toNumber();
        var ws = (w * _scale).toNumber();
        var hs = (h * _scale).toNumber();
        var in3 = (3 * _scale).toNumber();
        dc.setColor(COLOR_FRAME_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xs, ys, ws, hs);
        dc.setColor(COLOR_FRAME_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(xs, ys, ws, hs);
        dc.setColor(COLOR_AMBER_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(xs + in3, ys + in3, ws - 2 * in3, hs - 2 * in3);
    }

    // ================================================================
    //  DYNAMIC LAYER - tag, time, data fields, INK RIBBON
    // ================================================================

    public function drawCenterElement(dc as Graphics.Dc) as Void {
        var text = (WatchUi.loadResource(Rez.Strings.LabelSteps) as String) + " " + (_steps * 100 / _goal).toString() + "%";
        dc.setColor(COLOR_AMBER, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, TAG_BASELINE * _scale, pick(_fTag, Graphics.FONT_XTINY), text,
            Graphics.TEXT_JUSTIFY_CENTER, 1);
    }

    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        var font = pick(_fTime, Graphics.FONT_NUMBER_HOT);
        var base = TIME_BASELINE * _scale;
        var off  = TIME_SHADOW * _scale;
        dc.setColor(COLOR_SHADOW, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX + off, base + off, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
        dc.setColor(COLOR_AMBER, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, base, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER, 0);
    }

    public function drawDataFields(dc as Graphics.Dc) as Void {
        drawField(dc, 130, 258, _fieldTopLeft);
        drawField(dc, 234, 258, _fieldTopRight);
        drawField(dc, 130, 290, _fieldBottomLeft);
        drawField(dc, 234, 290, _fieldBottomRight);
    }

    //! Label on the left, value on the right of a 90 px frame; the label is dropped when both would not fit
    //! with a 2 px gap (measured: "STEPS" 30 px + "12345" 40 px just fit in the 72 px between them).
    private function drawField(dc as Graphics.Dc, x as Number, y as Number, type as Number) as Void {
        if (type == FIELD_OFF) { return; }
        var data = getFieldDataStr(type);
        var value = data[1] as String;
        if (value.length() == 0) { return; }
        var label = data[0] as String;
        var fLabel = pick(_fLabel, Graphics.FONT_XTINY);
        var fValue = pick(_fValue, Graphics.FONT_XTINY);

        var right = (x + 82) * _scale;
        dc.setColor(COLOR_PAPER, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, right, (y + 19) * _scale, fValue, value, Graphics.TEXT_JUSTIFY_RIGHT, 0);

        var room = 72 * _scale - 2 * _scale - dc.getTextWidthInPixels(value, fValue);
        if (label.length() > 0 && spacedWidth(dc, label, fLabel, spacingPx(1)) <= room) {
            dc.setColor(COLOR_LABEL, Graphics.COLOR_TRANSPARENT);
            drawBaselineText(dc, (x + 10) * _scale, (y + 18) * _scale, fLabel, label, Graphics.TEXT_JUSTIFY_LEFT, 1);
        }
    }

    //! Battery as an INK RIBBON: label with the percentage and a 10-notch bar.
    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var bat = 0;
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            bat = stats.battery.toNumber();
        }
        dc.setColor(COLOR_PAPER, Graphics.COLOR_TRANSPARENT);
        drawBaselineText(dc, _centerX, RIBBON_BASELINE * _scale, pick(_fRibbon, Graphics.FONT_XTINY),
            "INK RIBBON " + bat.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER, 3);

        // 10 notches, 112 px wide with 2 px gaps (9.4 px each), 6 px high
        var filled = (bat + 5) / 10;
        var y = (341 * _scale).toNumber();
        var h = (6 * _scale).toNumber();
        for (var i = 0; i < 10; i++) {
            var x0 = ((171 + i * 11.4) * _scale).toNumber();
            var x1 = ((171 + i * 11.4 + 9.4) * _scale).toNumber();
            dc.setColor((i < filled) ? COLOR_AMBER : COLOR_AMBER_DARK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0, y, x1 - x0, h);
        }
    }

    // ================================================================
    //  AOD - segment outlines and the time, shifted every minute against burn-in
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var time = System.getClockTime();
        var cx = _centerX + (time.min % 5) * 5 - 10;
        var cy = _centerY + (time.min % 7) * 5 - 15;

        var k = LOGO_SCALE * AOD_LOGO_SCALE * _scale;
        var red = shapeOffsets(RED_SHAPE, k);
        var wht = shapeOffsets(WHT_SHAPE, k);
        for (var i = 0; i < 8; i++) {
            var isRed = (i % 2 == 0);
            drawWedge(dc, isRed ? red : wht, cx.toFloat(), cy.toFloat(), isRed ? i * 45 : i * 45 + 45,
                Graphics.COLOR_TRANSPARENT, COLOR_BORDER);
        }
        // Keep only the outline of the ring band (r > 150 scaled): blank the inside where the segment edges converge
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(cx, cy, 150 * AOD_LOGO_SCALE * _scale);

        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(COLOR_AMBER_AOD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, pick(_fTime, Graphics.FONT_NUMBER_HOT), timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ================================================================
    //  TEXT HELPERS
    // ================================================================

    private function pick(font, fallback) {
        return (font != null) ? font : fallback;
    }

    //! Letter-spacing in device pixels: scaled like the layout but never below 1 px (0 would drop the spacing on small screens).
    private function spacingPx(spacing as Number) as Number {
        var px = (spacing * _scale + 0.5).toNumber();
        return (px < 1) ? 1 : px;
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
        var px = x.toNumber();
        var total = spacedWidth(dc, text, font, step);
        if (justify == Graphics.TEXT_JUSTIFY_CENTER) {
            px -= total / 2;
        } else if (justify == Graphics.TEXT_JUSTIFY_RIGHT) {
            px -= total;
        }
        var n = text.length();
        for (var i = 0; i < n; i++) {
            var ch = text.substring(i, i + 1);
            dc.drawText(px, y, font, ch, Graphics.TEXT_JUSTIFY_LEFT);
            px += dc.getTextWidthInPixels(ch, font) + step;
        }
    }
}
