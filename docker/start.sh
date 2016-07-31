DEFAULTUSER=`stat -c %u /meteor`

USER=${USER:=$DEFAULTUSER}

cd /meteor/programs/server
sudo -E -u "#$USER" npm install
cd /meteor
sudo -E -u "#$USER" node main.js
