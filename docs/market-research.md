# Market research: what could make Slime a hit with kids

Written 2026-10-18 from app-store listings, review mining, Google/Amazon developer docs and
coverage of the slime toy trend. Sources at the end.

## 1. What the competition gets wrong (our opening)

The slime-app category is large but almost entirely ad-funded, and the reviews show it:

- The top Android slime app (Goo, 14k reviews, 3.9 stars) has a highly upvoted review
  complaining of four 30-second ads before the first slime and interruptions every few
  seconds of play.
- Super Slime Simulator charges $14.99 to remove ads, and parental-guide site Bark warns of
  accidental purchases and ads unsuitable for young children.
- Review-mining of the "Super Slime" clones: "focuses more on advertising than gameplay",
  ads that auto-download other games, paid ad-removal that still shows reward ads.
- "Gets boring after a while" is the second most common complaint after ads.
- Kid-focused lists (Khan Academy Kids, ABC Kids, Lingokids) all lead with the same three
  words parents search for: **no ads, no in-app purchases, offline**.

**Position:** "the slime app with no ads, no shop, nothing to buy, nothing to break." That
is a real gap, it is what parents type into the search box, and it costs us nothing because
we already made those choices.

## 2. What kids actually want from slime (from the toy and video trend)

- **Sound is the hook.** Ofcom found children under 10 are the heaviest searchers for
  "satisfying" videos; a nine-year-old quoted: "I like the sound the slime makes, that
  popping sound." Our squish/pop/crackle layer is the right instinct; it should get richer,
  not quieter.
- **Making it is half the fun.** The 2015-onward trend was driven by kids filming
  themselves making slime (glue, activator, glitter, food colouring). Our ritual matches
  this. Real slime shops (Slimeatory, Sloomoo) let kids pick texture, colour and scent
  before the staff mix it.
- **Kinds that sell in 2026 kits:** butter, cloud, fluffy, glow-in-the-dark, glitter,
  metallic, holographic, colour-changing, scented. We have butter, cloud, fluffy, glitter,
  metallic. **Missing: glow-in-the-dark, holographic, colour-changing.**
- **Cutting and slicing** is a huge ASMR sub-genre (sand-slime cutting, soap cutting apps).
  We have stamps but no knife.
- **Food and themed slimes** (ice-cream slime, unicorn slime, "slime pizza delivery") are the
  marketing hooks on nearly every kit.
- **Showing off.** Kids film and share their slime; selling slime to friends is a thing from
  age ~8 up. Our snapshot button serves the under-8s; a "my slimes" shelf would serve the
  rest.

## 3. Discovery: how a free kids app actually gets found

- **Google Play Teacher Approved** is the only lever that matters on Play. Any app meeting
  the Families policy is auto-queued for teacher review; approved apps get the badge, a
  "why we like it" blurb, and placement on the Kids tab (which now shows only Teacher
  Approved apps). Reviewers score design, appeal, enrichment, age-appropriateness and the
  *absence* of ads/IAP/cross-promotion. A no-ads, no-text, no-shop sensory toy is close to
  an ideal candidate. Requirement from the criteria: a simple interface a young child can
  navigate alone, and "healthy development" framing (calm, creative, sensory).
- **Amazon:** there is no featuring form. Kids+ inclusion is by Amazon's invitation; free
  Amazon Kids visibility is purely parents choosing to share the app into the child profile.
  So the Amazon store page (screenshots, "no ads" in the title line) and word of mouth are
  the whole funnel there.
- **Sensory / special-needs angle:** OT-adjacent roundups recommend "fluid", "fidget" and
  "cause-and-effect" apps for autism, SPD and ADHD breaks, explicitly valuing no scores, no
  pressure, no fast pacing. We fit that description exactly and should say so in the listing
  ("calm sensory play, no timers, no scores").

## 4. Recommendations, ranked by payoff per hour

1. **Lead the listing with the gap.** Title line "Slime: no ads, no purchases". First
   screenshot caption-free but obviously the ritual. Mention "calm sensory play" for the
   OT/parent search traffic.
2. **Apply for Teacher Approved on day one** of the Play release.
3. **Richer sound.** Layered wet sounds that respond to drag speed and pressure, per-kind
   variants, a few more pops. Cheapest big win per the Ofcom finding.
4. **Add the three missing kinds:** glow-in-the-dark (dark table + glowing slime, kids love
   it), holographic (hue-shift by slope), colour-changing (hue drifts with how much you knead).
5. **A knife/slice tool** (drag a line across the lump: it parts with a crunchy or wet
   sound, then slowly heals). Pairs with crunchy and butter.
6. **Scented slimes as a visual gag:** a scent icon that puffs little fruit/ice-cream
   particles; no smell, but it matches the kit marketing kids recognise.
7. **"My slimes" shelf:** save up to ~6 lumps as jars and reopen them. Gives the 6-8 year
   olds the collecting/showing-off loop without any economy.
