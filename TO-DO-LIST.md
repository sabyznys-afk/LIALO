# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly

### 🎯 UI, 3D & UX Overhaul (v0.193 — Plán pro implementaci)

Detailní 9-bodový plán úprav po playtestu v0.192 (připraveno k přímé implementaci podle konkrétních souborů v repu).

---

#### 1. Vyčištění levého dolního HUDu v boji & přejmenování „Bankai“
- **Kde:** `scripts/battle_table_3d.gd`, `scripts/mp/mp_battle_table_3d.gd`, `scripts/battle/bankai_fx.gd`, `scripts/lialo_catalog.gd`, `scripts/scoring_engine.gd`, `scripts/ui/deck_builder_panel.gd`
- **Co udělat:**
  - [ ] **Nechat:** `YOUR TURN` + čistý odpočet tahu (`TURN: XXs`, bez systémového emoji přesýpacích hodin) + kompaktní počet karet & zlato.
  - [ ] **Odstranit počítadlo `BANKAI SEAL: 0 / 4`** z bitevního HUDu (`bankai_seal_pill` / `bankai_seal_panel`).
  - [ ] **Přejmenovat celou „Bankai“ mechaniku** (v UI, textech i názvech buildů) na originální temně-fantasy LIALO název, aby hra nepůsobila jako Bleach klon — např. **„VELKÁ PEČEŤ“ / „GRAND SEAL“** (příp. *Krvavá Přísaha / Blood Oath* nebo *Probuzení Pečeti*):
    - *Katova Poprava* → **Pečeť Popravy (Seal of Execution)**
    - *Zrcadlový Trůn* → **Královská Pečeť (Sovereign Seal)**
    - *Karneval Šílenství* → **Pečeť Chaosu (Jester's Pact)**
    - *Nekonečná Mlha* → **Mlžná Pečeť (Mistbound Rite)**
  - [ ] **Odstranit okénko `Carry: 360 · +132g`** z HUDu.
  - [ ] **Odstranit trvalé tlačítko `✕ Cancel`** (`MapExitBtn` / zrušení tahu) z dolního HUDu — zobrazovat `Cancel` **pouze kontextově**, když má hráč otevřený výběr (např. hraní Svrška `H` / výběr barvy nebo rozestavěné kombo).
  - [ ] **Odstranit `25g STAKE`** z Campaign HUDu — sázky (Stake / Wager) schovat z Kampaně a ponechat/připravit primárně pro Multiplayer.

#### 2. Přepracování (Reshape) Score / Combo Pop-upu — Epický, animovaný & čitelnější
- **Kde:** `scripts/battle_table_3d.gd` (`_spawn_score_popup`, `combo_hud_grp`, `score_fx_overlay`, `scoring_banner`), `scripts/mp/mp_battle_table_3d.gd`
- **Co udělat:**
  - [ ] **Zrušit statickou černou zaoblenou krabici** (`[7] × [1] = [+15]`). Místo boxu vytvořit otevřený, vrstvený **kaligrafický/inkoustový animovaný banner** bez těžkého obdélníku (přesahující tah štětce, jiskry, rázová vlna, dynamický scale-punch).
  - [ ] **Dynamická vizualizace čísel podle typu a síly komba:**
    - *1× tah:* čisté pergamenovo-zlaté číslice s jemným dopadem.
    - *2× kombo:* žhnoucí oranžovo-zlatý gradient, větší font, puls + záblesk.
    - *3× kombo:* azurovo-fialové blesky, lehký třes číslic, nárazové jiskry.
    - *4× kombo / Velká Pečeť:* karmínově-zlatý oheň, maximální velikost, dramatický zoom-in + nárazový efekt.
  - [ ] **Prodloužit dobu zobrazení pop-upu**, aby hráč stihl vše v klidu přečíst:
    - Normální tah: ~1.8–2.2 s (s plynulým fade-outem).
    - Kombo (2×+): ~2.8–3.5 s (jasná pauza na finálním výsledku před zmizením).

#### 3. Oprava rukou NPC soupeře (Rivala) u stolu
- **Kde:** `scripts/battle_table_3d.gd` (`_setup_opponent_shadow_and_hands`, `opp_hands_anchor`, `opp_glove_left_mesh`, `opp_glove_right_mesh` a pozice 3D těla rivala)
- **Co udělat:**
  - [ ] Opravit pozici, rotaci a pózu rukou/rukavic NPC rivala — aktuálně mu visí pěsti divně u pasu/boků vedle okraje stolu a vůbec nedrží karty.
  - [ ] Napozicovat levé i pravé předloktí/rukavice tak, aby **přirozeně svíraly vějíř soupeřových karet před hrudí nad stolem** (podobně jako hráčovy ruce drží karty z první osoby), včetně přirozeného pohybu ruky při vykládání a lízání karty.

#### 4. Top-Down pohled (`[TAB]` / `[SPACE]`): Inspekce itemů, méně věcí na stole & lepší efekty uprostřed
- **Kde:** `scripts/battle_table_3d.gd`, `scripts/battle/tavern_scene_builder.gd`, `scripts/mp/mp_battle_table_3d.gd`
- **Co udělat:**
  - [ ] **Omezit počet předmětů na stole:** Pryč s přeplněným kruhem 7–8 malých modelů kolem stolu! Na stole má hráč **maximálně 2 své 3D relikvie** + jen nutné aktivní herní prvky (balíček, meč, případně 1 aktivní předmět).
  - [ ] **Přidat inspekci předmětů v Top-Down pohledu:** Hover zvýrazní model + čistý tooltip; klik / pravý klik otevře detailní 3D inspect náhled (název, signature efekt, zbývající nabití).
  - [ ] **Přepracovat efekty kolem odhazovacího balíčku uprostřed stolu:** Nahradit jednoduché ploché zelené šipky/kruhy **detailnějšími, ručně kreslenými dřevorytovými/runovými magickými kruhy a částicemi**, které se **dynamicky mění podle aktivní barvy i síly tahu**:
    - *Srdce (♥):* karmínové žhnoucí runy + stoupající uhlíky.
    - *Listí (♠):* smaragdové propletené větve/trny + vířící mlha.
    - *Žaludy (♣):* dubově-zlaté staré pečetě + dřevorytové záblesky.
    - *Koule (●):* sluneční mosazný astroláb + zlatý prach.

#### 5. Pravý dolní roh HUDu: Sbalitelné menu nástrojů pod jedním `?`
- **Kde:** `scripts/battle_table_3d.gd` (tlačítka `Rank [1]`, `Suit [2]`, `Power [3]`, `Items [TAB]`, `REDRAW [M]`, `?`, `⚙`)
- **Co udělat:**
  - [ ] Odstranit hromadu trvale roztažených, překrývajících se bublin v pravém dolním rohu (aktuálně se `?` dokonce překrývá s `REDRAW`).
  - [ ] Nechat v rohu trvale **pouze kompaktní ikonu `?` (Tools / Nápověda)** (a vedle malou ikonu Nastavení).
  - [ ] Po kliknutí na `?` se **plynule vyroluje (animovaný vertikální/vějířový šuplík)** panel se všemi akcemi (`Rank [1]`, `Suit [2]`, `Power [3]`, `Items [TAB]`, `Redraw [M]`) — hráč je má během hry vždy k dispozici, klávesové zkratky `[1/2/3/TAB/M]` fungují stále přímo, ale obrazovka zůstává čistá!

#### 6. GLOBÁLNÍ PRAVIDLO: Pryč se všemi systémovými emoty — všude vlastní tematické ikony
- **Kde:** Celý projekt (`downpour_root.gd`, `battle_table_3d.gd`, `mp_lobby_overlay.gd`, `mp_battle_table_3d.gd`, `deck_builder_panel.gd`, `lobby_options_3d.gd`, `lialo_catalog.gd`)
- **Co udělat:**
  - [ ] **Kompletně odstranit všechny Unicode / systémové emoty** (`🔊`, `⚔`, `⏳`, `⚡`, `🗡`, `♻`, `⚙`, `🔥`, `👑`, `🃏`, `🌫`, `🏛`, `📜`, `🪙`, `🩸`, `🛡`, `✓`, `✕` — mimo jiné na Windows způsobují rozbité bílé čtverečky `□` např. u `🌫 Mistblade Shadow` a působí amatérsky).
  - [ ] Vytvořit jednotnou sadu **vlastních ručně kreslených tematických 2D ikon** (dřevoryt / mosaz / pergamen v `assets/ui/icons/*.png` — např. mosazný reproduktor/zvon pro zvuk `55%`, přesýpací hodiny, zkřížené meče, koruna, lebka/kletba, štít, mince, otazník, ozubené kolo, refresh, zamčený visací zámek) a použít je přes `TextureRect` / `Button.icon` napříč celým UI.

#### 7. Zjednodušený, moderní & animovaný Multiplayer Hub
- **Kde:** `scripts/mp/mp_lobby_overlay.gd`, `scripts/mp/mp_network.gd`, `scripts/mp/mp_history.gd`
- **Co udělat:**
  - [ ] **Velký dominantní nadpis `MULTIPLAYER`** nahoře v tematické kaligrafické typografii s jemnou animací.
  - [ ] **Odebrat stavění balíčku a Extra Aces posuvníky z MP lobby!** Deck se primárně staví v **Deck Builderu** — tady si hráč pouze jedním klikem vybere některý ze svých uložených buildů (případně proklikne rovnou do Deck Builderu).
  - [ ] **Zjednodušit celou obrazovku na čisté, výrazně animované UI — NIC VÍC:**
    - **4 velké animované tematické režimy** (velké ručně dělané ikony, plynulé hover/glow/parallax efekty):
      1. **Public Match**
      2. **Private Match** *(Host / Join přes čistý rozbalovací modal s IP/kódem a Radmin/Tailscale sdílením)*
      3. **Ranked**
      4. **Unranked**
    - **Leaderboard (Global & Local)** — čistý panel s přepínačem **Global / Local** žebříčku (pořadí, přezdívka, W–L, rating / body).
  - [ ] Žádné systémové emoty, žádné rozbité čtverečky, čistá hierarchie a plynulé animace.

#### 8. 3D Relikvie s CS2-style inspekcí (Max 2 na stole, jednoduché ikonické efekty)
- **Kde:** `assets/models/relics/*.glb`, `scripts/lialo_catalog.gd`, `scripts/downpour_root.gd` (Arzenál), `scripts/ui/relic_inspect_3d.gd` *(nový modul)*, `scripts/battle_table_3d.gd`, `scripts/mp/mp_battle_table_3d.gd`
- **Co udělat:**
  - [ ] **Přestat zobrazovat relikvie jako ploché 2D karty!** Relikvie jsou fyzické 3D předměty na stole (hráč může mít na stole a ve výbavě **maximálně 2 relikvie**).
  - [ ] V Arzenálu i Deck Builderu vytvořit **interaktivní 3D prohlížeč ve stylu CS2 inspect (`SubViewport`):**
    - Relikvie se otáčejí na temném dřevěném podstavci pod teplým světlem svíčky.
    - Hráč může relikvii **chytit myší a libovolně otáčet v 360° + přibližovat kolečkem**, vidět její čistý název a 1-řádkový signature efekt (opravit překrývající se text `Unlocked (MP Ready)` vs `Antiquity • Temple Guard`!).
  - [ ] **Předělat 8 relikvií na okamžitě zapamatovatelné, ikonické krčmové 3D předměty (4 buildy × 2, max 2 na stole):**
    - Příklady jasných signature předmětů a efektů:
      - **Krčmový korbel piva (Tavern Mug):** *Healuje / obnovuje HP* (okamžitě jasný efekt!).
      - **Cinknuté kostky (Loaded Dice):** *Vysoký multiplikátor bodů při kombu*.
      - **Magická runa (Arcane Rune):** *Okamžitě nabíjí Mágy a posiluje kouzla/Power karty*.
      - **Katův brousek (Whetstone):** *Zesiluje údery Es/Rytířů a průraz štítem*.
      - **Královská pečeť / Štít (Royal Aegis):** *Přidává Štíty a blokuje první útok/kletbu*.
      - **Zlaté váhy (Merchant Scales):** *Generuje extra zlato při zahrání karet*.
      - **Krvavý kalich (Blood Chalice):** *Vysává body/HP soupeři při útoku*.
      - **Mlžná lucerna (Mist Lantern):** *Bonus při 2+ karetních kombech a skrytí ruky v mlze*.
    - Každá z 8 relikvií má vlastní detailní 3D `.glb` model zobrazený jak v CS2-style inspekci, tak fyzicky na 3D stole v Kampani i MP!

#### 9. Nový krokový (Wizard) Deck Builder — Velké vizuální karty, plynulé animace & pojmenované buildy
- **Kde:** `scripts/ui/deck_builder_panel.gd`, `scripts/lialo_catalog.gd`, `scripts/downpour_root.gd`
- **Co udělat:**
  - [ ] **Opravit bug `POWER CARDS IN DECK (65 / 3)`:** V `Catalog.sanitize_profile()` a `DeckBuilderPanel` striktně vynutit max limit (např. max 3 Power karty) a deduplikaci `custom_cards`.
  - [ ] **Předělat Deck Builder z jedné přeplněné stránky na příjemný, animovaný krokový průvodce (Wizard) s velkými vizuálními kartami a velkými vlastními ikonami:**
    - **Krok 1 — Základní karty (7, 8, 9, 10, D, H, K, E):** Hráč prochází hodnoty karet a fyzicky/velce na obrazovce vidí samotné ilustrované karty (s plynulým flipem, hoverem a volbou třídy *Rytíř / Mág / Zloděj / Kupec*), aby přesně viděl, co si do balíčku skládá.
    - **Krok 2 — Power karty:** Plynulý přechod (slide/fade animace) → velký přehledný výběr Power karet (opět velké ilustrované karty, jasné počítadlo `X / 3`).
    - **Krok 3 — 4-kartová Velká Pečeť (Ultimátní kombo — bez názvu „Bankai“):** Hráč si vybere 4 karty ze svého balíčku do 4 runových slotů + tlačítko pro živý náhled animace.
    - **Krok 4 — 2× 3D Relikvie (s CS2-style 3D prohlížením) + Vizuální set / Rub karet (Card Back) + Skin meče.**
    - **Krok 5 — Pojmenování a uložení buildu:** Textové pole pro vlastní jméno buildu (např. *„Královský Kat“*), podpora více uložených slotů balíčků (`saved_decks` v profilu), přehledná souhrnná karta a velké tlačítko **„ULOŽIT & HRÁT“** (použitelné jak v Kampani, tak v Multiplayeru!).

#### Ověření po implementaci (DoD)
- [ ] `tools/verify_ci_headless.gd` — všechny skripty se zkompilují bez chyb.
- [ ] `tools/verify_progression_mp.gd` — všechny testy (včetně limitu max 2 3D relikvií, opravy `custom_cards` bez `65/3`, přejmenovaného 4-kartového komba a uložených decků) projdou na 100 %.
- [ ] `tools/verify_battle_redesign.gd` — singleplayer testy zůstávají zelené.
- [ ] Vizuální kontrola ve hře: nulový výskyt systémových emoji / `□` čtverečků, nepřekrývající se HUD vpravo dole i vlevo dole, opravené ruce NPC rivala, plynulý CS2 inspect 3D relikvií.

---

### 🔧 Zbývající build úkol
1. **Export Windows buildu (`build/windows/LIALO.exe`):** Po dokončení a otestování v0.193 vyexportovat finální `.exe`.
