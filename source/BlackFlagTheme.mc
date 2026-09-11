import Toybox.Graphics;
import Toybox.Math;
import Toybox.System;
import Toybox.Lang;

class BlackFlagTheme extends ThemeBase {

    function initialize() {
        ThemeBase.initialize();
        _colorPrimary = 0xD4AF37;   // Jackdaw brass
        _colorSecondary = 0xF4EBD9; // Aged parchment
        _colorAccent = 0x00A896;    // Caribbean turquoise
        _colorDim = 0x52796F;       // Verdigris patina
        _colorAlert = 0x9E2A2B;     // Spanish port red
        _colorTime = 0xF4EBD9;      // Parchment
    }

    function drawBackground(dc) {
        dc.setColor(0x1A2F2A, Graphics.COLOR_TRANSPARENT); // Dark patina
        dc.setPenWidth(1);

        // Draw concentric dashed arcs (bathymetric contour lines)
        var r1 = 120 * _scale;
        var r2 = 160 * _scale;
        var r3 = 200 * _scale;

        // Simulate dashed lines using short arcs
        for (var i = 0; i < 360; i += 15) {
            dc.drawArc(_centerX, _centerY, r1.toNumber(), Graphics.ARC_CLOCKWISE, i, i - 5);
            dc.drawArc(_centerX, _centerY, r2.toNumber(), Graphics.ARC_CLOCKWISE, i + 5, i);
            dc.drawArc(_centerX, _centerY, r3.toNumber(), Graphics.ARC_CLOCKWISE, i + 10, i + 5);
        }
    }

