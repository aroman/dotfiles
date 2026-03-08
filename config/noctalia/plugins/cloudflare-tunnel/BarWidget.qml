import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property var main: pluginApi?.mainInstance
    readonly property string statusState: main?.statusState ?? "disconnected"
    readonly property string statusTooltip: main?.statusTooltip ?? "Cloudflare Tunnel"

    readonly property string iconText: {
        switch (statusState) {
        case "connected":
            return "󰛳";
        case "starting":
            return "󰛳";
        default:
            return "󰛵";
        }
    }

    readonly property color stateColor: {
        switch (statusState) {
        case "connected":
            return Color.mPrimary;
        case "starting":
            return Color.mTertiary;
        default:
            return Color.mOutline;
        }
    }

    readonly property real contentWidth: isVertical ? capsuleHeight : layout.implicitWidth + Style.marginS * 2
    readonly property real contentHeight: isVertical ? layout.implicitHeight + Style.marginS * 2 : capsuleHeight
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusM
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: Style.marginS

            Item {
                id: iconContainer
                implicitWidth: statusIcon.implicitWidth
                implicitHeight: statusIcon.implicitHeight

                NText {
                    id: statusIcon
                    anchors.centerIn: parent
                    text: root.iconText
                    color: root.stateColor
                    pointSize: root.barFontSize
                }

                // Pulse during starting
                SequentialAnimation {
                    running: root.statusState === "starting"
                    loops: Animation.Infinite
                    alwaysRunToEnd: false

                    NumberAnimation {
                        target: statusIcon
                        property: "opacity"
                        from: 1.0; to: 0.3
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: statusIcon
                        property: "opacity"
                        from: 0.3; to: 1.0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }

                    onRunningChanged: {
                        if (!running) statusIcon.opacity = 1.0;
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (root.statusState === "disconnected") {
                        root.main?.start();
                    } else {
                        root.main?.stop();
                    }
                }
            }

            onEntered: TooltipService.show(root, root.statusTooltip, BarService.getTooltipDirection())
            onExited: TooltipService.hide()
        }
    }
}
