# Masterplan Bowbridge: Archer Legion

Doel: een spel dat je niet weg wilt leggen. Eerst het spel eerlijk maken, dan de
beloningen erbovenop. Alles met gratis munten en advertenties; geen betaalde
gokelementen, geen misleiding, niet gericht op kinderen onder de 13.

Werkafspraak: er wordt alleen gebouwd waar uitdrukkelijk akkoord op is gegeven,
per stap. Voor alles wat een plaatje is eerst prompts; beweging gaat in code.

## Stap 1 – Eerlijk spel (gedaan)
Goed spelen wordt beloond en verliezen is mogelijk.
- [x] Trol heeft vaste levens per level; een groot leger wint sneller.
- [x] Poorten groeien door schieten tot een maximum (de helft van hun waarde
      erbij, minstens 3).
- [x] Drie testbots (slecht, gemiddeld, perfect) en een meetscript:
      `godot --headless -s scripts/bench.gd -- --bot=avg --levels=1-14 --runs=20`
- [x] Balans afgesteld. Gemeten over level 1–14, 20 keer per level:
      perfect 280/280, gemiddeld 211/280 (75%), slecht 42/280 (15%, waarvan
      16/20 op level 1). Baasgevecht: perfect ongeveer 7 s, gemiddeld 11 s.
- [x] Level 1 en 2 zijn leerlevels: kleinere golven en geen poorten die
      soldaten afnemen.

## Stap 2 – Winstmoment
Elke overwinning voelt als een prijs.
- Sterren naar legergrootte; munten die één voor één optellen met oplopende toon;
  een rad na de baas dat de beloning vermenigvuldigt (x1 tot x5); de knop
  "volgende level" verschijnt pas na het feest.
- Art: sterren, rad met wijzer, lichtstralen voor het winstscherm.
- Geslaagd als het winstscherm 5–8 seconden duurt en je er niet doorheen tikt.

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
