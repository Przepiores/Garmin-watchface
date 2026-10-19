import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Weather;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.Application;

//! Base class for all watch face themes.
//! Each theme overrides drawing methods to create a unique visual identity.
class ThemeBase {

    // Screen geometry — set by init()
    protected var _screenWidth as Number = 454;
    protected var _screenHeight as Number = 454;
    protected var _centerX as Number = 227;
    protected var _centerY as Number = 227;
    protected var _scale as Float = 1.0;

    // Radial font (shared, CIQ 4.2.1+)
    protected var _radialFont as Graphics.VectorFont or Null = null;
    protected var _radialFontScale as Float = 1.0;

    // ── Palette (override in subclass constructor) ──────────────────
    protected var _colorPrimary   as Number = 0xFFFFFF;
    protected var _colorSecondary as Number = 0xAAAAAA;
    protected var _colorAccent    as Number = 0x00D2FF;
    protected var _colorDim       as Number = 0x333333;
    protected var _colorAlert     as Number = 0xFF0000;
    protected var _colorTime      as Number = 0xFFFFFF;

    // ── Data-field type identifiers (see getFieldDataStr()) ──────────
    public const FIELD_OFF      = 0;
    public const FIELD_WEATHER  = 1;
    public const FIELD_ALTITUDE = 2;
    public const FIELD_STEPS    = 3;
    public const FIELD_DATE     = 4;
    public const FIELD_HR       = 5;
    public const FIELD_KCAL     = 6;
    public const FIELD_DIST     = 7;

    // ── Cached data-field settings (see refreshFieldTypes()) ─────────
    protected var _fieldTopLeft     as Number = FIELD_WEATHER;
    protected var _fieldTopRight    as Number = FIELD_ALTITUDE;
    protected var _fieldBottomLeft  as Number = FIELD_STEPS;
    protected var _fieldBottomRight as Number = FIELD_DATE;

    //! Called once with dc dimensions
    public function init(dc as Graphics.Dc) as Void {
        _screenWidth  = dc.getWidth();
        _screenHeight = dc.getHeight();
        _centerX = _screenWidth / 2;
        _centerY = _screenHeight / 2;
        _scale   = _screenWidth / 454.0;

        if (Graphics has :getVectorFont) {
            try {
                _radialFont = Graphics.getVectorFont({
                    :face => ["RobotoCondensedBold", "Swiss721Regular", "RobotoRegular"],
                    :size => (24 * _scale * _radialFontScale).toNumber()
                });
            } catch (e) {
                _radialFont = null;
            }
        }

        refreshFieldTypes();
    }

    //! Re-read Field* properties. Called once from init() and again whenever
    //! Application.onSettingsChanged() fires (see Division2WatchFaceView.onSettingsChanged()).
    public function refreshFieldTypes() as Void {
        _fieldTopLeft     = getProp("FieldTopLeft", FIELD_WEATHER);
        _fieldTopRight    = getProp("FieldTopRight", FIELD_ALTITUDE);
        _fieldBottomLeft  = getProp("FieldBottomLeft", FIELD_STEPS);
        _fieldBottomRight = getProp("FieldBottomRight", FIELD_DATE);
    }

    // ── Static-layer offscreen buffer (background + outer ring) ─────
    protected var _bgBuffer as Graphics.BufferedBitmap or Null = null;

    //! Load heavy resources (bitmaps). Called when theme becomes active.
    public function loadResources() as Void {
        if (_bgBuffer == null) {
            var ref = Graphics.createBufferedBitmap({
                :width  => _screenWidth,
                :height => _screenHeight
            });
            _bgBuffer = ref.get() as Graphics.BufferedBitmap or Null;
        }
        renderStaticBuffer();
    }

    //! Unload heavy resources. Called when theme becomes inactive.
    public function unloadResources() as Void {
        _bgBuffer = null;
    }

    //! (Re)draw the static background + outer ring once into the offscreen buffer.
    protected function renderStaticBuffer() as Void {
        if (_bgBuffer == null) { return; }
        var bufDc = _bgBuffer.getDc();
        bufDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        bufDc.clear();
        drawBackground(bufDc);
        drawOuterRing(bufDc);
    }

