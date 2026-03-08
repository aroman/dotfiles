import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 260 * Style.uiScaleRatio
    property real contentPreferredHeight: contentColumn.implicitHeight + Style.marginL * 2

    readonly property var main: pluginApi?.mainInstance
    readonly property string statusState: main?.statusState ?? "disconnected"

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            // Status row
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon: root.statusState === "disconnected" ? "broadcast-off" : "broadcast"
                    color: root.statusState === "error" ? Color.mError : Color.mOnSurface
                    pointSize: Style.fontSizeL
                }

                NText {
                    text: "Cloudflare Tunnel"
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeL
                    Layout.fillWidth: true
                }
            }

            // Status text
            NText {
                text: {
                    switch (root.statusState) {
                    case "connected": return "Tunnel is connected";
                    case "starting": return "Tunnel is starting...";
                    default: return "Tunnel is disconnected";
                    }
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeM
            }

            // Action button
            Rectangle {
                Layout.fillWidth: true
                height: 36 * Style.uiScaleRatio
                radius: Style.radiusM
                color: actionMouseArea.containsMouse ? Color.mHover : (root.statusState === "disconnected" ? Color.mPrimary : Color.mError)

                NText {
                    anchors.centerIn: parent
                    text: root.statusState === "disconnected" ? "Connect" : "Disconnect"
                    color: actionMouseArea.containsMouse ? Color.mOnHover : (root.statusState === "disconnected" ? Color.mOnPrimary : Color.mOnError)
                    pointSize: Style.fontSizeM
                }

                MouseArea {
                    id: actionMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (root.statusState === "disconnected") {
                            root.main?.start();
                        } else {
                            root.main?.stop();
                        }
                        root.pluginApi?.closePanel(root.pluginApi.panelOpenScreen);
                    }
                }
            }
        }
    }
}
