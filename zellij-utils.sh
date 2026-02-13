#!/bin/bash
# ============================================================
# zellij-utils.sh - zellij 版 send-keys 代替ユーティリティ
# ============================================================
# 使用方法: source zellij-utils.sh
#
# 機能:
#   - zellij_send_to_pane: 指定したペインにメッセージを送信
#   - zellij_capture_pane: ペインの出力をキャプチャ
#   - zellij_get_agent_id: 現在のエージェントIDを取得
#
# 制約事項:
#   - zellij は tmux の send-keys -t と異なり、任意のペインに直接
#     テキストを送信する機能がない
#   - そのため、フォーカス切替方式で実装
#   - 画面が一瞬動くが、機能的には同等
# ============================================================

# ペイン名からフォーカス移動シーケンスを取得
# multiagent タブの 3x3 グリッド配置に基づく
# ペイン配置:
#   +--------+--------+--------+
#   |  karo  |ashigaru|ashigaru|
#   |   (0)  |  3 (3) |  6 (6) |
#   +--------+--------+--------+
#   |ashigaru|ashigaru|ashigaru|
#   |  1 (1) |  4 (4) |  7 (7) |
#   +--------+--------+--------+
#   |ashigaru|ashigaru|ashigaru|
#   |  2 (2) |  5 (5) |  8 (8) |
#   +--------+--------+--------+

# ============================================================
# 設定
# ============================================================
ZELLIJ_SHOGUN_TAB="shogun"
ZELLIJ_MULTIAGENT_TAB="multiagent"

# ペイン名とインデックスのマッピング
declare -A PANE_INDEX=(
    ["karo"]=0
    ["ashigaru1"]=1
    ["ashigaru2"]=2
    ["ashigaru3"]=3
    ["ashigaru4"]=4
    ["ashigaru5"]=5
    ["ashigaru6"]=6
    ["ashigaru7"]=7
    ["ashigaru8"]=8
)

# ============================================================
# zellij_get_agent_id - 現在のエージェントIDを取得
# ============================================================
# 使用方法: zellij_get_agent_id
# 出力: shogun, karo, ashigaru1, ... ashigaru8
# ============================================================
zellij_get_agent_id() {
    echo "$AGENT_ID"
}

# ============================================================
# zellij_send_to_pane - 指定したペインにメッセージを送信
# ============================================================
# 使用方法: zellij_send_to_pane <pane_name> <message>
# 例: zellij_send_to_pane "karo" "報告書を確認されよ"
#     zellij_send_to_pane "ashigaru1" "任務を確認せよ"
#
# 引数:
#   pane_name: karo, ashigaru1, ... ashigaru8
#   message: 送信するメッセージ
#
# 動作:
#   1. multiagent タブに移動
#   2. 対象ペインにフォーカス
#   3. メッセージを書き込み
#   4. Enterを送信
#
# 注意:
#   - フォーカスが移動するため画面が一瞬動く
#   - 呼び出し元のペインに戻る処理は含まれない
#     (呼び出し元が人間のペインでなければ問題なし)
# ============================================================
zellij_send_to_pane() {
    local pane_name="$1"
    local message="$2"

    if [ -z "$pane_name" ] || [ -z "$message" ]; then
        echo "Usage: zellij_send_to_pane <pane_name> <message>" >&2
        return 1
    fi

    local pane_index="${PANE_INDEX[$pane_name]}"
    if [ -z "$pane_index" ]; then
        echo "Error: Unknown pane name: $pane_name" >&2
        echo "Valid names: karo, ashigaru1-8" >&2
        return 1
    fi

    # multiagent タブに移動
    zellij action go-to-tab-name "$ZELLIJ_MULTIAGENT_TAB"

    # 対象ペインにフォーカス (インデックスで指定)
    # zellij は pane ID での直接指定が難しいため、
    # 一度左上に移動してから相対移動する

    # まず左上 (karo) に移動
    zellij action focus-previous-pane 2>/dev/null || true
    for _ in {1..10}; do
        zellij action move-focus up 2>/dev/null || true
        zellij action move-focus left 2>/dev/null || true
    done

    # 目的のペインまで移動
    # 3x3 グリッドなので、column = index / 3, row = index % 3
    local col=$((pane_index / 3))
    local row=$((pane_index % 3))

    # 右に col 回移動
    for ((i=0; i<col; i++)); do
        zellij action move-focus right
    done

    # 下に row 回移動
    for ((i=0; i<row; i++)); do
        zellij action move-focus down
    done

    # メッセージを書き込み
    zellij action write-chars "$message"

    # Enter を送信 (ASCII 10 = LF)
    zellij action write 10
}