    //! Draw the cached static layer, or fall back to direct drawing if buffering failed/unavailable.
    public function drawStaticLayer(dc as Graphics.Dc) as Void {
        if (_bgBuffer != null) {
            dc.drawBitmap(0, 0, _bgBuffer);
        } else {
            drawBackground(dc);
            drawOuterRing(dc);
        }
    }

    // ── Main drawing pipeline (override each in subclass) ──────────

    public function drawBackground(dc as Graphics.Dc) as Void {}

    public function drawOuterRing(dc as Graphics.Dc) as Void {}

    public function drawCenterElement(dc as Graphics.Dc) as Void {}

    //! Font used by drawTime(). Override to substitute a differently-sized vector font.
    protected function getTimeFont() {
        return Graphics.FONT_NUMBER_HOT;
    }

    //! Font used for the small accessory text (date/battery). Override for a differently-sized vector font.
    protected function getSmallFont() {
        return Graphics.FONT_XTINY;
    }

    public function drawTime(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$",
            [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(_colorTime, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX, (263 * _scale).toNumber(), getTimeFont(), timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    public function drawDataFields(dc as Graphics.Dc) as Void {
        var arcRadius = 181.0 * _scale;

        var tlType = _fieldTopLeft;
        var trType = _fieldTopRight;
        var blType = _fieldBottomLeft;
        var brType = _fieldBottomRight;

        // Top-Left at 140°
        var tlData = getFieldDataStr(tlType);
        if (tlType != FIELD_OFF && tlData[1].length() > 0) {
            var str = tlData[0].length() > 0 ? tlData[0] + " " + tlData[1] : tlData[1];
            drawTextAlongArc(dc, str, arcRadius, 140.0, -1, _colorPrimary, Graphics.FONT_XTINY);
        }

        // Top-Right at 40°
        var trData = getFieldDataStr(trType);
        if (trType != FIELD_OFF && trData[1].length() > 0) {
            var str = trData[0].length() > 0 ? trData[0] + " " + trData[1] : trData[1];
            drawTextAlongArc(dc, str, arcRadius, 40.0, -1, _colorPrimary, Graphics.FONT_XTINY);
        }

        // Bottom-Left at 240°
        var blData = getFieldDataStr(blType);
        if (blType != FIELD_OFF && blData[1].length() > 0) {
            var str = blData[0].length() > 0 ? blData[0] + " " + blData[1] : blData[1];
            drawTextAlongArc(dc, str, arcRadius, 240.0, 1, _colorPrimary, Graphics.FONT_XTINY);
        }

        // Bottom-Right at 300°
        var brData = getFieldDataStr(brType);
        if (brType != FIELD_OFF && brData[1].length() > 0) {
            var str = brData[0].length() > 0 ? brData[0] + " " + brData[1] : brData[1];
            drawTextAlongArc(dc, str, arcRadius, 300.0, 1, _colorPrimary, Graphics.FONT_XTINY);
        }
    }

    public function drawBatteryRow(dc as Graphics.Dc) as Void {
        var dateY = 319 * _scale;
        var batY  = 356 * _scale;

        // Date
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dayLabelStr = Lang.format("$1$ $2$", [info.day_of_week.toUpper(), info.day.format("%d")]);
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centerX, dateY.toNumber(), getSmallFont(), dayLabelStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Battery
        var batPct = 0;
        var sysStats = System.getSystemStats();
        if (sysStats != null && sysStats.battery != null) {
            batPct = sysStats.battery.toNumber();
        }
        var batStr = batPct.toString() + "%";

        var textWidth = dc.getTextWidthInPixels(batStr, getSmallFont());
        var iconW = 26 * _scale;
        var iconH = 12 * _scale;
        var gap   = 6 * _scale;
        var nubW  = 3 * _scale;
        var nubH  = 6 * _scale;
        var totalWidth = textWidth + gap + iconW + nubW;

        var startX = _centerX - (totalWidth / 2.0).toNumber();

        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, batY.toNumber(), getSmallFont(), batStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var iconX = startX + textWidth + gap;
        var iconY = batY - (iconH / 2);
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(iconX.toNumber(), iconY.toNumber(), iconW.toNumber(), iconH.toNumber());

        var nubY = batY - (nubH / 2);
        dc.fillRectangle((iconX + iconW).toNumber(), nubY.toNumber(), nubW.toNumber(), nubH.toNumber());

        var fillW = ((iconW - 4 * _scale) * batPct / 100).toNumber();
        if (fillW < 1 && batPct > 0) { fillW = 1; }

        if (batPct > 50) {
            dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        } else if (batPct > 20) {
            dc.setColor(_colorSecondary, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(_colorAlert, Graphics.COLOR_TRANSPARENT);
        }

        if (batPct > 0) {
            dc.fillRectangle((iconX + 2 * _scale).toNumber(), (iconY + 2 * _scale).toNumber(),
                fillW, (iconH - 4 * _scale).toNumber());
        }
    }

    public function drawProgressArc(dc as Graphics.Dc) as Void {
        var monInfo = ActivityMonitor.getInfo();
        var steps = 0;
        var stepGoal = 10000;

        if (monInfo != null) {
            if (monInfo.steps != null) { steps = monInfo.steps; }
            if (monInfo.stepGoal != null) { stepGoal = monInfo.stepGoal; }
        }
        if (stepGoal == 0) { stepGoal = 10000; }

        var progress = steps.toFloat() / stepGoal.toFloat();
        if (progress > 1.0) { progress = 1.0; }

        var arcRadius = 201.0 * _scale;
        var startAngle = 210;
        var totalArcDeg = 120;

        // Container arc
        dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(_centerX, _centerY, arcRadius,
            Graphics.ARC_COUNTER_CLOCKWISE, startAngle, startAngle + totalArcDeg);

        // End ticks
        var r1 = arcRadius - 5 * _scale;
        var r2 = arcRadius + 5 * _scale;

        var radStart = startAngle * Math.PI / 180.0;
        dc.drawLine(_centerX + r1 * Math.cos(radStart), _centerY - r1 * Math.sin(radStart),
                    _centerX + r2 * Math.cos(radStart), _centerY - r2 * Math.sin(radStart));

        var radEnd = (startAngle + totalArcDeg) * Math.PI / 180.0;
        dc.drawLine(_centerX + r1 * Math.cos(radEnd), _centerY - r1 * Math.sin(radEnd),
                    _centerX + r2 * Math.cos(radEnd), _centerY - r2 * Math.sin(radEnd));

        // Progress fill
        var progressDeg = (totalArcDeg * progress).toNumber();
        if (progressDeg > 0) {
            if (progress >= 1.0) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(_colorPrimary, Graphics.COLOR_TRANSPARENT);
            }
            dc.setPenWidth(6);
            dc.drawArc(_centerX, _centerY, arcRadius,
                Graphics.ARC_COUNTER_CLOCKWISE, startAngle, startAngle + progressDeg);
        }
    }

    public function drawAOD(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();

        var shiftX = (time.min % 5) * 5 - 10;
        var shiftY = (time.min % 7) * 5 - 15;
        var aodCenterX = _centerX + shiftX;
        var aodCenterY = _centerY + shiftY;

        dc.setColor(_colorDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var aodOuterR = 224 * _scale;
        dc.drawArc(aodCenterX, aodCenterY, aodOuterR, Graphics.ARC_COUNTER_CLOCKWISE, 35, 145);
        dc.drawArc(aodCenterX, aodCenterY, aodOuterR, Graphics.ARC_COUNTER_CLOCKWISE, 155, 265);
        dc.drawArc(aodCenterX, aodCenterY, aodOuterR, Graphics.ARC_COUNTER_CLOCKWISE, 275, 25);

        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(_colorSecondary, Graphics.COLOR_TRANSPARENT);
        dc.drawText(aodCenterX, aodCenterY, Graphics.FONT_NUMBER_HOT, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Shared utility methods ─────────────────────────────────────

    protected function getProp(key as String, defaultVal as Number) as Number {
        try {
            if (Application has :Properties) {
                var val = Application.Properties.getValue(key);
                if (val != null) { return val as Number; }
            } else {
                var val = Application.getApp().getProperty(key);
                if (val != null) { return val as Number; }
            }
        } catch (e) {}
        return defaultVal;
    }

    protected function getFieldDataStr(fieldType as Number) as Array {
        if (fieldType == FIELD_WEATHER) {
            var valStr = "--\u00B0";
            try {
                if (Weather has :getCurrentConditions) {
                    var conditions = Weather.getCurrentConditions();
                    if (conditions != null && conditions.temperature != null) {
                        valStr = conditions.temperature.format("%d") + "\u00B0";
                    }
                }
            } catch (e) {}
            return [WatchUi.loadResource(Rez.Strings.LabelNow) as String, valStr];
        } else if (fieldType == FIELD_ALTITUDE) {
            var valStr = "--";
            try {
                var actInfo = Activity.getActivityInfo();
                if (actInfo != null && actInfo.altitude != null) {
                    valStr = actInfo.altitude.toNumber().toString();
                }
            } catch (e) {}
            return [WatchUi.loadResource(Rez.Strings.LabelAlt) as String, valStr];
        } else if (fieldType == FIELD_STEPS) {
            var valStr = "0";
            var monInfo = ActivityMonitor.getInfo();
            if (monInfo != null && monInfo.steps != null) {
                valStr = monInfo.steps.toString();
            }
            return [WatchUi.loadResource(Rez.Strings.LabelSteps) as String, valStr];
        } else if (fieldType == FIELD_DATE) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            var valStr = Lang.format("$1$ $2$", [info.day.format("%d"), info.month.toUpper()]);
            return ["", valStr];
        } else if (fieldType == FIELD_HR) {
            var valStr = "--";
            var actInfo = Activity.getActivityInfo();
            if (actInfo != null && actInfo.currentHeartRate != null) {
                valStr = actInfo.currentHeartRate.toString();
            } else {
                var hrIter = ActivityMonitor.getHeartRateHistory(1, true);
                if (hrIter != null) {
                    var hrSample = hrIter.next();
                    if (hrSample != null && hrSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        valStr = hrSample.heartRate.toString();
                    }
                }
            }
            return [WatchUi.loadResource(Rez.Strings.LabelHR) as String, valStr];
        } else if (fieldType == FIELD_KCAL) {
            var valStr = "0";
            var monInfo = ActivityMonitor.getInfo();
            if (monInfo != null && monInfo.calories != null) {
                valStr = monInfo.calories.toString();
            }
            return [WatchUi.loadResource(Rez.Strings.LabelKcal) as String, valStr];
        } else if (fieldType == FIELD_DIST) {
            var valStr = "0.0";
            var monInfo = ActivityMonitor.getInfo();
            if (monInfo != null && monInfo.distance != null) {
                var sysInfo = System.getDeviceSettings();
                if (sysInfo.distanceUnits == System.UNIT_METRIC) {
                    valStr = (monInfo.distance / 100000.0).format("%.1f");
                } else {
                    valStr = (monInfo.distance / 160934.4).format("%.1f");
                }
            }
            return [WatchUi.loadResource(Rez.Strings.LabelDist) as String, valStr];
        }
        return ["", ""];
    }

    //! Draw text along a circular arc
    protected function drawTextAlongArc(dc as Graphics.Dc, text as String, radius as Float,
            centerAngleDeg as Float, direction as Number, color as Number, font) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var charCount = text.length();
        if (charCount == 0) { return; }

        if (_radialFont != null && dc has :drawRadialText) {
            var radialDir = (direction < 0) ? Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE : Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE;
            dc.drawRadialText(_centerX, _centerY, _radialFont, text, Graphics.TEXT_JUSTIFY_CENTER, centerAngleDeg, radius, radialDir);
        } else {
            var totalWidthPx = dc.getTextWidthInPixels(text, font);
            var spacedWidth = totalWidthPx.toFloat() * 1.3;
            var totalAngleRad = spacedWidth / radius;
            var totalAngleDeg = totalAngleRad * 180.0 / Math.PI;
            var charStepDeg = totalAngleDeg / charCount.toFloat();

            var startAngleDeg = centerAngleDeg
                - direction.toFloat() * totalAngleDeg / 2.0
                + direction.toFloat() * charStepDeg / 2.0;

            for (var i = 0; i < charCount; i++) {
                var angleDeg = startAngleDeg + direction.toFloat() * i.toFloat() * charStepDeg;
                var angleRad = angleDeg * Math.PI / 180.0;
                var x = _centerX + radius * Math.cos(angleRad);
                var y = _centerY - radius * Math.sin(angleRad);

                dc.drawText(x.toNumber(), y.toNumber(), font,
                    text.substring(i, i + 1),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }
}
