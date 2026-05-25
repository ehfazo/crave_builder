#!/usr/bin/env bash
set -euo pipefail

echo '>>>> [STEP] Clean'
remove=(
  .repo/local_manifests
  hardware/qcom-caf/common
  hardware/qcom-caf/sm6225
  device/xiaomi
  vendor/xiaomi
  vendor/lineage-priv/keys
  vendor/qcom/opensource
)
for folder in "${remove[@]}"; do
  rm -rf "$folder"
  echo "    Cleaned: $folder"
done

repo init -u "$REPO_INIT_URL" -b "$REPO_INIT_BRANCH" --depth=1
if [[ "$LOCAL_MANIFEST_IS_XML" == "true" ]]; then
  mkdir -p .repo/local_manifests
  curl -o .repo/local_manifests/local_manifest.xml "$LOCAL_MANIFEST_URL"
else
  git clone "$LOCAL_MANIFEST_URL" --depth 1 -b "$LOCAL_MANIFEST_BRANCH" .repo/local_manifests
fi

if [ -f /usr/bin/resync ]; then
  /usr/bin/resync
else
  /opt/crave/resync.sh
fi

source build/envsetup.sh
echo "Repository: ${GITHUB_REPOSITORY:-unknown}"
echo "Run ID: ${GITHUB_RUN_ID:-unknown}"
lunch "$LUNCH_TARGET"
make installclean

set +e
$BUILD_COMMAND
BUILD_EXIT=$?
set -e

exit $BUILD_EXIT
