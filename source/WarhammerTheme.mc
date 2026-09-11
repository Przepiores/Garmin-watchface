import Toybox.Graphics;
import Toybox.Math;
import Toybox.System;
import Toybox.Lang;
import Toybox.ActivityMonitor;

class WarhammerTheme extends ThemeBase {

    function initialize() {
        ThemeBase.initialize();
        
        // Carcharodons (Space Sharks) Night Theme Palette
        _colorPrimary = 0x8D99AE;   // Void-ash ceramite grey
        _colorSecondary = 0xEAEAEA; // Relic bone/chalk white
        _colorAccent = 0x00FF66;    // Auspex scanner green
        _colorDim = 0x2B2D42;       // Outer dark charcoal
        _colorAlert = 0xBA181B;     // Bloody tide crimson
        _colorTime = 0xEAEAEA;      // Chalk white
    }

    function drawBackground(dc) {
        // Clear background to pitch black void
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Niho Taniwha (Shark Tooth) tribal pattern
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        var r1 = 160 * _scale;
        var r2 = 190 * _scale;
        var numTeeth = 32;
        var angleStep = 360.0 / numTeeth;
        
        for (var i = 0; i < numTeeth; i++) {
            var a1 = (i * angleStep) * Math.PI / 180.0;
            var a2 = ((i + 0.5) * angleStep) * Math.PI / 180.0;
            var a3 = ((i + 1) * angleStep) * Math.PI / 180.0;
            
            // Outward pointing triangle
            var p1x = _centerX + r1 * Math.cos(a1);
            var p1y = _centerY - r1 * Math.sin(a1);
            var p2x = _centerX + r2 * Math.cos(a2);
            var p2y = _centerY - r2 * Math.sin(a2);
            var p3x = _centerX + r1 * Math.cos(a3);
            var p3y = _centerY - r1 * Math.sin(a3);
            dc.fillPolygon([[p1x, p1y], [p2x, p2y], [p3x, p3y]]);
            
            // Inward pointing triangle
            var p4x = _centerX + r2 * Math.cos(a1);
            var p4y = _centerY - r2 * Math.sin(a1);
            var p5x = _centerX + r1 * Math.cos(a2);
            var p5y = _centerY - r1 * Math.sin(a2);
            var p6x = _centerX + r2 * Math.cos(a3);
            var p6y = _centerY - r2 * Math.sin(a3);
            dc.fillPolygon([[p4x, p4y], [p5x, p5y], [p6x, p6y]]);
        }
    }

