import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Main application entry point for the Division 2 Watch Face
class Division2WatchFaceApp extends Application.AppBase {

    private var _view as Division2WatchFaceView or Null = null;

    //! Constructor
    function initialize() {
        AppBase.initialize();
    }

    //! Called on application start up
    //! @param state Application start state
    function onStart(state as Lang.Dictionary?) as Void {
    }

    //! Called when application is exiting
    //! @param state Application stop state
    function onStop(state as Lang.Dictionary?) as Void {
    }

    //! Return the initial view and delegate for the watch face
    //! @return Array containing the initial view and, on devices that support it, the delegate for touch and hold
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new Division2WatchFaceView();
        _view = view;
        if (WatchUi has :WatchFaceDelegate) {
            return [view, new Division2WatchFaceDelegate(view)] as [WatchUi.Views, WatchUi.InputDelegates];
        }
        return [view] as [WatchUi.Views];
    }

    //! Called when application settings are changed in Garmin Connect Mobile
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }

}

//! Global helper function to get the app instance
//! @return The Division2WatchFaceApp instance
function getApp() as Division2WatchFaceApp {
    return Application.getApp() as Division2WatchFaceApp;
}
