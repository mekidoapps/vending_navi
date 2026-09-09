# Phase 24: Maps, Billing, and App Check Verification

## Confirmed production configuration

### Maps

- The dedicated `VendingNavi Maps Android` key is restricted to Android apps.
- The allowed Android package is `com.mekidoapps.vendingnavi`.
- Required release-signing SHA-1 registrations are present.
- API restriction is limited to Maps SDK for Android.
- `MAPS_API_KEY` in ignored `android/local.properties` selects the dedicated
  key; the key value is not stored in this repository.
- A Play-distributed release device test passed map display, current location,
  vending-machine markers, machine detail, and external route guidance.

The Firebase auto-created Android key remains a separate shared Firebase key.
It was not destructively repurposed as a Maps-only key.

### Billing and quota

- The `vendingnavi` Production budget is 1,000 JPY per month.
- Actual-spend alert email is enabled at 50%, 90%, and 100%.
- Maps SDK for Android is enabled. Its displayed daily/minute map-load quota
  is unlimited, current usage is low, and no quota increase is required.

### App Check

- Play Integrity is registered for `com.mekidoapps.vendingnavi`.
- Firestore App Check enforcement is enabled. Before enforcement, local
  sideloaded release requests were invalid; after enforcement, the
  Play-distributed v19 verification window was 550/550 verified requests.
- The Play v19 post-enforcement smoke passed vending-machine access,
  search/data access, MyPage, and login.
- Storage App Check enforcement is enabled. The current Play-distributed
  traffic verification was 4/4 verified, with no invalid requests, and the
  post-enforcement photo flow passed.
- Callable Functions retain strict App Check enforcement.

## Operational contract

`flutter run --release` sideloads are not a valid Production App Check E2E
path. Production E2E uses a Play-distributed build. Do not weaken App Check
enforcement to accommodate sideload testing.

## Repository boundary checks

- Maps configuration reads only `MAPS_API_KEY` from `android/local.properties`.
- `android/local.properties` and `android/key.properties` are ignored and not
  tracked.
- Android namespace, application ID, manifest package, and Firebase Android
  configuration use `com.mekidoapps.vendingnavi`.
- Firebase project configuration uses `vendingnavi`.
- Release builds reject any `APP_ENTRY` other than `v2`.
- No service-account private key or client secret is stored in the tracked
  source scanned for this verification. The tracked Firebase client
  configuration is intentionally versioned for reproducible release builds.

## Release gate

Phase 24 is GO when the configuration above remains in place for the
Play-distributed release candidate. Any change to Android signing, Maps key
restriction, App Check enforcement, billing alerts, or quota policy requires a
fresh Console verification and Play-distributed E2E check.
