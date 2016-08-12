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

source config

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
  source config
  chmod -R +w $buildPath
  rm -r $buildPath
}

restoreContainers () {
  trap ERR
  log "-restoreContainers"
  for f in servers/*.conf ; do
    echo "--$f"
    source config
    source $f
    ssh -t $user@$server docker stop $appName$next
    ssh -t $user@$server docker start $appName$version
    ssh -t $user@$server docker rm $appName$next
  done
}

clean () {
  trap ERR
  log "-Cleaning servers"
  for f in servers/*.conf ; do
    echo "--$f"
    source config
    source $f
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
  for f in servers/*.conf ; do
    echo "--$f"
    source config
    source $f
    rsync --info=progress2 -acz $buildPath/bundle/ $user@$server:$to[$next]
  done
}


startContainers () {
  trap ERR
  trap 'errorMesage "error starting containers";restoreContainers $next;clean;cleanBuild; exit;' ERR
  log "-Starting containers"
  for f in servers/*.conf ; do
    echo "--$f"
    source config
    source $f
    log "---updating image"
    ssh -t $user@$server docker pull $dockerImage
    if [ "$version" -ne "0" ]
    then
      log "---stoping old container"
      ssh -t $user@$server docker stop $appName$version || log "---may be there is no old container"
    fi
    log "---lauching new container"
    ssh -t $user@$server docker run -d --name=$appName$next -v $to[$next]/:/meteor --restart=always -e ROOT_URL=$ROOT_URL -e MONGO_URL=$MONGO_URL -e MONGO_OPLOG_URL=$MONGO_OPLOG_URL -e BIND_IP=$bindIp -e PORT=$port -e METEOR_SETTINGS="'"$METEOR_SETTINGS"'" $EXTRA_DOCKER --net=host $dockerImage
    log "---waitting $sleep"
    sleep $sleep
    log "---testing new container"
    ssh -t $user@$server curl -I -X GET $bindIp:$port
  done
}

cleanOldVersion () {
  trap ERR
  log "-Cleaning old containers and files"
  for f in servers/*.conf ; do
    source config
    source $f
    log "---removing old container"
    ssh -t $user@$server docker rm $appName$version || log "---may be there is no old container"
    ssh $user@$server rm -r $to[$version]
  done
}
incrementVersion () {
  log "-incrementing version counter"
  cd $currentDir
  sed -i.bak s/version=$version/version=$next/g version
}
log "\n\n\nStart:\n\n\n"

build
upload
startContainers

if [ "$version" -ne "0" ]
then
  cleanOldVersion
fi

incrementVersion

log "\n\n\DONE\n\n\n"
