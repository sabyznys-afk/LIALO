# LIALO — Sdílený To-Do List (v0.194 UI / 3D / UX Overhaul & Bugfixes)

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly — v0.194 Plán pro kolegu

### 1. Deck Forge Wizard — Jednotný herní styl, font, textury & fyzické Base Cards
- **Soubor:** `scripts/ui/deck_builder_panel.gd`
- **Úkol:**
  - Nahradit plochý tmavý/cyan UI styl jednotným herním tavern/woodcut stylem: všude používat herní písma `assets/fonts/LialoDisplay.ttf` a `assets/fonts/LialoUI.ttf`, dřevěné/pergamenové/zlaté textury a rámečky a animovaná tlačítka.
  - Krok **1. Base Cards**: místo textových tlačítek (`H-E: Thief`, `7 8 9 10 D H K E`) zobrazovat **skutečné fyzické karty** (`assets/cards/*.png`, stejně jako v náhledu Grand Seal) v přehledné mřížce podle barev s hover animací a kliknutím pro výběr třídy.

### 2. Méně textu + Power Cards jako skutečné ilustrované karty
- **Soubor:** `scripts/ui/deck_builder_panel.gd` (včetně opravy duplicitního nadpisu `GRAND SEAL: GRAND SEAL:` na ř. `704`)
- **Úkol:**
  - Výrazně zredukovat textové popisky napříč celým Deck Builderem („méně je víc“ — odstranit dlouhé odstavce a zbytečné popisy, opravit zdvojený nadpis `GRAND SEAL: GRAND SEAL:`).
  - Krok **2. Power Cards**: místo textového seznamu názvů ukazovat **reálné grafické karty** Power karet, ze kterých si hráč vizuálně vybírá (max 3, max 1 Mythic).

### 3. Grand Seal — Grafické karty i ve spodním výběru + hover animace
- **Soubor:** `scripts/ui/deck_builder_panel.gd` (ř. `~808`)
- **Úkol:**
  - Spodní picker (`Pick a card for Grand Seal Slot #X`) předělat z textových tlačítek (`♥ 7`, `♥ 8`…) na mřížku **reálných grafických karet** (`_get_card_tex`).
  - Přidat plynulou hover animaci na každé kartě (zvětšení `scale`, nadzvednutí, jemný náklon a zlatý/runový glow).

### 4. Zrušit Core Passives (jen 3D Relics) + grafický Card Back + 10+ UI animací + Návod jak postavit build
- **Soubory:** `scripts/ui/deck_builder_panel.gd`, `scripts/lialo_catalog.gd`, `scripts/mp/mp_config.gd`
- **Úkol:**
  - **Kompletně odstranit „Core Passive Relics“** z Deck Builderu i herních loadoutů — ve hře existují **pouze 3D Tabletop Relics** (max 2 na stůl).
  - Krok **4. Relics & Visuals**: zobrazovat 3D relikvie vizuálně (přímý 3D náhled / `RelicInspect3D`, minimum textu), **Card Back** i **Sword Skin** zobrazit jako **fyzické grafické náhledy** (`assets/table/deck_back_*.png` a textury čepelí) s animací při hoveru a výběru.
  - Přidat **10+ hmatatelných UI animací** napříč Deck Builderem (plynulé přechody kroků, hover zdvih karet, 3D flip rubu karet, puls aktivního slotu, vložení karty do Grand Seal se zábleskem, animace equipnutí relikvie, animované krokové ukazatele, potvrzení uložení buildu aj.).
  - Přidat **krátký vizuální návod**, jak správně postavit vlastní build (stručné vizuální tipy krok za krokem bez zbytečných stěn textu).

### 5. Lobby Arsenal tab „Relics & Blades“ -> 3D Relics místo 2D Passives
- **Soubor:** `scripts/downpour_root.gd` (ř. `~2899`, `~3037`)
- **Úkol:**
  - Nahradit staré 2D kartičky `Catalog.RELICS` (Anvil, Ring, Boot, VII Book…) v záložce `Relics & Blades` za **3D Tabletop Relics** (`Catalog.TABLE_RELICS`) se živým 3D náhledem a CS2-style `RelicInspect3D` na klik (max 2 vybavené).

### 6. Zvětšit ikony `?` a ozubeného kola v pravém dolním rohu
- **Soubor:** `scripts/battle_table_3d.gd` (ř. `8550–8586`)
- **Úkol:**
  - Zvětšit velikost `icon_help` a `icon_gear` z `20 px` na cca `34–38 px` (nebo upravit padding/škálu tlačítka), aby symboly čistě vyplnily téměř celý zlatý kruh.

### 7. Sbalitelné `?` menu jako rozbalovací papyrový svitek s křížkem nahoře
- **Soubor:** `scripts/battle_table_3d.gd` (ř. `8588–8696`)
- **Úkol:**
  - Předělat `bottom_right_drawer` z tmavého boxu na **papyrový/pergamenový svitek**, který se plynule rozvine směrem **nahoru** nad tlačítko `?` (bez překrývání spodních kruhových tlačítek).
  - Přidat výrazné tlačítko **křížek (`×` / `icon_cross`) přímo nahoru na svitek** pro zavření.

