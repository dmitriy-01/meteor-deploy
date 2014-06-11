#!/bin/bash
set -e
set -u
set -o pipefail  # so curl failure triggers the "set -e"

CWD=$(pwd)
echo $CWD
exit

function server{
    yum install -y nodejs --enablerepo=epel
    node --version
    yum install -y npm --enablerepo=epel

    curl install.meteor.com | /bin/sh
    npm install -g meteorite
    npm install -g forever
}

function config {
    echo -n "Enter your APP_NAME [eg. example]: "
    read APP_NAME
    echo -n "Enter your ROOT_URL [eg. http://example.com]: "
    read ROOT_URL
    echo -n "Enter your PORT [eg. 3000]: "
    read PORT
    echo -n "Enter your GIT_URL [eg. git@bitbucket.org:example/example.git]: "
    read GIT_URL
    echo -n "Enter your GIT_BRANCH [eg. master]: "
    read GIT_BRANCH
    echo -n "Enter your MAIL_URL [eg. smtp://postmaster@example.com:password@smtp.mailgun.org:465]: "
    read MAIL_URL
    echo
    FORCE_CLEAN=true

    cat >meteor-deploy.config <<EOL
APP_NAME="${APP_NAME}"
ROOT_URL="${ROOT_URL}"
PORT="${PORT}"
GIT_URL="${GIT_URL}"
GIT_BRANCH="${GIT_BRANCH}"
MAIL_URL="${MAIL_URL}"
FORCE_CLEAN=${FORCE_CLEAN}
EOL

}

function run {

    if [[ ! -f ./meteor-deploy.config ]]; then
        config
    else
        #Importing configuration
        source ./meteor-deploy.config
    fi

    ###################
    # You usually don't need to change anything here –
    # You should modify your meteor-deploy.config file instead.
    #

    # Check for git repository
    if [ ! -d "${APP_NAME}" ];
        then
            echo "Cloning repo";
            git clone $GIT_URL $APP_NAME;
            cd $APP_NAME;
        else
            echo "Updating code";
            cd $APP_NAME;
            git fetch origin;
    fi;

    git checkout $GIT_BRANCH;

    if [ "$1" == "bundle" ] || [ $(git rev-parse HEAD) != $(git rev-parse @{u}) ];
        then
            git pull;
            if [ "$FORCE_CLEAN" == "true" ]; then
                    #echo "Killing forever and node";
                    #killall nodejs;
                    echo "Cleaning bundle files";
                    rm -rf ../bundle > /dev/null 2>&1;
                    rm -rf ../bundle.tgz > /dev/null 2>&1;
            fi;
            mrt install
            echo "Creating new bundle. This may take a few minutes";
            meteor bundle ../bundle.tgz;
            cd ..;
            tar -zxvf bundle.tgz;
        else
            cd ..;
    fi;

    export MONGO_URL=$MONGO_URL;
    if [ -n "$ROOT_URL" ]; then
        export ROOT_URL=$ROOT_URL:$PORT;
    fi;
    if [ -n "$MAIL_URL" ]; then
        export MAIL_URL=$MAIL_URL;
    fi;
    export PORT=$PORT;
    #printenv

    echo "Starting forever";
    forever restart bundle/main.js || forever start bundle/main.js;

}

if [[ -z $1 ]]; then
    echo "Usage: $0 [server|config|run]"
    exit
elif [[ $1 == "server" ]]; then
    server
elif [[ $1 == "config" ]]; then
    config
elif [[ $1 == "run" ]]; then
    run
fi