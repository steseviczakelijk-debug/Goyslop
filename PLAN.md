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

## Next, in order
3. Upgrades (give coins a purpose)
   Start army, damage, fire rate, coin bonus; rising prices; an always-visible
   bar to the next affordable upgrade; upgrade screen between levels.
   Triggers: goal gradient, visible growth, "one more level and I can afford it".
   Art: four upgrade icons, upgrade card, "upgrade" button badge.
   Done when: after every level there is something to buy or nearly buy, and
   calibration accounts for upgrades so levels stay winnable and not trivial.

4. Surprises (things to shoot)
   Barrel with a counter, treasure chest with a random coin amount, rare golden
   orc that showers coins, gates for fire rate and damage.
   Triggers: variable reward, surprise, a choice of what to aim at.
   Art: broken barrel, chest, golden orc (3 poses), gate icons.
   Done when: every level contains at least one thing the previous one lacked.

5. Streaks and near-misses
   Kill-combo counter with rising pitch and a coin bonus; win streak that raises
   the wheel's values and is lost on defeat; defeat screen showing the real
   distance to victory ("troll had 4% left") with retry as the big button.
   Triggers: momentum, loss aversion, near-miss, instant retry.
   Art: combo badge, streak flame.

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
   One hero archer with a skill, upgraded with coins and tokens from chests (no
   paid random pulls); second world with its own bridge, enemies and boss; a
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
