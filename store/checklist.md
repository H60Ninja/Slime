# Release checklist — Slime 1.0.0 (versionCode 2)

Tick in order. Everything in **bold** needs Adam personally.

## Build
- [x] `targetSdk 36`, `minSdk 30` (Fire OS 8). `compileSdk 36`.
- [x] Release keystore `~/.android/slime-release.jks` (alias `slime`, password in Keychain `slime-release-keystore`). **Back it up off this Mac.**
- [x] `make export-apk-release` → `build/slime-release.apk` (Amazon). `make export-aab` → `build/slime-release.aab` (Google).
- [x] Not debuggable; only permission is VIBRATE; no INTERNET.
- [x] Landscape + portrait, Android back closes overlays instead of quitting.
- [x] **Physical tablet test**: Adam tested on the onn. 11" kids tablet (Android 16) on 2026-10-18 and it works. A Fire-OS-specific pass is still worth doing when a Fire tablet is around.

## Assets
- [x] Icon 512 `game/icons/icon_512.png`; adaptive fg/bg in APK.
- [x] Feature / promo graphic 1024×500 `store/feature-graphic.png`.
- [x] 10 screenshots 1920×1200 `store/screenshots/` (both stores accept this size).
- [x] Listing text `store/listing.md`. Privacy policy `docs/privacy.md`.
- [ ] **Privacy policy URL.** Both stores need a public URL. Options: make the GitHub repo public and turn on GitHub Pages (docs/ folder), or paste the policy into a public Gist. Decide, then put the URL in listing.md.

## Amazon Appstore (Fire tablets) — full walkthrough in `docs/amazon-submission.md`
- [ ] **Create developer account** (free) at developer.amazon.com with the personal Amazon login.
- [ ] **Identity verification**: photos of the account owner's government ID, name matching the Company Profile.
- [x] **Physical device test** (required by Amazon's presubmission checklist): done 2026-10-18 on the onn. tablet.
- [x] Binary: zip-aligned, arm64 + armeabi-v7a, targetSdk 36, minSdk 24, versionCode 2.
- [x] Assets: 114 and 512 icons, 10 screenshots at 1920×1200, promo 1024×500 with the app name.
- [ ] Add New App → Android → upload `build/slime-release.apk`. Category Kids › Games › Simulation.
- [ ] Target: Fire tablets only (untick Fire TV/Automotive). Audience: children 0–12. Content rating: all None/No. User data privacy: **No**.
- [ ] Appstore Details: title, short/long description, 3–5 feature bullets, keywords (all in `store/listing.md`), images.
- [ ] Submit; review 1–3 days. Then share into each child profile (Settings → Profiles & Family Library → child → Add Content).

## Google Play (Kids Space tablets)
- [ ] **Create developer account** ($25, ID verification, personal). Register as individual.
- [ ] Create app "Slime: No Ads Sensory Play", Game, Free.
- [ ] App content: privacy URL · no ads · no login · target audience: 5 & under + 6–8 · Families self-certification · Data safety: no data collected · IARC rating (all "none").
- [ ] Closed testing track "family": upload `slime-release.aab`, add **12+ tester emails**, share opt-in link. 14 consecutive days, testers must open the app.
- [ ] Apply for production access → Production release → review.
- [ ] Grow → **Teacher Approved opt-in** on day one.
- [ ] On the tablet: Kids Space → Parent menu → Add more apps → Slime.

## Store-review gotchas to pre-empt
- "App contains no text" is fine; reviewers may ask for a short description of controls — it's in listing.md.
- Snapshot writes to Pictures via MediaStore (no permission). If a reviewer asks: "saves a picture the child made to the device gallery; nothing leaves the device".
- Families policy forbids *any* third-party SDK that isn't certified: we ship none (plain Godot, no plugins).
