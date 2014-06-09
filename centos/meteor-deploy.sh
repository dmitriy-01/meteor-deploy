#!/bin/bash

#Importing configuration
source meteor-deploy.config.sh

###################
# You usually don't need to change anything here –
# You should modify your meteor-deploy.config.sh file instead.
#

# Check for git repository
if [ ! -d ".git" ];
    then
        echo "Cloning repo";
        git clone $GIT_URL;
    else
        echo "Updating code";
        git fetch origin;
fi;

git checkout $GIT_BRANCH;

if [ "$1" == "bundle" ] || [ $("git rev-parse HEAD") != $("git rev-parse @{u}") ]; then
	git pull;
	if [ "$FORCE_CLEAN" == "true" ]; then
    		echo "Killing forever and node";
    		killall nodejs;
    		echo "Cleaning bundle files";
    		rm -rf ../bundle > /dev/null 2>&1;
    		rm -rf ../bundle.tgz > /dev/null 2>&1;
	fi;
	mrt install
	echo "Creating new bundle. This may take a few minutes";
	meteor bundle ../bundle.tgz;
	tar -zxvf bundle.tgz;
fi;

export MONGO_URL=$MONGO_URL;
if [ -n "$ROOT_URL" ]; then
    export ROOT_URL=$ROOT_URL:$PORT;
fi;
if [ -n "$MAIL_URL" ]; then
    export MAIL_URL=$MAIL_URL;
fi;
export PORT=$PORT;
printenv

echo "Starting forever";
forever restart bundle/main.js || forever start bundle/main.js;