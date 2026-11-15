# Bowbridge: Archer Legion

Middeleeuwse lane shooter voor Android, gemaakt met Godot 4.5.

Sleep om je boogschutters over de brug te bewegen; schieten gaat automatisch.
Poorten veranderen de grootte van je leger (ze groeien als je erop schiet),
orkhordes kosten soldaten en aan het eind van elk level wacht een trol.

## Spelen en bouwen

- **In de editor:** open de map in Godot 4.5 en druk op F5.
- **APK:** elke push bouwt een debug-APK via GitHub Actions en zet die op een
  vaste link:
  https://github.com/steseviczakelijk-debug/Goyslop/releases/download/latest-build/bowbridge.apk
- **Testbot:** `godot --headless --fixed-fps 60 -- --autoplay --levels=5`
- **Zware test:** tik in een testbuild op de fps-teller rechtsboven.

## Opbouw

| Bestand | Inhoud |
|---|---|
| `main.gd` | Verbindt de onderdelen: invoer, spelstatus, opslaan |
| `scripts/balance.gd` | Alle instelbare getallen |
| `scripts/sim.gd` | De spelregels, zonder beeld |
| `scripts/level_gen.gd` | Maakt een level uit het levelnummer |
| `scripts/world.gd` | Alles wat je in 3D ziet |
| `scripts/hud.gd` | De interface |
| `scripts/save_data.gd` | Voortgang op schijf |
| `scripts/bot.gd` | Automatische speler voor tests |
| `tools/process_art.py` | Maakt spelklare art uit `assets/raw/` |

Het stappenplan staat in `PLAN.md`.

`ci/debug.keystore` is alleen voor testbuilds (standaard debug-wachtwoord).
Een Play Store-release krijgt een eigen, geheime sleutel.
