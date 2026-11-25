# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly

### 🐍 Loading screen — Ouroboros had (PŘIPRAVENO, NEIMPLEMENTOVAT bez schválení)

**Stav:** První verze (`scripts/ui/snake_loading_screen.gd`, procedurálně kreslený had z kruhů) byla zamítnuta a **odpojena ze hry**. Skript i audio zůstávají v repu jen jako asset/reference.

**Hotové assety:**
- `assets/audio/sfx_loading_snake.mp3` — znělka loading screenu (prvních 15 s, fade-in/out).
- `assets/audio/bgm_battle_intense.mp3` — celá skladba (66 s), již zapojena jako *climax* vrstva bitevní hudby (intenzivní boj + boss) v `downpour_root.gd`.

**Zadání nové verze:**
1. **Had — detailní, děsivý, ručně kreslený 2D styl** (stejný styl jako 2D animace mečů / ancient kruhů, woodcut/ink linky):
   - Sprite sheet místo procedurálních kruhů: hlava (otevřená tlama, tesáky, rozeklaný jazyk, žhnoucí oči se štěrbinovou zornicí), článkované tělo se šupinami, ocas.
   - Tmavě červená paleta, černé inkoustové obrysy, šrafování, jizvy/staré šupiny.
   - Tělo jako řetěz segmentů (`Line2D`/`Polygon2D` s texturou nebo segmentové sprity) pro plynulé vlnění.
2. **Choreografie:**
   - Had se plíží zespodu/zboku ke středu obrazovky (sinusové vlnění, šustění).
   - Ve středu začne kroužit; kruh se postupně zmenšuje, až hlava dožene ocas.
   - **Ouroboros moment:** had se snaží sežrat vlastní ocas — chňapne (rozevřená tlama, záblesk), ocas uhne, opakuje se 2–3×, nakonec se zakousne a vytvoří uzavřený kruh → kruh se rozzáří a přejde do intra/menu.
3. **Pozadí — animace karet:** pomalu poletující / otáčející se karty (Žaludy, Srdce, Listy, Kule + speciální karty) v ručně kresleném stylu, jemný parallax, občas karta vzplane / rozpadne se do inkoustu; ztmavené, aby nekonkurovaly hadovi.
4. **Zvuk:** `sfx_loading_snake.mp3` (max 15 s) + syčení / chňapnutí jako SFX synchronizované s animací.
5. **Chování:** skip klikem/klávesou po ~3 s, automatický konec po dohrání choreografie, fade do splash screenu; v headless/testech přeskočit.
6. **Ověření:** `tools/verify_ci_headless.gd` musí projít; přidat skript do seznamu kompilace.

---

### ⚔ Multiplayer Overhaul (v0.9.1-mp2) — QA & Další vylepšení

**Co bylo právě nasazeno:**
- 100% Campaign 3D krčma sdílená pro MP (`scripts/battle/tavern_scene_builder.gd` + `mp_battle_table_3d.gd`) včetně klikatelných rekvizit, Suit Astrolabe, `deck_shoe.glb` a battle hudby.
- Opravena kamera klienta (`_built_my_seat`, prázdný avatar u lokálního sedadla — už žádné překrytí ruky s kartami).
- Nový Tavern Multiplayer Hall (`mp_lobby_overlay.gd`, odemčený přímo přes ceduli **VÍCE HRÁČŮ / MULTIPLAYER** v hlavním menu bez dev/experimental bannerů): jiskry & karty v pozadí, Radmin/Tailscale VPN detekce, `MpHistory` (`user://lialo_mp_history.json`) s W–L bilancí a Quick Rematch, 4-slotový stůl, přepínač atmosféry oken, lobby chat, in-session hlasování **⚔ SEND REMATCH** a **🏛 Return to Lobby** bez odpojení.