    function drawOuterRing(dc) {
        var r = 220 * _scale;
        
        // Outer mechanicus cog-wheel
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((4 * _scale).toNumber());
        dc.drawCircle(_centerX, _centerY, r);
        
        // Cog teeth
        var numCogs = 24;
        for (var i = 0; i < numCogs; i++) {
            var angle = (i * (360.0 / numCogs)) * Math.PI / 180.0;
            var cx = _centerX + (r + 2) * Math.cos(angle);
            var cy = _centerY - (r + 2) * Math.sin(angle);
            
            // Small rectangular cog tooth
            dc.fillPolygon([
                [cx - 3, cy - 3], [cx + 3, cy - 3],
                [cx + 3, cy + 3], [cx - 3, cy + 3]
            ]);
        }
        
        // Inner accent ring
        var innerR = 210 * _scale;
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((2 * _scale).toNumber());
        dc.drawCircle(_centerX, _centerY, innerR);
        
        // Tick marks
        for (var i = 0; i < 60; i++) {
            var angle = (i * 6) * Math.PI / 180.0;
            var cosA = Math.cos(angle);
            var sinA = Math.sin(angle);
            
            var isCardinal = (i % 15 == 0);
            var isMajor = (i % 5 == 0);
            
            var len = isCardinal ? 12 : (isMajor ? 8 : 4);
            var outR = 210 * _scale;
            var inR = outR - len * _scale;
            
            var pWidth = isCardinal ? 3 : (isMajor ? 2 : 1);
            dc.setPenWidth(pWidth);
            
            var c = isCardinal ? _colorSecondary : (isMajor ? _colorPrimary : _colorDim);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            
            var x1 = _centerX + outR * cosA;
            var y1 = _centerY - outR * sinA;
            var x2 = _centerX + inR * cosA;
            var y2 = _centerY - inR * sinA;
            
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    function drawCenterElement(dc) {
        var cy = _centerY - 30 * _scale;
        
        // Carcharodons Shark Jaw
        var outerJawR = 50 * _scale;
        var innerJawR = 35 * _scale;
        
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((2 * _scale).toNumber());
        // Jaw arc (from 30 deg to 150 deg in garmin coords)
        dc.drawArc(_centerX, cy, outerJawR, Graphics.ARC_COUNTER_CLOCKWISE, 30, 150);
        dc.drawArc(_centerX, cy, innerJawR, Graphics.ARC_COUNTER_CLOCKWISE, 30, 150);
        
        // Teeth along jaw
        dc.setColor(_colorSecondary, Graphics.COLOR_TRANSPARENT);
        var numJawTeeth = 8;
        var jawStart = 35;
        var jawEnd = 145;
        var step = (jawEnd - jawStart) / (numJawTeeth - 1.0);
        
        for (var i = 0; i < numJawTeeth; i++) {
            var ang = (jawStart + i * step) * Math.PI / 180.0;
            var midR = (outerJawR + innerJawR) / 2.0;
            
            var tx = _centerX + midR * Math.cos(ang);
            var ty = cy - midR * Math.sin(ang);
            
            var leftR = innerJawR;
            var rightR = outerJawR;
            var toothTipR = innerJawR - 12 * _scale;
            
            var px1 = _centerX + leftR * Math.cos(ang - 0.05);
            var py1 = cy - leftR * Math.sin(ang - 0.05);
            var px2 = _centerX + rightR * Math.cos(ang + 0.05);
            var py2 = cy - rightR * Math.sin(ang + 0.05);
            var px3 = _centerX + toothTipR * Math.cos(ang);
            var py3 = cy - toothTipR * Math.sin(ang);
            
            dc.fillPolygon([[px1, py1], [px2, py2], [px3, py3]]);
        }
        
        // Auspex Scanner Crosshair
        dc.setColor(_colorAccent, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var auspexR = 80 * _scale;
        dc.drawCircle(_centerX, _centerY, auspexR);
        
        // Crosshair lines
        var lineLen = 10 * _scale;
        dc.drawLine(_centerX, _centerY - auspexR, _centerX, _centerY - auspexR + lineLen);
        dc.drawLine(_centerX, _centerY + auspexR, _centerX, _centerY + auspexR - lineLen);
        dc.drawLine(_centerX - auspexR, _centerY, _centerX - auspexR + lineLen, _centerY);
        dc.drawLine(_centerX + auspexR, _centerY, _centerX + auspexR - lineLen, _centerY);
        
        // Center dot
        dc.fillCircle(_centerX, _centerY, 2 * _scale);
        
        // Imperial Aquila hints (angled wing lines at 10 and 2)
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((2 * _scale).toNumber());
        dc.drawLine(_centerX - 60*_scale, _centerY - 40*_scale, _centerX - 80*_scale, _centerY - 50*_scale);
        dc.drawLine(_centerX - 60*_scale, _centerY - 30*_scale, _centerX - 85*_scale, _centerY - 40*_scale);
        dc.drawLine(_centerX + 60*_scale, _centerY - 40*_scale, _centerX + 80*_scale, _centerY - 50*_scale);
        dc.drawLine(_centerX + 60*_scale, _centerY - 30*_scale, _centerX + 85*_scale, _centerY - 40*_scale);
    }

    function drawProgressArc(dc) {
        var info = ActivityMonitor.getInfo();
        var steps = 0;
        var goal = 1;
        
        if (info != null) {
            if (info.steps != null) { steps = info.steps; }
            if (info.stepGoal != null) { goal = info.stepGoal; }
        }
        if (goal == 0) { goal = 1; }
        
        var pct = steps.toFloat() / goal.toFloat();
        var isComplete = pct >= 1.0;
        if (pct > 1.0) { pct = 1.0; }
        
        var arcR = 195 * _scale;
        var startAngle = 210;
        var endAngle = 330;
        var totalAngle = endAngle - startAngle;
        
        // Background track
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((4 * _scale).toNumber());
        dc.drawArc(_centerX, _centerY, arcR, Graphics.ARC_COUNTER_CLOCKWISE, startAngle, endAngle);
        
        if (pct > 0) {
            var currentEnd = startAngle + (totalAngle * pct);
            var color = isComplete ? _colorSecondary : _colorAlert; // Bone white if 100%, otherwise crimson
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth((4 * _scale).toNumber());
            dc.drawArc(_centerX, _centerY, arcR, Graphics.ARC_COUNTER_CLOCKWISE, startAngle, currentEnd);
        }
    }

    function drawAOD(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var clockTime = System.getClockTime();
        // Pixel shifting logic (varies by minute)
        var shiftX = (clockTime.min % 5) - 2;
        var shiftY = ((clockTime.min / 5) % 5) - 2;
        
        var cx = _centerX + shiftX;
        var cy = _centerY + shiftY;
        
        // Auspex minimal crosshair
        dc.setColor(0x004422, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx - 30, cy, cx + 30, cy);
        dc.drawLine(cx, cy - 30, cx, cy + 30);
        
        // Minimal arc
        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, 100 * _scale, Graphics.ARC_COUNTER_CLOCKWISE, 180, 270);
        
        // Time
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        dc.setColor(0x4A4A5A, Graphics.COLOR_TRANSPARENT);
        if (_radialFont != null) {
            dc.drawText(cx, cy - 20, _radialFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(cx, cy - 20, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
