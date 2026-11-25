# LIALO — Sdílený To-Do List (v0.195 Plán: Epické Power Cards, Relics Overwork, Deck Builder & MP Flow)

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## ★ HLAVNÍ PRIORITA #0: Epické, vysoce detailní 1st-Person animace pro všechny Power Cards

- **Referenční hotová animace (VZOR):** `scripts/battle/power_card_vfx_showcase.gd` — **`SPEC_STORM` (Thunder Strike / Úder blesku)**.
  - Už je připnutá jako **#1 v Lobby Dev Inspectoru (`F9`)** přímo z pohledu 1. osoby hráče i zapojená v `BattleTable3D`.
- **Úkol pro kolegu:** Podle tohoto nového standardu vytvořit epické, vysoce detailní 4–5fázové 1st-person animace pro zbývajících **14 Power Cards** a každou z nich připnout jako `[1ST-PERSON]` náhled do `DevAssetInspector` (`F9`):
  - Každá animace musí mít: výlet karty z ruky hráče -> rituální slam na stůl -> unikátní 3D manifestaci nad stolem + dynamická světla + kamera shake/zoom/roll + 2D woodcut/ink impact frame s kaligrafií -> dopad na soupeře/stůl:
  1. `SPEC_VAMPIRE` — rudý srpek krve, temný vír, siphon paprsek vysávající body ze soupeře.
  2. `SPEC_MIRROR` — praskající 3D zrcadlová brána před soupeřem, zdvojení odrazu zahrané karty.
  3. `SPEC_ALCHEMIST` — zlatý transmutační kruh, bublající alchymistická baňka, zlatý déšť jisker nad rukou.
  4. `SPEC_ORACLE` — obří otvírající se třetí oko nad stolem, runové paprsky odkrývající karty soupeře.
  5. `SPEC_PHOENIX` — vzestup hořícího fénixe ze spálené kletby, ohnivé pera po celém stole.
  6. `SPEC_MIDAS` — exploze zlatých mincí a krystalizace soupeřovy strany stolu ve zlato.
  7. `SPEC_CHRONOS` — obří 3D astroláb / hodinový ciferník zastavující čas, modré zkreslení času + otočení ručiček.
  8. `SPEC_JESTER` — chaotický vír karet a masek, zdvojený výboj na všechny relikvie na stole.
  9. `SPEC_HEX` — fialové stíny a inkoustové řetězy svazující soupeře + voodoo jehly.
  10. `SPEC_MAGNET` — magnetický vír přitahující karty z balíčku v zářících obloucích do ruky hráče.
  11. `SPEC_SHIELD` — masivní 3D železná bašta a dva rotující runové štíty obklopující hráče.
  12. `SPEC_GAMBLER` — 3D obří zlaté kostky letící přes stůl s jiskrami multiplikátoru `×2 / ×3`.
  13. `SPEC_PLAGUE` — mrazivá vánice, ledové krystaly vyrůstající kolem soupeře a zamrznutí tahu.
  14. `SPEC_CROWN` — sestoupení levitující zlaté koruny se svatozáří paprsků pro každou figuru v ruce.

---

## Otevřené úkoly — v0.195

### 1. Arsenal Decks — Ponechat pouze 5 balíčků (poslední 3 odstranit)
- **Soubory:** `scripts/downpour_root.gd` (`PLAYER_DECKS`, ř. `244–373`), `scripts/ui/deck_builder_panel.gd` (`CARD_BACKS`, ř. `28–37`)
- **Úkol:**
  - Ponechat pouze prvních **5 balíčků**: `Classic Leather`, `Pharaoh's Vault`, `Legion's Aegis`, `Iron Crown`, `Corsair's Grip` (`klasic`, `antika`, `rim`, `stredovek`, `objavy`).
  - Odstranit poslední 3 (`prohibicia` / Syndicate Noir, `obsidian` / Obsidian Seal, `astral` / Astral Compass) a bezpečně migrovat `selected_deck_idx` / `selected_card_back` pro staré uložené profily, aby nespadly mimo rozsah `0..4`.