    function drawOuterRing(dc) {
        var ringRadius = (_screenWidth / 2.0) - 10 * _scale;

        // Complete circle ring
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(_centerX, _centerY, ringRadius.toNumber());

        var innerTickRadius = ringRadius - 10 * _scale;
        var outerTickRadius = ringRadius;
        var innerSpokeRadius = ringRadius - 20 * _scale;
        var outerSpokeRadius = ringRadius + 5 * _scale;

        // Draw ticks
        for (var i = 0; i < 60; i++) {
            var angle = i * 6; // degrees
            var rad = angle * Math.PI / 180.0;
            var cosA = Math.cos(rad);
            var sinA = Math.sin(rad);

            var isMajor = (i % 5 == 0);
            
            dc.setPenWidth(isMajor ? 3 : 1);
            dc.setColor(isMajor ? _colorPrimary : _colorDim, Graphics.COLOR_TRANSPARENT);
            
            var tR1 = isMajor ? (ringRadius - 15 * _scale) : innerTickRadius;
            var x1 = (_centerX + tR1 * cosA).toNumber();
            var y1 = (_centerY + tR1 * sinA).toNumber();
            var x2 = (_centerX + outerTickRadius * cosA).toNumber();
            var y2 = (_centerY + outerTickRadius * sinA).toNumber();
            
            dc.drawLine(x1, y1, x2, y2);
        }

        // Draw 8 helm spokes
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        for (var a = 0; a < 360; a += 45) {
            var rad = a * Math.PI / 180.0;
            var cosA = Math.cos(rad);
            var sinA = Math.sin(rad);

            var x1 = (_centerX + innerSpokeRadius * cosA).toNumber();
            var y1 = (_centerY + innerSpokeRadius * sinA).toNumber();
            var x2 = (_centerX + outerSpokeRadius * cosA).toNumber();
            var y2 = (_centerY + outerSpokeRadius * sinA).toNumber();

            dc.drawLine(x1, y1, x2, y2);
            dc.fillCircle(x2, y2, (3 * _scale).toNumber());
        }

        // Cardinal directions just inside the ring
        var textRadius = ringRadius - 35 * _scale;
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        // N
        dc.drawText(_centerX, (_centerY - textRadius).toNumber(), Graphics.FONT_TINY, "N", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // E
        dc.drawText((_centerX + textRadius).toNumber(), _centerY, Graphics.FONT_TINY, "E", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // S
        dc.drawText(_centerX, (_centerY + textRadius).toNumber(), Graphics.FONT_TINY, "S", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        // W
        dc.drawText((_centerX - textRadius).toNumber(), _centerY, Graphics.FONT_TINY, "W", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawCenterElement(dc) {
        var cy = _centerY - 40 * _scale;
        var rMain = 60 * _scale;
        var rSec = 40 * _scale;
        var rInner = 10 * _scale;
        
        // Draw 4 secondary points (NE, SE, SW, NW)
        dc.setColor(0x8C6E28, Graphics.COLOR_TRANSPARENT); // Darker brass
        for (var a = 45; a < 360; a += 90) {
            var rad = a * Math.PI / 180.0;
            var rad1 = (a - 90) * Math.PI / 180.0;
            var rad2 = (a + 90) * Math.PI / 180.0;
            
            var p1 = [(_centerX + rSec * Math.cos(rad)).toNumber(), (cy + rSec * Math.sin(rad)).toNumber()];
            var p2 = [(_centerX + rInner * Math.cos(rad1)).toNumber(), (cy + rInner * Math.sin(rad1)).toNumber()];
            var p3 = [(_centerX + rInner * Math.cos(rad2)).toNumber(), (cy + rInner * Math.sin(rad2)).toNumber()];
            dc.fillPolygon([p1, p2, p3]);
        }

        // Draw 4 primary points (N, E, S, W)
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        for (var a = 0; a < 360; a += 90) {
            var rad = a * Math.PI / 180.0;
            var rad1 = (a - 90) * Math.PI / 180.0;
            var rad2 = (a + 90) * Math.PI / 180.0;
            
            var p1 = [(_centerX + rMain * Math.cos(rad)).toNumber(), (cy + rMain * Math.sin(rad)).toNumber()];
            var p2 = [(_centerX + rInner * Math.cos(rad1)).toNumber(), (cy + rInner * Math.sin(rad1)).toNumber()];
            var p3 = [(_centerX + rInner * Math.cos(rad2)).toNumber(), (cy + rInner * Math.sin(rad2)).toNumber()];
            dc.fillPolygon([p1, p2, p3]);
        }

        // Center dot
        dc.fillCircle(_centerX, cy.toNumber(), (3 * _scale).toNumber());

        // Assassin's Creed Symbol (y approx 40-70)
        var acTopY = 40 * _scale;
        var acBotY = 80 * _scale;
        var acWidth = 40 * _scale;
        
        dc.setPenWidth(3);
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        
        // Left & right wing lines
        dc.drawLine(_centerX, acTopY.toNumber(), (_centerX - acWidth/2).toNumber(), acBotY.toNumber());
        dc.drawLine(_centerX, acTopY.toNumber(), (_centerX + acWidth/2).toNumber(), acBotY.toNumber());
        // Bottom curve up (inverted chevron shape for the center)
        dc.drawLine((_centerX - acWidth/2).toNumber(), acBotY.toNumber(), _centerX, (acBotY - 15 * _scale).toNumber());
        dc.drawLine((_centerX + acWidth/2).toNumber(), acBotY.toNumber(), _centerX, (acBotY - 15 * _scale).toNumber());
    }

    function drawAOD(dc) {
        var clockTime = System.getClockTime();
        var min = clockTime.min;
        var hour = clockTime.hour;
        var timeStr = Lang.format("$1$:$2$", [hour.format("%02d"), min.format("%02d")]);
        
        // Pixel shifting for burn-in protection
        var xOffset = (min % 10) * 2 - 9;
        var yOffset = (min % 11) * 2 - 10;
        var tx = _centerX + xOffset;
        var ty = _centerY + yOffset;
        
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        
        // Compass cross behind time
        dc.setPenWidth(1);
        dc.drawLine(tx, ty - 60, tx, ty + 60);
        dc.drawLine(tx - 60, ty, tx + 60, ty);
        
        // 4 cardinal dots
        dc.fillCircle(tx, ty - 70, 2);
        dc.fillCircle(tx, ty + 70, 2);
        dc.fillCircle(tx - 70, ty, 2);
        dc.fillCircle(tx + 70, ty, 2);
        
        // Time
        dc.drawText(tx, ty, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
