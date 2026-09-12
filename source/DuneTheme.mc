import Toybox.Graphics;
import Toybox.Math;
import Toybox.System;
import Toybox.Lang;

class DuneTheme extends ThemeBase {
    
    public function initialize() {
        ThemeBase.initialize();
        
        // Color Palette
        _colorPrimary = 0xE9B872; // Arrakis spice gold
        _colorSecondary = 0xC27A47; // Desert terracotta
        _colorAccent = 0x00D2FF; // Eyes of Ibad cyan
        _colorDim = 0x8C5A3C; // Stillsuit basalt
        _colorAlert = 0x8C271E; // Crimson melange
        _colorTime = 0xD4A050; // Spice gold semi
    }

    public function drawBackground(dc as Graphics.Dc) as Void {
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        
        var baseY = 220 * _scale;
        var prevX = 0;
        var prevY1 = (baseY + 20 * _scale * Math.sin(0)).toNumber();
        var prevY2 = (baseY + 20 * _scale + 15 * _scale * Math.sin(1.0)).toNumber();
        var prevY3 = (baseY - 20 * _scale + 25 * _scale * Math.sin(2.0)).toNumber();
        
        for (var x = 10; x <= _screenWidth; x += 10) {
            var y1 = (baseY + 20 * _scale * Math.sin(x * 0.02)).toNumber();
            var y2 = (baseY + 20 * _scale + 15 * _scale * Math.sin(x * 0.025 + 1.0)).toNumber();
            var y3 = (baseY - 20 * _scale + 25 * _scale * Math.sin(x * 0.015 + 2.0)).toNumber();
            
            dc.drawLine(prevX, prevY1, x, y1);
            dc.drawLine(prevX, prevY2, x, y2);
            dc.drawLine(prevX, prevY3, x, y3);
            
            prevX = x;
            prevY1 = y1;
            prevY2 = y2;
            prevY3 = y3;
        }
    }

    public function drawOuterRing(dc as Graphics.Dc) as Void {
        dc.setPenWidth(4);
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        
        var rOuter = (_screenWidth / 2) - 4;
        var rInner = rOuter - 6;
        
        // 4 broken arc segments in gold (asymmetric gaps)
        // Garmin degrees: 0 is 3 o'clock, CCW positive
        dc.drawArc(_centerX, _centerY, rOuter, Graphics.ARC_COUNTER_CLOCKWISE, 15, 75);
        dc.drawArc(_centerX, _centerY, rOuter, Graphics.ARC_COUNTER_CLOCKWISE, 105, 165);
        dc.drawArc(_centerX, _centerY, rOuter, Graphics.ARC_COUNTER_CLOCKWISE, 195, 255);
        dc.drawArc(_centerX, _centerY, rOuter, Graphics.ARC_COUNTER_CLOCKWISE, 285, 345);
        
        // Inner accent ring in terracotta
        dc.setPenWidth(2);
        dc.setColor(_colorSecondary, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_centerX, _centerY, rInner, Graphics.ARC_COUNTER_CLOCKWISE, 0, 360);
        
        // 12 minimalist tick marks
        for (var i = 0; i < 12; i++) {
            var angleDeg = i * 30;
            var angleRad = angleDeg * Math.PI / 180.0;
            var cosA = Math.cos(angleRad);
            var sinA = Math.sin(angleRad);
            
            // Cardinal tick marks in cyan, others in gold
            if (i % 3 == 0) {
                dc.setColor(_colorAccent, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
                var x1 = _centerX + (rOuter - 15) * cosA;
                var y1 = _centerY - (rOuter - 15) * sinA;
                var x2 = _centerX + rOuter * cosA;
                var y2 = _centerY - rOuter * sinA;
                dc.drawLine(x1, y1, x2, y2);
            } else {
                dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                var x1 = _centerX + (rOuter - 8) * cosA;
                var y1 = _centerY - (rOuter - 8) * sinA;
                var x2 = _centerX + rOuter * cosA;
                var y2 = _centerY - rOuter * sinA;
                dc.drawLine(x1, y1, x2, y2);
            }
        }
    }

    public function drawCenterElement(dc as Graphics.Dc) as Void {
        // Arrakis Sun
        var sunY = (65 * _scale).toNumber();
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX, sunY, (30 * _scale).toNumber());
        
        // Sun Halo
        dc.setPenWidth(1);
        dc.setColor(_colorAccent, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_centerX, sunY, (35 * _scale).toNumber());
        
        // 4 concentric crescent arcs (Dune film title motif)
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        
        var motifBaseY = (140 * _scale).toNumber();
        dc.drawArc(_centerX, motifBaseY, (20 * _scale).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 190, 350);
        dc.drawArc(_centerX, motifBaseY + (10 * _scale).toNumber(), (30 * _scale).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 200, 340);
        dc.drawArc(_centerX, motifBaseY + (20 * _scale).toNumber(), (40 * _scale).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 210, 330);
        dc.drawArc(_centerX, motifBaseY + (30 * _scale).toNumber(), (50 * _scale).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 220, 320);
        
        // Ornithopter wings
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        
        var wingOut = (100 * _scale).toNumber();
        var wingIn = (40 * _scale).toNumber();
        var wingSpread = (10 * _scale).toNumber();
        
        // Left side wings (9 o'clock)
        dc.drawLine(_centerX - wingOut, _centerY - wingSpread, _centerX - wingIn, _centerY);
        dc.drawLine(_centerX - wingOut, _centerY + wingSpread, _centerX - wingIn, _centerY);
        
        // Right side wings (3 o'clock)
        dc.drawLine(_centerX + wingOut, _centerY - wingSpread, _centerX + wingIn, _centerY);
        dc.drawLine(_centerX + wingOut, _centerY + wingSpread, _centerX + wingIn, _centerY);
    }
    
    public function drawAOD(dc as Graphics.Dc) as Void {
        // Pixel-shifting for burn-in protection
        var clockTime = System.getClockTime();
        var shiftX = (clockTime.min % 3) - 1;
        var shiftY = (clockTime.min % 5) - 2;
        
        var tx = _centerX + shiftX;
        var ty = _centerY + shiftY;
        
        // Time in dim gold
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        if (_radialFont != null) {
            dc.drawText(tx, ty, _radialFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(tx, ty, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        
        // 2 thin crescent arcs above time
        dc.setPenWidth(2);
        dc.setColor(_colorSecondary, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(tx, ty - 60, 20, Graphics.ARC_COUNTER_CLOCKWISE, 200, 340);
        dc.drawArc(tx, ty - 50, 30, Graphics.ARC_COUNTER_CLOCKWISE, 210, 330);
    }
}