# ============================================================
# zellij_send_to_shogun - 将軍ペインにメッセージを送信
# ============================================================
# 使用方法: zellij_send_to_shogun <message>
# 注意: 通常、家老は将軍に send-keys しない (dashboard.md 経由)
# ============================================================
zellij_send_to_shogun() {
    local message="$1"

    if [ -z "$message" ]; then
        echo "Usage: zellij_send_to_shogun <message>" >&2
        return 1
    fi

    # shogun タブに移動
    zellij action go-to-tab-name "$ZELLIJ_SHOGUN_TAB"

    # メッセージを書き込み
    zellij action write-chars "$message"

    # Enter を送信
    zellij action write 10
}

# ============================================================
# zellij_capture_pane - ペインの出力をキャプチャ
# ============================================================
# 使用方法: zellij_capture_pane <pane_name> [lines]
# 例: zellij_capture_pane "karo" 20
#
# 動作:
#   1. 対象ペインの内容を一時ファイルにダンプ
#   2. 指定行数分を出力
#   3. 一時ファイルを削除
# ============================================================
zellij_capture_pane() {
    local pane_name="$1"
    local lines="${2:-20}"
    local tmp_file="/tmp/zellij_capture_$$.txt"

    if [ -z "$pane_name" ]; then
        echo "Usage: zellij_capture_pane <pane_name> [lines]" >&2
        return 1
    fi

    # 対象ペインにフォーカスしてダンプ
    # 現在のタブを保存
    local current_tab
    current_tab=$(zellij action query-tab-names 2>/dev/null | head -1 || echo "")

    # ペインにフォーカス
    local pane_index="${PANE_INDEX[$pane_name]}"
    if [ -n "$pane_index" ]; then
        zellij action go-to-tab-name "$ZELLIJ_MULTIAGENT_TAB"

        # 左上に移動
        for _ in {1..10}; do
            zellij action move-focus up 2>/dev/null || true
            zellij action move-focus left 2>/dev/null || true
        done

        # 目的のペインまで移動
        local col=$((pane_index / 3))
        local row=$((pane_index % 3))
        for ((i=0; i<col; i++)); do zellij action move-focus right; done
        for ((i=0; i<row; i++)); do zellij action move-focus down; done
    elif [ "$pane_name" = "shogun" ]; then
        zellij action go-to-tab-name "$ZELLIJ_SHOGUN_TAB"
    else
        echo "Error: Unknown pane name: $pane_name" >&2
        return 1
    fi

    # スクリーンをダンプ
    zellij action dump-screen "$tmp_file"

    # 最後の N 行を出力
    tail -n "$lines" "$tmp_file" 2>/dev/null

    # クリーンアップ
    rm -f "$tmp_file"

    # 元のタブに戻る (オプション)
    if [ -n "$current_tab" ]; then
        zellij action go-to-tab-name "$current_tab" 2>/dev/null || true
    fi
}

# ============================================================
# zellij_check_pane_busy - ペインが処理中か確認
# ============================================================
# 使用方法: zellij_check_pane_busy <pane_name>
# 戻り値: 0 = busy, 1 = idle
# ============================================================
zellij_check_pane_busy() {
    local pane_name="$1"
    local output

    output=$(zellij_capture_pane "$pane_name" 5 2>/dev/null)

    if echo "$output" | grep -qE "(thinking|Effecting|Generating|Working)"; then
        return 0  # busy
    else
        return 1  # idle
    fi
}

# ============================================================
# 使用例
# ============================================================
# source zellij-utils.sh
#
# # エージェントIDを確認
# zellij_get_agent_id  # → "karo"
#
# # 足軽にタスク通知
# zellij_send_to_pane "ashigaru1" "queue/tasks/ashigaru1.yaml に任務がある。確認して実行せよ。"
#
# # 家老に報告
# zellij_send_to_pane "karo" "ashigaru1、任務完了でござる。報告書を確認されよ。"
#
# # ペインの状態をキャプチャ
# zellij_capture_pane "ashigaru1" 10
#
# # ペインがビジーか確認
# if zellij_check_pane_busy "karo"; then
#     echo "家老は処理中..."
# fi
# ============================================================

echo "zellij-utils.sh loaded. Available functions:"
echo "  - zellij_get_agent_id"
echo "  - zellij_send_to_pane <pane_name> <message>"
echo "  - zellij_send_to_shogun <message>"
echo "  - zellij_capture_pane <pane_name> [lines]"
echo "  - zellij_check_pane_busy <pane_name>"
