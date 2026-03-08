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

    readonly property string iconName: statusState === "disconnected" ? "broadcast-off" : "broadcast"

    readonly property string labelText: {
        switch (statusState) {
        case "connected": return "Connected";
        case "starting": return "Connecting...";
        case "error": return "Error";
        default: return "Disconnected";
        }
    }

    readonly property color stateColor: statusState === "error" ? Color.mError : Color.mOnSurface

    property bool expanded: false
    readonly property real capsuleWidth: isVertical ? capsuleHeight : iconLayout.implicitWidth + Style.marginS * 2
    readonly property real contentHeight: isVertical ? iconLayout.implicitHeight + Style.marginS * 2 : capsuleHeight

    implicitWidth: visualCapsule.width
    implicitHeight: contentHeight

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.capsuleWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusM
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }

        RowLayout {
            id: iconLayout
            anchors.centerIn: parent
            spacing: Style.marginS

            Item {
                id: iconContainer
                implicitWidth: statusIcon.implicitWidth
                implicitHeight: statusIcon.implicitHeight

                NIcon {
                    id: statusIcon
                    anchors.centerIn: parent
                    icon: root.iconName
                    color: mouseArea.containsMouse ? Color.mOnHover : root.stateColor
                    // Match built-in bar pill icon sizing (BarPillHorizontal.qml)
                    pointSize: Style.toOdd(root.capsuleHeight * 0.48)
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

            NText {
                id: hoverLabel
                text: root.labelText
                color: Color.mOnHover
                pointSize: Style.fontSizeXS
                visible: root.expanded
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: expandTimer.running = true
            onExited: {
                expandTimer.running = false;
                root.expanded = false;
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (root.pluginApi) {
                        root.pluginApi.togglePanel(root.screen, root);
                    }
                }
            }
        }

        Timer {
            id: expandTimer
            interval: 1000
            onTriggered: root.expanded = true
        }
    }
}
