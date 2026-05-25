#!/usr/bin/env bash
set -euo pipefail

send_telegram() {
  local message="$1"
  if [[ -n "${TG_TOKEN:-}" && -n "${TG_CHAT:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      -d "chat_id=${TG_CHAT}" \
      --data-urlencode "text=${message}" >/dev/null
  fi
}

send_telegram "[${GITHUB_REPOSITORY:-unknown}] Build init started%0ADevice: ${LUNCH_TARGET:-unknown}%0ARepo: ${REPO_INIT_URL:-unknown}"

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

SYNC_START=$(date +%s)
if [ -f /usr/bin/resync ]; then
  /usr/bin/resync
else
  /opt/crave/resync.sh
fi
SYNC_END=$(date +%s)
SYNC_DURATION=$((SYNC_END - SYNC_START))
send_telegram "[${GITHUB_REPOSITORY:-unknown}] Sync complete%0ADevice: ${LUNCH_TARGET:-unknown}%0ADuration: ${SYNC_DURATION}s"

source build/envsetup.sh
echo "Repository: ${GITHUB_REPOSITORY:-unknown}"
echo "Run ID: ${GITHUB_RUN_ID:-unknown}"
lunch "$LUNCH_TARGET"
make installclean

send_telegram "[${GITHUB_REPOSITORY:-unknown}] Bacon starting%0ADevice: ${LUNCH_TARGET:-unknown}%0ACommand: ${BUILD_COMMAND:-unknown}"

BUILD_START=$(date +%s)
set +e
$BUILD_COMMAND
BUILD_EXIT=$?
set -e
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

if [[ $BUILD_EXIT -eq 0 ]]; then
  send_telegram "[${GITHUB_REPOSITORY:-unknown}] Bacon burned successfully!%0ADevice: ${LUNCH_TARGET:-unknown}%0ADuration: ${BUILD_DURATION}s"
else
  send_telegram "[${GITHUB_REPOSITORY:-unknown}] Bacon burned - FAILED!%0ADevice: ${LUNCH_TARGET:-unknown}%0AExit code: ${BUILD_EXIT}%0ADuration: ${BUILD_DURATION}s"
fi

exit $BUILD_EXIT