### 8. Odstranit plovoucí pilulku `9×1 +9` & opravit neviditelné karty rivala
- **Soubor:** `scripts/battle_table_3d.gd` (ř. `5332–5366`, `7601`, `6781–6789`, `10502–10514`, `11141–11195`)
- **Úkol:**
  - **Plovoucí `9×1 +9` / `12×1 +12`:** Odstranit zbytečné plovoucí chip pilulky ze `score_breakdown_row` / `_set_score_breakdown_chips`.
  - **Neviditelné karty rivala (např. Faraon):** Opravit pozici `opp_hands_anchor` a rotaci paží (`opp_arm_left_node` / `opp_arm_right_node`) u 3D modelů rivalů tak, aby vějíř `opp_card_nodes` nebyl schovaný za/uvnitř trupu nebo zkřížených paží — posunout ho jasně dopředu před hrudník směrem ke stolu, aby hráč vždy viděl karty v rukou soupeře.

### 9. Opravit posunutí panelu `SCORE / LAST PLAY` a vylepšit jeho detailní animaci
- **Soubor:** `scripts/battle_table_3d.gd` (ř. `7152–7155`, `7496–7623`)
- **Root cause:** `player_hud_grp.size.y = 168`, ale `combo_hud_grp` má `position.y = 68` a `size.y = 118` (`68 + 118 = 186 > 168`), takže vnitřní `LAST PLAY` panel a řádek `Turns:` přetékají o `18 px` mimo spodní zlatý rám `ui_score_board_3d.png`.
- **Úkol:**
  - Zarovnat `combo_hud_grp` přesně dovnitř zlatého rámu `player_hud_grp` bez přetékání.
  - Přepracovat pozadí a animaci (nahradit neostrý žlutý půlkruh za detailní dřevořezbové runy, ostré jiskry a čitelný energetický pulz při připsání bodů).

### 10. MP Hub — Steam jméno / Tester fallback + schovat IP bar do Dev Settings + auto-join
- **Soubor:** `scripts/mp/mp_lobby_overlay.gd` (ř. `488–560`)
- **Úkol:**
  - Automaticky zobrazovat jméno hráče ze **Steamu** (pokud běží Steam integrace); mimo Steam automaticky přiřadit čitelné testovací jméno (`Tester Arny`, `Tester Simon`, …) místo náhodného `Duelist_31`.
  - **Celý IP/Port bar (`Host IP`, `Port`, `HOST TABLE`, `JOIN TABLE`, `+2nd`) přesunout do skrytého panelu `Dev Settings`** (otevíraného malou dev ikonou).
  - Běžný tok hry udělat automatický: tlačítko **PLAY / FIND MATCH** automaticky vyhledá/připojí lobby (`Public` / `Ranked` / `Unranked`), u `Private Match` jen čistý Room Code.

### 11. MP Hub — Match módy jako horní záložky, oddálené HD portréty 3D duelistů, čisté Saved Builds
- **Soubor:** `scripts/mp/mp_lobby_overlay.gd` (ř. `950–1155`, `1380–1435`)
- **Úkol:**
  - Přesunout 4 módy (`Public Match`, `Private Match`, `Ranked`, `Unranked`) do **horních záložek (tabs)** namísto 4 velkých boxů uprostřed.
  - **3D Duelist portréty (`_build_char_bust_portrait`):** Zvýšit rozlišení `SubViewport.size` z `74×74` na **`256×256` (+ MSAA 4×)** a **oddálit kameru** (`z` z `0.76` na cca `1.35–1.65`, zacílit výš na hlavu a ramena), aby nebyl uříznutý trup a portrét byl ostrý a detailní.
  - **Saved Builds:** Zobrazovat pouze **1 základní „Basic Set“** + **vlastní buildy vytvořené hráčem v Deck Builderu** (ne 4 natvrdo předvyplněné presety).

### 12. Top-Down (`[TAB]`) volné prohlížení 3D itemů + agresivnější, epické počítání bodů & MP hudba
- **Soubory:** `scripts/battle_table_3d.gd`, `scripts/mp/mp_battle_table_3d.gd`, `scripts/downpour_root.gd`
- **Úkol:**
  - **Oprava volného inspectu v Top-Down (`TABLE_ITEMS`):**
    - Opravit dead-code bug v `battle_table_3d.gd` ř. `12052–12058`, kde handler `MOUSE_BUTTON_RIGHT` vždy udělá `return` a nikdy neprovede `relic_inspect_modal.inspect_relic(...)` na ř. `12089–12095`!
    - V režimu `TABLE_ITEMS` povolit **volné prohlížení (360° CS2 inspect)** pro všechny 3D předměty na stole (vlastní i soupeřovy relikvie, meč, pivo, kostky, baňku IGNIS) levým i pravým klikem (u aktivovatelných předmětů nabídnout přímou volbu *Inspect / Use* nebo `RMB` = Inspect, `LMB` = Use/Inspect).
  - **Agresivnější a epičtější počítání bodů a kombo animace:**
    - Výrazně zesílit scoring feedback (větší agresivní kaligrafická čísla, micro hit-stop, škálovaný camera shake/punch podle násobiče `2×/3×/4×+`, dramatický slam multiplikátoru, ohnivé/bleskové čáry letící z karty do skóre a dynamické protáčení počítadla).
  - **Fix hudby v MP bitvě (`scripts/downpour_root.gd`, ř. `753–765`):**
    - Napojit `_update_battle_music_mix` také na aktivní `MpBattleTable3D` (aktuálně čte jen SP `battle_3d`, takže v MP bitvě zůstává intenzita na `0.0` / `bgm_battle_calm.mp3`).

---

### 🔧 Zbývající build úkol
1. **Export Windows buildu (`build/windows/LIALO.exe`):** Po dokončení a otestování v0.194 vyexportovat finální `.exe`.
