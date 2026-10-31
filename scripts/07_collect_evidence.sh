#!/usr/bin/env bash
# 07 - 汇总所有云端证据（目录树、校验和、文件清单）
#
# 用法：bash scripts/07_collect_evidence.sh
#
# 产出：evidence/cloud/07_runs_tree.txt、07_checksums.txt、07_manifest.md

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RUN="$(latest_run)"

log "汇总证据"

{
    echo "================================================================"
    echo "host      : $(hostname)"
    echo "date      : $(date -Is)"
    echo "run dir   : ${RUN#$REPO_ROOT/}"
    echo "================================================================"
    echo
    echo "# tree"
    ( cd "$ML_DIR" && find "runs/cartpole" -printf '%y %10s  %p\n' 2>/dev/null | sort -k3 ) \
        || ( cd "$ML_DIR" && find "runs/cartpole" -exec ls -ld {} \; )
} > "$EVID/07_runs_tree.txt"

cat "$EVID/07_runs_tree.txt"

{
    echo "# 证据文件校验和（sha256）"
    echo
    ( cd "$REPO_ROOT" && find evidence/cloud -type f ! -name '07_checksums.txt' -print0 \
        | sort -z | xargs -0 sha256sum )
} > "$EVID/07_checksums.txt"

{
    echo "# 云端证据清单"
    echo
    echo "- 生成时间：$(date -Is)"
    echo "- 主机：$(hostname)"
    echo "- 训练目录：\`${RUN#$REPO_ROOT/}\`"
    echo
    echo "| 文件 | 大小 | 说明 |"
    echo "| --- | --- | --- |"
    for f in "$EVID"/*; do
        [[ -f "$f" ]] || continue
        printf '| `%s` | %s | |\n' "$(basename "$f")" "$(du -h "$f" | cut -f1)"
    done
} > "$EVID/07_manifest.md"

log "完成：$EVID/07_manifest.md"
