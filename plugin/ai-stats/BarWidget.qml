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
  property string themeMode: "dark"
  property string barDisplayText: "󰧑 $0.00 · 0%"
  property string barTooltipText: "左键点击展开图表卡片 · 右键刷新"
  property bool pendingRefresh: false
  property string pendingActionArgs: ""
  property int hoveredModelIdx: -1
  property int hoveredSlotIdx: -1

  readonly property bool isLight: themeMode === "light"

  // 白天与黑夜两套高对比主题令牌
  readonly property color bgCard: isLight ? "#f8fafc" : "#151f1e"
  readonly property color bgSurface: isLight ? "#ffffff" : "#1c2827"
  readonly property color borderCard: isLight ? "#cbd5e1" : Commons.Color.popups.border
  readonly property color borderItem: isLight ? "#dbe3ec" : "#2f4441"
  readonly property color fgPrimary: isLight ? "#0f172a" : "#e2e8f0"
  readonly property color fgMuted: isLight ? "#64748b" : "#8ea39e"
  readonly property color accentMain: isLight ? "#0284c7" : "#38bdf8"
  readonly property color sepColor: isLight ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.14)
  readonly property color trackBg: isLight ? "#e2e8f0" : "#233331"
  readonly property color emptySlotBg: isLight ? "#f1f5f9" : "#182422"
  readonly property color emptySlotBar: isLight ? "#cbd5e1" : "#2d3f3c"
  readonly property color refLineColor: isLight ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
  readonly property color btnBg: isLight ? "#ffffff" : "#1c2827"
  readonly property color btnHoverBg: isLight ? "#f1f5f9" : "#253634"
  readonly property color btnActiveBg: isLight ? "#e0f2fe" : "#24403c"
  readonly property color btnActiveBorder: isLight ? "#0284c7" : "#52b788"

  property var stats: ({
    rangeKey: "24h",
    rangeLabel: "过去 24 小时",
    resetTs: 0,
    resetLabel: "",
    theme: "dark",
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

  readonly property string uiFont: (root.bar && root.bar.fontFamily) ? root.bar.fontFamily : Style.font.family

  function close() {
    popupOpen = false
  }

  function runStatsCommand(extraArgs) {
    if (statsProc.running) {
      root.pendingRefresh = true
      if (extraArgs) root.pendingActionArgs = extraArgs
      return
    }
    root.pendingRefresh = false
    root.pendingActionArgs = ""
    var tail = extraArgs ? (" " + extraArgs) : ""
    statsProc.command = ["bash", "-c", "exec \"$HOME/.local/bin/omarchy-ai-stats\" --json-detail --range \"$1\"" + tail, "stats", root.selectedRange]
    statsProc.running = true
  }

  function refreshStats(forceFresh) {
    runStatsCommand(forceFresh ? "--no-cache" : "")
  }

  function resetStats() {
    root.hoveredModelIdx = -1
    root.hoveredSlotIdx = -1
    runStatsCommand("--reset --no-cache")
  }

  function restoreStats() {
    root.hoveredModelIdx = -1
    root.hoveredSlotIdx = -1
    runStatsCommand("--restore --no-cache")
  }

  function toggleTheme() {
    var nextTheme = root.isLight ? "dark" : "light"
    root.themeMode = nextTheme
    runStatsCommand("--set-theme " + nextTheme)
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
      if (parsed.theme === "light" || parsed.theme === "dark") {
        root.themeMode = parsed.theme
      }
    } catch (e) {}
  }

  function hitColor(rate) {
    if (root.isLight) {
      if (rate >= 95) return "#0284c7"
      if (rate >= 88) return "#059669"
      if (rate >= 75) return "#d97706"
      if (rate >= 50) return "#ea580c"
      return "#dc2626"
    }
    if (rate >= 95) return "#00e5ff"
    if (rate >= 88) return "#34d399"
    if (rate >= 75) return "#fbbf24"
    if (rate >= 50) return "#fb923c"
    return "#f87171"
  }

  function modelSeriesColor(idx, fallbackColor) {
    if (root.isLight) {
      var lightPalette = ["#0284c7", "#059669", "#d97706", "#7c3aed"]
      return lightPalette[idx % 4]
    }
    return String(fallbackColor || "#00e5ff")
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
        root.runStatsCommand(root.pendingActionArgs)
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

  // 自适应白天/黑夜主题的小按钮
  component CardBtn: Rectangle {
    id: cb
    property string label: ""
    property bool active: false
    property bool danger: false
    property real hPad: Style.space(8)
    property real vPad: Style.space(4)
    signal triggered()

    implicitWidth: cbText.implicitWidth + hPad * 2
    implicitHeight: cbText.implicitHeight + vPad * 2
    radius: Style.space(6)
    color: active ? root.btnActiveBg : (cbMouse.containsMouse ? root.btnHoverBg : root.btnBg)
    border.width: 1
    border.color: active ? root.btnActiveBorder : (danger && cbMouse.containsMouse ? (root.isLight ? "#dc2626" : "#f87171") : root.borderItem)
    scale: cbMouse.pressed ? 0.96 : 1.0

    Text {
      id: cbText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: cb.label
      color: cb.danger && cbMouse.containsMouse
        ? (root.isLight ? "#dc2626" : "#f87171")
        : (cb.active ? (root.isLight ? "#0369a1" : "#ffffff") : root.fgPrimary)
      font.family: root.uiFont
      font.pixelSize: Style.font.caption
      font.bold: cb.active
    }

    MouseArea {
      id: cbMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: cb.triggered()
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    padding: 0
    borderColor: root.borderCard
    borderSpec: Border.flat(root.borderCard, Math.max(1, Style.space(2)))
    contentWidth: popup.fittedContentWidth(Style.space(536))
    contentHeight: popup.fittedContentHeight(themeWrap.implicitHeight)

    Rectangle {
      id: themeWrap
      width: parent.width
      implicitHeight: mainColumn.implicitHeight + Style.spacing.popupPadding * 2
      height: implicitHeight
      radius: Style.cornerRadius
      color: root.bgCard

      Behavior on color {
        ColorAnimation { duration: Style.duration(160) }
      }

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.popupPadding
        spacing: Style.space(8)

        // 顶部标题、主题切换与时间区间切换
        Row {
          width: parent.width
          spacing: Style.space(8)

          Column {
            width: parent.width - rightHeaderControls.implicitWidth - Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "󰧑"
                color: root.accentMain
                font.family: root.uiFont
                font.pixelSize: Style.font.subtitle
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: "AI 模型用量与缓存监控"
                color: root.fgPrimary
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
              text: (root.stats.rangeLabel || "过去 24 小时")
                + (root.stats.resetLabel ? (" (" + root.stats.resetLabel + ")") : "")
                + " · 更新于 " + (root.stats.updatedAt || "--:--")
              color: root.stats.resetLabel ? root.accentMain : root.fgMuted
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: rightHeaderControls
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(5)

            CardBtn {
              label: root.isLight ? "🌙 黑夜" : "☀ 白天"
              onTriggered: root.toggleTheme()
            }

            Row {
              spacing: Style.space(3)
              Repeater {
                model: [
                  { key: "1h", label: "1小时" },
                  { key: "24h", label: "24小时" },
                  { key: "7d", label: "7天" }
                ]

                CardBtn {
                  required property var modelData
                  label: modelData.label
                  active: root.selectedRange === modelData.key
                  onTriggered: {
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
        }

        // 三列核心指标卡片
        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: (parent.width - Style.space(16)) / 3
            height: Style.space(52)
            radius: Style.spacing.labelGap
            color: root.bgSurface
            border.width: 1
            border.color: root.borderItem

            Column {
              anchors.centerIn: parent
              width: parent.width - Style.space(10)
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "等效模型估值"
                color: root.fgMuted
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
              }
              Text {
                textFormat: Text.PlainText
                text: "$" + Number(root.stats.cost || 0).toFixed(2)
                color: root.fgPrimary
                font.family: root.uiFont
                font.pixelSize: Style.font.subtitle
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
              }
            }
          }

          Rectangle {
            width: (parent.width - Style.space(16)) / 3
            height: Style.space(52)
            radius: Style.spacing.labelGap
            color: root.bgSurface
            border.width: 1
            border.color: root.borderItem

            Column {
              anchors.centerIn: parent
              width: parent.width - Style.space(10)
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "平均缓存命中"
                color: root.fgMuted
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

          Rectangle {
            width: (parent.width - Style.space(16)) / 3
            height: Style.space(52)
            radius: Style.spacing.labelGap
            color: root.bgSurface
            border.width: 1
            border.color: root.borderItem

            Column {
              anchors.centerIn: parent
              width: parent.width - Style.space(10)
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "调用与总量"
                color: root.fgMuted
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
              }
              Text {
                textFormat: Text.PlainText
                text: String(root.stats.calls || 0) + " 次 · " + (root.stats.totalTokensShort || "0")
                color: root.fgPrimary
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
              color: root.fgPrimary
              font.family: root.uiFont
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              width: parent.width * 0.45
            }
            Text {
              textFormat: Text.PlainText
              text: "每 1 输出伴随 " + Number(root.stats.cacheMultiplier || 0).toFixed(1) + " 缓存读取"
              color: root.fgMuted
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              width: parent.width * 0.55
            }
          }

          Repeater {
            model: [
              { label: "缓存读取输入", count: root.stats.cachedShort || "0", pct: Number(root.stats.cachedPct || 0), color: root.isLight ? "#0284c7" : "#00e5ff", show: true },
              { label: "常规未缓存输入", count: root.stats.uncachedShort || "0", pct: Number(root.stats.uncachedPct || 0), color: root.isLight ? "#2563eb" : "#60a5fa", show: true },
              { label: "缓存写入输入", count: root.stats.cacheWriteShort || "0", pct: Number(root.stats.cacheWritePct || 0), color: root.isLight ? "#d97706" : "#fbbf24", show: Number(root.stats.cacheWrite || 0) > 0 },
              { label: "生成与思考输出", count: root.stats.outputShort || "0", pct: Number(root.stats.outputPct || 0), color: root.isLight ? "#7c3aed" : "#c084fc", show: true }
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
                  color: root.fgPrimary
                  font.family: root.uiFont
                  font.pixelSize: Style.font.caption
                  width: parent.width * 0.45
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.count + "  (" + modelData.pct.toFixed(1) + "%)"
                  color: root.fgMuted
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
                color: root.trackBg

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

        Rectangle {
          width: parent.width
          height: 1
          color: root.sepColor
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
              color: root.fgPrimary
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
                ? root.modelSeriesColor(root.hoveredModelIdx, root.stats.modelTrends[root.hoveredModelIdx].color)
                : root.fgMuted
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideLeft
              width: parent.width * 0.58
            }
          }

          Rectangle {
            visible: !root.stats.modelTrends || root.stats.modelTrends.length === 0
            width: parent.width
            height: Style.space(52)
            radius: Style.spacing.labelGap
            color: root.bgSurface
            border.width: 1
            border.color: root.borderItem

            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(20)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.stats.resetLabel
                ? ("已从 " + root.stats.resetLabel.replace("自 ", "").replace(" 起", "") + " 清空统计基线，等待新请求产生后从零展示")
                : "当前所选时间范围内暂无模型调用数据"
              color: root.fgMuted
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          Grid {
            visible: root.stats.modelTrends && root.stats.modelTrends.length > 0
            width: parent.width
            columns: 2
            columnSpacing: Style.space(6)
            rowSpacing: Style.space(6)

            Repeater {
              model: root.stats.modelTrends || []

              Rectangle {
                id: mCard
                required property var modelData
                required property int index
                readonly property color seriesCol: root.modelSeriesColor(mCard.index, mCard.modelData.color)
                width: (parent.width - Style.space(6)) / 2
                height: Style.space(86)
                radius: Style.spacing.labelGap
                color: root.bgSurface
                border.width: 1
                border.color: root.hoveredModelIdx === mCard.index ? mCard.seriesCol : root.borderItem

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
                      color: mCard.seriesCol
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: root.compactModelTitle(mCard.modelData.name)
                      color: root.fgPrimary
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

                  Item {
                    width: parent.width
                    height: Style.space(40)

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width
                      height: 1
                      color: root.refLineColor
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

                          Rectangle {
                            anchors.fill: parent
                            radius: Style.space(1)
                            color: (root.hoveredModelIdx === mCard.index && root.hoveredSlotIdx === sItem.index)
                              ? (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.14))
                              : root.emptySlotBg
                          }

                          Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: sItem.modelData.hasData
                              ? Math.max(Style.space(3), parent.height * Math.min(1.0, Math.max(0.0, Number(sItem.modelData.hitRate || 0) / 100.0)))
                              : Style.space(2)
                            radius: Style.space(1)
                            color: sItem.modelData.hasData ? mCard.seriesCol : root.emptySlotBar
                            opacity: sItem.modelData.hasData
                              ? ((root.hoveredModelIdx === mCard.index && root.hoveredSlotIdx === sItem.index) ? 1.0 : 0.90)
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
                      color: root.fgMuted
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
                      color: root.fgMuted
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

        Rectangle {
          visible: root.stats.models && root.stats.models.length > 0
          width: parent.width
          height: 1
          color: root.sepColor
        }

        // 全部活跃模型列表 (精确 3 行整数高度 + 右侧滚动条)
        Column {
          visible: root.stats.models && root.stats.models.length > 0
          width: parent.width
          spacing: Style.space(5)

          readonly property real itemH: Style.space(42)
          readonly property real itemGap: Style.space(4)

          Row {
            width: parent.width
            Text {
              textFormat: Text.PlainText
              text: "全部活跃模型用量与平均缓存"
              color: root.fgPrimary
              font.family: root.uiFont
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              width: parent.width * 0.65
            }
            Text {
              textFormat: Text.PlainText
              text: "共 " + String(root.stats.models ? root.stats.models.length : 0) + " 个 (滚轮翻页)"
              color: root.fgMuted
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              width: parent.width * 0.35
            }
          }

          Item {
            id: listViewport
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

                  Rectangle {
                    required property var modelData
                    width: modelListCol.width
                    height: Style.space(42)
                    radius: Style.spacing.labelGap
                    color: root.bgSurface
                    border.width: 1
                    border.color: root.borderItem

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
                          color: root.fgPrimary
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
                          color: root.fgPrimary
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
                        color: root.fgMuted
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

            Rectangle {
              id: scrollTrack
              visible: listViewport.canScroll
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: Style.space(4)
              radius: Style.space(2)
              color: root.trackBg

              Rectangle {
                width: parent.width
                radius: parent.radius
                color: root.accentMain
                opacity: 0.65
                readonly property real ratio: modelFlick.contentHeight > 0 ? Math.min(1.0, modelFlick.height / modelFlick.contentHeight) : 1.0
                height: Math.max(Style.space(16), parent.height * ratio)
                y: modelFlick.contentHeight > modelFlick.height
                  ? (modelFlick.contentY / (modelFlick.contentHeight - modelFlick.height)) * (parent.height - height)
                  : 0
              }
            }
          }
        }

        // 底部数据源与操作按钮组 (含清空、恢复历史、刷新、终端看板)
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            text: (root.stats.sources && root.stats.sources.length > 0)
              ? ("数据源: " + root.stats.sources.join("、"))
              : (root.stats.resetLabel ? ("状态: 已清零待新请求") : "数据源: 等待日志接入")
            color: root.fgMuted
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width - actionRow.implicitWidth - Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
          }

          Row {
            id: actionRow
            spacing: Style.space(5)
            anchors.verticalCenter: parent.verticalCenter

            CardBtn {
              visible: Number(root.stats.resetTs || 0) > 0
              label: "恢复历史"
              active: true
              onTriggered: root.restoreStats()
            }

            CardBtn {
              label: "清空"
              danger: true
              onTriggered: root.resetStats()
            }

            CardBtn {
              label: "刷新"
              onTriggered: root.refreshStats(true)
            }

            CardBtn {
              label: "终端看板"
              onTriggered: {
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
}
