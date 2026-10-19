import Toybox.Lang;
import Toybox.WatchUi;

//! Input for the watch face. A watch face receives only one touch event: a touch and hold (WatchFaceDelegate.onPress, API 4.2.0),
//! which switches to the next theme (see Division2WatchFaceView.cycleTheme()).
class Division2WatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as Division2WatchFaceView;

    public function initialize(view as Division2WatchFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    public function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        _view.cycleTheme();
        return true;
    }
}
