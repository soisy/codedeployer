#!/bin/bash

set -e
set -o pipefail

# Build archive path from AWS Codedeploy environment variables
# The source is the temporary folder where Codedeploy stores the uncompressed archive of the current revision
ARCHIVE_DIR="/opt/codedeploy-agent/deployment-root/${DEPLOYMENT_GROUP_ID}/${DEPLOYMENT_ID}/deployment-archive"

if [ -z $TARGET_DEPLOY_DIR ];
then
    echo "Target directory not defined."
    exit 1
fi

rsync -a --exclude-from="${ARCHIVE_DIR}/deploy/hook-scripts/rsync_exclude" "${ARCHIVE_DIR}/${ARCHIVE_SOURCE_SUBDIR}/" "${TARGET_DEPLOY_DIR}"

# Execute application scripts
for COMMAND in "${POST_INSTALL_COMMANDS[@]}"; do
  eval "${COMMAND}"
done
