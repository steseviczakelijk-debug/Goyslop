# Goyslop

Lane shooter voor Android, gemaakt met Godot 4.5.

Sleep om je baan te kiezen; schieten gaat automatisch. Poorten veranderen de
grootte van je leger (blauwe poorten groeien als je erop schiet), hordes kosten
soldaten en aan het eind van elk level wacht een baas.

## Spelen en bouwen

- **In de editor:** open de map in Godot 4.5 en druk op F5.
- **APK:** elke push bouwt een debug-APK via GitHub Actions
  (Actions → laatste run → artifact `goyslop-apk`).
- **Testbot:** `godot --headless --fixed-fps 60 -- --autoplay --levels=5`

`ci/debug.keystore` is alleen voor testbuilds (standaard debug-wachtwoord).
Een Play Store-release krijgt een eigen, geheime sleutel.
