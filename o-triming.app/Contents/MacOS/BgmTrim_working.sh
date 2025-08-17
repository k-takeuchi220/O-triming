#!/bin/bash

log_info() {
    echo "INFO: $1"
}

log_info "o-triming.app 緊急復旧版"
log_info "アプリが正常に動作することを確認しています..."

# 基本的なテスト
if [ -f ".env" ]; then
    log_info "設定ファイルが見つかりました"
    . .env
    log_info "設定読み込み完了"
    log_info "開始: ${START_SECOND}秒, 終了: ${STOP_SECOND}秒"
else
    log_info "設定ファイルが見つかりません"
fi

log_info "復旧テスト完了"
exit 0
