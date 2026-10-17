import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

//! Dawnwalker theme - active 17:00-19:00 (Dusk).
//! Night-indigo sky, a castle against the rising sun, and a 24-hour day/night ring
//! with a sun/moon marker that follows the current time (noon at the top, midnight at the bottom).
class DawnwalkerTheme extends ThemeBase {

    private const COLOR_DAWN   = 0xF2A541;
    private const COLOR_DUSK   = 0xD2552E;
    private const COLOR_NIGHT  = 0x2A2A5A;
    private const COLOR_VIOLET = 0x7B6FA8;
    private const COLOR_MOON   = 0xC9C6E6;
    private const COLOR_STAR   = 0x6E6A9A;

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_MOON;
        _colorSecondary = COLOR_VIOLET;
        _colorAccent    = COLOR_DAWN;
        _colorDim       = COLOR_NIGHT;
        _colorAlert     = 0xC1272D;
        _colorTime      = 0xF5D9A8;
    }

    // ================================================================
    //  BACKGROUND - stars + castle-and-sun emblem (static, buffered)
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // Stars: fixed pseudo-random sky (tiny LCG, so every redraw looks identical)
        var seed = 7;
        for (var i = 0; i < 140; i++) {
            seed = (seed * 75 + 74) % 65537;
            var ang = (seed % 360) * Math.PI / 180.0;
            seed = (seed * 75 + 74) % 65537;
            var rad = (72 + seed % 126) * _scale;
            var x = _centerX + rad * Math.cos(ang);
            var y = _centerY - rad * Math.sin(ang);

            // Keep the emblem and the text band (time, date, battery, bottom fields) clear
            var inEmblem = (y < 190 * _scale && x > 130 * _scale && x < 324 * _scale);
            var inText   = (y > 205 * _scale && y < 385 * _scale && x > 90 * _scale && x < 364 * _scale);
            // ...and the two upper data-field labels
            var nearLabel = (y > 80 * _scale && y < 150 * _scale && (x < 175 * _scale || x > 279 * _scale));
            if (inEmblem || inText || nearLabel) { continue; }

            if (i % 5 == 0) {
                dc.setColor(COLOR_MOON, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 2);
            } else {
                dc.setColor(COLOR_STAR, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 1);
            }
        }

        drawEmblem(dc);
    }

    private function drawEmblem(dc as Graphics.Dc) as Void {
        var cx = _centerX;
        var cy = 118 * _scale;
        var k  = 1.2 * _scale;

        // Rays above the horizon
        dc.setColor(0xC8802F, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((2 * _scale).toNumber());
        for (var a = 0; a <= 180; a += 15) {
            var rad = a * Math.PI / 180.0;
            var r2 = ((a % 30 == 0) ? 62 : 54) * k;
            dc.drawLine(cx + 42 * k * Math.cos(rad), cy - 42 * k * Math.sin(rad),
                        cx + r2 * Math.cos(rad), cy - r2 * Math.sin(rad));
        }

        // Sun disc: three concentric steps fake a glow gradient
        dc.setColor(COLOR_DAWN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 34 * k);
        dc.setColor(0xF7BD6A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 26 * k);
        dc.setColor(0xFBD891, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 17 * k);

        // Mountains with a two-tower castle; indices 1..20 are the skyline, 0 and 21 close the shape
        var ridge = [[-64, 50], [-64, 20], [-52, 12], [-42, 20], [-32, 8], [-22, 18], [-16, 16],
                     [-14, -4], [-10, -14], [-6, -4], [-6, 6], [6, 6], [6, -8], [10, -18], [14, -8],
                     [16, 16], [22, 18], [32, 8], [42, 20], [52, 12], [64, 20], [64, 50]];
        var n = ridge.size();
        var poly = new [n];
        for (var i = 0; i < n; i++) {
            poly[i] = [cx + ridge[i][0] * k, cy + ridge[i][1] * k];
        }
        // Black fill: it only cuts the sun; the skyline line below makes the silhouette visible
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(poly);

        dc.setColor(0x7A74B0, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((2 * _scale).toNumber());
        for (var i = 1; i < n - 2; i++) {
            dc.drawLine(cx + ridge[i][0] * k, cy + ridge[i][1] * k,
                        cx + ridge[i + 1][0] * k, cy + ridge[i + 1][1] * k);
        }

        // Lit windows
        dc.setColor(COLOR_DAWN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 10 * k, cy + 2 * k, 1.5 * k);
        dc.fillCircle(cx + 10 * k, cy - 2 * k, 1.5 * k);
    }

    // ================================================================
    //  OUTER RING - 24-hour day/night dial (static part)
    // ================================================================

    public function drawOuterRing(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var r = 224 * _scale;
        dc.setPenWidth((6 * _scale).toNumber());

        // Day half (top): dawn on the left, gold noon, dusk on the right
        dc.setColor(0xE8795A, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, r, Graphics.ARC_COUNTER_CLOCKWISE, 150, 180);
        dc.setColor(COLOR_DAWN, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, r, Graphics.ARC_COUNTER_CLOCKWISE, 30, 150);
        dc.setColor(COLOR_DUSK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, r, Graphics.ARC_COUNTER_CLOCKWISE, 0, 30);

        // Night half (bottom)
        dc.setColor(0x6A2A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, r, Graphics.ARC_COUNTER_CLOCKWISE, 180, 215);
        dc.drawArc(_centerX, _centerY, r, Graphics.ARC_COUNTER_CLOCKWISE, 325, 360);
        dc.setColor(COLOR_NIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, r, Graphics.ARC_COUNTER_CLOCKWISE, 215, 325);

        // 24 hour ticks, bigger at 0 / 6 / 12 / 18
        for (var h = 0; h < 24; h++) {
            var a = (270.0 - 15.0 * h) * Math.PI / 180.0;
            var big = (h % 6 == 0);
            var r1 = (big ? 206 : 211) * _scale;
            var r2 = 219 * _scale;
            dc.setColor(big ? COLOR_MOON : COLOR_STAR, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(big ? (3 * _scale).toNumber() : 1);
            dc.drawLine(_centerX + r1 * Math.cos(a), _centerY - r1 * Math.sin(a),
                        _centerX + r2 * Math.cos(a), _centerY - r2 * Math.sin(a));
        }
    }

    // ================================================================
    //  CENTER ELEMENT - sun / moon marker on the 24-hour ring
    // ================================================================

    public function drawCenterElement(dc as Graphics.Dc) as Void {
        var t = System.getClockTime();
        var a = (270.0 - 15.0 * (t.hour + t.min / 60.0)) * Math.PI / 180.0;
        var r = 212 * _scale;
        var x = _centerX + r * Math.cos(a);
        var y = _centerY - r * Math.sin(a);
        var m = 8 * _scale;

        if (t.hour >= 6 && t.hour < 18) {
            dc.setColor(COLOR_DAWN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, m);
            dc.setColor(0xFFE2A8, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, m / 2);
        } else {
            // Crescent: moon disc with a black bite taken on the inner side
            dc.setColor(COLOR_MOON, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, m);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 3.5 * _scale * Math.cos(a), y + 3.5 * _scale * Math.sin(a), m - 1 * _scale);
        }
    }
}
