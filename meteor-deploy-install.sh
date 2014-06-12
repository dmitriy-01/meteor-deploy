#!/bin/sh

# curl https://raw.githubusercontent.com/websquared/meteor-deploy/master/meteor-deploy-install.sh | /bin/sh

#if [ -x /usr/local/bin/meteor-deploy ]; then
#  exec /usr/local/bin/meteor-deploy update
#fi
#
#if [ -x /usr/bin/meteor-deploy ]; then
#  exec /usr/bin/meteor-deploy update
#fi

PREFIX="/usr/local"

set -e

# Let's display everything on stderr.
exec 1>&2

function usage {
    cat <<"EOF"

To get started fast:

  $ meteor-deploy server
  $ mkdir ~/my_cool_app
  $ cd ~/my_cool_app
  $ meteor-deploy config
  $ meteor-deploy run

EOF
}

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
LAUNCHER="/tmp/meteor-deploy.sh"

curl -H "Cache-Control: no-cache, max-age=0" --progress-bar --fail -o "$LAUNCHER" "$SCRIPT_URL"

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

chmod +x "$PREFIX/bin/meteor-deploy"

rm -f $LAUNCHER

trap - EXIT