8. **Themed sets** (ice cream, unicorn, galaxy) as one-tap presets of colour + kind +
   add-ins. Cheap, and they are the words parents search.
9. **Keep it offline and tiny.** Offline is one of the three parent must-haves; we're already
   there. Watch APK size (currently ~52 MB; fine).

## 4b. Sound research (2026-10-18, applied in art/make_sfx.py)
- Tingling in ASMR listeners is best predicted by the amplitude envelope around 5 kHz in
  the ~1.5 s before the response; pleasantness needs longer, denser, cyclic patterns; sounds
  that feel *close* (low inter-aural correlation) work best. → every wet sound now carries
  clusters of 3–15 ms resonant "sticky clicks" at 2–6 kHz; the kneading bed is stereo with
  decorrelated channels; the bus is nearly dry with a tiny room and light compression.
- Foley practice: a squeeze builds pressure gradually then ends in a brief tearing release;
  pulling out is a long wet suction; squelches at uneven spacing read as organic. → squish
  has an 18 ms pressure ramp and a late release; pop is a falling-resonance release with a
  faint delayed tail; click timing is jittered.
- "Squish engine" recipe: noise through a modulated band-pass + comb filter. → `wet_body()`.
- CC0 recordings now form the body of squish/pop/squelch/stretch/slurp/slice and the
  kneading bed: EZduzziteh "Squish Sounds Effects", rubberduck "25 CC0 mud sfx" and
  "40 CC0 water/splash/slime SFX" (16 slime sounds partly recorded from real slime).
  Licenses verified on each OpenGameArt page 2026-10-18; see art/cc0/LICENSE.md.

## 5. Honest expectations

Free with no ads means no revenue by design, and the category's leaders buy installs. What
a clean app can win is: the Teacher Approved badge, high ratings (no ad complaints), the
"no ads" search traffic, and parent word-of-mouth. That is enough for a few thousand happy
families and a 4.7-star page; it is not a path to the top charts without spending. For
*your* kids it is already the best slime app on the tablet.

## Sources (sound)
- Sound texture statistics vs tingling: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11444235/
- Artificial ASMR (cyclic patterns): https://arxiv.org/html/2210.14321v3
- Squish Engine (comb/flanger recipe): https://klangmag.co/surrealism-through-sound-design-the-squish-engine-manifesto/
- Foley envelope notes: https://morphic.com/resources/sounds/squish-sound-effect
- Procedural audio review (soft bodies): https://www.eecs.qmul.ac.uk/~josh/documents/2023/Procedural%20audio%20review.pdf
- CC0 packs: https://opengameart.org/content/squish-sounds-effects , https://opengameart.org/node/183322

## Sources
- Goo (Google Play reviews): https://play.google.com/store/apps/details?id=gg.goo
- Super Slime Simulator (App Store): https://apps.apple.com/us/app/super-slime-simulator/id1375330146
- Bark parental guide, Super Slime Simulator: https://www.bark.us/app-overview/super-slime-simulator/
- Kimola review analysis, Super Slime: https://kimola.com/reports/dive-deep-into-super-slime-game-feedback-insights-google-play-en-141225
- Slimify / DIY Slime Simulator listings: https://play.google.com/store/apps/details?id=com.cupcake.asmr , https://apps.apple.com/us/app/diy-slime-simulator-asmr/id1487034018
- Google Play Teacher Approved: https://play.google.com/console/about/programs/teacherapproved
- Android Developers blog, Kids tab / Families policy merge (Nov 2022): https://android-developers.googleblog.com/2022/11/helping-kids-and-families-find-high-quality-apps-for-kids.html
- Amazon Fire tablet developer FAQ (Kids+ by invitation): https://developer.amazon.com/docs/fire-tablets/ft-faq.html
- Best apps for toddlers 2025 (parent priorities): https://myboredtoddler.com/best-apps-for-toddlers/
- Fire tablet kids apps (no ads / offline): https://twisttravelmag.com/kindle-fire-apps-for-kids-ages-1-to-5/
- Slime trend history and "satisfying" videos: https://www.scarymommy.com/another-you-tube-trend-has-sucked-my-kids-in-slime-making-videos-are-now-all-the-rage , https://www.thecourier.co.uk/?p=817431
- Slime shops: https://www.abc15.com/entertainment/events/slimeatory-a-gilbert-shop-with-a-diy-slime-bar-and-to-go-supplies , https://sloomooinstitute.com/blogs/sloomoo-stories/meet-oxide-slimes
- 2026 slime kit roundups: https://products.newsnationnow.com/toys-and-games/hobby-collectibles/best-slime-kits , https://www.peggyomara.com/?p=18005
- Sensory / OT app roundups: https://sourcekids.com.au/7-apps-to-help-with-sensory-processing-and-self-regulation/ , https://otsimo.com/en/best-sensory-autism-apps/
