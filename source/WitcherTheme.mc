import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! The Witcher theme - active 08:00-12:00 (Morning).
//! Steel and silver on black, a Wolf School medallion with glowing cat eyes.
class WitcherTheme extends ThemeBase {

    private const COLOR_STEEL = 0xC9CED6;
    private const COLOR_GOLD  = 0x9A7B2F;
    private const COLOR_AMBER = 0xE0A526;   // cat-eye glow
    private const COLOR_IRON  = 0x3B3F46;
    private const COLOR_BLOOD = 0xC1121F;
    private const COLOR_PARCH = 0xE6D5A3;

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_STEEL;
        _colorSecondary = COLOR_GOLD;
        _colorAccent    = COLOR_AMBER;
        _colorDim       = COLOR_IRON;
        _colorAlert     = COLOR_BLOOD;
        _colorTime      = COLOR_PARCH;
    }

    // ================================================================
    //  BACKGROUND - crossed steel and silver swords + wolf medallion (static, buffered)
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var cy = 120 * _scale;
        drawSword(dc, cy, 45, 0xA9B0B8, 0x5C626A);    // steel sword, tip up-right
        drawSword(dc, cy, 135, 0xF0F3F7, 0x9AA0A8);   // silver sword, tip up-left
        drawMedallion(dc, cy);
    }

    //! One sword through the medallion centre: blade tip towards `deg` (math angle), hilt opposite.
    //! Works in a local frame (u along the blade, v across it) mapped to screen coordinates.
    private function drawSword(dc as Graphics.Dc, cy as Float, deg as Number, bladeColor as Number, fullerColor as Number) as Void {
        var a  = deg * Math.PI / 180.0;
        var ux = Math.cos(a);
        var uy = -Math.sin(a);
        var vx = -uy;
        var vy = ux;
        var k  = _scale;
        var ox = _centerX;

        // Blade with a dark fuller down the middle
        dc.setColor(bladeColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            swordPoint(ox, cy, ux, uy, vx, vy, 40 * k, -4 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, 92 * k, -4 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, 104 * k, 0),
            swordPoint(ox, cy, ux, uy, vx, vy, 92 * k, 4 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, 40 * k, 4 * k)
        ]);
        var f1 = swordPoint(ox, cy, ux, uy, vx, vy, 62 * k, 0);
        var f2 = swordPoint(ox, cy, ux, uy, vx, vy, 90 * k, 0);
        dc.setColor(fullerColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(f1[0], f1[1], f2[0], f2[1]);

        // Crossguard, grip and pommel on the hilt side
        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            swordPoint(ox, cy, ux, uy, vx, vy, -69 * k, -14 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, -63 * k, -14 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, -63 * k, 14 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, -69 * k, 14 * k)
        ]);
        dc.setColor(0x5A4420, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            swordPoint(ox, cy, ux, uy, vx, vy, -69 * k, -2.5 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, -92 * k, -2.5 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, -92 * k, 2.5 * k),
            swordPoint(ox, cy, ux, uy, vx, vy, -69 * k, 2.5 * k)
        ]);
        var p = swordPoint(ox, cy, ux, uy, vx, vy, -96 * k, 0);
        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], 5 * k);
    }

    // Tuple return type: Dc.fillPolygon only accepts [Numeric, Numeric] points.
    private function swordPoint(ox as Number, oy as Float, ux as Float, uy as Float, vx as Float, vy as Float,
            u as Numeric, v as Numeric) as [Float, Float] {
        return [ox + ux * u + vx * v, oy + uy * u + vy * v] as [Float, Float];
    }

    private function drawMedallion(dc as Graphics.Dc, cy as Float) as Void {
        var cx = _centerX;
        var r  = 56 * _scale;
        var k  = 0.95 * _scale;   // wolf unit scale

        dc.setColor(0x14161A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(COLOR_STEEL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((3 * _scale).toNumber());
        dc.drawCircle(cx, cy, r);
        dc.setColor(COLOR_IRON, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, r - 6 * _scale);

        // Gold studs at N / E / S / W
        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        var stud = 3 * _scale;
        dc.fillCircle(cx, cy - r, stud);
        dc.fillCircle(cx, cy + r, stud);
        dc.fillCircle(cx - r, cy, stud);
        dc.fillCircle(cx + r, cy, stud);

        // Wolf head: right half listed top to bottom, the left half is its mirror image
        var half = [[0, -20], [12, -24], [22, -38], [30, -14], [34, 2], [26, 16], [14, 28], [6, 34], [0, 40]];
        var n = half.size();
        var poly = new [2 * n - 2];
        for (var i = 0; i < n; i++) {
            poly[i] = [cx + half[i][0] * k, cy + half[i][1] * k];
        }
        for (var i = 1; i < n - 1; i++) {
            poly[n - 1 + i] = [cx - half[n - 1 - i][0] * k, cy + half[n - 1 - i][1] * k];
        }
        dc.setColor(COLOR_STEEL, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(poly);

        // Inner ears
        dc.setColor(COLOR_IRON, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 20 * k, cy - 31 * k], [cx + 14 * k, cy - 23 * k], [cx + 26 * k, cy - 19 * k]]);
        dc.fillPolygon([[cx - 20 * k, cy - 31 * k], [cx - 14 * k, cy - 23 * k], [cx - 26 * k, cy - 19 * k]]);

        // Cat eyes with slit pupils
        dc.setColor(COLOR_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 22 * k, cy - 6 * k], [cx + 8 * k, cy - 2 * k], [cx + 14 * k, cy + 4 * k]]);
        dc.fillPolygon([[cx - 22 * k, cy - 6 * k], [cx - 8 * k, cy - 2 * k], [cx - 14 * k, cy + 4 * k]]);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx + 14 * k, cy - 4 * k, cx + 14 * k, cy + 2 * k);
        dc.drawLine(cx - 14 * k, cy - 4 * k, cx - 14 * k, cy + 2 * k);

        // Brow line and nose
        dc.setPenWidth((2 * _scale).toNumber());
        dc.drawLine(cx, cy - 18 * k, cx, cy + 12 * k);
        dc.fillPolygon([[cx - 6 * k, cy + 29 * k], [cx + 6 * k, cy + 29 * k], [cx, cy + 37 * k]]);
    }

    // ================================================================
    //  OUTER RING - steel circle, minute studs, hour diamonds
    // ================================================================

    public function drawOuterRing(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        dc.setColor(COLOR_STEEL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((2 * _scale).toNumber());
        dc.drawCircle(_centerX, _centerY, 224 * _scale);

        // Minute studs
        dc.setColor(0x6B7078, Graphics.COLOR_TRANSPARENT);
        var studR = 216.0 * _scale;
        for (var i = 0; i < 60; i++) {
            if (i % 5 != 0) {
                var a = i * 6 * Math.PI / 180.0;
                dc.fillCircle(_centerX + studR * Math.cos(a), _centerY - studR * Math.sin(a), 1);
            }
        }

        // Hour diamonds: gold at 12 / 3 / 6 / 9, steel elsewhere
        var rc = 213.0 * _scale;
        for (var h = 0; h < 12; h++) {
            var a = h * 30 * Math.PI / 180.0;
            var cardinal = (h % 3 == 0);
            var len = (cardinal ? 9 : 6) * _scale;
            var wid = (cardinal ? 4 : 3) * _scale;
            var dx = Math.cos(a);
            var dy = -Math.sin(a);
            var px = _centerX + rc * dx;
            var py = _centerY + rc * dy;
            dc.setColor(cardinal ? COLOR_GOLD : COLOR_STEEL, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [px + len * dx, py + len * dy],
                [px - dy * wid, py + dx * wid],
                [px - len * dx, py - len * dy],
                [px + dy * wid, py - dx * wid]
            ]);
        }
    }
}
