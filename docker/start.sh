ln -s `which nodejs` /usr/bin/node
cd /meteor/programs/server
echo "\ninstall"
npm install
echo "\nrebuild"
npm rebuild
chmod -R a+w /meteor
cd /meteor
echo "\nstart"
nodejs main.js
