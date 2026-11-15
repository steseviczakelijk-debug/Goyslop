# Masterplan Bowbridge: Archer Legion

Doel: een spel dat je niet weg wilt leggen. Eerst het spel eerlijk maken, dan de
beloningen erbovenop. Alles met gratis munten en advertenties; geen betaalde
gokelementen, geen misleiding, niet gericht op kinderen onder de 13.

Werkafspraak: er wordt alleen gebouwd waar uitdrukkelijk akkoord op is gegeven,
per stap. Voor alles wat een plaatje is eerst prompts; beweging gaat in code.

## Stap 1 – Eerlijk spel (gedaan)
Goed spelen wordt beloond en verliezen is mogelijk.
- [x] Elk level is gebouwd rond één perfecte route. `scripts/calibrate.gd` speelt
      die route per level vooraf en legt in `scripts/level_table.gd` vast hoe
      zwaar de golven mogen zijn en hoe groot het perfecte leger bij de trol is.
      Na elke wijziging aan de spelregels opnieuw draaien.
- [x] De trol is zo sterk dat je hem verslaat met een leger tot 28% onder het
      perfecte (`ALLOWED_DEVIATION`); dat percentage is afgesteld op de
      gemiddelde bot.
- [x] Poortkeuzes liggen dicht bij elkaar (plus tegen plus, x2 tegen een plus
      die bijna evenveel oplevert, soms twee rode poorten).
- [x] Poorten hebben geen maximum; elke volgende stap kost 30% meer treffers.
- [x] Tempo loopt vanaf level 3 met 3% per level op, tot hooguit 1,4 keer.
- [x] Level 1 en 2 zijn leerlevels. Na level 100 herhalen de levels 21–100.
- [x] Gemeten (`scripts/bench.gd`): perfecte bot wint alle levels 1–260;
      gemiddelde bot 79% op level 1–30 en 76% op 31–100; slechte bot 15%.

## Stap 2 – Winstmoment (gedaan, art nog tijdelijk)
Elke overwinning voelt als een prijs.
- [x] Sterren naar legergrootte: 3 bij minstens 85% van het perfecte leger, 2 bij
      60%, anders 1.
- [x] Munten tellen op met een oplopende toon.
- [x] Rad na de baas (x1 x2 x1 x3 x2 x1 x4 x5, elk vak even waarschijnlijk);
      tikken om te draaien; de bonus wordt bij je munten geteld.
- [x] De knop "volgende level" verschijnt pas na het rad.
- [ ] Art: sterren, rad, wijzer en lichtstralen zijn nu in code getekend.

## Stap 3 – Verrassingen
Tijdens het level gebeurt iets onverwachts.
- Gouden ork (zeldzaam, muntenregen); schatkist met willekeurige inhoud; ton met
  teller; af en toe een jackpot-poort.
- Art: gouden ork (drie poses), kapotte ton, schatkist, jackpot-banier. De ton
  zelf is binnen.
- Geslaagd als elk level minstens één ding heeft dat het vorige niet had.

## Stap 4 – Reeksen
Doorspelen loont.
- Combo-teller bij snel achter elkaar gedode orks, met steeds hoger geluid en een
  bonus; winstreeks over levels met een groeiende vermenigvuldiger.
- Art: combo-badge, vlam-icoon.

## Stap 5 – Vooruitgang
Altijd iets dat bijna af is.
- Upgrades voor munten (startleger, schade, vuursnelheid, muntenbonus); kaart met
  werelden; balk naar de volgende beloning; vrij te spelen skins.
- Art: upgrade-iconen, kaart, tweede wereld, twee of drie skins.

## Stap 6 – Terugkomen
Een reden om morgen weer te openen.
- Dagelijkse beloning die oploopt over zeven dagen; kist die na vier uur opengaat;
  melding als hij klaar is (alleen met toestemming).
- Art: kalender met zeven vakjes, kist dicht en open.

## Stap 7 – Verlies ombuigen
Verlies leidt tot "nog één keer".
- Verliesscherm dat toont hoe dichtbij je was (altijd het echte getal); "doorgaan
  met je leger" en "dubbele beloning" via een advertentie; "opnieuw" als grootste
  knop.
- Nodig: AdMob-account, advertentie-icoon.

## Stap 8 – Meten en bijstellen
- Meten: op welk level mensen afhaken, sessieduur, terugkeer na 1 en 7 dagen,
  gebruik van rad en advertenties.
- Nodig: 12 testers voor de gesloten Play Store-test, privacybeleid.
- Streefwaarden: 35% terug na één dag, 10% na zeven dagen.

## Stand van het spel
- Godot 4.5, Android, portret. Code opgedeeld in scripts/ (zie README).
- Inhoud: boogschutters (vier poses plus vallen), orks, gepantserde orks vanaf
  level 3 (vijf poses), trol met loop, uithaal, klap en ineenkrimpen.
- Effecten, geluid (gesynthetiseerd, tijdelijk), trillen, menu met instellingen.
- Lettertype Lilita One (Open Font License, assets/fonts/OFL.txt).
- Afgewezen: water langs de hele brug.
- Open beslissingen van de maker: lettertype, verborgen fps-teller en iets doffer
  gras zijn zonder akkoord ingebouwd; blijven of terug.

## Later (buiten dit plan)
Release-ondertekening en Play Store-pagina, echte geluiden in plaats van
gesynthetiseerde, iPhone-versie, meer talen.
