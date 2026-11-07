#!/bin/bash
# 把本仓库推送到 GitHub。token 只从环境变量读取，绝不写入仓库或 .git/config。
#
# 用法:
#   GITHUB_TOKEN=<pat> ./push-to-github.sh [仓库名] [可见性]
#
# token 需要 classic PAT 的 repo 权限，或 fine-grained PAT 对目标账户的
# "Administration: write" + "Contents: write"。
set -euo pipefail

REPO=${1:-sogou-shurufa-ubuntu-26.04}
VISIBILITY=${2:-public}

: "${GITHUB_TOKEN:?请先设置 GITHUB_TOKEN 环境变量}"

# GitHub 直连较慢，优先走 gh-proxy 转发 API；两者都试
API=""
for base in https://gh-proxy.com/https://api.github.com https://api.github.com; do
  if timeout 25 curl -fsS -o /dev/null -H "Authorization: Bearer $GITHUB_TOKEN" "$base/user" 2>/dev/null; then
    API=$base; break
  fi
done
[ -n "$API" ] || { echo "无法访问 GitHub API（或 token 无效）" >&2; exit 1; }
echo "API: $API"

USER=$(curl -fsS -H "Authorization: Bearer $GITHUB_TOKEN" "$API/user" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["login"])')
echo "账户: $USER   仓库: $REPO ($VISIBILITY)"

# 仓库名只允许字母数字 . _ -，中文不行（中文放在 description / README 里）
if ! [[ "$REPO" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "仓库名含非法字符（GitHub 只允许 A-Z a-z 0-9 . _ -），请改用英文/拼音名" >&2
  exit 1
fi

DESC='搜狗输入法 NG 在 Ubuntu 26.04 / Fcitx 5 / Wayland 上的适配验证（免 root 沙箱 + 真机实测）| Sogou NG on Ubuntu 26.04 with Fcitx 5 + Wayland'

# 已存在则跳过创建
CODE=$(curl -sS -o /tmp/gh-repo-check.json -w '%{http_code}' \
  -H "Authorization: Bearer $GITHUB_TOKEN" "$API/repos/$USER/$REPO" || true)
if [ "$CODE" = "200" ]; then
  echo "仓库已存在，跳过创建"
else
  echo "创建仓库…"
  curl -fsS -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H 'Accept: application/vnd.github+json' \
    -d "$(python3 -c 'import json,sys; print(json.dumps({
        "name": sys.argv[1],
        "description": sys.argv[2],
        "homepage": "",
        "private": sys.argv[3]=="private",
        "has_issues": True,
        "has_projects": False,
        "has_wiki": False
    }, ensure_ascii=False))' "$REPO" "$DESC" "$VISIBILITY")" \
    "$API/user/repos" > /tmp/gh-repo-created.json
  echo "已创建"
fi

cd "$(dirname "$0")/.."
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 推送时用带 token 的临时 URL，但不写入 remote，避免凭据残留
PUSH_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${USER}/${REPO}.git"
echo "推送 $BRANCH …"
git push -u "$PUSH_URL" "$BRANCH" 2>&1 | sed -E 's/x-access-token:[^@]*@/x-access-token:***@/g'

# 把 remote 改回不含凭据的干净 URL
if git remote | grep -qx origin; then
  git remote set-url origin "https://github.com/${USER}/${REPO}.git"
else
  git remote add origin "https://github.com/${USER}/${REPO}.git"
fi

echo
echo "完成: https://github.com/${USER}/${REPO}"
echo "说明：token 未写入 .git/config；请检查 git remote -v 确认。"
