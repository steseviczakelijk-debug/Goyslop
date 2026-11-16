# Bowbridge: Archer Legion – roadmap

Goal: a game people do not want to put down. Order: make playing fair, make
winning feel great, give coins a purpose, add surprise, add reasons to return,
then measure before investing further.

Rules of the road
- Build only what the maker has explicitly approved, one step at a time.
- Art comes from the maker via prompts; motion is done in code.
- Free coins and ads only. No paid random rewards, no fake timers or rigged
  near-misses, shown odds are the real odds, audience 13+.
- After any change to game rules: run `scripts/calibrate.gd`, then `scripts/bench.gd`.

## Done
1. Fair game – levels built around one measured perfect route; troll sized so
   an army up to 28% below perfect still wins; close gate choices; pace rises
   to 1.4x; gates grow without a cap but cost more per step. Measured: perfect
   bot wins every level to 260, average bot about 3 in 4, weak bot about 1 in 7.
2. Win moment – stars against the perfect army, coins counting up with a rising
   tone, an honest reward wheel (x1–x5), continue button only afterwards.

3. Upgrades (built) – army, damage, fire
   rate and coin bonus, bought on the start screen; prices rise 45% per level,
   25 levels each. After a win the game returns to the start screen. Not yet measured: how much upgrades ease the
   calibrated levels.
6a. Daily reward (built early, from step 6) – seven days, 100 to 1500 coins; a
   missed day restarts the run.
Also built: logo and tutorial hand on the start screen. Stored, unused: store
banner (store/feature_graphic.png), hero archer (one pose).

4. Surprises (built) – barrels that free soldiers and chests with a random
   coin amount (from level 3), a rare golden orc worth 60 coins (from level 2),
   and gates that give +25% fire rate or damage for the level (from level 4).
5. Streaks and near-misses (built) – kill combo with rising pitch and a coin
   bonus, win streak that adds +1 to the wheel per three wins (max +2), defeat
   screen showing the troll's remaining health or how far you got.
8a. Hero archer (built early, from step 8) – joins from level 5 and fires a
   burst of five heavy arrows every four seconds. No upgrades for him yet.
Balance after these: perfect bot wins every level to 260; average bot 77% on
levels 1–30 and 76% on 31–100; weak bot 17%. Calibration now also measures,
per level, the toughest troll the perfect route can beat; the real troll is
15% weaker (ALLOWED_DEVIATION). Bots do not use upgrades or the hero, so real
players have it somewhat easier; not yet measured how much.

## Next, in order
6. Reasons to return
   Seven-day daily reward, a chest that fills while away (capped), three daily
   missions, opt-in notification when the chest is full.
   Triggers: appointment, streak, unfinished goals.
   Art: calendar, chest closed/open, mission card.

7. Measure (decision gate)
   Analytics (level drop-off, session length, day-1 and day-7 return), release
   signing, privacy policy, closed test with 12 testers for 14 days, and a small
   ad test (three videos, 50–100 euro) for cost per install.
   Go on only if roughly 35% return after a day, 10% after seven days and an
   install costs under about 0.30 euro. Otherwise fix the leaking step or stop.

8. Depth (only after the gate)
   Hero upgrades with coins and tokens from chests (no paid random pulls);
   second world with its own bridge, enemies and boss; a
   map; skins to collect.
   Triggers: attachment, novelty, collection.

9. Earning and soft launch
   Rewarded ads only where the player asks for them: spin the wheel again,
   continue with your army, fill the chest faster; interstitials from level 5 at
   most every third level; one "no ads" purchase. Soft launch in a few
   countries, then scale or approach a publisher with the numbers.

## State of the game
Godot 4.5, Android, portrait; code split under scripts/ (see README). Content:
archers (4 poses + fall), orcs, armored orcs from level 3 (5 poses), troll with
walk, wind-up, smash and flinch. Effects, synthesised placeholder sound, haptics,
pause menu with settings, Lilita One font (OFL). Rejected: water along the
bridge. Still open from the maker: keep or revert the font, the hidden fps
readout and the slightly calmer grass. Barrel art is in but unused.
