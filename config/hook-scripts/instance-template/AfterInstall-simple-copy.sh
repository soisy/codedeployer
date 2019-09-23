#!/bin/bash

set -e
set -o pipefail

### --------------------------------------------------------------------------------------------
### START OF DEPLOYMENT SPECIFIC CONFIGURATION OPTIONS

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