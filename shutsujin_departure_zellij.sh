#!/bin/bash
# ============================================================
# shutsujin_departure_zellij.sh - multi-agent-shogun zellij版出陣スクリプト
# ============================================================
# 使用方法:
#   ./shutsujin_departure_zellij.sh           # 全エージェント起動
#   ./shutsujin_departure_zellij.sh -c        # キューをリセットして起動
#   ./shutsujin_departure_zellij.sh -s        # セットアップのみ（Claude起動なし）
#   ./shutsujin_departure_zellij.sh -k        # 決戦の陣（全足軽Opus）
#   ./shutsujin_departure_zellij.sh -h        # ヘルプ表示
# ============================================================

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 言語設定を読み取り（デフォルト: ja）
LANG_SETTING="ja"
if [ -f "./config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# 色付きログ関数（戦国風）
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_war() {
    echo -e "\033[1;31m【戦】\033[0m $1"
}

# ============================================================
# オプション解析
# ============================================================
SETUP_ONLY=false
CLEAN_MODE=false
KESSEN_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--setup-only)
            SETUP_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        -k|--kessen)
            KESSEN_MODE=true
            shift
            ;;
        -h|--help)
            echo ""
            echo "🏯 multi-agent-shogun zellij版 出陣スクリプト"
            echo ""
            echo "使用方法: ./shutsujin_departure_zellij.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -c, --clean         キューとダッシュボードをリセットして起動"
            echo "  -k, --kessen        決戦の陣（全足軽をOpusで起動）"
            echo "  -s, --setup-only    zellijセッションのセットアップのみ（Claude起動なし）"
            echo "  -h, --help          このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./shutsujin_departure_zellij.sh              # 通常起動"
            echo "  ./shutsujin_departure_zellij.sh -c           # クリーンスタート"
            echo "  ./shutsujin_departure_zellij.sh -s           # セットアップのみ"
            echo "  ./shutsujin_departure_zellij.sh -k           # 決戦の陣"
            echo ""
            echo "モデル構成:"
            echo "  将軍:      Opus（thinking無効）"
            echo "  家老:      Opus Thinking"
            echo "  足軽1-4:   Sonnet Thinking（平時）/ Opus Thinking（決戦）"
            echo "  足軽5-8:   Opus Thinking"
            echo ""
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            echo "./shutsujin_departure_zellij.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# ============================================================
# 出陣バナー表示
# ============================================================
show_battle_cry() {
    clear

    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗██╗  ██╗██╗   ██╗████████╗███████╗██╗   ██╗     ██╗██╗███╗   ██╗\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m██╔════╝██║  ██║██║   ██║╚══██╔══╝██╔════╝██║   ██║     ██║██║████╗  ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗███████║██║   ██║   ██║   ███████╗██║   ██║     ██║██║██╔██╗ ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚════██║██╔══██║██║   ██║   ██║   ╚════██║██║   ██║██   ██║██║██║╚██╗██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████║██║  ██║╚██████╔╝   ██║   ███████║╚██████╔╝╚█████╔╝██║██║ ╚████║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝  ╚════╝ ╚═╝╚═╝  ╚═══╝\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m       \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35mzellij版 天下布武！\033[0m                   \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    echo -e "\033[1;34m  ╔═════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m  ║\033[0m                    \033[1;37m【 足 軽 隊 列 ・ 八 名 配 備 】\033[0m                      \033[1;34m║\033[0m"
    echo -e "\033[1;34m  ╚═════════════════════════════════════════════════════════════════════════════╝\033[0m"

    cat << 'ASHIGARU_EOF'

       /\      /\      /\      /\      /\      /\      /\      /\
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
     /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\
       ||      ||      ||      ||      ||      ||      ||      ||
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
      /  \    /  \    /  \    /  \    /  \    /  \    /  \    /  \
     [足1]   [足2]   [足3]   [足4]   [足5]   [足6]   [足7]   [足8]

ASHIGARU_EOF

    echo -e "                    \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""

    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-shogun (zellij版)\033[0m  〜 \033[1;36m戦国マルチエージェント統率システム\033[0m 〜  \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m将軍\033[0m: プロジェクト統括    \033[1;31m家老\033[0m: タスク管理    \033[1;34m足軽\033[0m: 実働部隊×8      \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# バナー表示実行
show_battle_cry

echo -e "  \033[1;33m天下布武！陣立てを開始いたす\033[0m (Setting up the battlefield)"
echo ""

# ============================================================
# STEP 1: 既存セッションクリーンアップ
# ============================================================
log_info "🧹 既存の陣を撤収中..."
if zellij list-sessions 2>/dev/null | grep -q "shogun"; then
    zellij delete-session shogun --force 2>/dev/null && log_info "  └─ shogun陣、撤収完了" || log_info "  └─ shogun陣は存在せず"
fi

# ============================================================
# STEP 2: キューディレクトリ確保 + リセット（--clean時のみ）
# ============================================================
[ -d ./queue/reports ] || mkdir -p ./queue/reports
[ -d ./queue/tasks ] || mkdir -p ./queue/tasks

if [ "$CLEAN_MODE" = true ]; then
    log_info "📜 前回の軍議記録を破棄中..."

    # バックアップ
    BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
    if [ -f "./dashboard.md" ] && grep -q "cmd_" "./dashboard.md" 2>/dev/null; then
        mkdir -p "$BACKUP_DIR"
        cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/tasks" "$BACKUP_DIR/" 2>/dev/null || true
        log_info "📦 前回の記録をバックアップ: $BACKUP_DIR"
    fi

    # 足軽タスクファイルリセット
    for i in {1..8}; do
        cat > ./queue/tasks/ashigaru${i}.yaml << EOF
# 足軽${i}専用タスクファイル
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
    done

    # 足軽レポートファイルリセット
    for i in {1..8}; do
        cat > ./queue/reports/ashigaru${i}_report.yaml << EOF
worker_id: ashigaru${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    done

    # キューファイルリセット
    cat > ./queue/shogun_to_karo.yaml << 'EOF'
queue: []
EOF

    cat > ./queue/karo_to_ashigaru.yaml << 'EOF'
assignments:
  ashigaru1: { task_id: null, description: null, target_path: null, status: idle }
  ashigaru2: { task_id: null, description: null, target_path: null, status: idle }
  ashigaru3: { task_id: null, description: null, target_path: null, status: idle }
  ashigaru4: { task_id: null, description: null, target_path: null, status: idle }
  ashigaru5: { task_id: null, description: null, target_path: null, status: idle }
  ashigaru6: { task_id: null, description: null, target_path: null, status: idle }
  ashigaru7: { task_id: null, description: null, target_path: null, status: idle }
  ashigaru8: { task_id: null, description: null, target_path: null, status: idle }
EOF

    # ダッシュボード初期化
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
    cat > ./dashboard.md << EOF
# 📊 戦況報告
最終更新: ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております
なし

## 🔄 進行中 - 只今、戦闘中でござる
なし

## ✅ 本日の戦果
| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち
なし

## 🛠️ 生成されたスキル
なし

## ⏸️ 待機中
なし

## ❓ 伺い事項
なし
EOF

    log_success "✅ 陣払い完了"
else
    log_info "📜 前回の陣容を維持して出陣..."
fi
echo ""

# ============================================================
# STEP 3: zellij の存在確認
# ============================================================
if ! command -v zellij &> /dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] zellij not found!                                ║"
    echo "  ║  zellij が見つかりません                                   ║"
    echo "  ╠════════════════════════════════════════════════════════════╣"
    echo "  ║  インストール方法:                                         ║"
    echo "  ║     cargo install zellij                                  ║"
    echo "  ║     または: brew install zellij                           ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

log_success "✅ zellij 確認完了 ($(zellij --version))"
echo ""

# ============================================================
# STEP 4: zellij セッション起動
# ============================================================
log_war "👑 将軍の本陣を構築中..."

# レイアウトファイルの存在確認
LAYOUT_FILE="$SCRIPT_DIR/layouts/shogun.kdl"
if [ ! -f "$LAYOUT_FILE" ]; then
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] Layout file not found!                           ║"
    echo "  ║  layouts/shogun.kdl が見つかりません                       ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    exit 1
fi

# zellij セッション起動（バックグラウンド）
log_info "  └─ zellij セッション起動中..."
zellij --layout "$LAYOUT_FILE" --session shogun &
ZELLIJ_PID=$!

# セッション起動を待機
sleep 3

log_success "  └─ 将軍の本陣・家老・足軽の陣、構築完了"
echo ""

# ============================================================
# STEP 5: Claude Code 起動（-s / --setup-only のときはスキップ）
# ============================================================
if [ "$SETUP_ONLY" = false ]; then
    if ! command -v claude &> /dev/null; then
        log_info "⚠️  claude コマンドが見つかりません"
        echo "  first_setup.sh を再実行してください"
        exit 1
    fi

    log_war "👑 全軍に Claude Code を召喚中..."

    # zellij セッションにアタッチして各ペインでClaude起動
    # zellij の制約: 直接ペインにコマンドを送れないため、
    # 起動時に command を指定するか、後からアタッチして実行

    # 方式: zellij run コマンドで各ペインでコマンド実行
    # 注意: zellij run は新しいペインを作る。既存ペインには write-chars を使う

    # まずセッションにアタッチ可能か確認
    sleep 2

    echo ""
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  📜 Claude Code 起動方法                                  │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
    echo "  zellij セッションが起動しました。"
    echo "  各ペインで Claude Code を起動するには:"
    echo ""
    echo "  1. セッションにアタッチ: zellij attach shogun"
    echo "  2. 各ペインで以下を実行:"
    echo ""
    echo "     将軍:      MAX_THINKING_TOKENS=0 claude --model opus --dangerously-skip-permissions"
    echo "     家老:      claude --model opus --dangerously-skip-permissions"
    if [ "$KESSEN_MODE" = true ]; then
        echo "     足軽1-8:   claude --model opus --dangerously-skip-permissions"
    else
        echo "     足軽1-4:   claude --model sonnet --dangerously-skip-permissions"
        echo "     足軽5-8:   claude --model opus --dangerously-skip-permissions"
    fi
    echo ""
    echo "  3. 各エージェントに指示書を読ませる:"
    echo "     将軍: instructions/shogun.md を読んで役割を理解せよ"
    echo "     家老: instructions/karo.md を読んで役割を理解せよ"
    echo "     足軽: instructions/ashigaru.md を読んで役割を理解せよ"
    echo ""

    # 自動起動を試みる（zellij の write-chars は現在フォーカス中のペインのみ）
    # セッションにアタッチして順次実行する方式は複雑なので、
    # ユーザーに手動実行を案内する

    if [ "$KESSEN_MODE" = true ]; then
        log_success "✅ 決戦の陣で出陣！全軍Opus！"
    else
        log_success "✅ 平時の陣で出陣"
    fi
    echo ""
fi

# ============================================================
# STEP 6: 環境確認・完了メッセージ
# ============================================================
log_info "🔍 陣容を確認中..."
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📺 Zellij陣容 (Session)                                  │"
echo "  └──────────────────────────────────────────────────────────┘"
zellij list-sessions 2>/dev/null | sed 's/^/     /' || echo "     (セッション確認中...)"
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📋 布陣図 (Formation)                                   │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "     【shogunタブ】将軍の本陣"
echo "     ┌─────────────────────────────┐"
echo "     │  将軍 (SHOGUN)              │  ← 総大将・プロジェクト統括"
echo "     └─────────────────────────────┘"
echo ""
echo "     【multiagentタブ】家老・足軽の陣（3x3 = 9ペイン）"
echo "     ┌─────────┬─────────┬─────────┐"
echo "     │  karo   │ashigaru3│ashigaru6│"
echo "     │  (家老) │ (足軽3) │ (足軽6) │"
echo "     ├─────────┼─────────┼─────────┤"
echo "     │ashigaru1│ashigaru4│ashigaru7│"
echo "     │ (足軽1) │ (足軽4) │ (足軽7) │"
echo "     ├─────────┼─────────┼─────────┤"
echo "     │ashigaru2│ashigaru5│ashigaru8│"
echo "     │ (足軽2) │ (足軽5) │ (足軽8) │"
echo "     └─────────┴─────────┴─────────┘"
echo ""

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 出陣準備完了！天下布武！                              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

if [ "$SETUP_ONLY" = true ]; then
    echo "  ⚠️  セットアップのみモード: Claude Codeは未起動です"
    echo ""
fi

echo "  次のステップ:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  セッションにアタッチ:                                    │"
echo "  │     zellij attach shogun                                 │"
echo "  │                                                          │"
echo "  │  エージェントID確認:                                      │"
echo "  │     echo \$AGENT_ID                                       │"
echo "  │                                                          │"
echo "  │  タブ切替:                                                │"
echo "  │     Ctrl+t → 1 (shogunタブ)                              │"
echo "  │     Ctrl+t → 2 (multiagentタブ)                          │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   天下布武！勝利を掴め！ (Tenka Fubu! Seize victory!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""