### 2. Relics Complete Overwork — Návrh nové ručně kreslené 3D sady (KE SCHVÁLENÍ UŽIVATELEM)
- **Soubory:** `scripts/relic_mesh_factory.gd`, `scripts/lialo_catalog.gd`, nové modely/textury v `assets/models/relics/` a `assets/relics/`
- **Problém:** Současné relikvie působí jako strohé 3D primitivy (viz `Phantom Mask Shard` na screenshotu).
- **Návrh nové sady 8 ikonických, ručně kreslených woodcut 3D relikvií** (každá s výraznou siluetou, kreslenou texturou + inkoustovým outline shaderem; uživatel návrh před finálním dopracováním ještě upraví/schválí):
  1. **Krčmový korbel piva (`Tavern Tankard`)** — *Vyléčí +2 ♥ HP a uhasí Burn/Venom* (dubový korbel s mosaznými obručemi a bohatou kreslenou pěnou).
  2. **Cinknuté kostky (`Loaded Bone Dice`)** — *Vysoký combo multiplier (příští kombo ×2.2)* (dvojice vyřezávaných slonovinových kostek s inkoustovými tečkami a zlatou patinou).
  3. **Magická runa (`Arcane Slate Rune`)** — *Nabije všechny Mágy v ruce na 2/2 & +15 bodů* (rozlomený břidlicový kámen se zářící vyrytou runou).
  4. **Krvavý kalich (`Crimson Goblet`)** — *Vysaje soupeři -18 bodů a přidá +1 Štít* (tepaný pohár s rudým krystalem).
  5. **Brousek na čepel (`Executioner's Whetstone`)** — *Posílí Esa a Rytíře (+20 b. & prorazí štít)* (kamenný brousek s jiskrami a koženým pásem).
  6. **Přesýpací hodiny (`Fate Hourglass`)** — *Přidá čas / vrátí kartu a +1 líznutí* (tepané mosazné hodiny se zlatým pískem).
  7. **Měšec kupce (`Guild Coin Purse`)** — *+30 Zlatých & příští zahraná karta dává 2× mince* (naditý kožený měšec s raženými zlaťáky).
  8. **Hřbitovní zvonec (`Toll Bell`)** — *Soupeř lízne +2 karty a ztratí 1 Štít* (prasklý bronzový zvon se zubatým okrajem a stínem).

### 3. Deck Builder Overwork — Bez Archetypů, Třídy jen od 10 výš, `Explain ?` & Interaktivní Spirko Tutorial
- **Soubor:** `scripts/ui/deck_builder_panel.gd`
- **Úkol:**
  - **Odstranit Archetypes:** Zrušit horní výběr 4 archetypů — hráč si skládá build zcela svobodně.
  - **Base Cards vs. Třídy (`Normal` / `Mage` / `Thief` / `Knight`):**
    - Karty `7, 8, 9, 10` jsou čistý základ (`Normal`).
    - Pro každou kartu **nad 10 (`D`, `H`, `K`, `E` ve všech 4 barvách)** si hráč samostatně vybírá tuto třídu/raritu přímo na grafické kartě + přidat více hmatatelných animací karet.
  - **Tlačítko `Explain ?` u každé karty:** Kliknutí skočí přímo do sekce *Power Cards* nebo *Normal Cards* (Encyklopedie/Arsenal) s plným vysvětlením schopnosti dané karty + tlačítko pro návrat zpět do Deck Builderu.
  - **Interaktivní 2D Spirko Tutorial v Deck Builderu:**
    - Stejný systém jako v kampani — detailně nakreslený animovaný 2D duch **Spirko**, který živě sleduje akce hráče (výběr třídy nad 10 -> výběr Power karet -> složení Grand Seal -> výběr 2 relikvií -> uložení buildu) a dává interaktivní úkoly podle toho, co uživatel právě dělá.

### 4. Multiplayer Hub — Dynamické nativní obrazovky pro každý mód
- **Soubor:** `scripts/mp/mp_lobby_overlay.gd`
- **Úkol:**
  - Po kliknutí na `Private Match` (a obdobně pro `Public Match`, `Ranked`, `Unranked`) dynamicky přepnout obrazovku na čistý moderní **Match Room** layout (nativní styl moderních her):
    - Hráč vidí **jen svůj aktuální Deck**, **ostatní připojené hráče u stolu**, velké tlačítko **READY** a přehledné **Match Settings** (zbytečný balast a staré formuláře schovat).

