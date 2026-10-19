# Amazon Appstore submission guide for Slime

Researched 2026-10-18 from Amazon's developer docs (archived copies dated Oct–Dec 2025;
Amazon's live doc server was rate-limiting). Verify field names in the live console as you
go; the structure has been stable.

## 0. Before the console

| Requirement | Source | Slime status |
|---|---|---|
| Amazon customer account + Amazon developer account (same email). **Personal, not Vehlo.** | Understanding Submission | **Adam** |
| **Identity verification**: front and back photos of the account owner's government ID; the name must match "Full legal name" on the Company Profile. A banner appears in the console when requested. | Identity Verification | **Adam** |
| Physical-device test before submitting ("the Amazon Appstore requires that you test on a physical device"). | Presubmission Checklist | ✅ Adam tested on the onn. 11" kids tablet (Android 16) 2026-10-18; works. Re-check on a Fire tablet when one is available |
| Binary: APK or AAB; versionName < 50 chars; versionCode increases each release; zip-aligned; 32-bit **and** 64-bit libs both present (do not drop armeabi-v7a). | Understanding Submission | ✅ `build/slime-release.apk` 1.0.0 / code 2, arm64-v8a + armeabi-v7a, zip-aligned |
| Fire OS 8 minimum targetSdk 30 (Fire OS 14: 34, Fire OS 16: 36). | Device Filtering | ✅ targetSdk 36, minSdk 24 |
| Install location: Amazon recommends `preferExternal`. | Presubmission Checklist | Godot sets `auto`; acceptable (recommendation, not requirement) |
| Privacy questionnaire completed (mandatory for all new apps since Q2 2025). | Privacy Labels | Answer **No** to "Does your app collect user data or transfer user data to third parties?" — nothing further is required, and no privacy policy URL is demanded by Amazon in that case. We still link `docs/privacy.md`. |
| Child-Directed App (COPPA) policy: age-appropriate content, no Amazon ads/Associates, only child-suitable SDKs. | Policy Center | ✅ no ads, no SDKs, no data |
| Amazon re-signs the app with its own key; our signature is replaced. | Understanding Submission | Fine (no signature-dependent features) |

## 1. Console: Add a New App → Android

- **App title** (internal): Slime
- **Package name**: `com.h60ninja.slime` (must not contain "amazon")
- **Category**: Kids › Games › Simulation (`simulation-games-for-kids`). Alternative: Kids › Lifestyle › Crafts & DIY. Kids is a top-level category with its own Games/Lifestyle refinements.
- **Customer support email / website**: a personal address; website can be the GitHub repo or Pages site.

## 2. Step 1 — Upload Your App File

- Upload `build/slime-release.apk`. (AAB also accepted; APK is simpler for Amazon.)
- The console shows "Appstore Certificate Hashes" here; not needed for us.

## 3. Step 2 — Target Your App

- **Supported devices**: keep all Fire tablets the manifest allows; **untick every Fire TV and Automotive device** (we have no Fire TV assets and the app is touch-only).
- **Availability**: all countries, or just US.
- **Target audience**: tick **children (0–12)**. (Also "13–15" if offered.) Do **not** tick adults-only. This places us under the Child-Directed policy, which we already satisfy.
- **Content rating** questionnaire — answer every subject-matter item **None**: Violence, Cartoon Violence, Drugs, Nudity, Sex, Intolerance, Profanity, Academic. Additional information: Account creation / personal info **No**; Advertisements **No**; Gambling **No**; Location **No**; User Generated Content / user-to-user communication **No**.
- **User data privacy**: "Does your app collect user data or transfer user data to third parties?" → **No**. (Snapshots and jars are stored only on the device; nothing is transmitted.)

## 4. Step 3 — Add Appstore Details

