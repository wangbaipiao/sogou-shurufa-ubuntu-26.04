#!/bin/bash
# 把本仓库推送到 GitHub。
#
# token 来源（任选其一），绝不写入仓库、.git/config 或日志：
#   GITHUB_TOKEN_FILE=/path/to/token   ← 推荐，文件权限应为 600
#   GITHUB_TOKEN=<pat>                 ← 直接给环境变量
#
# 用法:
#   GITHUB_TOKEN_FILE=~/.config/github-pat ./push-to-github.sh [仓库名] [public|private]
#
# token 需要 classic PAT 的 repo 权限，或 fine-grained PAT 对目标账户的
# "Administration: write" + "Contents: write"。
set -euo pipefail

REPO=${1:-sogou-shurufa-ubuntu-26.04}
VISIBILITY=${2:-public}

# ---- 读取 token，全程不回显 ----
if [ -n "${GITHUB_TOKEN_FILE:-}" ]; then
  [ -f "$GITHUB_TOKEN_FILE" ] || { echo "token 文件不存在: $GITHUB_TOKEN_FILE" >&2; exit 1; }
  MODE=$(stat -c '%a' "$GITHUB_TOKEN_FILE")
  [ "$MODE" = "600" ] || { echo "为安全起见，请先 chmod 600 $GITHUB_TOKEN_FILE（当前 $MODE）" >&2; exit 1; }
  GITHUB_TOKEN=$(tr -d '[:space:]' < "$GITHUB_TOKEN_FILE")
fi
: "${GITHUB_TOKEN:?请设置 GITHUB_TOKEN_FILE 或 GITHUB_TOKEN}"
[ -n "$GITHUB_TOKEN" ] || { echo "token 为空" >&2; exit 1; }
TOKEN=$(printf '%s' "$GITHUB_TOKEN" | tr -d '[:space:]')
unset GITHUB_TOKEN

# 用 curl 的 config 文件传递 Authorization 头，token 不出现在 argv / ps 里
CURLCFG=$(mktemp /tmp/gh-curl-XXXXXX)
trap 'rm -f "$CURLCFG" /tmp/gh-repo-check.json /tmp/gh-repo-created.json' EXIT
chmod 600 "$CURLCFG"
printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > "$CURLCFG"
printf 'header = "Accept: application/vnd.github+json"\n' >> "$CURLCFG"

gh() { curl -fsS -K "$CURLCFG" "$@"; }
gh_raw() { curl -sS -K "$CURLCFG" "$@"; }

# 所有输出统一脱敏（防止上游错误信息带出 token）
redact() { sed -E 's/ghp_[A-Za-z0-9]+/ghp_***/g; s/github_pat_[A-Za-z0-9_]+/github_pat_***/g; s/x-access-token:[^@]*@/x-access-token:***@/g'; }

# GitHub 直连较慢，优先走 gh-proxy 转发 API。
# 注意：timeout 只能执行外部命令，不能执行 shell 函数，这里直接调 curl。
API=""
for base in https://gh-proxy.com/https://api.github.com https://api.github.com; do
  if timeout 30 curl -fsS -K "$CURLCFG" -o /dev/null "$base/user" 2>/dev/null; then
    API=$base; break
  fi
done
[ -n "$API" ] || { echo "无法访问 GitHub API（网络或 token 无效）" >&2; exit 1; }
echo "API: $API"

USER=$(gh "$API/user" | python3 -c 'import sys,json; print(json.load(sys.stdin)["login"])')
echo "账户: $USER   仓库: $REPO ($VISIBILITY)"

# GitHub 仓库名只允许 A-Z a-z 0-9 . _ -；中文放在 description / README 里
if ! [[ "$REPO" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "仓库名含非法字符（GitHub 只允许 A-Z a-z 0-9 . _ -）" >&2; exit 1
fi

DESC='搜狗输入法 NG 在 Ubuntu 26.04 / Fcitx 5 / Wayland 上的适配验证（免 root 沙箱 + 真机实测）| Sogou NG on Ubuntu 26.04 with Fcitx 5 + Wayland'

CODE=$(gh_raw -o /tmp/gh-repo-check.json -w '%{http_code}' "$API/repos/$USER/$REPO" || true)
if [ "$CODE" = "200" ]; then
  echo "仓库已存在，跳过创建"
else
  echo "创建仓库…"
  python3 -c 'import json,sys; print(json.dumps({
      "name": sys.argv[1], "description": sys.argv[2],
      "private": sys.argv[3]=="private",
      "has_issues": True, "has_projects": False, "has_wiki": False
  }, ensure_ascii=False))' "$REPO" "$DESC" "$VISIBILITY" > /tmp/gh-repo-created.json
  gh -X POST -d @/tmp/gh-repo-created.json "$API/user/repos" > /dev/null | redact
  echo "已创建"
fi

cd "$(dirname "$0")/.."
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 推送：token 放进 git 的临时 extraheader，用完即弃，不写入 .git/config
echo "推送 $BRANCH …"
if ! git -c http.extraheader="AUTHORIZATION: bearer $TOKEN" \
      push -u "https://github.com/${USER}/${REPO}.git" "$BRANCH" 2>&1 | redact; then
  echo "直连推送失败，可尝试走 gh-proxy 的 git 代理，或检查 token 的 repo 权限" >&2
  exit 1
fi

# remote 只留干净 URL，不含任何凭据
if git remote | grep -qx origin; then
  git remote set-url origin "https://github.com/${USER}/${REPO}.git"
else
  git remote add origin "https://github.com/${USER}/${REPO}.git"
fi

echo
echo "完成: https://github.com/${USER}/${REPO}"
echo "凭据未写入 .git/config；可用 git remote -v 复核。"
