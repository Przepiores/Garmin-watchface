import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;

//! Main watch face view — theme dispatcher.
//! Selects one theme per local calendar day (the themes take turns in _themes order) and delegates all drawing.
//! A touch and hold on the watch face (see Division2WatchFaceDelegate) pins a theme instead; the choice is stored on the watch.
class Division2WatchFaceView extends WatchUi.WatchFace {

    // Names shown by the toast, in _themes order
    private const THEME_NAMES = ["HADES", "DIVISION", "DAWNWALKER", "CYBERPUNK", "WARHAMMER", "ASSASSIN", "DUNE"];
    private const PIN_KEY      = "ThemePin";
    private const TOAST_MS     = 2500;   // how long the theme name stays on screen after a switch
    private const PRESS_GAP_MS = 1200;   // a hold can be reported more than once; presses closer than this are ignored

    // Theme instances
    private var _themes as Array or Null = null;
    private var _currentThemeIdx as Number = -1;
    private var _isAwake as Boolean = true;

    // Theme chosen by touch and hold: an index into _themes, or -1 for the automatic one-per-day rotation
    private var _pinned as Number = -1;
    private var _toastUntil as Number = 0;
    private var _lastPress as Number = -PRESS_GAP_MS;
    private var _toastTimer as Timer.Timer or Null = null;

    public function initialize() {
        WatchFace.initialize();
        _pinned = loadPin();
    }

    private function loadPin() as Number {
        try {
            var value = Application.Storage.getValue(PIN_KEY);
            if (value != null && value instanceof Lang.Number) {
                return value;
            }
        } catch (e) {}
        return -1;
    }

    //! Touch and hold: automatic -> first theme -> ... -> last theme -> automatic. The choice is stored and survives a restart.
    public function cycleTheme() as Void {
        var themes = _themes;
        if (themes == null) { return; }
        var now = System.getTimer();
        var since = now - _lastPress;
        if (since >= 0 && since < PRESS_GAP_MS) { return; }   // the timer wraps after ~24 days, hence the range check
        _lastPress = now;

        _pinned = _pinned + 1;
        if (_pinned >= themes.size()) { _pinned = -1; }
        try {
            Application.Storage.setValue(PIN_KEY, _pinned);
        } catch (e) {}

        // The toast is drawn by onUpdate(); the timer asks for one more update when it expires so the toast does not linger
        _toastUntil = now + TOAST_MS;
        if (_toastTimer == null) { _toastTimer = new Timer.Timer(); }
        _toastTimer.stop();
        _toastTimer.start(method(:onToastDone), TOAST_MS + 100, false);
        WatchUi.requestUpdate();
    }

    public function onToastDone() as Void {
        WatchUi.requestUpdate();
    }

    public function onLayout(dc as Graphics.Dc) as Void {
        // New theme instances have no buffer yet; -1 forces loadResources() on the next onUpdate()
        _currentThemeIdx = -1;

        // Create all 7 themes
        var hades      = new HadesTheme();
        var division   = new DivisionTheme();
        var dawnwalker = new DawnwalkerTheme();
        var cyberpunk  = new CyberpunkTheme();
        var warhammer  = new WarhammerTheme();
        var assassin   = new AssassinTheme();
        var dune       = new DuneTheme();

        // Initialize geometry for each
        hades.init(dc);
        division.init(dc);
        dawnwalker.init(dc);
        cyberpunk.init(dc);
        warhammer.init(dc);
        assassin.init(dc);
        dune.init(dc);

        // Order = rotation order: one theme per day (see getThemeIndex())
        _themes = [hades, division, dawnwalker, cyberpunk, warhammer, assassin, dune];
    }

    //! The pinned theme if there is one, otherwise one theme per local calendar day: day number since 1970 (local time, DST included)
    //! modulo the theme count, so the themes take turns in _themes order and the switch happens at midnight.
    private function getThemeIndex(count as Number) as Number {
        if (_pinned >= 0 && _pinned < count) { return _pinned; }
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
            var left = _toastUntil - System.getTimer();
            if (left > 0 && left <= TOAST_MS) { drawToast(dc, idx); }
        } else {
            theme.drawAOD(dc);
        }
    }

    //! A small plate near the bottom with the name of the theme just chosen, or AUTO when the daily rotation is on.
    private function drawToast(dc as Graphics.Dc, idx as Number) as Void {
        var label = "AUTO";
        if (_pinned >= 0 && idx < THEME_NAMES.size()) { label = THEME_NAMES[idx]; }
        var s = dc.getWidth() / 454.0;
        var w = dc.getTextWidthInPixels(label, Graphics.FONT_XTINY) + 28 * s;
        var h = 28 * s;
        var x = (dc.getWidth() - w) / 2;
        var y = 386 * s;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(x, y, w, h, 8 * s);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, h, 8 * s);
        dc.drawText(dc.getWidth() / 2, y + h / 2, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
