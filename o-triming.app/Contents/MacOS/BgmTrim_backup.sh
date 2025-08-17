#!/bin/bash

# エラー時の動作を制御（デバッグのため一時的に緩和）
# set -e

# エラー表示制御用変数
error_dialog_shown=false

# デバッグログ関数
log_error() {
    echo "ERROR: $1" >&2
    # ダイアログでのエラー表示は重要なもののみに制限
}

log_info() {
    echo "INFO: $1"
}

# 重要なエラーのみダイアログ表示する関数（一度だけ）
critical_error() {
    echo "CRENVEOF

            log_info "設定が更新されました。スクリプトを再実行します..."
            exec bash "$0"  # スクリプトを再実行
        else
            error_message="❌ 入力エラー

入力された値に数値以外が含まれています:

開始時間: $new_start
終了時間: $new_stop
フェードアウト: $new_fadeout
無音追加: $new_silence

数値のみ入力してください（例: 10, 10.5）"
            osascript -e "display dialog \"$error_message\" buttons {\"設定をやり直す\"} default button 1 with icon stop" 2>/dev/null || true
            exec bash "$0"  # 設定画面に戻る
        fi2
    if [ "$error_dialog_shown" != true ]; then
        error_dialog_shown=true
        osascript -e "display dialog \"重要なエラーが発生しました: $1\" buttons {\"OK\"} default button 1 with icon stop" 2>/dev/null || true
    fi
}

# エラーハンドリング関数
error_exit() {
    local exit_code=${2:-1}
    critical_error "$1"
    exit $exit_code
}

currentdir=$(cd "$(dirname "$0")"; pwd)

# load env
env="$currentdir/.env"

# デフォルト設定値
DEFAULT_START_SECOND=0
DEFAULT_STOP_SECOND=30
DEFAULT_FADEOUT_SECOND=2
DEFAULT_SILENCE_SECOND=1

# 設定ファイルの存在確認と作成
if [ ! -f "$env" ]; then
    log_info "設定ファイルが見つかりません。デフォルト設定で作成します: $env"

    # デフォルト設定ファイルを作成
    cat > "$env" << EOF
# 音声編集設定ファイル
# 各値は秒単位で指定してください

# 開始時間（秒）
START_SECOND=$DEFAULT_START_SECOND

# 終了時間（秒）
STOP_SECOND=$DEFAULT_STOP_SECOND

# フェードアウト時間（秒）- 終了時刻から遡る時間
FADEOUT_SECOND=$DEFAULT_FADEOUT_SECOND

# 無音追加時間（秒）- 末尾に追加する無音の長さ
SILENCE_SECOND=$DEFAULT_SILENCE_SECOND
EOF

    if [ ! -f "$env" ]; then
        error_exit "設定ファイルの作成に失敗しました: $env" 2
    fi

    log_info "デフォルト設定ファイルを作成しました"
fi

# 設定ファイルの読み込みを安全に実行
if ! . "$env"; then
    error_exit "設定ファイルの読み込みに失敗しました: $env" 3
fi

# 必須変数のチェック
if [ -z "$START_SECOND" ] || [ -z "$STOP_SECOND" ] || [ -z "$FADEOUT_SECOND" ] || [ -z "$SILENCE_SECOND" ]; then
    error_exit "必要な設定値が不足しています。設定ファイルを確認してください。" 4
fi

