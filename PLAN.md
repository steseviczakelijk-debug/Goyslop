# Plan: van prototype naar uitgeefbare game

Keuzes van de maker: commerciële poging, 2D-sprites, eerst het spel zelf (beeld,
spelregels, geluid), progressie daarna, verdienmodel als laatste.
Aanname: 8–10 uur per week van de maker; code wordt door een AI-assistent geschreven.

## Fase 0 – Fundament (1 week)
Eindresultaat: het spel draait op een goedkope Android-telefoon op 60 beelden per
seconde met een zichtbare fps-teller, en de code is opgedeeld.
1. [ ] Meten op een echte telefoon: soepel op een Galaxy S26 Ultra; een goedkoop
   toestel en de zware test (tik op de fps-teller) moeten nog.
2. [x] main.gd opgedeeld: simulatie, levelgenerator, weergave, interface, opslag, bot.
3. [x] Alle balansgetallen in scripts/balance.gd.
4. [x] Nieuwe naam: Bowbridge: Archer Legion, pakketnaam com.bowbridge.game.

## Fase 1 – Spelgevoel (2–3 weken)
Eindresultaat: elke gebeurtenis geeft beeld én geluid; tien seconden opname zonder
uitleg ziet eruit als een levend spel.
1. Treffers: witte flits op de ork, vonkje, kort geluid.
2. Dood van een ork: uit elkaar spatten in een rookwolkje, munt die opspringt.
3. Poorten: getal veert op bij groei, flits en geluid bij doorlopen, nieuwe
   boogschutters "ploppen" erin; verloren soldaten vallen zichtbaar weg.
4. Schieten: terugslag per boogschutter, pijlen met spoor.
5. Lopen: orks en boogschutters wiegen en stuiteren in code; twee-frame loopje als
   de sprites consistent te genereren zijn.
6. Trol: stampen met camerabeweging, rood oplichten, levensbalk, val bij verslaan.
7. Camera: lichte schok bij verlies en baastreffers, inzoomen bij winst.
8. Trillen van de telefoon bij poort, verlies en winst.
9. Geluid: ongeveer vijftien effecten, één muziekstuk voor het level, één voor de baas.
10. Win- en verliesmoment: confetti, leger juicht, munten tellen op.

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
- Opnieuw maken: de leuning (voor deze camerahoek), en alles wat bij fase 2 nieuw is.
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
