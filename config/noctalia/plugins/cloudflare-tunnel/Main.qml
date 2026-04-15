import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

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
                if (state !== "connected" && state !== "starting" && state !== "disconnected") {
                    state = "disconnected";
                }
                root.statusState = state;
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.statusState = "disconnected";
            }
        }
    }

    function handleActionExit(verb, exitCode, errText) {
        if (exitCode !== 0) {
            ToastService.showError("Cloudflare Tunnel failed to " + verb,
                errText.trim() || ("cloudflare-tunnel " + verb + " exited with code " + exitCode));
        }
        pollTimer.restart();
    }

    Process {
        id: startProc
        command: ["cloudflare-tunnel", "start"]
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            root.handleActionExit("start", exitCode, stderr.text);
        }
    }

    Process {
        id: stopProc
        command: ["cloudflare-tunnel", "stop"]
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            root.handleActionExit("stop", exitCode, stderr.text);
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
