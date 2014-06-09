#!/bin/bash

# What's your app name?
APP_NAME=example

# App URL
ROOT_URL=http://example.com

# Setup a listening port for your instance / default is 80
PORT=3000

# What's your project's Git repo?
GIT_URL=git@bitbucket.org:example/example.git

# If you would like to use a different branch, set it here
GIT_BRANCH=master

#If you have an external service, such as Google SMTP, set this
MAIL_URL=smtp://postmaster@example.com:password@smtp.mailgun.org:465

# Kill the forever and node processes, and deletes the bundle directory and tar file prior to deploying
FORCE_CLEAN=true