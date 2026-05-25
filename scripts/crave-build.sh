#!/usr/bin/env bash
set -euo pipefail

send_telegram() {
  local message="$1"
  if [[ -n "${TG_TOKEN:-}" && -n "${TG_CHAT:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      -d "chat_id=${TG_CHAT}" \
      -d "text=${message}" >/dev/null
  fi
}

send_telegram "🚀 REMOTE BUILD STARTED%0A━━━━━━━━━━━━━━━━━━━━%0A📱 Device  : ${LUNCH_TARGET:-unknown}%0A📦 Repo    : ${REPO_INIT_URL:-unknown}"

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
send_telegram "📥 SYNC COMPLETE%0A━━━━━━━━━━━━━━━━━━━━%0A📱 Device  : ${LUNCH_TARGET:-unknown}%0A⏱ Duration : ${SYNC_DURATION}s"

source build/envsetup.sh
echo "Repository: ${GITHUB_REPOSITORY:-unknown}"
echo "Run ID: ${GITHUB_RUN_ID:-unknown}"
lunch "$LUNCH_TARGET"
make installclean

send_telegram "🔥 BACON STARTING%0A━━━━━━━━━━━━━━━━━━━━%0A📱 Device  : ${LUNCH_TARGET:-unknown}%0A⚙️ Command : ${BUILD_COMMAND:-unknown}"

BUILD_START=$(date +%s)
set +e
$BUILD_COMMAND
BUILD_EXIT=$?
set -e
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

if [[ $BUILD_EXIT -eq 0 ]]; then
  send_telegram "✅ BACON BURNED SUCCESSFULLY%0A━━━━━━━━━━━━━━━━━━━━%0A📱 Device  : ${LUNCH_TARGET:-unknown}%0A⏱ Duration : ${BUILD_DURATION}s%0A🎉 Build completed!"
else
  send_telegram "❌ BACON BURN FAILED%0A━━━━━━━━━━━━━━━━━━━━%0A📱 Device   : ${LUNCH_TARGET:-unknown}%0A🚩 Exit Code : ${BUILD_EXIT}%0A⏱ Duration  : ${BUILD_DURATION}s"
fi

exit $BUILD_EXIT
