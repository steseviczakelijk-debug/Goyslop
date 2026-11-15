# Plan: van prototype naar uitgeefbare game

Keuzes van de maker: commerciële poging, 2D-sprites, eerst het spel zelf (beeld,
spelregels, geluid), progressie daarna, verdienmodel als laatste.
Aanname: 8–10 uur per week van de maker; code wordt door een AI-assistent geschreven.

## Fase 0 – Fundament (1 week)
Eindresultaat: het spel draait op een goedkope Android-telefoon op 60 beelden per
seconde met een zichtbare fps-teller, en de code is opgedeeld.
1. [x] Meten op een echte telefoon: goede fps op een Galaxy S26 Ultra. Een goedkoop
   toestel is nog niet gemeten.
2. [x] main.gd opgedeeld: simulatie, levelgenerator, weergave, interface, opslag, bot.
3. [x] Alle balansgetallen in scripts/balance.gd.
4. [x] Nieuwe naam: Bowbridge: Archer Legion, pakketnaam com.bowbridge.game.

## Fase 1 – Spelgevoel (2–3 weken)
Eindresultaat: elke gebeurtenis geeft beeld én geluid; tien seconden opname zonder
uitleg ziet eruit als een levend spel.
1. [x] Treffers: witte flits op de ork, geluid.
2. [x] Dood van een ork: valt achterover met een eigen pose, rookwolkje, munt.
3. [x] Poorten: getal veert op bij groei, deeltjes en geluid bij doorlopen, nieuwe
   boogschutters "ploppen" erin, verliezen als rood getal en rode wolkjes.
4. [x] Schieten: terugslag per boogschutter, pijlen met boog en spoor.
5. [x] Lopen: orks wisselen tussen twee poses en wiegen; boogschutters tonen een
   aparte pose na het schot. De generator hield de figuren consistent, dus
   pose-animatie via bewerkte afbeeldingen werkt.
6. [x] Trol: loopt met twee poses, stampt met camerabeweging, licht op, heeft een
   levensbalk en spat uiteen. Hij haalt uit met een eigen pose (knots omhoog, dan op
   de grond); de klap kost 35 procent van je leger en is te ontwijken. De rode
   waarschuwingsvlek op de grond is nog in code getekend.
7. [x] Camera: schok bij verlies en baas. [ ] Inzoomen bij winst.
8. [x] Trillen bij poort, verlies, stamp en winst.
9. [x] Geluid: dertien effecten en één muziekstuk, allemaal gesynthetiseerd als
   tijdelijke vulling (tools/make_sounds.py). [ ] Vervangen door opgenomen geluid;
   [ ] apart muziekstuk voor de baas.
10. [x] Winst: confetti, juichend leger, vertraging bij de laatste klap.
    [x] Munten vliegen naar de teller. [ ] Munten die optellen op het winstscherm.
11. [x] Menu met pauze, volume voor muziek en geluid, trillen aan/uit, level
    opnieuw; de terugknop van Android en het verlaten van de app openen het menu.
12. [x] Levendiger: boogschutters volgen met vertraging, orks verschillen in
    grootte en tempo en lopen niet meer in een strak raster.

## Fase 2 – Kernspel en balans (3–4 weken)
Eindresultaat: tien levels die verschillend aanvoelen; een gemiddelde testbot wint
60–80 procent, een slechte verliest, een perfecte wint altijd.
1. Baas herstellen: levens volgen uit het level, niet uit je leger; een groot leger
   wint sneller en levert een hogere eindbonus op.
2. Poorten begrenzen: groei door schieten krijgt een maximum per poort.
3. Testbots met drie vaardigheidsniveaus; elke wijziging wordt daartegen gemeten.
4. Levelgenerator bouwen uit handgemaakte bouwstenen met een spanningsboog.
5. Nieuwe vijanden: snelle renner, gepantserde ork, grote bruut.
6. Obstakels en beloningen: ton met teller, stekelval, poorten voor vuursnelheid en
   schade.
7. Twee extra bazen met een eigen aanvalspatroon.
8. Moeilijkheidscurve met rustlevels en eerlijk verlies (zien aankomen, bijna gehaald).
9. Tweede omgeving om afwisseling te tonen.

