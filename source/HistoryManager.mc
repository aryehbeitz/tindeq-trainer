using Toybox.Application.Storage;
using Toybox.Time;

class HistoryManager {
    const MAX_SESSIONS = 50;

    function initialize() {
    }

    function saveSession(mode, peak, avg, sets, reps, durationSec) {
        var id = Time.now().value();
        var data = {};
        data.put("id", id);
        data.put("date", id);
        data.put("mode", mode);
        data.put("peak", peak);
        data.put("avg", avg);
        data.put("sets", sets);
        data.put("reps", reps);
        data.put("dur", durationSec);
        Storage.setValue("ses_" + id, data);

        // Update session list
        var list = getIdList();
        list.add(id);

        // Prune old sessions
        while (list.size() > MAX_SESSIONS) {
            var oldId = list[0];
            Storage.deleteValue("ses_" + oldId);
            list = list.slice(1, null);
        }
        Storage.setValue("session_list", list);
    }

    function getSession(id) {
        return Storage.getValue("ses_" + id);
    }

    function getIdList() {
        var list = Storage.getValue("session_list");
        if (list == null) {
            return [];
        }
        return list;
    }

    function getSessionCount() {
        return getIdList().size();
    }

    function deleteSession(id) {
        Storage.deleteValue("ses_" + id);
        var list = getIdList();
        var newList = [];
        for (var i = 0; i < list.size(); i++) {
            if (list[i] != id) {
                newList.add(list[i]);
            }
        }
        Storage.setValue("session_list", newList);
    }
}
