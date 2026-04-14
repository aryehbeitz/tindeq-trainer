using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Time.Gregorian;

class HistoryView extends WatchUi.Menu2 {
    var histMgr;

    function initialize() {
        Menu2.initialize({:title => "History"});
        histMgr = getApp().historyManager;
        var ids = histMgr.getIdList();

        if (ids.size() == 0) {
            addItem(new WatchUi.MenuItem("No sessions", "Start training!", :empty, null));
        } else {
            // Show newest first
            for (var i = ids.size() - 1; i >= 0 && i >= ids.size() - 20; i--) {
                var raw = histMgr.getSession(ids[i]);
                if (raw != null) {
                    var ses = raw as Toybox.Lang.Dictionary;
                    var dateStr = formatDate(ses["date"]);
                    var detail = ses["mode"] + " | " + ses["peak"].format("%.1f") + "kg";
                    addItem(new WatchUi.MenuItem(dateStr, detail, ids[i], null));
                }
            }
        }
    }

    function formatDate(epoch) {
        var moment = new Time.Moment(epoch);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.month + "/" + info.day + " " + info.hour.format("%02d") + ":" + info.min.format("%02d");
    }
}

class HistoryDelegate extends WatchUi.Menu2InputDelegate {
    var view;

    function initialize(v) {
        Menu2InputDelegate.initialize();
        view = v;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :empty) { return; }

        var raw = getApp().historyManager.getSession(id);
        if (raw != null) {
            var ses = raw as Toybox.Lang.Dictionary;
            var detailView = new HistoryDetailView(ses);
            WatchUi.pushView(detailView, new HistoryDetailDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class HistoryDetailView extends WatchUi.View {
    var session;

    function initialize(ses) {
        View.initialize();
        session = ses;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // Mode
        var mode = session["mode"];
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_SMALL, mode.toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        // Date
        var moment = new Time.Moment(session["date"]);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.23, Graphics.FONT_XTINY,
            info.month + "/" + info.day + " " + info.hour.format("%02d") + ":" + info.min.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Peak force
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.33, Graphics.FONT_NUMBER_MILD, session["peak"].format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.50, Graphics.FONT_TINY, "kg peak", Graphics.TEXT_JUSTIFY_CENTER);

        // Details
        var y = h * 0.60;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (session["sets"] > 0) {
            dc.drawText(cx, y, Graphics.FONT_XTINY, "Sets: " + session["sets"] + "  Reps: " + session["reps"], Graphics.TEXT_JUSTIFY_CENTER);
            y += h * 0.08;
        }
        if (session["dur"] > 0) {
            var m = session["dur"] / 60;
            var s = session["dur"] % 60;
            dc.drawText(cx, y, Graphics.FONT_XTINY, "Duration: " + m + ":" + s.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
            y += h * 0.08;
        }
        if (session["avg"] > 0) {
            dc.drawText(cx, y, Graphics.FONT_XTINY, "Avg: " + session["avg"].format("%.1f") + "kg", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.85, Graphics.FONT_XTINY, "BACK=Return", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class HistoryDetailDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
