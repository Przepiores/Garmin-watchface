import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Math;

//! Division 2 SHD Theme — active 12:00–17:00 (Day)
//! Orange tactical HUD with honeycomb background and SHD logo.
class DivisionTheme extends ThemeBase {

    // Division 2 color palette
    private const COLOR_SHD_ORANGE    = 0xFF6B00;
    private const COLOR_SHD_AMBER     = 0xCC4400;
    private const COLOR_SHD_RUST      = 0x882200;
    private const COLOR_SHD_HEX_MID   = 0x331000;
    private const COLOR_SHD_HEX_OUTER = 0x1A0800;
    private const COLOR_SHD_DIM       = 0x220800;
    private const COLOR_SHD_SEMI      = 0xBB5500;

    private var _shdLogo as Graphics.BitmapType or Null = null;

    public function initialize() {
        ThemeBase.initialize();
        _colorPrimary   = COLOR_SHD_ORANGE;
        _colorSecondary = COLOR_SHD_AMBER;
        _colorAccent    = 0x00E5FF;
        _colorDim       = COLOR_SHD_RUST;
        _colorAlert     = 0xFF1E27;
        _colorTime      = COLOR_SHD_SEMI;
    }

    public function loadResources() as Void {
        ThemeBase.loadResources();
        if (_shdLogo == null) {
            _shdLogo = WatchUi.loadResource(Rez.Drawables.ShdLogo) as Graphics.BitmapType;
        }
    }

    public function unloadResources() as Void {
        ThemeBase.unloadResources();
        _shdLogo = null;
    }

    // ================================================================
    //  HONEYCOMB BACKGROUND
    // ================================================================

    public function drawBackground(dc as Graphics.Dc) as Void {
        dc.setPenWidth(1);

        var hexRadius = 22.0 * _scale;
        var hexWidth = Math.sqrt(3.0) * hexRadius;
        var rowSpacing = hexRadius * 1.5;

        var hexOffsets = new [6];
        for (var i = 0; i < 6; i++) {
            var angle = i * Math.PI / 3.0 + (Math.PI / 6.0);
            hexOffsets[i] = [hexRadius * Math.cos(angle), hexRadius * Math.sin(angle)];
        }

        var innerBandSq = (90.0 * _scale) * (90.0 * _scale);
        var midBandSq   = (140.0 * _scale) * (140.0 * _scale);
        var outerLimitSq = (225.0 * _scale) * (225.0 * _scale);

        var extent = 225.0 * _scale;
        var row = 0;
        for (var cy = _centerY - extent; cy <= _centerY + extent; cy += rowSpacing) {
            var xOffset = (row % 2 == 0) ? 0.0 : (hexWidth / 2.0);
            for (var cx = _centerX - extent + xOffset; cx <= _centerX + extent; cx += hexWidth) {
                var dx = cx - _centerX;
                var dy = cy - _centerY;
                var distSq = dx * dx + dy * dy;

                if (distSq >= innerBandSq && distSq <= outerLimitSq) {
                    if (distSq >= midBandSq) {
                        dc.setColor(COLOR_SHD_HEX_OUTER, Graphics.COLOR_TRANSPARENT);
                    } else {
                        dc.setColor(COLOR_SHD_HEX_MID, Graphics.COLOR_TRANSPARENT);
                    }
                    // Draw hex inline for performance
                    for (var h = 0; h < 6; h++) {
                        var p1 = hexOffsets[h];
                        var p2 = hexOffsets[(h + 1) % 6];
                        dc.drawLine(cx + p1[0], cy + p1[1], cx + p2[0], cy + p2[1]);
                    }
                }
            }
            row++;
        }
    }

    // ================================================================
    //  OUTER RING — 3 segmented arcs + tick marks
    // ================================================================

    public function drawOuterRing(dc as Graphics.Dc) as Void {
        var outerR = 224.0 * _scale;
        var innerAccentR = 211.0 * _scale;

        // Main outer ring — 3 segments with gaps
        dc.setColor(COLOR_SHD_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(6);
        dc.drawArc(_centerX, _centerY, outerR, Graphics.ARC_COUNTER_CLOCKWISE, 35, 145);
        dc.drawArc(_centerX, _centerY, outerR, Graphics.ARC_COUNTER_CLOCKWISE, 155, 265);
        dc.drawArc(_centerX, _centerY, outerR, Graphics.ARC_COUNTER_CLOCKWISE, 275, 25);

        // Inner accent circle
        dc.setColor(COLOR_SHD_RUST, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(_centerX, _centerY, innerAccentR);

        // 60 tick marks
        for (var i = 0; i < 60; i++) {
            var angle = (i * 6.0 - 90.0) * Math.PI / 180.0;
            var isMajor = (i % 5 == 0);
            var isCardinal = (i == 0 || i == 15 || i == 30 || i == 45);

            var tickInnerR = isMajor ? innerAccentR : (218.0 * _scale);
            var tickOuterR = outerR;

            var x1 = _centerX + tickInnerR * Math.cos(angle);
            var y1 = _centerY + tickInnerR * Math.sin(angle);
            var x2 = _centerX + tickOuterR * Math.cos(angle);
            var y2 = _centerY + tickOuterR * Math.sin(angle);

            if (isCardinal) {
                dc.setColor(COLOR_SHD_ORANGE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
            } else if (isMajor) {
                dc.setColor(COLOR_SHD_AMBER, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
            } else {
                dc.setColor(COLOR_SHD_RUST, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
            }
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    // ================================================================
    //  SHD LOGO — centered upper area
    // ================================================================

    public function drawCenterElement(dc as Graphics.Dc) as Void {
        if (_shdLogo != null) {
            var logoSize = 200;
            var logoX = _centerX - logoSize / 2;
            var logoY = 30 * _scale;
            dc.drawBitmap(logoX.toNumber(), logoY.toNumber(), _shdLogo);
        }
    }

    // ================================================================
    //  AOD — Division amber time with rust arcs
    // ================================================================

    public function drawAOD(dc as Graphics.Dc) as Void {
        var time = System.getClockTime();

        var shiftX = (time.min % 5) * 5 - 10;
        var shiftY = (time.min % 7) * 5 - 15;
        var aodCenterX = _centerX + shiftX;
        var aodCenterY = _centerY + shiftY;

        dc.setColor(COLOR_SHD_RUST, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var aodOuterR = 224 * _scale;
        dc.drawArc(aodCenterX, aodCenterY, aodOuterR, Graphics.ARC_COUNTER_CLOCKWISE, 35, 145);
        dc.drawArc(aodCenterX, aodCenterY, aodOuterR, Graphics.ARC_COUNTER_CLOCKWISE, 155, 265);
        dc.drawArc(aodCenterX, aodCenterY, aodOuterR, Graphics.ARC_COUNTER_CLOCKWISE, 275, 25);

        var timeStr = Lang.format("$1$:$2$", [time.hour.format("%02d"), time.min.format("%02d")]);
        dc.setColor(COLOR_SHD_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(aodCenterX, aodCenterY, Graphics.FONT_NUMBER_HOT, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
