import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string statusText: ""
    property string statusState: "idle"
    property string statusTooltip: "Voxtype"

    readonly property string iconTheme: cfg?.iconTheme ?? defaults.iconTheme ?? "nerd-font"

    Process {
        id: statusProc
        command: ["voxtype", "status", "--follow", "--format", "json", "--icon-theme", root.iconTheme]
        running: true

        stdout: SplitParser {
            onRead: function(data) {
                try {
                    var obj = JSON.parse(data);
                    root.statusText = obj.text ?? "";
                    root.statusState = obj.alt ?? obj.class ?? "idle";
                    root.statusTooltip = obj.tooltip ?? "Voxtype";
                } catch (e) {
                    root.statusText = "?";
                    root.statusState = "error";
                    root.statusTooltip = "Voxtype: parse error";
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.statusText = "?";
            root.statusState = "error";
            root.statusTooltip = "Voxtype: not running";
            restartTimer.running = true;
        }
    }

    Timer {
        id: restartTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: statusProc.running = true
    }

    IpcHandler {
        target: "plugin:voxtype"

        function refresh(): void {
            if (!statusProc.running) {
                statusProc.running = true;
            }
        }
    }
}
