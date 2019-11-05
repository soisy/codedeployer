#!/bin/bash

set -e
set -o pipefail

# Build archive path from AWS Codedeploy environment variables
# The source is the temporary folder where Codedeploy stores the uncompressed archive of the current revision
ARCHIVE_DIR="/opt/codedeploy-agent/deployment-root/${DEPLOYMENT_GROUP_ID}/${DEPLOYMENT_ID}/deployment-archive"

# Check that all shared objects exist in the shared directory
for OBJECT in "${SHARED_OBJECTS[@]}"; do
  if [ ! -d "${TARGET_DEPLOY_DIR}/shared/${OBJECT}" ] && [ ! -f "${TARGET_DEPLOY_DIR}/shared/${OBJECT}" ]; then
    echo "Shared object '${OBJECT}' does not exist."
    exit 1
  fi
done

# Create the new release directory
DEPLOY_SCRIPTS_DIR=$(dirname $0)
REVISION=$(cat "${DEPLOY_SCRIPTS_DIR}/../deployed_revision")

NEW_REVISION_DIRECTORY="${TARGET_DEPLOY_DIR}/releases/${REVISION}"
mkdir -p "${NEW_REVISION_DIRECTORY}"

# Copy files to the new directory
rsync -a --exclude-from="${ARCHIVE_DIR}/deploy/hook-scripts/rsync_exclude" "${ARCHIVE_DIR}/${ARCHIVE_SOURCE_SUBDIR}/" "${NEW_REVISION_DIRECTORY}"

# Symlink shared objects
for i in "${SHARED_OBJECTS[@]}"; do
  (cd "${TARGET_DEPLOY_DIR}/releases/${REVISION}"; ln -s "${TARGET_DEPLOY_DIR}/shared/${i}" "${i}")
done

# Execute application scripts
for COMMAND in "${POST_INSTALL_COMMANDS[@]}"; do
  (cd "${NEW_REVISION_DIRECTORY}"; eval "${COMMAND}")
done

# Switch current release
(cd ${TARGET_DEPLOY_DIR}; rm -f current; ln -sf "releases/${REVISION}" "current")

# Delete old releases
(cd ${TARGET_DEPLOY_DIR}/releases && /bin/ls -1 | head -n -5 | xargs rm -rf)

# Done.