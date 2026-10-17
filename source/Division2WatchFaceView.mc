import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;

//! Main watch face view — theme dispatcher.
//! Selects one theme per local calendar day (the themes take turns in _themes order) and delegates all drawing.
class Division2WatchFaceView extends WatchUi.WatchFace {

    // Theme instances
    private var _themes as Array or Null = null;
    private var _currentThemeIdx as Number = -1;
    private var _isAwake as Boolean = true;

    public function initialize() {
        WatchFace.initialize();
    }

    public function onLayout(dc as Graphics.Dc) as Void {
        // New theme instances have no buffer yet; -1 forces loadResources() on the next onUpdate()
        _currentThemeIdx = -1;

        // Create all 5 themes
        var witcher      = new WitcherTheme();
        var division     = new DivisionTheme();
        var dawnwalker   = new DawnwalkerTheme();
        var residentEvil = new ResidentEvilTheme();
        var warhammer    = new WarhammerTheme();

        // Initialize geometry for each
        witcher.init(dc);
        division.init(dc);
        dawnwalker.init(dc);
        residentEvil.init(dc);
        warhammer.init(dc);

        // Order = rotation order: one theme per day (see getThemeIndex())
        _themes = [witcher, division, dawnwalker, residentEvil, warhammer];
    }

    //! One theme per local calendar day: day number since 1970 (local time, DST included) modulo the theme count,
    //! so the themes take turns in _themes order and the switch happens at midnight.
    private function getThemeIndex(count as Number) as Number {
        var localSeconds = Time.now().value() + System.getClockTime().timeZoneOffset;
        return (localSeconds / 86400) % count;
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        if (_themes == null) { return; }

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Clear to black
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var idx = getThemeIndex(_themes.size());

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
