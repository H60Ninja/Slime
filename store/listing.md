# Store listing material

Same text for both stores. Package `com.h60ninja.slime`, version 0.1.0 (versionCode 1).

## Title
Slime

## Short description (80 chars max)
Squish, stretch and poke colourful slime with your fingers. No ads, no internet.

## Full description
Slime is a calm, simple toy for little hands.

Mold it: press to make craters, drag to pull out strands and spread it thin, pinch to
pile up ridges and peaks, smooth it flat again. Pour in a second colour and swirl it into
marble. Stamp a star or a heart. Sprinkle beads. The slime keeps the shape you give it and
slowly relaxes, like the real thing. Tap plus for a fresh lump whenever you like.

- Real molding physics: craters, strands, ridges, peaks — it keeps your shape
- 10 bright colours: pour drops in and swirl them into marble
- Four slime types: shiny, clear, metallic, cloud — plus sparkle
- Sprinkle in beads and stars that ride along with the slime
- Star and heart cookie-cutter stamps
- Wet squish, stretch, squelch and pop sounds
- No text to read, no menus to get lost in
- No ads, no in-app purchases, no internet, no data collection

Made by a dad for his kids.

## Category
Amazon: Games > Kids (Age 3–5 / 6–8). Google: Casual (Family: Ages 5 & under, 6–8).

## Content rating questionnaire answers (IARC / Amazon)
Violence: none. Sexual content: none. Language: none. Controlled substances: none.
User interaction / sharing: none. Shares location: no. Purchases: none. Ads: none.

## Google Play "Data safety"
Does the app collect or share user data? **No.** No data collected, no data shared,
no encryption-in-transit claim needed (no transit), data is not deletable because none
exists. App is not a "Families" ad-supported app. Target audience: children under 13 →
Families policy self-certification: yes, compliant (no ads, no PII, no network).

## Privacy policy URL
https://h60ninja.github.io/Slime/privacy   (publish `docs/privacy.md` via GitHub Pages,
or paste the raw GitHub URL of docs/privacy.md — both stores accept any public URL).

## Assets
- Icon 512×512: `game/icons/icon_512.png`
- Screenshots 1920×1200: `store/screenshots/*.png` (both stores accept landscape tablet
  shots; Google also wants a 1024×500 feature graphic — see `store/feature-graphic.png`).

## Builds
- Amazon Appstore: upload `build/slime-release.apk` (`make export-apk-release`).
- Google Play: upload `build/slime-release.aab` (`make export-aab`).
Both are signed with `~/.android/slime-release.jks` (password in the macOS Keychain,
service `slime-release-keystore`). **Back that keystore up** — losing it means the app can
never be updated under this package name.

## Amazon Appstore submission steps
1. developer.amazon.com → sign in with the personal (H60Ninja) Amazon account → Apps &
   Services → Add New App → Android.
2. General information: title, category Games/Kids, customer support email.
3. Availability & Pricing: free, all countries (or just US).
4. Description: paste from above. Images: icon 512, 3+ screenshots.
5. Content rating: answer as above. Tick "Directed to children under 13" (COPPA) → Amazon
   asks you to confirm no behavioural ads / no PII.
6. APK files: upload slime-release.apk. Device support: Fire tablets only.
7. Submit. Typical review 1–3 days.
8. On each Fire: parent profile → Appstore → install → Settings → Profiles & Family
   Library → child → Add Content → Games & Apps → toggle Slime on.

## Google Play submission steps
1. play.google.com/console → create developer account (personal, $25, ID verification).
2. Create app → "Slime", Game, Free. Package name is fixed by the first upload.
3. Set up app: privacy policy URL, app access (no login), ads (no), content rating,
   target audience (children), news app (no), COVID (no), data safety (no data), government
   app (no), Families self-certification.
4. Testing → Closed testing → create track "family" → upload `slime-release.aab` →
   add a Google Group / email list of 12+ testers → publish the track → share the opt-in link.
5. Testers must opt in, install and open the app. After 14 consecutive days with 12+
   testers, Dashboard → "Apply for production access".
6. Production → create release → same AAB (or a newer one) → review → publish.
7. Optional: Grow → Teacher Approved opt-in.
8. On the kids' tablet: Google Kids Space → Parent menu → Add more apps → Slime → approve
   (or approve the child's request from Family Link).
