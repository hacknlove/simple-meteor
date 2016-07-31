#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "
USAGE: deploy.sh path

where path is a folder with the proyect configuration
Example at https://github.com/pykiss/simple-meteor/tree/master/example
"
fi
currentDir=$PWD/$1
cd $currentDir

source version
next=$((version+1))

source deploy.config

errorMesage () {
  echo -e "\e[101m$1\e[0m"
}
log () {
  echo -e "\e[1m$1\e[0m"
}


cleanBuild () {
  trap ERR
  log "Cleaning build path"
  cd $currentDir
  source deploy.config
  chmod -R +w $buildPath
  rm -r $buildPath
}

restoreContainers () {
  for f in servers/* ; do
    echo $f
    source deploy.config
    source $f
    ssh -t $user@$server docker stop $appName$next
    ssh -t $user@$server docker start $appName$current
    ssh -t $user@$server docker rm $appName$next
  done
}

clean () {
  trap ERR
  log "-Cleaning servers"
  for f in servers/* ; do
    echo $f
    source deploy.config
    source $f
    ssh $user@$server chmod -R +w $to[$next]
    ssh $user@$server rm -r $to[$next]
  done
}

build () {
  trap ERR
  trap 'errorMesage "error building";cleanBuild; exit;' ERR
  cd $meteorRoute
  log "building from $PWD to $buildPath"
  meteor build --server-only --directory $buildPath --architecture os.linux.x86_64
  cd $currentDir
}

upload () {
  trap ERR
  trap 'errorMesage "error uploading";clean; exit;' ERR
  log "-Uploading bundles"
  for f in servers/* ; do
    echo $f
    source deploy.config
    source $f
    rsync --info=progress2 -acz $buildPath/bundle/ $user@$server:$to[$next]
  done
}


startContainers () {
  trap ERR
  trap 'errorMesage "error starting containers";restoreContainers $next;clean;cleanBuild; exit;' ERR
  log "-Starting containers"
  for f in servers/* ; do
    echo $f
    source deploy.config
    source $f
    log "--updating image"
    ssh -t $user@$server docker pull $dockerImage
    log "--stoping old container"
    ssh -t $user@$server docker stop $appName$version || log "---may be there is no old container"
    log "--lauching new container"
    ssh -t $user@$server docker run --name=$appName$next -v $to[$next]/:/meteor --restart=always -e ROOT_URL=$ROOT_URL -e MONGO_URL=$MONGO_URL -e MONGO_OPLOG_URL=$MONGO_OPLOG_URL -p $bindIp:$port:80  $dockerImage
    log "--waitting $sleep"
    sleep $sleep
    log "--testing new container"
    ssh -t $user@$server curl $bindIp:$port
  done
}

log "\n\n\nStart:\n\n\n"

build
upload
startContainers
