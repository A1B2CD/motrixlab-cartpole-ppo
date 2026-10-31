#!/usr/bin/env bash
# 08 - 把云端证据提交并推回 GitHub
#
# 前提（二选一）：
#   A) 服务器上配好了 deploy key / PAT，`git push` 免交互；
#   B) 设置 GH_TOKEN 环境变量（HTTPS 方式）：
#        export GH_TOKEN=ghp_xxx
#        git remote set-url origin https://x-access-token:${GH_TOKEN}@github.com/<owner>/<repo>.git
#
# 用法：bash scripts/08_push_evidence.sh
#       MSG="evidence: cartpole on A100" bash scripts/08_push_evidence.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$REPO_ROOT"

MSG="${MSG:-evidence: cartpole PPO 云端运行证据 ($(hostname), $(date +%F))}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    die "$REPO_ROOT 不是 git 仓库"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    die "没有配置 origin，请先：git remote add origin <你的仓库地址>"
fi

log "变更文件"
git status --short

git add -A
if git diff --cached --quiet; then
    warn "没有需要提交的变更"
    exit 0
fi

log "提交：$MSG"
git -c user.name="${GIT_NAME:-$(git config user.name || echo motrixlab)}" \
    -c user.email="${GIT_EMAIL:-$(git config user.email || echo motrixlab@local)}" \
    commit -m "$MSG"

log "推送"
git push origin HEAD

log "完成。仓库地址：$(git remote get-url origin)"
