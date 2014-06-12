#!/bin/bash
set -e
#set -u
set -o pipefail  # so curl failure triggers the "set -e"

CWD=$(pwd)

function server() {
     if [[ -n "$(command -v yum)" ]]; then
        cat <<EOM >/etc/yum.repos.d/epel-bootstrap.repo
[epel]
name=Bootstrap EPEL
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-\$releasever&arch=\$basearch
failovermethod=priority
enabled=0
gpgcheck=0
EOM

        cat >/etc/yum.repos.d/mongodb.repo <<EOL
[mongodb]
name=MongoDB Repository
baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/
gpgcheck=0
enabled=1
EOL

        sudo yum install -y nodejs --enablerepo=epel
        sudo yum install -y npm --enablerepo=epel

        sudo npm install -g meteorite
        sudo npm install -g forever

        sudo yum install -y mongodb-org
        sudo service mongod start
        sudo chkconfig mongod on

        rm -f /etc/yum.repos.d/epel-bootstrap.repo

     elif [[ -n "$(command -v apt-get)" ]]; then
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
        echo 'deb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
        sudo apt-get update

        sudo apt-get install nodejs
        sudo apt-get install nodejs-legacy
        sudo apt-get install npm

        sudo apt-get install -g meteorite
        sudo apt-get install -g forever

        sudo apt-get install mongodb-org
        sudo /etc/init.d/mongod start

     else
        echo "Error: your OS doesn't support 'yum' or 'apt-get'"
        exit 1;
     fi

     curl install.meteor.com | /bin/sh
}

function config() {
    read -e -p "Enter your APP_NAME:" -i "myapp" APP_NAME


    echo -n "Enter your APP_NAME [eg. myapp]: "
    read APP_NAME
    echo -n "Enter your ROOT_URL [eg. http://myapp.com]: "
    read ROOT_URL
    echo -n "Enter your PORT [eg. 3000]: "
    read PORT
    echo -n "Enter your GIT_URL [eg. git@bitbucket.org:myapp/myapp.git]: "
    read GIT_URL
    echo -n "Enter your GIT_BRANCH [eg. master]: "
    read GIT_BRANCH
    echo -n "Enter your MAIL_URL [eg. smtp://postmaster@myapp.com:password@smtp.mailgun.org:465]: "
    read MAIL_URL
    echo -n "Enter your MONGO_URL [eg. mongodb://localhost:27017/myapp]: "
    read MONGO_URL
    echo
    FORCE_CLEAN=true

    cat >meteor-deploy.config <<EOL
APP_NAME="${APP_NAME}"
ROOT_URL="${ROOT_URL}"
PORT="${PORT}"
GIT_URL="${GIT_URL}"
GIT_BRANCH="${GIT_BRANCH}"
MAIL_URL="${MAIL_URL}"
MONGO_URL="${MONGO_URL}"
FORCE_CLEAN=${FORCE_CLEAN}
EOL

}

function run() {

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
                    echo "Killing forever and node";
                    if ps aux | grep "[n]ode" > /dev/null; then
                        killall node;
                    fi
                    if ps aux | grep "[n]odejs" > /dev/null; then
                        killall nodejs;
                    fi

                    echo "Cleaning bundle files";
                    rm -rf ../bundle > /dev/null 2>&1;
                    rm -rf ../bundle.tgz > /dev/null 2>&1;
            fi;
            mrt install
            echo "Creating new bundle. This may take a few minutes";
            meteor bundle ../bundle.tgz;
            cd ..;
            tar -zxvf bundle.tgz;
            rm -f bundle.tgz;
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
    printenv

    echo "Starting forever";
    forever restart bundle/main.js || forever start bundle/main.js;
    forever logs

    echo "Application is running on $ROOT_URL"
}

function stop() {
    echo "Stopping forever :)";
    forever stop bundle/main.js;
}

if [[ $# == 0 ]]; then
    echo "Usage: $0 [server|config|run]"
    exit
elif [[ $1 == "server" ]]; then
    server
elif [[ $1 == "config" ]]; then
    config
elif [[ $1 == "run" ]]; then
    run $2
elif [[ $1 == "stop" ]]; then
    stop
elif [[ $1 == "update" ]]; then
    curl -H "Cache-Control: no-cache, max-age=0" https://raw.githubusercontent.com/websquared/meteor-deploy/master/meteor-deploy-install.sh | /bin/sh
fi