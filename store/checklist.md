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
- [x] **Create developer account** (DadBuilt Apps; tax name Ahmad Nofal).
- [x] **Identity verification** / account review complete.
- [x] **Physical device test** (required by Amazon's presubmission checklist): done 2026-10-18 on the onn. tablet.
- [x] Binary: zip-aligned, arm64 + armeabi-v7a, targetSdk 36, minSdk 24, versionCode 2.
- [x] Assets: 114 and 512 icons, 10 screenshots at 1920×1200, promo 1024×500 with the app name.
- [x] Add New App → Android → uploaded `slime-release.apk` (versionCode 2), DRM: No.
- [x] Target: 12 Fire tablets, no Fire TV/Automotive. Audience 0–12. Content rating all None/No. User data privacy No.
- [x] Appstore Details: display title "Squish! Slime for Kids", text from `store/amazon/`, 10 screenshots, both icons, promo image.
- [x] **Submitted 2026-10-18. Approved and live 2026-10-24.** Then share into each child profile (Settings → Profiles & Family Library → child → Add Content).

## Google Play (Kids Space tablets)
- [ ] **Create developer account** ($25, ID verification, personal). Register as individual.
- [ ] Create app "Slime: No Ads Sensory Play", Game, Free.
- [ ] App content: privacy URL · no ads · no login · target audience: 5 & under + 6–8 · Families self-certification · Data safety: no data collected · IARC rating (all "none").
- [x] Closed testing track "Alpha": `slime-release.aab` uploaded, Google Group `squish-tester@googlegroups.com` as testers, approved by Google 2026-10-27.
- [ ] Recruit 12 testers (group link + opt-in link), keep them opted in for 14 consecutive days.
- [ ] Apply for production access → Production release → review.
- [ ] Grow → **Teacher Approved opt-in** on day one.
- [ ] On the tablet: Kids Space → Parent menu → Add more apps → Slime.

## In-app purchase (later, v1.1)
- [ ] Decide price (~$0.99) and SKU id (`slime_shop_unlock`).
- [ ] Amazon: integrate Amazon Appstore SDK (IAP) as a Godot Android plugin; add payment + tax info in the developer profile; create the IAP item in the console.
- [ ] Google: integrate Play Billing plugin; create the one-time product.
- [ ] Flip `store.gd available()` to query the plugin; keep the parental gate.
- [ ] Re-answer Amazon content rating "purchases: yes" and Play IAP declaration; keep "no ads".

## Store-review gotchas to pre-empt
- "App contains no text" is fine; reviewers may ask for a short description of controls — it's in listing.md.
- Snapshot writes to Pictures via MediaStore (no permission). If a reviewer asks: "saves a picture the child made to the device gallery; nothing leaves the device".
- Families policy forbids *any* third-party SDK that isn't certified: we ship none (plain Godot, no plugins).
