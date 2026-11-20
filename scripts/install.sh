#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${HOME}/.local/share/ai-usage"
CFG_DIR="${HOME}/.config/omarchy-ai-stats"
PLUGIN_ID="${USER:-local}.ai-stats"
PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
BACKUP_TS="$(date +%Y%m%d-%H%M%S)"

echo "==> [1/5] 检查并安装依赖 (python-rich)..."
if ! python3 -c "import rich" >/dev/null 2>&1; then
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm python-rich
  else
    pip install --user rich
  fi
fi

echo "==> [2/5] 安装主程序与模型单价表..."
mkdir -p "${BIN_DIR}" "${DATA_DIR}" "${CFG_DIR}"
cp "${PROJECT_DIR}/bin/omarchy-ai-stats" "${BIN_DIR}/omarchy-ai-stats"
chmod +x "${BIN_DIR}/omarchy-ai-stats"

if [[ ! -f "${CFG_DIR}/pricing.json" ]]; then
  cp "${PROJECT_DIR}/config/pricing.example.json" "${CFG_DIR}/pricing.json"
  echo "    已创建默认价格表: ${CFG_DIR}/pricing.json"
else
  echo "    保留现有价格表: ${CFG_DIR}/pricing.json"
fi

echo "==> [3/5] 配置桌面顶栏插件..."
if command -v omarchy >/dev/null 2>&1 && [[ -d "${HOME}/.config/omarchy" ]]; then
  mkdir -p "${PLUGIN_DIR}"
  cp "${PROJECT_DIR}/plugin/ai-stats/manifest.json" "${PLUGIN_DIR}/manifest.json"
  cp "${PROJECT_DIR}/plugin/ai-stats/BarWidget.qml" "${PLUGIN_DIR}/BarWidget.qml"
  # 替换为当前用户标识与绝对路径以确保插件零依赖秒启动
  sed -i "s/dunova\.ai-stats/${PLUGIN_ID}/g" "${PLUGIN_DIR}/manifest.json" "${PLUGIN_DIR}/BarWidget.qml"
  sed -i "s/\"dunova\"/\"${USER:-local}\"/g" "${PLUGIN_DIR}/manifest.json"

  omarchy plugin validate "${PLUGIN_DIR}" || true
  omarchy plugin enable "${PLUGIN_ID}" >/dev/null 2>&1 || true
  omarchy bar put "${PLUGIN_ID}" --section right >/dev/null 2>&1 || true
  omarchy-shell shell reloadPlugins >/dev/null 2>&1 || true
  echo "    已安装并启用 Omarchy Shell 原生顶栏插件: ${PLUGIN_ID}"
elif [[ -d "${HOME}/.config/waybar" ]]; then
  WAYBAR_CSS="${HOME}/.config/waybar/style.css"
  if [[ -f "${WAYBAR_CSS}" ]] && ! grep -q "#custom-ai-usage" "${WAYBAR_CSS}"; then
    cp "${WAYBAR_CSS}" "${WAYBAR_CSS}.bak.${BACKUP_TS}"
    printf "\n" >> "${WAYBAR_CSS}"
    cat "${PROJECT_DIR}/config/waybar-style.css" >> "${WAYBAR_CSS}"
    echo "    已追加 Waybar 样式至 ${WAYBAR_CSS}"
  fi
  echo "    检测到 Waybar 环境，请将 config/waybar-module.jsonc 中的模块配置加入 ~/.config/waybar/config.jsonc"
fi

echo "==> [4/5] 配置 Hyprland 终端看板居中浮窗规则..."
if [[ -f "${HOME}/.config/hypr/hyprland.lua" ]] && ! grep -q "org\\.omarchy\\.ai-usage" "${HOME}/.config/hypr/hyprland.lua"; then
  cp "${HOME}/.config/hypr/hyprland.lua" "${HOME}/.config/hypr/hyprland.lua.bak.${BACKUP_TS}"
  printf "\n" >> "${HOME}/.config/hypr/hyprland.lua"
  cat "${PROJECT_DIR}/config/hyprland-rules.lua" >> "${HOME}/.config/hypr/hyprland.lua"
  hyprctl reload >/dev/null 2>&1 || true
  echo "    已写入 Omarchy Lua 浮窗规则至 ~/.config/hypr/hyprland.lua"
elif [[ -f "${HOME}/.config/hypr/windows.conf" ]] && ! grep -q "org\\.omarchy\\.ai-usage" "${HOME}/.config/hypr/windows.conf"; then
  cp "${HOME}/.config/hypr/windows.conf" "${HOME}/.config/hypr/windows.conf.bak.${BACKUP_TS}"
  printf "\n" >> "${HOME}/.config/hypr/windows.conf"
  cat "${PROJECT_DIR}/config/hyprland-rules.conf" >> "${HOME}/.config/hypr/windows.conf"
  hyprctl reload >/dev/null 2>&1 || true
  echo "    已写入 Hyprland 浮窗规则至 ~/.config/hypr/windows.conf"
fi

echo "==> [5/5] 运行诊断自检..."
"${BIN_DIR}/omarchy-ai-stats" --check

echo ""
echo "================================================================"
echo "安装完成! 版本: v$(cat "${PROJECT_DIR}/VERSION" 2>/dev/null || echo '0.1.0')"
echo "  1. 顶栏图标: 点击右上角 󰧑 图标即可弹出/收回过去 24 小时统计卡片"
echo "  2. 终端看板: 直接运行 omarchy-ai-stats (模拟预览: omarchy-ai-stats --demo)"
echo "================================================================"
