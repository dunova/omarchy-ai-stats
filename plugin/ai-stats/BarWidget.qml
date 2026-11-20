import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dunova.ai-stats"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool popupOpen: false
  property string selectedRange: "24h"
  property string barDisplayText: "󰧑 $0.00 · 0%"
  property string barTooltipText: "左键点击展开图表卡片 · 右键刷新"
  property bool pendingRefresh: false
  property int hoveredModelIdx: -1
  property int hoveredSlotIdx: -1

  property var stats: ({
    rangeKey: "24h",
    rangeLabel: "过去 24 小时",
    updatedAt: "--:--:--",
    cost: 0,
    hitRate: 0,
    calls: 0,
    totalTokensShort: "0",
    cachedShort: "0",
    cachedPct: 0,
    uncachedShort: "0",
    uncachedPct: 0,
    cacheWrite: 0,
    cacheWriteShort: "0",
    cacheWritePct: 0,
    outputShort: "0",
    outputPct: 0,
    cacheMultiplier: 0,
    models: [],
    modelTrends: [],
    sources: []
  })

  readonly property color fgColor: root.bar ? root.bar.foreground : Commons.Color.popups.text
  readonly property color mutedColor: Commons.Color.muted
  readonly property color accentColor: Commons.Color.accent
  readonly property string uiFont: (root.bar && root.bar.fontFamily) ? root.bar.fontFamily : Style.font.family

  function close() {
    popupOpen = false
  }

  function refreshStats(forceFresh) {
    if (statsProc.running) {
      root.pendingRefresh = true
      return
    }
    root.pendingRefresh = false
    var extra = forceFresh ? " --no-cache" : ""
    statsProc.command = ["bash", "-c", "exec \"$HOME/.local/bin/omarchy-ai-stats\" --json-detail --range \"$1\"" + extra, "stats", root.selectedRange]
    statsProc.running = true
  }

  function applyPayload(raw) {
    if (!raw) return
    try {
      var parsed = JSON.parse(raw.trim())
      if (parsed.rangeKey && parsed.rangeKey !== root.selectedRange) {
        return
      }
      root.stats = parsed
      if (parsed.barText) root.barDisplayText = parsed.barText
    } catch (e) {}
  }

  function hitColor(rate) {
    if (rate >= 95) return "#00e5ff"
    if (rate >= 88) return "#34d399"
    if (rate >= 75) return "#fbbf24"
    if (rate >= 50) return "#fb923c"
    return "#f87171"
  }

  function compactModelTitle(name) {
    return String(name || "").replace("Orchestrator", "Orch.")
  }

  Process {
    id: statsProc
    command: ["bash", "-c", "exec \"$HOME/.local/bin/omarchy-ai-stats\" --json-detail --range \"$1\"", "stats", root.selectedRange]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPayload(text)
    }
    onExited: function() {
      if (root.pendingRefresh) {
        root.refreshStats(false)
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStats(false)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barDisplayText
    tooltipText: root.popupOpen ? "" : root.barTooltipText
    active: root.popupOpen
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        root.refreshStats(true)
      } else {
        root.popupOpen = !root.popupOpen
        if (root.popupOpen) {
          root.hoveredModelIdx = -1
          root.hoveredSlotIdx = -1
          root.refreshStats(true)
        }
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(536))
    contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight)

    Column {
      id: mainColumn
      width: parent.width
      spacing: Style.space(8)

      // 顶部标题与时间区间切换
      Row {
        width: parent.width
        spacing: Style.space(8)

        Column {
          width: parent.width - rangeRow.implicitWidth - Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Row {
            width: parent.width
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: "󰧑"
              color: root.accentColor
              font.family: root.uiFont
              font.pixelSize: Style.font.subtitle
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              textFormat: Text.PlainText
              text: "AI 模型用量与缓存监控"
              color: root.fgColor
              font.family: root.uiFont
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              width: parent.width - Style.space(24)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            textFormat: Text.PlainText
            text: (root.stats.rangeLabel || "过去 24 小时") + " · 更新于 " + (root.stats.updatedAt || "--:--")
            color: root.mutedColor
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }
        }

        Row {
          id: rangeRow
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(4)

          Repeater {
            model: [
              { key: "1h", label: "1小时" },
              { key: "24h", label: "24小时" },
              { key: "7d", label: "7天" }
            ]

            Button {
              required property var modelData
              text: modelData.label
              foreground: root.fgColor
              accent: root.accentColor
              selected: root.selectedRange === modelData.key
              bordered: true
              fontSize: Style.font.caption
              horizontalPadding: Style.space(9)
              verticalPadding: Style.space(4)
              onClicked: {
                if (root.selectedRange !== modelData.key) {
                  root.selectedRange = modelData.key
                  root.hoveredModelIdx = -1
                  root.hoveredSlotIdx = -1
                  root.refreshStats(false)
                }
              }
            }
          }
        }
      }

      // 三列核心指标卡片
      Row {
        width: parent.width
        spacing: Style.space(8)

        BorderSurface {
          width: (parent.width - Style.space(16)) / 3
          height: Style.space(52)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.fgColor, root.accentColor)
          borderSpec: Border.controlSpec("normal", root.fgColor, root.accentColor)

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(10)
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "等效模型估值"
              color: root.mutedColor
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
            Text {
              textFormat: Text.PlainText
              text: "$" + Number(root.stats.cost || 0).toFixed(2)
              color: root.fgColor
              font.family: root.uiFont
              font.pixelSize: Style.font.subtitle
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }

        BorderSurface {
          width: (parent.width - Style.space(16)) / 3
          height: Style.space(52)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.fgColor, root.accentColor)
          borderSpec: Border.controlSpec("normal", root.fgColor, root.accentColor)

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(10)
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "平均缓存命中"
              color: root.mutedColor
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
            Text {
              textFormat: Text.PlainText
              text: Number(root.stats.hitRate || 0).toFixed(1) + "%"
              color: root.hitColor(Number(root.stats.hitRate || 0))
              font.family: root.uiFont
              font.pixelSize: Style.font.subtitle
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }

        BorderSurface {
          width: (parent.width - Style.space(16)) / 3
          height: Style.space(52)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.fgColor, root.accentColor)
          borderSpec: Border.controlSpec("normal", root.fgColor, root.accentColor)

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(10)
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "调用与总量"
              color: root.mutedColor
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
            Text {
              textFormat: Text.PlainText
              text: String(root.stats.calls || 0) + " 次 · " + (root.stats.totalTokensShort || "0")
              color: root.fgColor
              font.family: root.uiFont
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }
      }

      // Token 构成分布
      Column {
        width: parent.width
        spacing: Style.space(4)

        Row {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: "Token 构成分布"
            color: root.fgColor
            font.family: root.uiFont
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            width: parent.width * 0.45
          }
          Text {
            textFormat: Text.PlainText
            text: "每 1 输出伴随 " + Number(root.stats.cacheMultiplier || 0).toFixed(1) + " 缓存读取"
            color: root.mutedColor
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            width: parent.width * 0.55
          }
        }

        Repeater {
          model: [
            { label: "缓存读取输入", count: root.stats.cachedShort || "0", pct: Number(root.stats.cachedPct || 0), color: "#00e5ff", show: true },
            { label: "常规未缓存输入", count: root.stats.uncachedShort || "0", pct: Number(root.stats.uncachedPct || 0), color: "#60a5fa", show: true },
            { label: "缓存写入输入", count: root.stats.cacheWriteShort || "0", pct: Number(root.stats.cacheWritePct || 0), color: "#fbbf24", show: Number(root.stats.cacheWrite || 0) > 0 },
            { label: "生成与思考输出", count: root.stats.outputShort || "0", pct: Number(root.stats.outputPct || 0), color: "#c084fc", show: true }
          ]

          Column {
            required property var modelData
            visible: modelData.show
            width: parent.width
            spacing: Style.space(2)

            Row {
              width: parent.width
              Text {
                textFormat: Text.PlainText
                text: modelData.label
                color: root.fgColor
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
                width: parent.width * 0.45
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.count + "  (" + modelData.pct.toFixed(1) + "%)"
                color: root.mutedColor
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
                width: parent.width * 0.55
              }
            }

            Rectangle {
              width: parent.width
              height: Style.space(5)
              radius: Style.space(2)
              color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.14)

              Rectangle {
                width: Math.max(modelData.pct > 0 ? Style.space(4) : 0, parent.width * Math.min(1.0, modelData.pct / 100.0))
                height: parent.height
                radius: parent.radius
                color: modelData.color
              }
            }
          }
        }
      }

      PanelSeparator {
        width: parent.width
        foreground: root.fgColor
        strength: 0.22
      }

      // 前 4 模型独立分窗走势 (2x2)
      Column {
        width: parent.width
        spacing: Style.space(5)

        Row {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: "前 4 模型独立缓存走势"
            color: root.fgColor
            font.family: root.uiFont
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            width: parent.width * 0.42
          }
          Text {
            textFormat: Text.PlainText
            text: (root.hoveredModelIdx >= 0 && root.hoveredSlotIdx >= 0 && root.stats.modelTrends && root.hoveredModelIdx < root.stats.modelTrends.length && root.hoveredSlotIdx < root.stats.modelTrends[root.hoveredModelIdx].buckets.length)
              ? ("#" + String(root.hoveredModelIdx + 1) + " · " + (root.stats.modelTrends[root.hoveredModelIdx].buckets[root.hoveredSlotIdx].hasData
                  ? (String(root.stats.modelTrends[root.hoveredModelIdx].buckets[root.hoveredSlotIdx].label) + " 命中 " + Number(root.stats.modelTrends[root.hoveredModelIdx].buckets[root.hoveredSlotIdx].hitRate).toFixed(1) + "% (" + String(root.stats.modelTrends[root.hoveredModelIdx].buckets[root.hoveredSlotIdx].tokensShort) + ")")
                  : (String(root.stats.modelTrends[root.hoveredModelIdx].buckets[root.hoveredSlotIdx].label) + " 无调用")))
              : "悬停柱状查看该模型时段详情"
            color: (root.hoveredModelIdx >= 0 && root.hoveredSlotIdx >= 0 && root.stats.modelTrends && root.hoveredModelIdx < root.stats.modelTrends.length && root.hoveredSlotIdx < root.stats.modelTrends[root.hoveredModelIdx].buckets.length && root.stats.modelTrends[root.hoveredModelIdx].buckets[root.hoveredSlotIdx].hasData)
              ? String(root.stats.modelTrends[root.hoveredModelIdx].color)
              : root.mutedColor
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            width: parent.width * 0.58
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: !root.stats.modelTrends || root.stats.modelTrends.length === 0
          text: "当前所选时间范围内暂无模型调用数据。"
          color: root.mutedColor
          font.family: root.uiFont
          font.pixelSize: Style.font.caption
          width: parent.width
        }

        Grid {
          visible: root.stats.modelTrends && root.stats.modelTrends.length > 0
          width: parent.width
          columns: 2
          columnSpacing: Style.space(6)
          rowSpacing: Style.space(6)

          Repeater {
            model: root.stats.modelTrends || []

            BorderSurface {
              id: mCard
              required property var modelData
              required property int index
              width: (parent.width - Style.space(6)) / 2
              height: Style.space(86)
              radius: Style.spacing.labelGap
              color: Style.normalFillFor(root.fgColor, root.accentColor)
              borderSpec: Border.controlSpec(root.hoveredModelIdx === mCard.index ? "hover-cursor" : "normal", root.fgColor, root.accentColor)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(7)
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  spacing: Style.space(5)

                  Rectangle {
                    width: Style.space(6)
                    height: Style.space(6)
                    radius: Style.space(3)
                    color: String(mCard.modelData.color || "#00e5ff")
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: root.compactModelTitle(mCard.modelData.name)
                    color: root.fgColor
                    font.family: root.uiFont
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - mHrText.implicitWidth - Style.space(16)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    id: mHrText
                    textFormat: Text.PlainText
                    text: Number(mCard.modelData.hitRate || 0).toFixed(1) + "%"
                    color: root.hitColor(Number(mCard.modelData.hitRate || 0))
                    font.family: root.uiFont
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // 柱状图区 + 50% 参考基线
                Item {
                  width: parent.width
                  height: Style.space(40)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.10)
                  }

                  Row {
                    id: subBars
                    anchors.fill: parent
                    spacing: Style.space(2)

                    readonly property var bList: mCard.modelData.buckets || []
                    readonly property int bCount: bList.length > 0 ? bList.length : 1
                    readonly property real bW: Math.max(2, (width - spacing * (bCount - 1)) / bCount)

                    Repeater {
                      model: subBars.bList

                      Item {
                        id: sItem
                        required property var modelData
                        required property int index
                        width: subBars.bW
                        height: subBars.height

                        // 悬停高亮整条轨道，非悬停极淡底色，避免无数据列抢眼
                        Rectangle {
                          anchors.fill: parent
                          radius: Style.space(1)
                          color: (root.hoveredModelIdx === mCard.index && root.hoveredSlotIdx === sItem.index)
                            ? Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.16)
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.025)
                        }

                        Rectangle {
                          anchors.bottom: parent.bottom
                          width: parent.width
                          height: sItem.modelData.hasData
                            ? Math.max(Style.space(3), parent.height * Math.min(1.0, Math.max(0.0, Number(sItem.modelData.hitRate || 0) / 100.0)))
                            : Style.space(2)
                          radius: Style.space(1)
                          color: sItem.modelData.hasData
                            ? String(mCard.modelData.color || "#00e5ff")
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.14)
                          opacity: sItem.modelData.hasData
                            ? ((root.hoveredModelIdx === mCard.index && root.hoveredSlotIdx === sItem.index) ? 1.0 : 0.88)
                            : 1.0
                        }

                        MouseArea {
                          anchors.fill: parent
                          hoverEnabled: true
                          onEntered: {
                            root.hoveredModelIdx = mCard.index
                            root.hoveredSlotIdx = sItem.index
                          }
                          onExited: {
                            if (root.hoveredModelIdx === mCard.index && root.hoveredSlotIdx === sItem.index) {
                              root.hoveredModelIdx = -1
                              root.hoveredSlotIdx = -1
                            }
                          }
                        }
                      }
                    }
                  }
                }

                Row {
                  width: parent.width
                  Text {
                    textFormat: Text.PlainText
                    text: "$" + Number(mCard.modelData.cost || 0).toFixed(2) + " · " + String(mCard.modelData.calls || 0) + " 次"
                    color: root.mutedColor
                    font.family: root.uiFont
                    font.pixelSize: Style.font.caption
                    width: parent.width * 0.52
                    elide: Text.ElideRight
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: (mCard.modelData.buckets && mCard.modelData.buckets.length > 0)
                      ? (String(mCard.modelData.buckets[0].label) + " 至 " + String(mCard.modelData.buckets[mCard.modelData.buckets.length - 1].label))
                      : ""
                    color: root.mutedColor
                    font.family: root.uiFont
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                    width: parent.width * 0.48
                    elide: Text.ElideLeft
                  }
                }
              }
            }
          }
        }
      }

      PanelSeparator {
        width: parent.width
        foreground: root.fgColor
        strength: 0.22
      }

      // 全部活跃模型列表 (精确锁定 3 整行高度 + 右侧滚动滑块，彻底消灭半行腰斩)
      Column {
        width: parent.width
        spacing: Style.space(5)

        readonly property real itemH: Style.space(42)
        readonly property real itemGap: Style.space(4)

        Row {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: "全部活跃模型用量与平均缓存"
            color: root.fgColor
            font.family: root.uiFont
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            width: parent.width * 0.65
          }
          Text {
            textFormat: Text.PlainText
            text: "共 " + String(root.stats.models ? root.stats.models.length : 0) + " 个 (滚轮翻页)"
            color: root.mutedColor
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            width: parent.width * 0.35
          }
        }

        Item {
          id: listViewport
          visible: root.stats.models && root.stats.models.length > 0
          width: parent.width
          readonly property int totalItems: root.stats.models ? root.stats.models.length : 0
          readonly property int visibleRows: Math.min(3, totalItems)
          readonly property bool canScroll: totalItems > 3
          height: visibleRows > 0 ? (visibleRows * parent.itemH + (visibleRows - 1) * parent.itemGap) : 0

          Flickable {
            id: modelFlick
            anchors.left: parent.left
            anchors.right: listViewport.canScroll ? scrollTrack.left : parent.right
            anchors.rightMargin: listViewport.canScroll ? Style.space(5) : 0
            height: parent.height
            contentWidth: width
            contentHeight: modelListCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: modelListCol
              width: modelFlick.width
              spacing: Style.space(4)

              Repeater {
                model: root.stats.models || []

                BorderSurface {
                  required property var modelData
                  width: modelListCol.width
                  height: Style.space(42)
                  radius: Style.spacing.labelGap
                  color: Style.normalFillFor(root.fgColor, root.accentColor)
                  borderSpec: Border.controlSpec("normal", root.fgColor, root.accentColor)

                  Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(2)

                    Row {
                      width: parent.width

                      Text {
                        textFormat: Text.PlainText
                        text: String(modelData.name || "")
                        color: root.fgColor
                        font.family: root.uiFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width - costLabel.implicitWidth - hitBadge.implicitWidth - Style.space(14)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        id: hitBadge
                        textFormat: Text.PlainText
                        text: "缓存 " + Number(modelData.hitRate || 0).toFixed(1) + "%"
                        color: root.hitColor(Number(modelData.hitRate || 0))
                        font.family: root.uiFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Item { width: Style.space(8); height: 1 }

                      Text {
                        id: costLabel
                        textFormat: Text.PlainText
                        text: "$" + Number(modelData.cost || 0).toFixed(2)
                        color: root.fgColor
                        font.family: root.uiFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: String(modelData.calls || 0) + " 次 · " + String(modelData.totalShort || "0")
                        + " (缓存 " + String(modelData.cachedShort || "0")
                        + " / 输入 " + String(modelData.uncachedShort || "0")
                        + " / 输出 " + String(modelData.outputShort || "0") + ")"
                      color: root.mutedColor
                      font.family: root.uiFont
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }
                }
              }
            }
          }

          // 右侧细长滚动进度指示条
          Rectangle {
            id: scrollTrack
            visible: listViewport.canScroll
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Style.space(4)
            radius: Style.space(2)
            color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)

            Rectangle {
              width: parent.width
              radius: parent.radius
              color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55)
              readonly property real ratio: modelFlick.contentHeight > 0 ? Math.min(1.0, modelFlick.height / modelFlick.contentHeight) : 1.0
              height: Math.max(Style.space(16), parent.height * ratio)
              y: modelFlick.contentHeight > modelFlick.height
                ? (modelFlick.contentY / (modelFlick.contentHeight - modelFlick.height)) * (parent.height - height)
                : 0
            }
          }
        }
      }

      // 底部来源与操作按钮
      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: (root.stats.sources && root.stats.sources.length > 0)
            ? ("数据源: " + root.stats.sources.join("、"))
            : "数据源: 等待日志接入"
          color: root.mutedColor
          font.family: root.uiFont
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width - actionRow.implicitWidth - Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }

        Row {
          id: actionRow
          spacing: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter

          Button {
            text: "刷新"
            foreground: root.fgColor
            bordered: true
            fontSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(4)
            onClicked: root.refreshStats(true)
          }

          Button {
            text: "终端看板"
            foreground: root.fgColor
            bordered: true
            fontSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(4)
            onClicked: {
              root.popupOpen = false
              if (root.bar) {
                root.bar.run("xdg-terminal-exec --app-id=org.omarchy.ai-usage -e $HOME/.local/bin/omarchy-ai-stats")
              }
            }
          }
        }
      }
    }
  }
}
