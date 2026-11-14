# Kilo für Kilo

Ernährungsplan-App zum Abnehmen. Kein Ersatz für ärztliche Beratung.

- **Design „Fitness-Nacht“:** dunkel, mit drei Ringen für Kalorien, Eiweiß und Wasser. Die Ringe laufen animiert, jeder Wochentag zeigt Mini-Ringe, und ein geschlossener Ring wird gefeiert.
- **Plan:** Wochenplan mit skalierten Portionen, Wasser direkt an den Ringen, Sport, Fastenfenster, wahlweise sechs kleine Mahlzeiten.
- **Zusätzlich gegessen und getrunken:** Suche, eigene Einträge, Schnellauswahl der häufigsten, Zero-Getränke, Restaurant und Fast Food.
- **Rezepte:** 110 Rezepte mit Symbol, Zubereitungszeit und Küche. Übersicht mit Suche und Filtern (Mahlzeit, schnell bis 15 Minuten, Küche), Favoriten, Ausblenden, Vorkochen, eigene Rezepte direkt in der App.
- **Einkauf:** Einkaufsliste für die ganze Woche.
- **Spritze:** Medikament (Wegovy, Ozempic, Mounjaro, Saxenda oder eigenes), mg pro Spritze, nächster Termin, Pen-Vorrat, Einstichstellen-Wechsel, Nebenwirkungen, Dosis-Verlauf, Tagebuch.
- **Verlauf:** Wochenrückblick, Medaillen für Kilos, Serien und perfekte Tage, Gewicht mit Trendlinie und Prognose, Körpermaße.
- **Profil:** Kalorienziel nach Mifflin-St-Jeor, Lebensmittel ausschließen, Datensicherung.

Die ganze App steckt in `index.html`. Die Mac-App ist eine schlanke Hülle darum (`macos/`). Rezepte lädt die App bei jedem Start aus `recipes.json` in diesem Repository.

## Mac-App installieren

Die einfache Schritt-für-Schritt-Anleitung steht in [INSTALLATION.md](INSTALLATION.md).

**Variante A – selbst bauen (empfohlen, keine Sicherheitswarnung)**

```bash
xcode-select --install          # einmalig, falls noch nicht vorhanden
git clone https://github.com/Melo-Labs/Kilo-fuer-Kilo.git
cd Kilo-fuer-Kilo
./macos/build.sh install        # baut die App und legt sie in /Applications
```

**Variante B – fertige App herunterladen**

GitHub baut die App bei jeder Änderung automatisch und legt sie unter *Releases* → *Kilo für Kilo (aktuelle Version)* als `Kilo-fuer-Kilo.dmg` ab. Öffnen und die App in den Programme-Ordner ziehen.
Die App ist nicht von Apple notarisiert. Beim ersten Start deshalb: *Systemeinstellungen → Datenschutz & Sicherheit → „Dennoch öffnen“*.

## Neue Rezepte hinzufügen

`recipes.json` direkt auf GitHub bearbeiten und speichern. Die App holt die Datei beim nächsten Start (oder über „Rezepte aktualisieren“ ganz unten) – eine Neuinstallation ist nicht nötig. GitHub liefert Änderungen mit bis zu fünf Minuten Verzögerung aus. Das Repository muss dafür **öffentlich** sein.

Ein Rezept gehört in eine der vier Listen `fruehstueck`, `mittagessen`, `abendessen`, `snack`:

```json
{
  "id": "l10",
  "name": "Hähnchen-Curry mit Reis",
  "vegetarisch": false,
  "kcal": 540,
  "eiweiss": 44,
  "kohlenhydrate": 58,
  "fett": 12,
  "minuten": 25,
  "kueche": "Asiatisch",
  "symbol": "🍛",
  "zutaten": [
    ["Hähnchenbrust", 150, "g", "P"],
    ["Reis (roh)", 60, "g", "K"],
    ["Kokosmilch light", 100, "ml", "S"]
  ],
  "zubereitung": "Hähnchen anbraten, Kokosmilch und Currypaste zugeben, 10 Minuten köcheln. Mit Reis servieren."
}
```

- `id` muss eindeutig sein. Wer eine `id` ändert oder löscht, entfernt das Rezept aus bestehenden Plänen.
- Nährwerte gelten für die angegebene Portion; die App skaliert Mengen auf das Kalorienziel.
- Zutat: `[Name, Menge, Einheit, Kategorie]` – Einheit `g`, `ml` oder `Stk`; Kategorie `G` Gemüse & Obst, `P` Fleisch & Fisch, `M` Milchprodukte & Eier, `K` Getreide, Brot & Hülsenfrüchte, `S` Vorrat.
- Gleiche Zutaten immer gleich schreiben, damit die Einkaufsliste sie zusammenfasst.
- `minuten` ist die Zubereitungszeit; Rezepte bis 15 Minuten erscheinen im Filter „Schnell“.
- `kueche` und `symbol` sind freiwillig. Erlaubte Küchen: Klassisch, Italienisch, Asiatisch, Mexikanisch, Mediterran, Orientalisch. Fehlt eine Angabe, leitet die App Küche und Symbol aus dem Namen ab.
- Fehlerhafte Einträge überspringt die App. Ist die Datei kein gültiges JSON, bleibt der letzte funktionierende Stand aktiv.

## App-Updates

Jeder Push auf `main` baut die App neu und legt `Kilo-fuer-Kilo.dmg` und `version.json` im Release *latest* ab. Die Build-Nummer ist die Nummer des GitHub-Laufs. Die installierte App vergleicht ihre eigene Build-Nummer mit `version.json` und bietet unter *Profil → App und Updates* die Installation an: Sie lädt die `.dmg`, kopiert die neue App an ihren Platz und startet neu.

Voraussetzung: Die App liegt in einem Ordner mit Schreibrechten (normalerweise *Programme*) und wurde nicht direkt aus *Downloads* gestartet.

## Die App selbst ändern

Änderungen an `index.html` oder `macos/` brauchen einen neuen Build (Variante A erneut ausführen oder neues Release laden). Die in `index.html` eingebetteten Rezepte sind nur der Ausgangsstand für den ersten Start ohne Internet.
