$ErrorActionPreference = 'Stop'

# Closed-test release identity. Do not add AUTH_DIAGNOSTICS to this build.
& flutter build appbundle --release `
  --build-name=1.0.0 `
  --build-number=19 `
  --dart-define=APP_ENTRY=v2

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
