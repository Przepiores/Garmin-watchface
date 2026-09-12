import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

//! Main watch face view — theme dispatcher.
//! Selects the active theme based on current hour and delegates all drawing.
class Division2WatchFaceView extends WatchUi.WatchFace {

    // Theme instances
    private var _themes as Array or Null = null;
    private var _currentThemeIdx as Number = -1;
    private var _isAwake as Boolean = true;

    // ── Theme indices — must match _themes array order (see onLayout()) ──
    private const THEME_DUNE       = 0;
    private const THEME_DIVISION   = 1;
    private const THEME_BLACKFLAG  = 2;
    private const THEME_WARHAMMER  = 3;

    public function initialize() {
        WatchFace.initialize();
    }

    public function onLayout(dc as Graphics.Dc) as Void {
        // Create all 4 themes
        var dune      = new DuneTheme();
        var division  = new DivisionTheme();
        var blackFlag = new BlackFlagTheme();
        var warhammer = new WarhammerTheme();

        // Initialize geometry for each
        dune.init(dc);
        division.init(dc);
        blackFlag.init(dc);
        warhammer.init(dc);

        _themes = [dune, division, blackFlag, warhammer];
    }

    //! Determine which theme to use based on current hour
    //! THEME_DUNE(8-12), THEME_DIVISION(12-17), THEME_BLACKFLAG(17-22), THEME_WARHAMMER(22-8)
    private function getThemeIndex(hour as Number) as Number {
        if (hour >= 8  && hour < 12) { return THEME_DUNE; }       // morning
        if (hour >= 12 && hour < 17) { return THEME_DIVISION; }   // day
        if (hour >= 17 && hour < 22) { return THEME_BLACKFLAG; }  // evening
        return THEME_WARHAMMER;                                   // night
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        if (_themes == null) { return; }

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Clear to black
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var hour = System.getClockTime().hour;
        var idx = getThemeIndex(hour);

        // Switch theme if needed — load/unload resources
        if (idx != _currentThemeIdx) {
            if (_currentThemeIdx >= 0 && _currentThemeIdx < _themes.size()) {
                (_themes[_currentThemeIdx] as ThemeBase).unloadResources();
            }
            (_themes[idx] as ThemeBase).loadResources();
            _currentThemeIdx = idx;
        }

        var theme = _themes[idx] as ThemeBase;

        if (_isAwake) {
            theme.drawStaticLayer(dc);
            theme.drawProgressArc(dc);
            theme.drawCenterElement(dc);
            theme.drawDataFields(dc);
            theme.drawTime(dc);
            theme.drawBatteryRow(dc);
        } else {
            theme.drawAOD(dc);
        }
    }

    public function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    public function onSettingsChanged() as Void {
        if (_themes != null) {
            for (var i = 0; i < _themes.size(); i++) {
                (_themes[i] as ThemeBase).refreshFieldTypes();
            }
        }
    }
}
