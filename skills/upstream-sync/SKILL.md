---
name: upstream-sync
description: Fork repository upstream synchronization. Analyzes divergence, proposes merge strategy, and executes with local change preservation.
user-invocable: true
tags:
  - git
  - fork
  - upstream
  - sync
  - merge
---

# Upstream Sync

Fork リポジトリの upstream 同期を安全かつ体系的に実行するスキル。

## Trigger Keywords

- "upstream 同期", "upstream sync", "upstream pull"
- "fork 元マージ", "fork 同期"
- "upstream 取り込み", "upstream merge"

## Workflow

### Phase 1: Analysis

```bash
# 1. upstream の最新を取得
git fetch upstream

# 2. diverge 状況を分析
echo "=== Divergence Analysis ==="
git rev-list --left-right --count upstream/main...HEAD
# Output: <behind>\t<ahead>

# 3. conflict candidate files
git diff --name-only upstream/main...HEAD

# 4. upstream の新規・変更・削除ファイル
echo "=== Upstream changes (since fork point) ==="
FORK_POINT=$(git merge-base upstream/main HEAD)
git diff --stat "$FORK_POINT" upstream/main

echo "=== Local changes (since fork point) ==="
git diff --stat "$FORK_POINT" HEAD

# 5. overlap detection (files changed in BOTH)
comm -12 \
  <(git diff --name-only "$FORK_POINT" upstream/main | sort) \
  <(git diff --name-only "$FORK_POINT" HEAD | sort)
```

### Phase 2: Strategy Proposal

Analyze the divergence and propose ONE of these strategies:

| Strategy | When to Use | Risk |
|----------|-------------|------|
| **merge** | Few conflicts, clean history not critical | Low |
| **rebase** | Linear history needed, <10 local commits, few conflicts | Medium |
| **reset + re-apply** | Many conflicts, local changes are mostly new files, upstream restructured heavily | Low (with backup) |
| **cherry-pick** | Only specific upstream commits needed | Low |

Present to user with:
- Estimated conflict count and affected files
- Recommended strategy with rationale
- Time estimate (Quick/Medium/Long)

### Phase 3: Execution (after user approval)

#### Pre-flight

```bash
# Safety backup
git stash
git branch local-backup-$(date +%Y%m%d) HEAD

# Verify clean state
git status
```

#### Strategy: merge

```bash
git merge upstream/main
# Resolve conflicts if any
git add -A && git commit
```

#### Strategy: rebase

```bash
git rebase upstream/main
# Resolve conflicts per-commit if any
```

#### Strategy: reset + re-apply

```bash
# 1. Identify local-only files (new files not in upstream)
LOCAL_FILES=$(git diff --name-only --diff-filter=A "$FORK_POINT" HEAD)

# 2. Identify local modifications to upstream files
MODIFIED_FILES=$(comm -12 \
  <(git diff --name-only "$FORK_POINT" upstream/main | sort) \
  <(git diff --name-only "$FORK_POINT" HEAD | sort))

# 3. Reset to upstream
git reset --hard upstream/main

# 4. Restore local-only files
for f in $LOCAL_FILES; do
  git checkout local-backup-YYYYMMDD -- "$f"
done

# 5. Re-apply modifications to upstream files (manual, context-aware)
# For each file in MODIFIED_FILES:
#   - Compare local-backup version vs upstream version
#   - Apply local changes to upstream structure
```

#### Strategy: cherry-pick

```bash
# Pick specific commits
git cherry-pick <commit1> <commit2> ...
```

### Phase 4: Verification

```bash
# 1. Diff check (only expected changes remain)
git diff --stat upstream/main

# 2. Local feature preservation check
# Verify all local-only features still exist

# 3. Build/test if available
# Run project-specific verification commands

# 4. Grep for key local features
# e.g., grep -r "zellij" for zellij support
```

### Phase 5: Push

```bash
# force-with-lease if history was rewritten (reset/rebase)
git push origin main --force-with-lease

# normal push if merge
git push origin main
```

## Safety Rules

1. **ALWAYS create backup branch** before any destructive operation
2. **ALWAYS use `--force-with-lease`** instead of `--force`
3. **NEVER delete backup branch** until user confirms sync is complete
4. **ALWAYS show diff summary** before push
5. **ASK user before push** (force push changes remote history)

## Notes

- This skill is designed for fork repos where `upstream` remote points to the original repo
- If `upstream` remote doesn't exist, guide user to add it: `git remote add upstream <url>`
- The backup branch naming convention is `local-backup-YYYYMMDD`
- For projects with CI, run the CI checks before pushing
