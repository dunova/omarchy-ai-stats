#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="${USER:-local}.ai-stats"

echo "==> 卸载 omarchy-ai-stats..."
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin disable "${PLUGIN_ID}" >/dev/null 2>&1 || true
  rm -rf "${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
  omarchy-shell shell reloadPlugins >/dev/null 2>&1 || true
fi

rm -f "${HOME}/.local/bin/omarchy-ai-stats"
rm -rf "${HOME}/.config/omarchy-ai-stats"

echo "已移除可执行文件、价格配置与顶栏插件。"
echo "如需彻底清除自定义事件日志，可手动删除 ~/.local/share/ai-usage/"
