# O-triming

`brew install sox`

知り合い用に簡易作成した音声ファイルの一括編集アプリです。
Mac環境を想定しています。

編集対象は、「mp3, wav」が設定されております。

編集できる内容は、以下の3点です。
- 指定した秒数でトリミング。
- 指定した秒数の長さでフェードアウト。
- 指定した秒数分、最後に無音の時間を作る。

ダウンロードしたアプリをダブルクリックで起動します。
<img width="532" alt="o-triming1" src="https://user-images.githubusercontent.com/42257421/132041557-829b3c7a-761c-407f-b8b8-b83cb519be23.png">

設定値を確認します。
上記の設定値の場合は、
0~30秒までの音声をトリミングし、再生開始後20秒から10秒間かけてフェードアウト。
その後、10秒間の無音時間ができる、40秒の音声ファイルが作成されます。

設定値を変更したい場合は、Edit。
そのままで良い場合は、OKを押下します。

<img width="911" alt="o-triming2" src="https://user-images.githubusercontent.com/42257421/132041568-8eb8f776-e7ee-4ee0-b4ac-9308ac37ca58.png">

音声ファイルが入ったフォルダを選択します。
前述にもある通り、拡張子が「mp3, wav」のファイルのみ、変換処理されます。
ファイル名にスペースが入っている場合も問題なく動作します。

<img width="1025" alt="o-triming3" src="https://user-images.githubusercontent.com/42257421/132041573-a84893e5-29c6-4bbe-8f68-b63dec5d10bb.png">
変換が終了すると、画面右上に通知が表示され、
先ほど、選択したフォルダ内に「make」フォルダが作成されます。

<img width="1025" alt="o-triming4" src="https://user-images.githubusercontent.com/42257421/132041574-ff1328e2-c00f-42f9-8475-e7db7bbb3168.png">
「make」フォルダ内には、同名で変換後のファイルが格納されています。

※ m1の場合は、soxコマンド実行箇所を「/opt/homebrew/bin/sox」に置き換える必要があります。
