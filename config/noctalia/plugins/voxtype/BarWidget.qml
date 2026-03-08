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
    readonly property string statusText: main?.statusText ?? ""
    readonly property string statusState: main?.statusState ?? "idle"
    readonly property string statusTooltip: main?.statusTooltip ?? "Voxtype"

    readonly property color stateColor: {
        switch (statusState) {
        case "recording":
            return Color.mTertiary;
        case "transcribing":
            return Color.mPrimary;
        case "error":
            return Color.mError;
        default:
            return Color.mTertiary;
        }
    }

    readonly property real contentWidth: isVertical ? capsuleHeight : layout.implicitWidth + Style.marginS * 2
    readonly property real contentHeight: isVertical ? layout.implicitHeight + Style.marginS * 2 : capsuleHeight
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    visible: statusState !== "idle"

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
                    text: root.statusText
                    color: root.stateColor
                    pointSize: root.barFontSize
                }

                // Pulse opacity during recording
                SequentialAnimation {
                    running: root.statusState === "recording"
                    loops: Animation.Infinite
                    alwaysRunToEnd: false

                    NumberAnimation {
                        target: statusIcon
                        property: "opacity"
                        from: 1.0; to: 0.3
                        duration: 600
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: statusIcon
                        property: "opacity"
                        from: 0.3; to: 1.0
                        duration: 600
                        easing.type: Easing.InOutSine
                    }

                    onRunningChanged: {
                        if (!running) statusIcon.opacity = 1.0;
                    }
                }

                // Spin during processing
                NumberAnimation {
                    target: iconContainer
                    property: "rotation"
                    from: 0; to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: root.statusState === "transcribing"

                    onRunningChanged: {
                        if (!running) iconContainer.rotation = 0;
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true

            onEntered: TooltipService.show(root, root.statusTooltip, BarService.getTooltipDirection())
            onExited: TooltipService.hide()
        }
    }
}