**Otevřené navazující úkoly:**
1. **Live 2–4P Playtest (Radmin VPN / Tailscale / LAN):** Ověřit v reálném zápase novou Campaign krčmu v MP, čistý pohled klienta bez překryvu kápě, klikatelné rekvizity, přepínání atmosféry oken, tlačítko **⚔ SEND REMATCH** a **🏛 Return to Lobby (Keep Room)** bez odpojení.
2. **Lobby vizuální doladění:** Přidat 3D/2D portréty MP postav (`CHAR_GUILLOTINE`, `CHAR_MONARCH`, `CHAR_JESTER`, `CHAR_MISTBLADE`) k výběru postav a případně klasické textové pole pro chat vedle rychlých emotů.
3. **Singleplayer test (`tools/verify_battle_redesign.gd`):** Opravit pre-existující selhání 5 assertů u `CinematicDirector` v singleplayeru (`battle_table_3d.gd`).
4. **Export Windows buildu (`build/windows/LIALO.exe`):** Po finálním otestování MP znovu vyexportovat `.exe`, aby obsahovalo `v0.9.1-mp2` i nové audio.

---

### ⚔ BATTLE Quality of Life Overhaul (v0.192) — Inženýrský plán

Komplexní balík vylepšení pro boj, Arzenál, Deck Builder a plynulost Nastavení. Rozděleno do **4 pracovních bloků (Fází)** tak, aby šlo každý blok samostatně implementovat a ověřit v headless testech.

#### 1. Oprava sekání pohledu / kamery v Nastavení (Settings Stutter Fix)
- **Identifikovaná příčina v kódu:**
  - `scripts/lobby_options_3d.gd` (`_update_camera_pose`, ř. 1281): pozice kamery se plynule interpoluje (`_cam.position.lerp(...)`), ale `_cam.look_at(desired_target, Vector3.UP)` **skokově mění směr pohledu v jediném framu** pokaždé, když kurzor přejede přes tlačítko nebo mezeru mezi tlačítky (`_hovered_station` skočí mezi pozicemi rekvizit a `Vector3.ZERO`).
  - Stejný okamžitý skok cíle má i reflektor `_hover_spot.look_at(...)` (ř. 1312).
  - `_gui_input()` přestává aktualizovat paralaxu `_mouse_nx/_mouse_ny`, jakmile je kurzor nad knihou (`_book_panel` má `MOUSE_FILTER_STOP`), a při přejezdu přes okraj knihy paralaxa trhne.
  - `scripts/downpour_root.gd` (`_refresh_options_ui()`): každá změna volby (včetně tahu slideru) zbytečně přestavuje celé menu (`_populate_menu_signs()`) a celý Arzenál (`_rebuild_collection_view()`).
- **Plán úprav:**
  - [ ] Přidat do `LobbyOptions3D` vyhlazovaný stav `_cam_cur_target`, `_spot_cur_target` a vyhlazenou paralaxu s frame-rate nezávislým exponenciálním tlumením (`1.0 - exp(-k * delta)`).
  - [ ] Číst normalizovanou pozici kurzoru konzistentně přes viewport v `_process()` místo výpadků v `_gui_input()`.
  - [ ] Přidat hover debounce (~60 ms) pro přepínání 3D focusu a throttle na `card_hover` SFX při rychlém přejíždění myší.
  - [ ] V `downpour_root.gd` oddělit lehké aktualizace v `_refresh_options_ui()` — posuvníky (hlasitost, citlivost) nebudou volat `_rebuild_collection_view()` ani `_populate_menu_signs()`; plný rebuild spouštět jen při změně jazyka nebo vizuálního režimu.

#### 2. Časový limit tahu (30–45 s) + automatické líznutí karty
- **Aktuální stav:** Kampaň (`scripts/battle_table_3d.gd`) časovač tahu nemá; MP (`scripts/mp/mp_config.gd`) má pevně `TURN_TIMEOUT_SEC := 24.0`.
- **Plán úprav:**
  - [ ] Sjednotit časový limit tahu na rozmezí **30–45 s** (výchozí **35 s**; přidat volbu délky tahu `30 s / 35 s / 45 s` v Nastavení i v MP Lobby pro hosta; v `MpConfig` upravit `TURN_TIMEOUT_SEC` z `24.0` na `35.0`).
  - [ ] **Kampaň (`scripts/battle_table_3d.gd`):** Přidat `turn_time_left` odpočítávaný v `_process()` **pouze** během aktivního tahu hráče (`is_player_turn` a mimo `busy_animating`, `intro_animating`, `_is_cinematic_playing()`, `tutorial_mode`, `peddler_open`, `shop_gate_open` a otevřené modaly).
  - [ ] Při `turn_time_left <= 0.0` zrušit rozestavěný výběr karet, provést automatické líznutí 1 karty z balíčku, zobrazit upozornění (*„⏱ Čas vypršel — automatické líznutí!“*) a plynule předat tah soupeři.
  - [ ] **Multiplayer (`scripts/mp/mp_authority.gd`, `scripts/mp/mp_battle_table_3d.gd`):** Zachovat serverovou autoritu časovače na hostovi, pozastavit odpočet během Bankai/útočných animací a zobrazit stejný HUD časovač klientům.
  - [ ] **Diegetický HUD časovač (Kampaň + MP):** Stylizovaný ukazatel (přesýpací hodiny + ubíhající zlatý pruh), barevná eskalace (zlatá → oranžová ≤15 s → pulzující karmínová ≤10 s) a jemné tikání SFX posledních 5 sekund.

