#!/usr/bin/env bash
# patrol-scope.sh — 生成巡查审计面：自给定基线以来的增量范围
#
# 用法:
#   ./patrol-scope.sh <since-ref|YYYY-MM-DD> [branch]
#
# 参数:
#   since-ref   上期巡查基线（commit/tag/branch），或日期 YYYY-MM-DD
#               （日期会解析为该日最后一次提交，日期当天含边界）
#   branch      巡查目标分支，默认 HEAD
#
# 输出四段：基线信息 / 新增提交 / 变更文件（含状态）/ 新增文件清单。
# 退出码：0 正常；2 参数错误；3 仓库无提交或基线解析失败。

set -euo pipefail

usage() { echo "用法: $0 <since-ref|YYYY-MM-DD> [branch]" >&2; exit 2; }

[ $# -ge 1 ] || usage
SINCE="$1"
BRANCH="${2:-HEAD}"

command -v git >/dev/null 2>&1 || { echo "错误: 需要 git" >&2; exit 3; }
git rev-parse --verify "$BRANCH" >/dev/null 2>&1 || { echo "错误: 分支/引用不存在: $BRANCH" >&2; exit 3; }

if [[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  BASE=$(git rev-list -1 --before="${SINCE} 23:59:59" "$BRANCH" || true)
  if [ -z "${BASE:-}" ]; then
    echo "错误: $BRANCH 上找不到 $SINCE 之前的提交" >&2
    exit 3
  fi
else
  BASE=$(git rev-parse --verify "$SINCE" 2>/dev/null) || { echo "错误: 基线引用不存在: $SINCE" >&2; exit 3; }
fi

BASE_SHORT=$(git rev-parse --short "$BASE")
BASE_DATE=$(git show -s --format=%ci "$BASE")

echo "=== 基线 ==="
echo "基线: $BASE_SHORT ($BASE_DATE)"
echo "目标: $BRANCH ($(git rev-parse --short "$BRANCH"))"
echo

echo "=== 新增提交（自基线以来） ==="
git log --oneline "$BASE..$BRANCH"
echo

echo "=== 变更文件（A=新增 M=修改 D=删除） ==="
git diff --name-status "$BASE" "$BRANCH"
echo

echo "=== 新增文件清单（优先审计面） ==="
git diff --name-status --diff-filter=A "$BASE" "$BRANCH" | sed 's/^A\t/  /'
echo

NEW_COUNT=$(git diff --name-status --diff-filter=A "$BASE" "$BRANCH" | wc -l | tr -d ' ')
ALL_COUNT=$(git diff --name-only "$BASE" "$BRANCH" | wc -l | tr -d ' ')
echo "=== 汇总: 提交 $(git rev-list --count "$BASE..$BRANCH") 笔 · 变更 $ALL_COUNT 文件 · 其中新增 $NEW_COUNT ==="
