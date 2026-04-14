using Toybox.Application.Storage;

class ProgramManager {

    function initialize() {
    }

    function saveProgram(name, config) {
        var data = {};
        data.put("hang", config.hangTime);
        data.put("rest", config.repRest);
        data.put("reps", config.repsPerSet);
        data.put("setRest", config.setRest);
        data.put("sets", config.numSets);
        data.put("target", config.targetForce);
        data.put("countdown", config.countdownTime);
        Storage.setValue("prog_" + name, data);

        // Update program list
        var list = getList();
        var found = false;
        for (var i = 0; i < list.size(); i++) {
            if (list[i].equals(name)) {
                found = true;
                break;
            }
        }
        if (!found) {
            list.add(name);
            Storage.setValue("program_list", list);
        }
    }

    function loadProgram(name, config) {
        var raw = Storage.getValue("prog_" + name);
        if (raw == null) { return false; }
        var data = raw as Toybox.Lang.Dictionary;
        if (data["hang"] != null) { config.hangTime = data["hang"]; }
        if (data["rest"] != null) { config.repRest = data["rest"]; }
        if (data["reps"] != null) { config.repsPerSet = data["reps"]; }
        if (data["setRest"] != null) { config.setRest = data["setRest"]; }
        if (data["sets"] != null) { config.numSets = data["sets"]; }
        if (data["target"] != null) { config.targetForce = data["target"]; }
        if (data["countdown"] != null) { config.countdownTime = data["countdown"]; }
        return true;
    }

    function deleteProgram(name) {
        Storage.deleteValue("prog_" + name);
        var list = getList();
        var newList = [];
        for (var i = 0; i < list.size(); i++) {
            if (!list[i].equals(name)) {
                newList.add(list[i]);
            }
        }
        Storage.setValue("program_list", newList);
    }

    function getList() {
        var list = Storage.getValue("program_list");
        if (list == null) {
            return [];
        }
        return list;
    }
}
