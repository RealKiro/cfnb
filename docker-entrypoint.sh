#!/bin/sh
# docker-entrypoint.sh
# 用法：
#   docker run ghcr.io/xxx/cfnb                       -> 运行一次后退出
#   docker run -e RUN_INTERVAL=300 ghcr.io/xxx/cfnb   -> 每 300 秒循环运行
#   docker run ghcr.io/xxx/cfnb sh                    -> 进入交互 shell（参数透传）

set -eu

# 有额外参数时直接执行（供 CI 冒烟测试 / 调试用）
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

cd /app

# ---------- Git 环境初始化 ----------
# 镜像内不携带 .git，git_sync.sh 需要 commit 才能推送，这里按需初始化
GIT_USER_NAME="${GIT_USER_NAME:-cfnb-bot}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-cfnb@docker.local}"
GIT_REPO="${GIT_REPO:-}"          # 可选，格式：用户名/仓库名，用于补充 origin 远程
GIT_BRANCH="${GIT_BRANCH:-main}"

if [ ! -d /app/.git ]; then
    echo "[entrypoint] 未检测到 git 仓库，正在初始化..."
    git init -q -b "$GIT_BRANCH"
fi

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

if [ -n "$GIT_REPO" ] && ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/${GIT_REPO}.git"
    echo "[entrypoint] 已添加远程 origin -> github.com/${GIT_REPO}.git"
fi

# ---------- 运行模式 ----------
INTERVAL="${RUN_INTERVAL:-0}"

if [ "$INTERVAL" -gt 0 ] 2>/dev/null; then
    echo "[entrypoint] 循环模式：每 ${INTERVAL} 秒运行一次"
    while true; do
        python main.py || echo "[entrypoint] 本轮运行出现异常，继续下一轮"
        sleep "$INTERVAL"
    done
else
    echo "[entrypoint] 单次运行模式（设置 RUN_INTERVAL 可启用循环）"
    exec python main.py
fi
