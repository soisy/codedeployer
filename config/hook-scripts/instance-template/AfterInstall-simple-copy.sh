#!/bin/bash

set -e
set -o pipefail

### --------------------------------------------------------------------------------------------
### START OF DEPLOYMENT SPECIFIC CONFIGURATION OPTIONS

# Set this to the local relative path of the source to be deployed if it's not the root of the project
# The local path is relative to the level where the composer.json containing codedeployer is located
ARCHIVE_SOURCE_SUBDIR=

# Set this to the target directory on the remote machine where the source will be deployed
TARGET_DEPLOY_DIR=

# Commands to be executed after the code is copied in the target release directory
# The working directory when running these commands is set to the new release directory
# Enter one per line
# IMPORTANT: enclose commands in double quotes if they contain more than one word (commands usually do)
POST_INSTALL_COMMANDS=(
)

### END OF DEPLOYMENT SPECIFIC CONFIGURATION OPTIONS
### --------------------------------------------------------------------------------------------

source strategies/simple-copy.sh