#### 3. Rework relikvií v Arzenálu — 8 základních relikvií (4 deck buildy × 2 hlavní)
- **Aktuální stav:** `scripts/lialo_catalog.gd` obsahuje 23 pasivních `RELICS` + 10 `TABLE_RELICS`, což tříští identitu buildů a zahlcuje Arzenál.
- **Cílová struktura (4 hlavní Deck Buildy × 2 signature relikvie = 8 core relikvií):**
  1. **⚔ Guillotine Aces (Kat / Poprava Esy & Rytíři):**
     - *Katova pečeť (Executioner's Seal)* — zesiluje údery Es a komba Rytířů.
     - *Krvavý brousek (Bloodstone Whetstone)* — zrychluje nabíjení meče a průraz štítu.
  2. **🪞 Mirror Monarch (Panovník / Dvorní karty & Odraz):**
     - *Královská pečeť (Monarch's Signet)* — bonus ke skóre dvorních karet (`D/H/K/E`) a generování štítů.
     - *Stříbrné zrcadlo (Aegis Mirror)* — posiluje obranu/odraz útoků a redukuje kletby.
  3. **🃏 Chaos Jester (Šašek / Krádeže, Sedmy & Změny barev):**
     - *Šaškova rolnička (Jester's Bell)* — zesiluje útoky Sedem a krádeže Zlodějů (Thief).
     - *Kletba kostek (Trickster's Dice)* — bonusový multiplikátor a zlato při zahrání Svršků (`H`) a mocných karet.
  4. **🌫 Mistblade Shadow (Rytíř mlhy / Mágové & Stínová komba):**
     - *Mlžná lucerna (Mistborn Lantern)* — rychlejší nabíjení Mágů (Mage Charge) a bonus za 2+ karetní komba.
     - *Stínová dýka (Phantom Edge)* — dodatečný Rival Drain / stínové poškození při kombo tazích.
- **Plán úprav:**
  - [ ] V `scripts/lialo_catalog.gd` definovat nový přehledný seznam **8 core relikvií** s explicitním polem `build_id` (`GUILLOTINE_ACES`, `MIRROR_MONARCH`, `CHAOS_JESTER`, `MISTBLADE_DUELIST`); původní relikvie bezpečně přesunout do `ARCHIVED_RELIC_IDS`.
  - [ ] Přidat bezpečnou migraci uložených profilů v `Catalog.normalize_profile()` (stará ID z `active_relics` / `unlocked_relics` se bez chyby vyčistí nebo přemapují).
  - [ ] Upravit vyhodnocování v `scripts/scoring_engine.gd`, `scripts/battle_table_3d.gd`, `scripts/mp/mp_authority.gd`, nabídku v obchodě (`downpour_root.gd`) a `CAMPAIGN_UNLOCK_LADDER`.
  - [ ] Přestavět sekci Relikvie v Arzenálu (`downpour_root.gd`) tak, aby jasně zobrazovala 4 buildy × 2 hlavní relikvie.
  - [ ] Aktualizovat testovací asserty v `tools/verify_progression_mp.gd` na nová ID 8 relikvií.

#### 4. Subkategorie Deck Builder (Kampaň + MP) & 4-kartové „Bankai“ Awakening Kombo
- **4A. Deck Builder (nová subkategorie v Arzenálu, sdílená pro Kampaň i MP):**
  - [ ] Přidat do Arzenálu novou záložku **🛠 Deck Builder** (nový modul `scripts/ui/deck_builder_panel.gd`) a přímý zkratkový vstup i z MP Lobby (`scripts/mp/mp_lobby_overlay.gd`).
  - [ ] Umožnit hráči zvolit jeden ze **4 deck buildů**, ukládat vlastní sloty balíčků do profilu (`run_profile["custom_decks"]`) a skládat balíček pro **Kampaň i Multiplayer**:
    - výběr **2 relikvií** (doporučená dvojice daného buildu),
    - úprava tříd karet (*Knight / Mage / Thief / Merchant*) a výběr povolených *Power* karet v rámci balančního limitu,
    - výběr rubu karet a skinu meče.
  - [ ] **Vizuální a animační zpracování Deck Builderu:**
    - Přepracovaný temně-zlatý stůl Deck Builderu s živým pozadím (runový kruh + částice podle barvy buildu), plynulé flip/glow animace při přidávání/odebírání karet, vizuální graf složení balíčku a odznak kompatibility *„✓ Kampaň & MP Ready“*.
- **4B. 4-kartové „Bankai“ Kombo (Bleach-style transformace):**
  - [ ] Přidat v Deck Builderu speciální sekci **„Awakening Seal (4-Card Bankai Combo)“**, kde si hráč do 4 runových slotů vloží libovolné **4 karty** ze svého balíčku.
  - [ ] **Spouštěcí mechanika v boji (`scoring_engine.gd`, `battle_table_3d.gd`, `mp_authority.gd`):**
    - Hráč může Bankai aktivovat **buď** zahráním všech 4 karet najednou v jednom tahu *(Instant Bankai)*, **nebo** postupným zahráním všech 4 karet ze své pečeti během zápasu *(Resonance 4/4 — při zahrání 4. karty se automaticky spustí Awakening; 1× za duel)*.
    - Na HUD zobrazit kompaktní 4-runovou pečeť, kde se postupně rozsvěcují odehrané části komba (hráč okamžitě vidí progres `0/4 → 4/4`).
  - [ ] **Vizuální & zvuková choreografie (`scripts/battle/bankai_fx.gd`):**
    - Krátký dramatický hit-stop (~0.15 s), potemnění 3D krčmy a barevné přepnutí světel stolu do barvy buildu.
    - Full-screen ručně kreslený inkoustový **anime cut-in banner** (název Bankai transformace + roztržení pečeti + kaligrafický záblesk), rázová vlna na 3D stole, částice (`GPUParticles3D`), camera zoom-punch a doprovodný SFX/stinger.
    - Přetrvávající **Awakened Aura** na hráčově straně stolu (rotující runový kruh + zářící okraj karet/meče) po dobu trvání buffu.
    - Plná synchronizace v MP (host rozešle událost `bankai_triggered`, klienti přehrají shodnou animaci a časovač tahu je po dobu cut-inu pozastaven).
  - [ ] **Build-specifický Bankai Buff (posiluje aktuální build):**
    - **⚔ Guillotine Aces — *Bankai: Krvavá Poprava*:** Bonusový násobitel pro Esa/Rytíře, průraz štítů a snížení prahu popravy mečem.
    - **🪞 Mirror Monarch — *Bankai: Zrcadlový Trůn*:** Okamžitý přísun štítů, posílení dvorních karet a automatický odraz dalšího útoku.
    - **🃏 Chaos Jester — *Bankai: Karneval Šílenství*:** Zdvojení efektů Sedem a Zlodějů, extra líznutí a odčerpávání bodů soupeře.
    - **🌫 Mistblade Shadow — *Bankai: Nekonečná Mlha*:** Okamžité plné nabití všech Mágů v ruce (`2/2`) a stínový drain při každém 2+ kombu.

#### Doporučené pořadí implementace & ověření
1. **Fáze 1:** Oprava kamery v Nastavení + Časovač tahu (30–45 s) v Kampani i MP.
2. **Fáze 2:** Rework 8 core relikvií + migrace profilů + aktualizace testů.
3. **Fáze 3:** Nový vizuální Deck Builder v Arzenálu napojený do Kampaně i MP.
4. **Fáze 4:** 4-kartové Bankai kombo (logika + `bankai_fx.gd` cut-in/aura + build buffy + MP sync).
5. **Ověření po každé fázi:** `tools/verify_ci_headless.gd` a `tools/verify_progression_mp.gd` musí projít bez chyb (+ přidat testy pro Bankai detekci, validaci custom decku a 8 relikvií).