## Fase 3 – Eerste minuut en interface (1–2 weken)
Eindresultaat: iemand die het spel nooit zag, speelt level 1 tot en met 3 zonder
uitleg en zonder vast te lopen.
1. Wijzend handje en een eerste level dat slepen en poorten vanzelf aanleert.
2. Pauze, en netjes hervatten na een telefoontje of app-wissel.
3. Instellingen: geluid, muziek, trillen.
4. Resultaatscherm met beloningsmoment; eigen lettertype; alle schermformaten en
   inkepingen.
5. Teksten uit de code halen (Engels en Nederlands).

## Fase 4 – Meten en gesloten test (2 weken werk, 2 weken wachten)
Eindresultaat: een ondertekende release in een gesloten Play Store-test, met cijfers.
1. Analytics: level gestart, gehaald, verloren en waar; sessieduur; terugkeer.
2. Foutrapportage, opslag met versienummer.
3. Play Console-account, release-sleutel, privacybeleid, inhoudsclassificatie 13+.
4. Gesloten test: 12 testers gedurende 14 dagen (verplicht voor nieuwe accounts).
5. Winkelpagina: icoon, schermafbeeldingen, korte video.
Streefwaarden: 35 procent komt na één dag terug, 10 procent na zeven dagen, meer dan
80 procent haalt elk van de eerste vijf levels.

## Fase 5 – Verkoopbaarheid testen (1 week, klein budget)
Eindresultaat: bekend wat één installatie via advertenties kost.
Drie korte video's van het spel als advertentie draaien met 50–100 euro. Dit cijfer
bepaalt of doorinvesteren zin heeft en is wat uitgevers als eerste vragen.

## Fase 6 – Progressie (na de cijfers)
Upgrades voor munten (startleger, schade, vuursnelheid), dagelijkse beloning, nieuwe
werelden. Bewust uitgesteld: zonder leuk kernspel houdt progressie niemand vast.

## Fase 7 – Verdienmodel en soft launch
Beloningsvideo's (dubbele munten, doorgaan na verlies), schermvullende advertenties
tussen levels vanaf level 3, aankoop "geen advertenties". Soft launch in enkele
landen, daarna opschalen of naar een uitgever met de cijfers.

## Art en animatie
- Animatie eerst in code (wiegen, rekken, terugslag, flits); dat werkt met de
  bestaande sprites.
- Extra frames alleen waar code niet volstaat. Eerst één proef (ork, twee frames)
  om te zien of de generator het figuur consistent houdt.
- De leuning is een lage stenen muur van echte 3D-vlakken met eigen texturen.
- Geen water langs de hele brug (afgewezen); de rivier kruist alleen af en toe.
- Werkafspraak: alleen aanpassen waar uitdrukkelijk akkoord op is gegeven.
- Lettertype: Lilita One (Open Font License, licentie in assets/fonts/OFL.txt).
- Werkwijze: voor alles wat een plaatje is eerst prompts vragen; beweging in code.
- Per nieuwe sprite dezelfde stijlprompt en dezelfde referentie-afbeelding.

## Juridisch (geen juridisch advies)
- Op volledig door AI gemaakte afbeeldingen rust in veel landen weinig of geen
  auteursrecht: anderen kunnen ze mogelijk kopiëren. Controleer de voorwaarden van
  de generator op commercieel gebruik en bewaar prompts en originelen.
- De spelvorm is vrij; namen, figuren, art en muziek van bestaande games niet.
- Naam controleren op bestaande merken. Licenties van geluid, lettertype en Godot
  vermelden.

## Bewust niet in dit plan
3D-modellen, iPhone-versie, helden en kaarten, online functies, meer dan twee talen.

## Risico's en vroege signalen
1. Het spel verveelt na vijf levels: na fase 2 vijf onbekenden laten spelen en
   zwijgend toekijken.
2. Installaties zijn te duur: daarom fase 5 vóór progressie en verdienmodel.
3. AI-sprites blijven niet consistent over frames: de proef aan het begin van fase 1.
4. Haperen op goedkope telefoons: meten in fase 0, daarna bij elke fase opnieuw.
5. Het werk dijt uit: elke fase stopt bij zijn eindresultaat, extra ideeën gaan op
   een lijst.
6. Twaalf testers vinden kost tijd: tijdens fase 2 al beginnen met werven.
