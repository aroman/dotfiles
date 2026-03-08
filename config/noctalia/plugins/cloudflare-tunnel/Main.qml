import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string statusState: "disconnected"
    property string statusTooltip: "Cloudflare Tunnel: disconnected"

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
                root.statusTooltip = "Cloudflare Tunnel: " + root.statusState;
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.statusState = "disconnected";
                root.statusTooltip = "Cloudflare Tunnel: disconnected";
            }
        }
    }

    Process {
        id: startProc
        command: ["ptyxis", "--new-window", "-x", "cloudflare-tunnel start"]
    }

    Process {
        id: stopProc
        command: ["cloudflare-tunnel", "stop"]
    }

    function start() {
        startProc.running = true;
    }

    function stop() {
        stopProc.running = true;
        // Poll sooner to update state
        pollTimer.restart();
    }

    IpcHandler {
        target: "plugin:cloudflare-tunnel"

        function refresh(): void {
            statusProc.running = true;
        }
    }
}
