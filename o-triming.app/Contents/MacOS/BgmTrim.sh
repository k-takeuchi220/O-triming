#!/bin/sh

currentdir=$(cd $(dirname $0); pwd)

# load env
env=$currentdir/.env
. $env

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
if [ !$select ]; then
    exit
fi

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
rm -fr $tmpdir

# notify
osascript -e "display notification \"音声ファイル生成完了\" with title \"o-triming\""

IFS="$IFS_ORIGINAL"