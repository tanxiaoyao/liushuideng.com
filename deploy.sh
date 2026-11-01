#!/usr/bin/env bash
# 木子点灯博客一键部署：构建 + 推送源码(main) + 推送产物(gh-pages)
set -e
cd "$(dirname "$0")"

echo "[1/3] 构建站点..."
pnpm build > /tmp/blog-build.log 2>&1 && echo "  构建成功" || { echo "  构建失败，日志: /tmp/blog-build.log"; exit 1; }

echo "[2/3] 推送源码 (main)..."
git add -A
git commit -m "更新: $(date +%Y-%m-%d_%H:%M)" || echo "  源码无变更"
git push origin main 2>&1 | grep -E "main|error" || true

echo "[3/3] 推送产物 (gh-pages)..."
cd dist
git add -A
git commit -m "deploy: $(date +%Y-%m-%d_%H:%M)" || echo "  产物无变更"
git push origin gh-pages 2>&1 | grep -E "gh-pages|error" || true

echo "✅ 部署完成，CDN 生效约需 1-5 分钟"
echo "   站点: https://liushuideng.com/"
