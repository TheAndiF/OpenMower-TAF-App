# Run this script from the root of your OpenMower-TAF-App repository.
# It installs the unified TAF Release Build App workflow and disables old duplicate BS_/BL_ workflows.

$ErrorActionPreference = "Stop"

if (!(Test-Path ".github")) {
  throw "Please run this script from the root of the OpenMower-TAF-App repository. Folder .github was not found."
}

New-Item -ItemType Directory -Force -Path ".github/workflows" | Out-Null
New-Item -ItemType Directory -Force -Path ".github/workflows.disabled" | Out-Null

Copy-Item -Force ".github/workflows/taf-release-build.yml" ".github/workflows/taf-release-build.yml"

$oldWorkflows = @(
  ".github/workflows/build-android-apk.yml",
  ".github/workflows/build-container.yml",
  ".github/workflows/build.yaml"
)

foreach ($file in $oldWorkflows) {
  if (Test-Path $file) {
    $name = Split-Path $file -Leaf
    Move-Item -Force $file ".github/workflows.disabled/$name.disabled"
    Write-Host "Disabled old workflow: $file"
  }
}

Write-Host "Installed .github/workflows/taf-release-build.yml"
Write-Host "Next commands:"
Write-Host "  git add .github/workflows .github/workflows.disabled"
Write-Host "  git commit -m 'BL_ unify app build workflow'"
Write-Host "  git push"
