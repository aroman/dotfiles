import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null
    property string hostname: ""

    Process {
        id: hostnameProc
        command: ["hostname"]
        running: true

        stdout: SplitParser {
            onRead: function(data) {
                root.hostname = data.trim();
            }
        }
    }
}
