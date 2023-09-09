#!/bin/bash

currentdir=$(cd $(dirname $0); pwd)


osascript -e "display notification \"インストールを開始します。\" with title \"o-triming\""
currentdir=$(cd $(dirname $0); pwd)

# lame install
sudo curl -o $currentdir/lame-3.100.tar.gz -L https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz

cd $currentdir
sudo tar -zxvf lame-3.100.tar.gz

cd lame-3.100

sudo cp include/libmp3lame.sym include/libmp3lame.sym.bk
sudo chmod 777 include/libmp3lame.sym
sudo grep -v 'lame_init_old' include/libmp3lame.sym.bk > include/libmp3lame.sym

sudo ./configure
sudo make
make install

rm -rf $currentdir/lame-3.100.tar.gz

# lib mat
# sudo curl -o libmad-0.15.1b.tar.gz -L https://downloads.sourceforge.net/project/mad/libmad/0.15.1b/libmad-0.15.1b.tar.gz
# tar -zxvf libmad-0.15.1b.tar.gz
# cd libmad-0.15.1b
# curl -o config.sub 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'


# sox install
sudo curl -o $currentdir/sox-14.4.2.tar.gz -L http://downloads.sourceforge.net/project/sox/sox/14.4.2/sox-14.4.2.tar.gz

cd $currentdir
sudo tar -zxvf sox-14.4.2.tar.gz

cd sox-14.4.2

./configure
make
make install

sudo rm $currentdir/sox-14.4.2.tar.gz

# done
sudo touch $currentdir/completed
