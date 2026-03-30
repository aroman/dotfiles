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
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property var main: pluginApi?.mainInstance
    readonly property string hostname: main?.hostname ?? ""

    implicitWidth: label.implicitWidth + Style.marginS * 2
    implicitHeight: capsuleHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.hostname
        font.weight: Font.Bold
        font.family: Settings.data.ui.fontDefault
        font.pointSize: root.barFontSize
        color: Color.mOnSurface
    }
}