### 5. Dev Inspector (`F9`) — Všechny animace z 1st-Person pohledu & oprava prázdných položek
- **Soubor:** `scripts/ui/dev_asset_inspector.gd`
- **Úkol:**
  - Vzor `SPEC_STORM` (`_stage_fpv_wrap`) už běží v 1st-person POV nahoře jako připnutá položka #1.
  - Převést i všechny ostatní animace (`sword_anim`, `fx_lib`, `cinematic`, `BlenderVfx`, `combo_banner`, `bankai`, `fujira_intro`, `snake_loading`) tak, aby se přehrávaly primárně z pohledu hráče a všechny položky v seznamu se spolehlivě vykreslily a přehrály (opravit položky, které se dosud neukazovaly nebo měly statickou/chybějící animaci).

### 6. Battle HUD (`SCORE` rovnice & Srdce) — Větší magická typografie + 5 animací + žádné emoji `🛡`
- **Soubor:** `scripts/battle_table_3d.gd` (ř. `7152–7650`)
- **Úkol:**
  - **Pravá část Score Boardu (`CARD × COUNT / 0 × 1 = +0`) působí příliš suše:**
    - Výrazně zvětšit rovnici i čísla, použít expresivní magický font (`LialoDisplay.ttf`) a přidat **5+ animací**:
      1. Živé dýchání/pulzování rovnice při tahu,
      2. Magický letící paprsek/energie z rovnice rovnou do Kalicha při připsání bodů,
      3. Úderný „slam“ + scale bounce jednotlivých čísel při změně komba,
      4. Plovoucí runové jiskry kolem rovnice podle aktivní barvy,
      5. Ohnivá/blesková aura okolo výsledného `+N` čísla při `2× / 3× / 4×+` kombu.
  - **Srdce (`HeartbeatHpDisplay`):** Graficky propracovat zasazení srdce v UI a **nahradit poslední systémové modré emoji `🛡`** vedle `10 / 10` za naši woodcut ikonu (`LialoIcons` `icon_shield.png`).

### 7. 3D Tabletop Inspect přímo nad hrou bez černého boxu + oprava šedé kostky u meče
- **Soubory:** `scripts/ui/relic_inspect_3d.gd`, `scripts/battle_table_3d.gd`
- **Úkol:**
  - **Bez velkého černého boxu:** Odstranit neprůhledné tmavé pozadí a box kolem 3D inspectu — prohlížený 3D předmět vykreslit přes průhledný `SubViewport` **přímo do scény hry**, s čistým textem po straně, takže hráč v pozadí **stále vidí soupeře i stůl**.
  - **Oprava šedé kostky (`Oath Blade: Tavern Falchion`):** `inspect_prop("sword", ...)` nedostává `custom_node` ani `glb_path` a padá do šedého `BoxMesh` fallbacku (`relic_inspect_3d.gd` ř. `314–323`). Předat skutečný 3D model meče z `RelicMeshFactory.build_sword_3d_mesh(...)`!

### 8. Settings — Rozšíření možností se scrollováním & přesně 3 Visual Styles
- **Soubory:** `scripts/lobby_options_3d.gd`, `scripts/battle_table_3d.gd`, `scripts/downpour_root.gd`
- **Úkol:**
  - Přidat více nastavení (např. Master / Music / SFX / Tavern Ambient hlasitosti, Camera Shake, Screen VFX, Rychlost animací, Kvalita stínů/MSAA, VSync/FPS limit, Jazyk, Citlivost kamery) a zabalit obsah do **`ScrollContainer`**, aby se vše pohodlně scrollovalo.
  - **Visual Style zredukovat přesně na 3 režimy:**
    1. **Woodcut Ink** (`0`)
    2. **3D** (`2`)
    3. **Ultra Detailed** (`3`)
    *(Odstranit `Broadsheet Sepia`.)*

---

### 🔧 Zbývající build úkol
1. **Export Windows buildu (`build/windows/LIALO.exe`):** Po dokončení a otestování v0.195 vyexportovat finální `.exe`.
