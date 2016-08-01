ln -s `which nodejs` /usr/bin/node
cd /meteor/programs/server
echo "install"
npm install
echo "rebuild"
npm rebuild
chmod -R a+w /meteor
cd /meteor
echo "start"
nodejs main.js
