#!/usr/bin/env bash
set -euo pipefail

# Run this script from the root of your OpenMower-TAF-App repository.
# It installs the unified TAF Release Build App workflow and disables old duplicate BS_/BL_ workflows.

if [ ! -d ".github" ]; then
  echo "Please run this script from the root of the OpenMower-TAF-App repository. Folder .github was not found." >&2
  exit 1
fi

mkdir -p .github/workflows .github/workflows.disabled
cp -f .github/workflows/taf-release-build.yml .github/workflows/taf-release-build.yml

for file in \
  .github/workflows/build-android-apk.yml \
  .github/workflows/build-container.yml \
  .github/workflows/build.yaml
  do
    if [ -f "$file" ]; then
      name="$(basename "$file")"
      mv -f "$file" ".github/workflows.disabled/${name}.disabled"
      echo "Disabled old workflow: $file"
    fi
  done

echo "Installed .github/workflows/taf-release-build.yml"
echo "Next commands:"
echo "  git add .github/workflows .github/workflows.disabled"
echo "  git commit -m 'BL_ unify app build workflow'"
echo "  git push"