- **Pricing**: Free.
- **Display title**: "Slime – Squish, Mold & Mix. No Ads"  (don't use "Fire"/"Kindle"/"Amazon").
- **Short description** (≤ 1,200 chars, no paragraph breaks; first 200 chars matter most): from `store/listing.md`.
- **Long description** (≤ 4,000 chars, plain text, no HTML): from `store/listing.md`.
- **Product feature bullets**: 3–5 lines, e.g.
  1. Real molding physics: craters, strands, ridges, peaks — it keeps your shape
  2. Ten slime kinds, each with its own sound; pour and swirl colours like paint
  3. Make your own slime first: glue, colour, activator, stir
  4. Beads, stars, stamps, knife, jars to save your favourites
  5. No ads, no purchases, no internet, nothing to read
- **Keywords**: slime, sensory, no ads, kids, toddler, calm, fidget, squishy, satisfying, play dough
- **Images and videos → Tablet assets**:
  - Small icon **114 × 114 PNG** → `game/icons/icon_114.png`
  - Large icon **512 × 512 PNG** → `game/icons/icon_512.png`
  - Screenshots **3–10**, allowed sizes include 1920 × 1200 → `store/screenshots/*.png` (10 files)
  - Promotional image (optional but worth it) **1024 × 500**, must include the app's name, text ≥ 50 px from edges, legible at 300 × 146 → `store/promo-1024x500.png`
  - Video: optional; skip.
  - Fire TV assets: not needed when Fire TV is untargeted.

## 5. Step 4 — Review and Submit

- Submit. Status emails go to the **account owner's** address only.
- Typical review 1–3 days; failures come with a reason and a resubmit path.
- "Most apps that fail the Appstore review process fail due to content policy violation" — ours uses only CC0 audio (`art/cc0/LICENSE.md`) and self-made art, so no IP documentation is needed.

## 6. After approval: put it in the kids' Amazon Kids profile

On each Fire tablet, in the parent profile: install from the Appstore → Settings → Profiles & Family Library → child → **Add Content** → Games & Apps → toggle Slime on. Amazon Kids (free) needs nothing from the developer; Amazon Kids+ is invitation-only and cannot be applied for.

## 7. Watch items

- **State age-verification laws** (Texas in effect Jan 1 2026, Utah May 6 2026, Louisiana Jul 1 2026): Amazon now exposes a `GetUserAgeData` API and asks developers to report "significant changes" that need renewed parental consent. Slime has no accounts, purchases, chat or age-gated content, so there is nothing to gate on. If the console asks whether an update is a significant change, answer no unless we add any of those.
- **Updates**: bump `version/code` in `game/export_presets.cfg` (both presets), re-export, upload. Content rating can only be changed with a new binary.
- Keep both ABIs in every update; dropping 32-bit shrinks device support and triggers a "reduced device support" warning.

## Sources
- Understanding Amazon Appstore Submission — https://developer.amazon.com/docs/app-submission/understanding-submission.html
- Step 2: Target Your App — https://developer.amazon.com/docs/app-submission/target-app.html
- Step 3: Add Appstore Details (image specs) — https://developer.amazon.com/docs/app-submission/appstore-details.html
- Presubmission Checklist — https://developer.amazon.com/docs/app-submission/presubmission-checklist.html
- Appstore Privacy Labels — https://developer.amazon.com/docs/app-submission/appstore-privacy-labels.html
- Child-Directed App (COPPA) Policy — https://developer.amazon.com/docs/policy-center/privacy-children.html
- Identity Verification — https://developer.amazon.com/docs/app-submission/identity-verification.html
- User Age Verification — https://developer.amazon.com/docs/app-submission/user-age-verification.html
- Device Filtering and Compatibility on Fire OS — https://developer.amazon.com/docs/app-submission/device-filtering-and-compatibility.html
- Choosing a Category — https://developer.amazon.com/docs/app-submission/categories.html
- Fire Tablet FAQ (Amazon Kids / Kids+) — https://developer.amazon.com/docs/fire-tablets/ft-faq.html