# 数値チェック
if ! [[ "$START_SECOND" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ "$STOP_SECOND" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ "$FADEOUT_SECOND" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ "$SILENCE_SECOND" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    error_exit "設定値は数値である必要があります。" 5
fi

# setting
setting="現在の設定値
==========================================
開始秒数:      ${START_SECOND}秒
終了秒数:      ${STOP_SECOND}秒
フェードアウト: ${FADEOUT_SECOND}秒 終了時刻から遡る
無音追加:      ${SILENCE_SECOND}秒
==========================================
再生時間:      $((STOP_SECOND - START_SECOND))秒"

# osascriptの実行を安全に行う
if ! isStart=$(osascript -e "display dialog \"$setting\n\nこの設定で音声ファイルを処理しますか？\" buttons {\"キャンセル\", \"設定編集\",\"実行\"} default button 3" 2>/dev/null); then
    log_info "ユーザーによりキャンセルされました"
    exit 0
fi

case $isStart in
    'button returned:キャンセル' )
        log_info "ユーザーによりキャンセルされました"
        exit 0
        ;;
    'button returned:設定編集' )
        log_info "GUI設定画面を開きます"

        # 分かりやすいステップバイステップ設定画面
        log_info "ステップバイステップ設定画面を開始します"

        # ステップ1: 開始時間
        new_start=$(osascript << EOF
tell application "System Events"
    set startDialog to display dialog "🎵 音声編集設定 (1/4)

【開始時間の設定】
音声ファイルの何秒目から処理を開始しますか？

現在の設定: ${START_SECOND}秒
通常は「0」を推奨します。" default answer "${START_SECOND}" with title "開始時間設定" buttons {"キャンセル", "次へ"} default button 2
    return text returned of startDialog
end tell
EOF
        )

        if [ $? -ne 0 ]; then
            log_info "設定編集がキャンセルされました"
            exit 0
        fi

        # ステップ2: 終了時間
        new_stop=$(osascript << EOF
tell application "System Events"
    set stopDialog to display dialog "🎵 音声編集設定 (2/4)

【終了時間の設定】
音声ファイルの何秒目で処理を終了しますか？

開始時間: ${new_start}秒
現在の設定: ${STOP_SECOND}秒
再生時間: $((STOP_SECOND - START_SECOND))秒

30秒なら「30」と入力してください。" default answer "${STOP_SECOND}" with title "終了時間設定" buttons {"戻る", "次へ"} default button 2
    return text returned of stopDialog
end tell
EOF
        )

        if [ $? -ne 0 ]; then
            log_info "設定編集がキャンセルされました"
            exit 0
        fi

        # ステップ3: フェードアウト時間
        new_fadeout=$(osascript << EOF
tell application "System Events"
    set fadeDialog to display dialog "🎵 音声編集設定 (3/4)

【フェードアウト時間の設定】
音声の最後を何秒間かけてフェードアウトしますか？

開始時間: ${new_start}秒
終了時間: ${new_stop}秒
現在の設定: ${FADEOUT_SECOND}秒

10秒のフェードアウトなら「10」と入力してください。
フェードアウト不要なら「0」と入力してください。" default answer "${FADEOUT_SECOND}" with title "フェードアウト設定" buttons {"戻る", "次へ"} default button 2
    return text returned of fadeDialog
end tell
EOF
        )

        if [ $? -ne 0 ]; then
            log_info "設定編集がキャンセルされました"
            exit 0
        fi

        # ステップ4: 無音追加時間
        new_silence=$(osascript << EOF
tell application "System Events"
    set silenceDialog to display dialog "🎵 音声編集設定 (4/4)

【無音追加時間の設定】
音声の最後に何秒間の無音を追加しますか？

開始時間: ${new_start}秒
終了時間: ${new_stop}秒
フェードアウト: ${new_fadeout}秒
現在の設定: ${SILENCE_SECOND}秒

10秒の無音なら「10」と入力してください。
無音追加不要なら「0」と入力してください。" default answer "${SILENCE_SECOND}" with title "無音追加設定" buttons {"戻る", "完了"} default button 2
    return text returned of silenceDialog
end tell
EOF
        )

        if [ $? -ne 0 ]; then
            log_info "設定編集がキャンセルされました"
            exit 0
        fi

        # 空白文字を削除
        new_start=$(echo "$new_start" | tr -d ' ')
        new_stop=$(echo "$new_stop" | tr -d ' ')
        new_fadeout=$(echo "$new_fadeout" | tr -d ' ')
        new_silence=$(echo "$new_silence" | tr -d ' ')

        log_info "入力された値: 開始=$new_start, 終了=$new_stop, フェードアウト=$new_fadeout, 無音=$new_silence"

        # 最終確認ダイアログ
        final_duration=$((new_stop - new_start + new_silence))
        confirmation=$(osascript << EOF
tell application "System Events"
    set confirmDialog to display dialog "✅ 設定内容の確認

【新しい設定】
開始時間: ${new_start}秒
終了時間: ${new_stop}秒
フェードアウト: ${new_fadeout}秒
無音追加: ${new_silence}秒

【処理結果】
音声部分: $((new_stop - new_start))秒
最終的な長さ: ${final_duration}秒

この設定で保存しますか？" buttons {"キャンセル", "保存して実行"} default button 2 with title "設定確認"
    return button returned of confirmDialog
end tell
EOF
        )

        if [[ "$confirmation" != *"保存して実行"* ]]; then
            log_info "設定保存がキャンセルされました"
            exit 0
        fi

        # 数値チェック
        if [[ "$new_start" =~ ^[0-9]+(\.[0-9]+)?$ ]] && \
           [[ "$new_stop" =~ ^[0-9]+(\.[0-9]+)?$ ]] && \
           [[ "$new_fadeout" =~ ^[0-9]+(\.[0-9]+)?$ ]] && \
           [[ "$new_silence" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then

            # 設定ファイルを更新
            cat > "$env" << ENVEOF
# 音声編集設定ファイル
# 各値は秒単位で指定してください

# 開始時間（秒）
START_SECOND=$new_start

# 終了時間（秒）
STOP_SECOND=$new_stop

# フェードアウト時間（秒）- 終了時刻から遡る時間
FADEOUT_SECOND=$new_fadeout

# 無音追加時間（秒）- 末尾に追加する無音の長さ
SILENCE_SECOND=$new_silence
ENVEOF

                log_info "設定が更新されました。スクリプトを再実行します..."
                exec bash "$0"  # スクリプトを再実行
        fi
        ;;
esac

# validation（数値チェックも強化）
# bcコマンドが利用できない場合のfallback
check_numeric_comparison() {
    local val1="$1"
    local op="$2"
    local val2="$3"

    if command -v bc >/dev/null 2>&1; then
        # bcが利用可能な場合
        result=$(echo "$val1 $op $val2" | bc -l)
        [ "$result" = "1" ]
    else
        # bcが利用できない場合、awk使用
        result=$(awk "BEGIN { print ($val1 $op $val2) }")
        [ "$result" = "1" ]
    fi
}

if check_numeric_comparison "$START_SECOND" ">" "$STOP_SECOND"; then
    error_exit "開始時間が、終了時間を超えています。" 7
fi

# フェードアウト時間の計算を事前に行う
duration=$(echo "$STOP_SECOND - $START_SECOND" | bc -l 2>/dev/null || awk "BEGIN {print $STOP_SECOND - $START_SECOND}")
if check_numeric_comparison "$FADEOUT_SECOND" ">" "$duration"; then
    error_exit "フェードアウト時間が、再生時間を超えています。" 8
fi

# パラメータの妥当性チェック
log_info "パラメータの確認:"
log_info "  開始時間: ${START_SECOND}秒"
log_info "  終了時間: ${STOP_SECOND}秒"
log_info "  再生時間: $((STOP_SECOND - START_SECOND))秒"
log_info "  フェードアウト: ${FADEOUT_SECOND}秒"
log_info "  無音追加: ${SILENCE_SECOND}秒"

# フォルダ選択機能（複数の方法で実装）
log_info "フォルダ選択ダイアログを表示中..."

# 方法1: 基本的なAppleScript
select_folder_basic() {
    osascript << 'EOF'
tell application "Finder"
    activate
    set theFolder to choose folder with prompt "音声ファイル（*.mp3, *.wav）が入っているフォルダを選択してください"
    return POSIX path of theFolder
end tell
EOF
}

# 方法2: シンプルなAppleScript（Finder使用なし）
select_folder_simple() {
    osascript -e 'set theFolder to choose folder with prompt "音声ファイル（*.mp3, *.wav）が入っているフォルダを選択してください"' -e 'return POSIX path of theFolder'
}

# 方法3: ターミナルベースの選択（最後の手段）
select_folder_terminal() {
    echo "フォルダ選択ダイアログが利用できません。"
    echo "音声ファイルが入っているフォルダのパスを直接入力してください："
    echo "（例: /Users/username/Music）"
    read -p "フォルダパス: " manual_path
    echo "$manual_path"
}

# フォルダ選択の実行
workdir=""
selection_method=""

# 方法1を試行
log_info "フォルダ選択方法1を試行中..."
if workdir=$(select_folder_basic 2>/dev/null) && [ -n "$workdir" ] && [ "$workdir" != "false" ]; then
    selection_method="Finder経由"
    log_info "フォルダ選択成功（方法1: Finder経由）"
else
    log_info "方法1失敗、方法2を試行中..."

    # 方法2を試行
    if workdir=$(select_folder_simple 2>/dev/null) && [ -n "$workdir" ] && [ "$workdir" != "false" ]; then
        selection_method="直接AppleScript"
        log_info "フォルダ選択成功（方法2: 直接AppleScript）"
    else
        log_info "AppleScriptが利用できません。手動入力モードに切り替えます。"

        # ユーザーに手動入力かキャンセルかを選択してもらう
        user_choice=$(osascript -e 'display dialog "フォルダ選択ダイアログが利用できません。\n\n手動でフォルダパスを入力しますか？" buttons {"キャンセル", "手動入力"} default button 2' 2>/dev/null || echo "button returned:キャンセル")

        if [[ "$user_choice" == *"手動入力"* ]]; then
            # 方法3を試行
            workdir=$(select_folder_terminal)
            selection_method="手動入力"
            if [ -z "$workdir" ]; then
                log_info "手動入力がキャンセルされました"
                exit 0
            fi
        else
            log_info "ユーザーによりキャンセルされました"
            exit 0
        fi
    fi
fi

# キャンセル確認
if [ -z "$workdir" ] || [ "$workdir" = "CANCELLED" ]; then
    log_info "フォルダ選択がキャンセルされました"
    exit 0
fi

log_info "選択されたディレクトリ: $workdir 選択方法: $selection_method"

# パスの妥当性チェック（強化版）
log_info "パスの検証を実行中..."

# パスの前後の空白文字を削除
workdir=$(echo "$workdir" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# 空のパスチェック
if [ -z "$workdir" ]; then
    error_exit "選択されたパスが空です" 10
fi

# ディレクトリ存在チェック
if [ ! -d "$workdir" ]; then
    log_error "指定されたディレクトリが存在しません: $workdir"

    # 存在しない場合、親ディレクトリをチェックして提案
    parent_dir=$(dirname "$workdir")
    if [ -d "$parent_dir" ]; then
        log_info "親ディレクトリは存在します: $parent_dir"
        log_info "利用可能なサブディレクトリ:"
        ls -la "$parent_dir" 2>/dev/null | grep "^d" | head -5 || log_info "サブディレクトリが見つかりません"
    fi

    error_exit "選択されたディレクトリが存在しません: $workdir" 10
fi

# 読み込み権限チェック
if [ ! -r "$workdir" ]; then
    error_exit "選択されたディレクトリに読み込み権限がありません: $workdir" 10
fi

# 書き込み権限チェック（出力ディレクトリ作成のため）
if [ ! -w "$workdir" ]; then
    log_error "選択されたディレクトリに書き込み権限がありません: $workdir"
    log_info "出力ディレクトリ（make）を作成できない可能性があります"

    # ユーザーに確認
    user_choice=$(osascript -e 'display dialog "選択されたフォルダに書き込み権限がありません。\n\n続行しますか？（処理が失敗する可能性があります）" buttons {"キャンセル", "続行"} default button 1' 2>/dev/null || echo "button returned:キャンセル")

    if [[ "$user_choice" != *"続行"* ]]; then
        log_info "ユーザーによりキャンセルされました"
        exit 0
    fi
fi

log_info "パス検証完了: $workdir"
log_info "作業ディレクトリ: $workdir"

# create dir
makedir="$workdir/make"
tmpdir="$makedir/temp"

log_info "出力ディレクトリを作成中..."

# ディレクトリ作成を安全に実行
if [ ! -d "$makedir" ]; then
    if ! mkdir -p "$makedir"; then
        error_exit "出力ディレクトリの作成に失敗しました: $makedir" 11
    fi
fi

if [ ! -d "$tmpdir" ]; then
    if ! mkdir -p "$tmpdir"; then
        error_exit "一時ディレクトリの作成に失敗しました: $tmpdir" 12
    fi
fi

# 音声処理ツールの存在確認（ffmpegのみ）
ffmpeg_command="$currentdir/ffmpeg"
use_ffmpeg=false

log_info "音声処理ツール（ffmpeg）の確認中..."

# 内蔵ffmpegコマンドの確認
if [ -x "$ffmpeg_command" ]; then
    log_info "内蔵ffmpegコマンドの動作テストを実行中..."

    if ffmpeg_test=$("$ffmpeg_command" -version 2>&1); then
        use_ffmpeg=true
        log_info "✓ 内蔵ffmpegコマンドが正常に動作しています"
        log_info "  使用コマンド: $ffmpeg_command"
        log_info "  バージョン: $(echo "$ffmpeg_test" | head -1)"
    else
        log_info "✗ 内蔵ffmpegコマンドの動作エラーを検出しました"
        log_info "エラー詳細: $(echo "$ffmpeg_test" | head -1)"
    fi
else
    log_info "内蔵ffmpegコマンドが見つかりません: $ffmpeg_command"
fi

# システムのffmpegコマンドの確認（内蔵が使えない場合のみ）
if [ "$use_ffmpeg" != true ] && command -v ffmpeg >/dev/null 2>&1; then
    if system_ffmpeg_test=$(ffmpeg -version 2>&1); then
        ffmpeg_command="ffmpeg"
        use_ffmpeg=true
        log_info "システムのffmpegコマンドを使用: $(which ffmpeg)"
    else
        log_info "システムのffmpegコマンドも利用できません"
    fi
fi

# ffmpegが見つからない場合の処理
if [ "$use_ffmpeg" != true ]; then
    log_info "ffmpegが見つかりません。ファイルコピーのみ実行します。"

    # 自動インストールの提案
    if command -v brew >/dev/null 2>&1; then
        install_choice=$(osascript -e 'display dialog "ffmpegが利用できません。\n\n自動インストールしますか？" buttons {"コピーのみ実行", "ffmpegインストール"} default button 2' 2>/dev/null || echo "button returned:コピーのみ実行")

        if [[ "$install_choice" == *"ffmpegインストール"* ]]; then
            log_info "ffmpegをインストール中..."
            if brew install ffmpeg 2>/dev/null; then
                ffmpeg_command="ffmpeg"
                use_ffmpeg=true
                log_info "ffmpegのインストールが完了しました"
            else
                log_info "ffmpegのインストールに失敗しました"
            fi
        fi
    fi
fi

# 音声処理準備の確認
log_info "=========================================="
log_info "音声処理の準備状況を確認中..."
log_info "=========================================="
log_info "使用予定ツール: ffmpeg=$use_ffmpeg"
if [ "$use_ffmpeg" = true ]; then
    log_info "ffmpegコマンドパス: $ffmpeg_command"
else
    log_info "ffmpegが利用できません。ファイルコピーのみ実行します。"
fi
log_info "作業ディレクトリ: $workdir"
log_info "出力ディレクトリ: $makedir"
log_info "一時ディレクトリ: $tmpdir"
log_info "=========================================="

# create music file
log_info "音声ファイルの変換を開始..."

# 音声ファイルの検索と処理
file_count=0
processed_count=0
failed_count=0

# ffmpegコマンドのバージョンと機能確認
if [ "$use_ffmpeg" = true ]; then
    log_info "ffmpegコマンドの情報確認中..."
    if ffmpeg_version=$("$ffmpeg_command" -version 2>/dev/null); then
        log_info "ffmpeg version: $(echo "$ffmpeg_version" | head -1)"
    else
        log_info "ffmpegコマンドは利用可能ですが、バージョン情報を取得できませんでした"
    fi
else
    log_info "音声処理なしモード（ファイルコピーのみ）"
fi

# ffmpeg処理関数（正確な時間制御版）
process_with_ffmpeg() {
    local input_file="$1"
    local output_file="$2"
    local filename="$3"

    log_info "    ffmpeg正確処理開始: $filename"

    # ファイル存在確認
    if [ ! -f "$input_file" ]; then
        log_error "    入力ファイルが存在しません: $input_file"
        return 1
    fi

    # 再生時間の計算
    local duration=$(echo "$STOP_SECOND - $START_SECOND" | bc -l 2>/dev/null || awk "BEGIN {print $STOP_SECOND - $START_SECOND}")
    # フェードアウト開始時刻はatrim後の時間軸での相対位置（20秒目から開始したい場合）
    local fade_start=$(echo "$STOP_SECOND - $START_SECOND - $FADEOUT_SECOND" | bc -l 2>/dev/null || awk "BEGIN {print $STOP_SECOND - $START_SECOND - $FADEOUT_SECOND}")
    local total_duration=$(echo "$duration + $SILENCE_SECOND" | bc -l 2>/dev/null || awk "BEGIN {print $duration + $SILENCE_SECOND}")

    log_info "    計算された時間:"
    log_info "      基本再生時間: ${duration}秒"
    log_info "      フェードアウト開始: ${fade_start}秒"
    log_info "      期待される最終時間: ${total_duration}秒"

    # 統合フィルターの構築（atrimを使用）
    local audio_filter=""

    # フェードアウトと無音追加の両方が有効な場合
    if [ "$FADEOUT_SECOND" != "0" ] && [ "$SILENCE_SECOND" != "0" ] && \
       [ "$(echo "$FADEOUT_SECOND > 0" | bc -l 2>/dev/null || awk "BEGIN {print ($FADEOUT_SECOND > 0)}")" = "1" ] && \
       [ "$(echo "$SILENCE_SECOND > 0" | bc -l 2>/dev/null || awk "BEGIN {print ($SILENCE_SECOND > 0)}")" = "1" ] && \
       [ "$(echo "$fade_start >= 0" | bc -l 2>/dev/null || awk "BEGIN {print ($fade_start >= 0)}")" = "1" ]; then

        audio_filter="atrim=${START_SECOND}:${STOP_SECOND},afade=t=out:st=${fade_start}:d=${FADEOUT_SECOND},apad=pad_dur=${SILENCE_SECOND}"
        log_info "    統合フィルター: トリミング + フェードアウト + 無音追加"

    elif [ "$FADEOUT_SECOND" != "0" ] && [ "$(echo "$FADEOUT_SECOND > 0" | bc -l 2>/dev/null || awk "BEGIN {print ($FADEOUT_SECOND > 0)}")" = "1" ] && \
         [ "$(echo "$fade_start >= 0" | bc -l 2>/dev/null || awk "BEGIN {print ($fade_start >= 0)}")" = "1" ]; then

        audio_filter="atrim=${START_SECOND}:${STOP_SECOND},afade=t=out:st=${fade_start}:d=${FADEOUT_SECOND}"
        total_duration="$duration"  # 無音追加なしの場合
        log_info "    統合フィルター: トリミング + フェードアウト"

    elif [ "$SILENCE_SECOND" != "0" ] && [ "$(echo "$SILENCE_SECOND > 0" | bc -l 2>/dev/null || awk "BEGIN {print ($SILENCE_SECOND > 0)}")" = "1" ]; then

        audio_filter="atrim=${START_SECOND}:${STOP_SECOND},apad=pad_dur=${SILENCE_SECOND}"
        log_info "    統合フィルター: トリミング + 無音追加"

    else
        audio_filter="atrim=${START_SECOND}:${STOP_SECOND}"
        log_info "    統合フィルター: トリミングのみ"
        total_duration="$duration"  # フェードアウトも無音追加もなし
    fi

    # ffmpegコマンドの実行（-ss と -t を使わずに、フィルターで全て制御）
    # メタデータをクリアし、完全再エンコードでフレーム構造をリセット
    log_info "    実行: 統合フィルター処理（完全再エンコード）"
    log_info "    実行コマンド: $ffmpeg_command -i \"$input_file\" -af \"$audio_filter\" -map_metadata -1 -c:a libmp3lame -b:a 128k -ar 44100 -y \"$output_file\""
    if "$ffmpeg_command" -i "$input_file" \
        -af "$audio_filter" \
        -map_metadata -1 \
        -c:a libmp3lame -b:a 128k -ar 44100 \
        -y "$output_file" >/dev/null 2>&1; then
        log_info "    統合処理成功: $filename 最終時間: ${total_duration}秒"
        return 0
    else
        log_error "    統合処理失敗: $filename"

        # フォールバック: 基本トリミングのみ（完全再エンコード）
        log_info "    フォールバック: 基本トリミングを試行"
        if "$ffmpeg_command" -i "$input_file" \
            -ss "$START_SECOND" \
            -t "$duration" \
            -map_metadata -1 \
            -c:a libmp3lame -b:a 128k -ar 44100 \
            -y "$output_file" >/dev/null 2>&1; then
            log_info "    基本トリミング成功 フォールバック: $filename ${duration}秒"
            return 0
        else
            log_error "    基本トリミングも失敗: $filename"
            return 1
        fi
    fi
}

# コピー処理関数
process_with_copy() {
    local input_file="$1"
    local output_file="$2"
    local filename="$3"

    log_info "    コピー処理開始: $filename"
    if cp "$input_file" "$output_file" 2>/dev/null; then
        log_info "    コピー成功: $filename"
        return 0  # 成功
    else
        log_error "    コピー失敗: $filename"
        return 1  # 失敗
    fi
}

# 音声処理関数の定義
process_audio_file() {
    local input_file="$1"
    local output_file="$2"
    local filename="$3"

    if [ "$use_ffmpeg" = true ]; then
        process_with_ffmpeg "$input_file" "$output_file" "$filename"
    else
        process_with_copy "$input_file" "$output_file" "$filename"
    fi
}

# プログレスバー表示関数
show_progress() {
    local current=$1
    local total=$2
    local filename="$3"
    local status="$4"

    local percent=$((current * 100 / total))
    local bars=$((percent / 5))
    local spaces=$((20 - bars))

    local progress_bar=""
    for ((i=0; i<bars; i++)); do
        progress_bar+="■"
    done
    for ((i=0; i<spaces; i++)); do
        progress_bar+="□"
    done

    # プログレスバー表示を安全に実行（改行を追加して上書きを防ぐ）
    echo "[$progress_bar] $percent% $current/$total $status: $filename"

    # macOSの通知センターでも進捗表示
    if [ $((current % 5)) -eq 0 ] || [ $current -eq $total ]; then
        osascript -e "display notification \"処理中: $filename $current/$total\" with title \"o-triming\" subtitle \"$percent% 完了\"" 2>/dev/null || true
    fi
}

# ファイル検索と総数取得
log_info "処理対象ファイルを検索中..."
log_info "検索ディレクトリ: $workdir"
log_info "検索パターン: *.mp3, *.wav"

# ファイル検索コマンドをテスト
find_command="find \"$workdir\" -maxdepth 1 \( -name '*.mp3' -o -name '*.wav' \) -type f"
log_info "実行するfindコマンド: $find_command"

# ファイルリストを取得
file_list=$(find "$workdir" -maxdepth 1 \( -name '*.mp3' -o -name '*.wav' \) -type f)
if [ -n "$file_list" ]; then
    log_info "見つかったファイル:"
    echo "$file_list" | while IFS= read -r file; do
        log_info "  - $(basename "$file")"
    done
else
    log_info "ファイルが見つかりませんでした"
fi

total_files=$(find "$workdir" -maxdepth 1 \( -name '*.mp3' -o -name '*.wav' \) -type f | wc -l | tr -d ' ')

if [ $total_files -eq 0 ]; then
    log_error "処理対象ファイルの詳細確認:"
    log_error "  ディレクトリ内容:"
    ls -la "$workdir" | head -10
    error_exit "処理対象の音声ファイル（*.mp3, *.wav）が見つかりませんでした" 14
fi

log_info "見つかったファイル数: $total_files"

# 処理内容の計算
duration=$(echo "$STOP_SECOND - $START_SECOND" | bc -l 2>/dev/null || awk "BEGIN {print $STOP_SECOND - $START_SECOND}")

log_info ""
log_info "音声ファイルの処理を開始します..."
log_info "=========================================="

# 使用ツールの表示
if [ "$use_ffmpeg" = true ]; then
    log_info "使用ツール: ffmpeg（音声編集処理）"
    log_info "処理内容: トリミング + フェードアウト + 無音追加"
else
    log_info "使用ツール: なし（ファイルコピーのみ）"
    log_info "処理内容: 元ファイルのコピー（音声編集なし）"
fi
log_info "=========================================="
echo ""

# ファイル検索を改善（より安全な方法）
log_info "ファイル処理ループを開始します..."

# デバッグ: ファイル検索結果を確認
log_info "デバッグ: find コマンドでファイル検索を実行中..."
find_result=$(find "$workdir" -maxdepth 1 \( -name '*.mp3' -o -name '*.wav' \) -type f)
log_info "デバッグ: 検索されたファイル一覧:"
echo "$find_result" | while IFS= read -r debug_file; do
    log_info "  見つかったファイル: [$debug_file]"
done

# globパターンを使った確実なファイル処理
cd "$workdir"
file_count=0
for file in *.mp3 *.wav; do
    # ファイルが実際に存在するかチェック（glob展開が失敗した場合のため）
    if [ ! -f "$file" ]; then
        log_info "DEBUG: globパターンでファイルが見つからない: [$file]"
        continue
    fi

    # フルパスに変換
    file="$workdir/$file"
    log_info "DEBUG: ループ内でファイルを処理中: [$file]"

    filename=$(basename "$file")
    file_count=$((file_count + 1))

    log_info "処理開始: ファイル $file_count/$total_files - $filename"
    log_info "DEBUG: ファイルパス変数: [$file]"
    log_info "DEBUG: ファイル存在確認: $([ -f "$file" ] && echo "存在" || echo "存在しない")"
    show_progress $file_count $total_files "$filename" "処理中"

    # 音声処理の実行
    output_file="$makedir/$filename"

    log_info "  入力ファイル: $file"
    log_info "  出力ファイル: $output_file"

    if process_audio_file "$file" "$output_file" "$filename"; then
        processed_count=$((processed_count + 1))
        show_progress $file_count $total_files "$filename" "完了"
        log_info "  処理成功: $filename"
    else
        log_info "  音声処理失敗、コピーを試行: $filename"
        # 最後の手段：単純コピー（静かに実行）
        if cp "$file" "$output_file" 2>/dev/null; then
            processed_count=$((processed_count + 1))
            show_progress $file_count $total_files "$filename" "コピー完了"
            log_info "  コピー成功: $filename"
        else
            failed_count=$((failed_count + 1))
            show_progress $file_count $total_files "$filename" "失敗"
            log_error "  コピーも失敗: $filename"
        fi
    fi
done

# 元のディレクトリに戻る
cd "$currentdir"

log_info "ファイル処理ループが完了しました"
log_info "DEBUG: ループ終了時の統計情報:"
log_info "DEBUG: file_count = $file_count"
log_info "DEBUG: processed_count = $processed_count"
log_info "DEBUG: failed_count = $failed_count"
log_info "DEBUG: total_files = $total_files"

echo ""  # 改行
echo ""

log_info "=========================================="
log_info "処理完了！"
log_info "=========================================="
log_info "処理結果: 合計 $total_files ファイル"
log_info "成功: $processed_count ファイル"
if [ $failed_count -gt 0 ]; then
    log_info "失敗: $failed_count ファイル"
fi

# 使用したツールと処理内容の詳細説明
if [ "$use_ffmpeg" = true ]; then
    log_info ""
    log_info "実行された処理:"
    log_info "• トリミング: ${START_SECOND}秒 〜 ${STOP_SECOND}秒 ${duration}秒間"
    if [ "$FADEOUT_SECOND" != "0" ]; then
        log_info "• フェードアウト: 最後の${FADEOUT_SECOND}秒間"
    fi
    if [ "$SILENCE_SECOND" != "0" ]; then
        log_info "• 無音追加: 末尾に${SILENCE_SECOND}秒"
    fi
    log_info "• 使用ツール: ffmpeg"
else
    log_info ""
    log_info "実行された処理:"
    log_info "• ファイルコピーのみ（音声編集なし）"
    log_info "• 理由: ffmpegが利用できませんでした"
fi

log_info ""
log_info "出力先: $makedir"
log_info "=========================================="

# delete tmp file
log_info "一時ファイルを削除中..."
if ! rm -rf "$tmpdir"; then
    log_error "一時ファイルの削除に失敗しました: $tmpdir"
fi

# notify
if [ $failed_count -eq 0 ]; then
    if [ "$use_ffmpeg" = true ]; then
        success_message="音声編集完了！（$processed_count ファイル処理）"
        success_subtitle="ffmpeg使用 - トリミング・フェード・無音追加"
    else
        success_message="ファイルコピー完了（$processed_count ファイル）"
        success_subtitle="音声処理ツールなし - コピーのみ実行"
    fi
    log_info "$success_message"
    osascript -e "display notification \"$success_message\" with title \"o-triming\" subtitle \"$success_subtitle\"" 2>/dev/null || true
else
    if [ "$use_ffmpeg" = true ]; then
        warning_message="処理完了（成功: $processed_count、失敗: $failed_count）"
        warning_subtitle="ffmpeg使用"
    else
        warning_message="処理完了（成功: $processed_count、失敗: $failed_count）"
        warning_subtitle="コピーのみ"
    fi
    log_info "$warning_message"
    osascript -e "display notification \"\$warning_message\" with title \"o-triming\" subtitle \"\$warning_subtitle\"" 2>/dev/null || true
fi

log_info "処理が完了しました"
exit 0
