#!/bin/sh

# curl https://raw.githubusercontent.com/websquared/meteor-deploy/master/meteor-deploy.sh | /bin/sh

#if [ -x /usr/local/bin/meteor-deploy ]; then
#  exec /usr/local/bin/meteor-deploy update
#fi
#
#if [ -x /usr/bin/meteor-deploy ]; then
#  exec /usr/bin/meteor-deploy update
#fi

PREFIX="/usr/local"
CURRENT_FOLDER=${PWD##*/}
echo $CURRENT_FOLDER

set -e

# Let's display everything on stderr.
exec 1>&2

### Functions

function install {

UNAME=$(uname)
if [ "$UNAME" != "Linux" -a "$UNAME" != "Darwin" ] ; then
    echo "Sorry, this OS is not supported yet."
    exit 1
fi

if [ "$UNAME" = "Darwin" ] ; then
  ### OSX ###
  if [ "i386" != "$(uname -p)" -o "1" != "$(sysctl -n hw.cpu64bit_capable 2>/dev/null || echo 0)" ] ; then
    # Can't just test uname -m = x86_64, because Snow Leopard can
    # return other values.
    echo "Only 64-bit Intel processors are supported at this time."
    exit 1
  fi
  ARCH="x86_64"
elif [ "$UNAME" = "Linux" ] ; then
  ### Linux ###
  ARCH=$(uname -m)
  if [ "$ARCH" != "i686" -a "$ARCH" != "x86_64" ] ; then
    echo "Unusable architecture: $ARCH"
    echo "Meteor only supports i686 and x86_64 for now."
    exit 1
  fi
fi
PLATFORM="${UNAME}_${ARCH}"
echo $PLATFORM

trap "echo Installation failed." EXIT

SCRIPT_URL="https://raw.githubusercontent.com/websquared/meteor-deploy/master/meteor-deploy.sh"

curl -o $CURRENT_FOLDER "$SCRIPT_URL"
LAUNCHER="./meteor-deploy.sh"

if cp "$LAUNCHER" "$PREFIX/bin/meteor-deploy" >/dev/null 2>&1; then
  echo "Writing a launcher script to $PREFIX/bin/meteor-deploy for your convenience."
  usage
elif type sudo >/dev/null 2>&1; then
  echo "Writing a launcher script to $PREFIX/bin/meteor-deploy for your convenience."
  echo "This may prompt for your password."

  # New macs (10.9+) don't ship with /usr/local, however it is still in
  # the default PATH. We still install there, we just need to create the
  # directory first.
  if [ ! -d "$PREFIX/bin" ] ; then
      sudo mkdir -m 755 "$PREFIX" || true
      sudo mkdir -m 755 "$PREFIX/bin" || true
  fi

  if sudo cp "$LAUNCHER" "$PREFIX/bin/meteor-deploy"; then
    usage
  fi
fi

rm LAUNCHER

yum install -y nodejs --enablerepo=epel
node --version
yum install -y npm --enablerepo=epel

curl install.meteor.com | /bin/sh
npm install -g meteorite
npm install -g forever
}

function usage {
    cat <<"EOF"

To get started fast:

  $ mkdir ~/my_cool_app
  $ cd ~/my_cool_app
  $ meteor-deploy config
  $ meteor-deploy run

EOF

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
    install
elif [[ $1 == "config" ]]; then
    config
elif [[ $1 == "run" ]]; then
    run
fi

trap - EXIT