import QtQuick
import Quickshell
import Quickshell.Io

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property real cpuPercent: 0.0
    property real prevTotal: 0.0
    property real prevIdle: 0.0
    property bool showLabel: pluginData.showLabel !== false
    property bool showLoadAvg: pluginData.showLoadAvg === true
    property int loadFullScale: pluginData.loadFullScale || 0
    property int ncpu: 1
    property string labelText: pluginData.labelText || "CPU"
    property int topCount: pluginData.topCount || 30
    property var rows: []
    property bool popoutOpen: false

    function usageColor(percent) {
        if (percent > 90) return Theme.error
        if (percent > 75) return "#ffa500"
        return Theme.primary
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statProcess.running = true
    }

    Process {
        id: statProcess
        command: ["sh", "-c", "cat /proc/stat; echo LOADAVG $(cat /proc/loadavg); echo NCPU $(nproc)"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const nm = text.match(/^NCPU (\d+)/m)
                if (nm) root.ncpu = Math.max(1, parseInt(nm[1]))
                if (root.showLoadAvg) {
                    const lm = text.match(/^LOADAVG ([0-9.]+)/m)
                    const fs = root.loadFullScale > 0 ? root.loadFullScale : root.ncpu
                    if (lm)
                        root.cpuPercent = 100 * parseFloat(lm[1]) / fs
                    return
                }
                const m = text.match(/^cpu +(.+)$/m)
                if (!m) return
                const f = m[1].trim().split(/\s+/).map(Number)
                const total = f.reduce((a, b) => a + b, 0)
                const idle = f[3] + (f[4] || 0)
                if (root.prevTotal > 0 && total > root.prevTotal) {
                    const dt = total - root.prevTotal
                    const di = idle - root.prevIdle
                    root.cpuPercent = Math.max(0, Math.min(100, 100 * (1 - di / dt)))
                }
                root.prevTotal = total
                root.prevIdle = idle
            }
        }
    }

    Timer {
        interval: 2000
        running: root.popoutOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: rowsProcess.running = true
    }

    Process {
        id: rowsProcess
        command: ["sh", Qt.resolvedUrl("collect.sh").toString().replace("file://", ""), String(root.loadFullScale)]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.trim().split("\n")) {
                    const f = line.split("\t")
                    if (f.length < 4) continue
                    if (f[0] === "T") continue
                    out.push({
                        value: parseInt(f[1]),
                        pid: f[2],
                        name: f[3],
                        detail: f[4] || "",
                        unit: f[5] || "%",
                        display: f[6] || "",
                        colorPct: parseInt(f[7]) || 0,
                        killable: f[0] === "P",
                        free: f[0] === "F" || f[0] === "L",
                        pinned: f[0] === "F" || f[0] === "L",
                        share: parseInt(f[1]) / 100
                    })
                }
                out.sort((a, b) => (a.pinned !== b.pinned) ? (a.pinned ? -1 : 1) : (a.pinned ? 0 : b.value - a.value))
                root.rows = out.slice(0, root.topCount)
            }
        }
    }

    Process {
        id: killProcess
        running: false
        onExited: rowsProcess.running = true
    }

    function killPid(pid) {
        killProcess.command = ["kill", pid]
        killProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "memory"
                size: Theme.fontSizeLarge
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showLabel
                text: root.labelText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 44
                height: 6
                radius: 3
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * Math.min(root.cpuPercent, 100) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.usageColor(root.cpuPercent)
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
            }

            StyledText {
                width: 34
                horizontalAlignment: Text.AlignRight
                text: `${root.cpuPercent.toFixed(0)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    popoutWidth: 340

    popoutContent: Component {
        PopoutComponent {
            id: popout

            Binding {
                target: root
                property: "popoutOpen"
                value: popout.parentPopout ? popout.parentPopout.shouldBeVisible : false
            }

            Item {
                width: parent.width
                implicitHeight: rows.implicitHeight + Theme.spacingM * 2

                Column {
                    id: rows
                    x: Theme.spacingM
                    y: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.rows

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width - stats.width - 16 - Theme.spacingS * 2
                                spacing: 5
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    id: procName
                                    width: Math.min(implicitWidth, parent.width)
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: modelData.free ? Theme.primary : (modelData.killable ? Theme.surfaceText : Theme.surfaceVariantText)
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    width: parent.width - procName.width - parent.spacing
                                    visible: modelData.detail.length > 0
                                    text: modelData.detail
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceVariantText
                                    opacity: 0.55
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                id: stats
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    width: 46
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.display.length > 0 ? modelData.display : `${modelData.value}${modelData.unit}`
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: modelData.free ? Theme.primary : Theme.surfaceVariantText
                                    opacity: modelData.free ? 1.0 : 0.7
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: 40
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: parent.width * Math.min(modelData.share || 0, 1)
                                        height: parent.height
                                        radius: parent.radius
                                        color: modelData.name === "Idle right now" ? Theme.primary : root.usageColor(modelData.colorPct > 0 ? modelData.colorPct : modelData.value)
                                    }
                                }
                            }

                            Item {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.fill: parent
                                    visible: modelData.killable
                                    name: "close"
                                    size: 16
                                    color: killArea.containsMouse ? Theme.error : Theme.surfaceVariantText

                                    MouseArea {
                                        id: killArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.killPid(modelData.pid)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
