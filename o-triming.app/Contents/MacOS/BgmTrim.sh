#!/bin/bash

currentdir=$(cd $(dirname $0); pwd)

# load env
env=$currentdir/.env
. $env

# install sox
if ! which /usr/local/bin/sox >/dev/null 2>&1; then
    isInstall=$(osascript -e "display dialog \"初回起動のようです。\\n必要なソフトウェアをインストールしますか？\" buttons {\"Cancel\",\"OK\"} default button 2")
    case $isInstall in
        'button returned:Cancel' ) exit ;;
        'button returned:OK' )
            osascript -e "do shell script \"sudo ${currentdir}/Install.sh &\" with administrator privileges"

            while [ ! -f "${currentdir}/completed" ]; do
                sleep 1
            done

            install_result=$?
            if [ $install_result -eq 0 ]; then
                isContinue=$(osascript -e "display dialog \"インストールが完了しました。\\n処理を続行しますか？\" buttons {\"Cancel\",\"OK\"} default button 2")
                case $isContinue in
                    'button returned:Cancel' ) exit
                esac
            else
                osascript -e "display dialog \"インストールに失敗しました。\""
                exit 1
            fi
            ;;
    esac
fi

# setting
setting="\n
開始秒数： ${START_SECOND}
終了秒数： ${STOP_SECOND}
フェードアウト秒数(終了時刻から遡る)： ${FADEOUT_SECOND}
追加する無音秒数： ${SILENCE_SECOND}\n"

isStart=$(osascript -e "display dialog \"現在の設定値は以下です。$setting\nこのままでよろしいですか？\" buttons {\"Cancel\", \"Edit\",\"OK\"} default button 3")
case $isStart in
    'button returned:Cancel' ) exit ;;
    'button returned:Edit' ) open $env
    exit ;;
esac

# validation
if [ $START_SECOND -gt $STOP_SECOND ]; then
    osascript -e "display dialog \"開始時間が、終了時間を超えています。\" buttons {\"OK\"} default button 1 with icon stop"
    exit
fi

if [ $FADEOUT_SECOND -gt $(($STOP_SECOND - $START_SECOND)) ]; then
    osascript -e "display dialog \"フェードアウト時間が、再生時間を超えています。\" buttons {\"OK\"} default button 1 with icon stop"
    exit
fi

select=$(osascript -e 'set theOutputFolder to choose folder with prompt "編集する音声ファイルが入ったフォルダを選択"')
# todo: warning
# echo $select >> $currentdir/log.txt
# if [ -z "$select" ]; then
#     exit
# fi

# convert posix to path
IFS_ORIGINAL="$IFS"
IFS=:
arr=($select)
unset arr[0]
workdir="/$(IFS=/; echo "${arr[*]}")"

# change delimiter
IFS=$'\n'

# create dir
makedir=$workdir/make
tmpdir=$makedir/temp

if [ ! -d $makedir ]; then
    mkdir $makedir
fi
if [ ! -d $tmpdir ]; then
    mkdir $tmpdir
fi

# create music file
for file in `\find $workdir -maxdepth 1 -name '*.mp3' -or -name '*.wav' -type f | sed 's!^.*/!!'`; do
    /usr/local/bin/sox $workdir/$file $tmpdir/$file fade t $START_SECOND $STOP_SECOND $FADEOUT_SECOND
    /usr/local/bin/sox $tmpdir/$file $makedir/$file pad 0 $SILENCE_SECOND
done

# delete tmp file
# rm -fr $tmpdir

# notify
osascript -e "display notification \"音声ファイル生成完了\" with title \"o-triming\""

IFS="$IFS_ORIGINAL"
