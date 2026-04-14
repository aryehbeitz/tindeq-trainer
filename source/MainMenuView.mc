using Toybox.WatchUi;
using Toybox.System;

class MainMenuView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => "Tindeq"});
        addItem(new WatchUi.MenuItem("Free Pull", "Live force", :freePull, null));
        addItem(new WatchUi.MenuItem("Repeaters", "Hang/rest intervals", :repeater, null));
        addItem(new WatchUi.MenuItem("Endurance", "Time to failure", :endurance, null));
        addItem(new WatchUi.MenuItem("Peak Test", "Max force", :peakTest, null));
        addItem(new WatchUi.MenuItem("Programs", "Saved workouts", :programs, null));
        addItem(new WatchUi.MenuItem("History", "Past sessions", :history, null));
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :freePull) {
            var ble = getApp().bleManager;
            ble.startMeasurement();
            var view = new FreePullView();
            WatchUi.switchToView(view, new FreePullDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (id == :repeater) {
            var view = new ConfigView();
            WatchUi.switchToView(view, new ConfigDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (id == :endurance) {
            var ble = getApp().bleManager;
            ble.startMeasurement();
            var view = new EnduranceView();
            WatchUi.switchToView(view, new EnduranceDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (id == :peakTest) {
            var view = new PeakTestView();
            WatchUi.switchToView(view, new PeakTestDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (id == :programs) {
            var progList = getApp().programManager.getList();
            if (progList.size() == 0) {
                var cView = new ConfigView();
                WatchUi.switchToView(cView, new ConfigDelegate(cView), WatchUi.SLIDE_LEFT);
            } else {
                var menu = new WatchUi.Menu2({:title => "Programs"});
                for (var i = 0; i < progList.size(); i++) {
                    menu.addItem(new WatchUi.MenuItem(progList[i], null, progList[i], null));
                }
                WatchUi.pushView(menu, new ProgramListDelegate(), WatchUi.SLIDE_LEFT);
            }
        } else if (id == :history) {
            var view = new HistoryView();
            WatchUi.pushView(view, new HistoryDelegate(view), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() {
        var ble = getApp().bleManager;
        ble.disconnect();
        System.exit();
    }
}

class ProgramListDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var name = item.getId();
        var config = getApp().trainingManager.config;
        getApp().programManager.loadProgram(name, config);
        var view = new ConfigView();
        WatchUi.switchToView(view, new ConfigDelegate(view), WatchUi.SLIDE_LEFT);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
