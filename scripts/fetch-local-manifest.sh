#!/usr/bin/env bash
# Fetch local manifest via curl (raw XML URL) or git clone (repo URL).
# Usage: fetch-local-manifest.sh <IS_XML> <URL> [BRANCH]
set -euo pipefail

IS_XML="$1"
URL="$2"
BRANCH="${3:-}"

mkdir -p .repo/local_manifests

if [[ "$IS_XML" == "true" ]]; then
  echo "Fetching local manifest via curl..."
  curl -sSL -o .repo/local_manifests/local_manifest.xml "$URL"
else
  echo "Cloning local manifest repository..."
  git clone "$URL" --depth 1 -b "$BRANCH" .repo/local_manifests
fi
