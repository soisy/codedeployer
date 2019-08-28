#!/bin/bash

set -e
set -o pipefail

### --------------------------------------------------------------------------------------------
### START OF DEPLOYMENT SPECIFIC CONFIGURATION OPTIONS

TARGET_DEPLOY_DIR=

# Objects (files and directories) shared between releases are stored in the "shared" directory
# and symlinked to the new release
# Enter one per line
SHARED_OBJECTS=(
)

# Commands to be executed after the code is copied in the target release directory
# The working directory when running these commands is set to the new release directory
# Enter one per line
# IMPORTANT: enclose commands in double quotes if they containe more than one words (commands usually do)
POST_INSTALL_COMMANDS=(
)

### END OF DEPLOYMENT SPECIFIC OPTIONS -- DO NOT EDIT BELOW THIS LINE UNLESS REALLY NEEDED
### CHANGES BELOW THIS LINE SHOULD BE APPLIED TO THE CODEDEPLOYER PACKAGE AS THE CODE IS GENERAL
### 8<------------------------------------------------------------------------------------------


# Build archive path from AWS Codedeploy environment variables
# The source is the temporary folder where Codedeploy stores the uncompressed archive of the current revision
ARCHIVE_DIR="/opt/codedeploy-agent/deployment-root/${DEPLOYMENT_GROUP_ID}/${DEPLOYMENT_ID}/deployment-archive"

# Check that all shared objects exist in the shared directory
for OBJECT in "${SHARED_OBJECTS[@]}"; do
  if [ ! -d "${TARGET_DEPLOY_DIR}/shared/${OBJECT}" ] && [ ! -f "${TARGET_DEPLOY_DIR}/shared/${OBJECT}" ]; then
    echo "Shared object '${i}' does not exist."
    exit 1
  fi
done

# Create the new release directory
DEPLOY_SCRIPTS_DIR=$(dirname $0)
REVISION=$(cat "${DEPLOY_SCRIPTS_DIR}/../deployed_revision")

NEW_REVISION_DIRECTORY="${TARGET_DEPLOY_DIR}/releases/${REVISION}"
mkdir -p "${NEW_REVISION_DIRECTORY}"

# Copy files to the new directory
rsync -a --exclude-from="${ARCHIVE_DIR}/deploy/hook-scripts/rsync_exclude" "${ARCHIVE_DIR}/" "${NEW_REVISION_DIRECTORY}"

# Symlink shared objects
for i in "${SHARED_OBJECTS[@]}"; do
  (cd "${TARGET_DEPLOY_DIR}/releases/${REVISION}"; ln -s "${TARGET_DEPLOY_DIR}/shared/${i}" "${i}")
done

# Execute application scripts
for COMMAND in "${POST_INSTALL_COMMANDS[@]}"; do
  (cd "NEW_REVISION_DIRECTORY"; eval "${COMMAND}")
done

# Switch current release
(cd ${TARGET_DEPLOY_DIR}; rm -f current; ln -sf "releases/${REVISION}" "current")

# Delete old releases
(cd ${TARGET_DEPLOY_DIR}/releases && /bin/ls -1 | head -n -5 | xargs rm -rf)

# Done.