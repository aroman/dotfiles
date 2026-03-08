import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null
    property string statusState: "disconnected"

    Timer {
        id: pollTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    Process {
        id: statusProc
        command: ["cloudflare-tunnel", "status"]

        stdout: SplitParser {
            onRead: function(data) {
                var state = data.trim();
                if (state === "connected" || state === "starting" || state === "disconnected") {
                    root.statusState = state;
                } else {
                    root.statusState = "disconnected";
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.statusState = "disconnected";
            }
        }
    }

    Process {
        id: startProc
        command: ["cloudflare-tunnel", "start"]

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.statusState = "error";
            }
            pollTimer.restart();
        }
    }

    Process {
        id: stopProc
        command: ["cloudflare-tunnel", "stop"]

        onExited: function(exitCode, exitStatus) {
            pollTimer.restart();
        }
    }

    function start() {
        startProc.running = true;
    }

    function stop() {
        stopProc.running = true;
    }

    IpcHandler {
        target: "plugin:cloudflare-tunnel"

        function refresh(): void {
            statusProc.running = true;
        }
    }
}
