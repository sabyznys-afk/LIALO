# LIALO — Fujara Studios | Kompletná Herná Dokumentácia (ALFA VERZIA)

> **STAV PROJEKTU: ALFA VERZIA (Alpha Build / Funkčný Vertical Slice)**  
> Tento dokument opisuje **aktuálny alfa prototyp** hry **LIALO** pred finálnou produkčnou fázou (ručne kreslené finálne assety, Blender 3D modely, plné vybalansovanie a sieťový multiplayer). Väčšina základných herných systémov, procedurálnych 3D scén, shaderov, kampane a roguelite progresie je už plne hrateľná a overiteľná priamo v engine.

---

## Pokyn / Brief pre hodnotiacu AI (ak tento dokument posielaš na posúdenie)

Prosím o odborné, konštruktívne zhodnotenie tejto hry na základe dokumentácie, priložených screenshotov (`screenshots/`) a animácií (`animations/`). Zameraj sa najmä na:
1. **Herný dizajn a spojenie žánrov:** Ako pôsobí spojenie stredoeurópskej klasiky **Prší** s **Balatro** Combo/Mult škálovaním a **Inscryption / Liar's Bar** stolným 3D pohľadom z prvej osoby?
2. **Obsah a znovuhrateľnosť (2+ hodín gameplayu):** Je 15 fáz kampane, 16 Power kariet, 14 relikvií, 5 edícií, 5 štartovacích balíčkov a 5 odomykateľných mečov dosť pestrých, alebo kde vidíš najslabšie miesta v ekonomike / kombináciách?
3. **Vizuál a čitateľnosť (UX/HUD):** Pôsobia karty, intarzovaný stôl, ruky/telo hráča, Combo ciferník, mapa a Almanach prehľadne? Ktoré miesta vyzerajú príliš "prototypovo" alebo neintuitívne pre nového hráča?
4. **Priority do Beta verzie:** Akých 5 najdôležitejších krokov by posunulo túto Alfu najbližšie ku komerčne atraktívnej hre na Steam?

---

## 1. Základná identita hry

- **Názov:** LIALO (*Fujara Studios*)
- **Žáner:** 3D stolný taktický duel z prvej osoby + historický roguelite deckbuilder založený na kartovej hre **Prší**
- **Engine:** Godot Engine `4.7.2` (GDScript, `GL Compatibility` / OpenGL 3.3, základné rozlíšenie `1366×768`)
- **Kľúčový pitch:** *„Čo ak by sa tradičné stredoeurópske Prší hralo za temným krčmovým stolom naprieč 5 historickými epochami, kde každá kombinácia kariet nabíja ohnivé multiplikátory, z oblohy udierajú blesky, hádžeš omračujúce elixíry a víťazný úder zakončíš popravou súperovej siluety vlastným mečom?“*

---

## 2. Herná štruktúra a obrazovky

Hra je postavená okolo centrálneho stavu `ScreenState` (`SPLASH`, `MAIN_MENU`, `WORLD_3D`, `MATCH_3D`):

1. **Splash Intro (`SPLASH` — ~13.4s animácia)**
   - Procedurálne kreslená silueta slovenskej/tatranskej hory vystúpi zo zeme, postupne na ňu padne sneh, ožijú kamzíky a zaznie tematická fujara (`sfx_splash_fujara.wav`).
2. **Hlavné Lobby (`MAIN_MENU`)**
   - Ruka kreslené logo **LIALO** + **FUJARA STUDIOS**, vychádzajúce lúče zlatého slnka a 5 striedajúcich sa kartových animácií na pozadí využívajúcich reálne kartové textúry (špirálová fontána, miešanie v rukaviciach, levitujúci dvojitý kruh, krupiérske rozdávanie, kartový víchor).
   - Drevené interaktívne tabule:
     - **CAMPAIGN** (vstup na 3D mapu kampane)
     - **TUTORIAL** (priame spustenie interaktívneho 6-krokového tutoriálu)
     - **DECKS** (výber z 5 štartovacích balíčkov a rukavíc)
     - **MULTIPLAYER** *(v Alfa verzii zámerne uzamknutá tabuľa — pripravovaná funkcia)*
     - **QUICK TABLE** (rýchly testovací stôl v Stredoveku prednabitý Power kartami, relikviami a edíciami)
   - Rozbaľovací **Almanach** (`ALMANAC`) so 4 záložkami (`16 Power Cards`, `14 Relics`, `5 Editions`, `5 Swords`), v ktorom si hráč môže prezerať odomknutý obsah a meniť nasadený meč (`EQUIP BLADE`), plus zrolovateľné ovládanie hlasitosti/stíšenia zvuku.
3. **3D Mapa Kampane (`WORLD_3D`)**
   - Voľne posúvateľná (`WASD` / ťahanie pravým tlačidlom myši / scroll zoom) 3D top-down mapa ohraničená maľovaným pergamenovým rámom s kompasom, plávajúcimi 3D oblakmi, vlniacou sa riekou a pasúcimi sa 3D ovcami.
   - 5 žiarivých medailónov a veží reprezentujúcich historické epochy + spodná karta zvolenej etapy (`Stage 1–3/3`, Boss modifikátor, cieľové skóre, odmena vo Florinoch).
   - Top bar zobrazuje Floriny, úroveň Ascension, aktívne relikvie, rýchly prístup k Pravidlám (`? Rules`), Navigácii (`Navigation`), Almanachu a Obchodu (`Shop`).
4. **3D Súbojový stôl (`MATCH_3D` — `BattleTable3D`)**
   - Hráč sedí z prvej osoby v atmosférickej krčme za okrúhlym stolom s intarzovanou podložkou (zlaté prstence, kompasová rozeta, vyrezané lôžka pre balíček a odhodenú kopu).
   - Oproti sedí tieňová silueta rivala osvetlená zozadu tematickým výhľadom z dvoch krčmových okien (napr. slnečná antika alebo spln mesiaca v stredoveku).

---

## 3. Pravidlá súboja a špeciálne mechaniky

### 3.1 Základný balíček a pravidlá Prší
- **32 klasických kariet:** 4 farby (`♥ Hearts`, `♠ Spades`, `♣ Clubs`, `♦ Diamonds`) × 8 hodnôt:
  - `7 (Seven)` = **20 pts** — núti súpera ťahať **+2 karty** (možno prebiť a zreťaziť ďalšou `7` alebo očistiť kartou `Ash Phoenix`).
  - `8 (Eight)` = **10 pts**
  - `9 (Nine)` = **10 pts**
  - `10 (Ten)` = **10 pts**
  - `D (Lower / Dolník)` = **15 pts**
  - `H (Upper / Horník)` = **20 pts** — **Divoká zmena farby** (možno zahrať na hocičo a vybrať novú aktívnu farbu).
  - `K (King / Kráľ)` = **15 pts**
  - `E (Ace / Eso)` = **20 pts** — **Skip** (preskočí súperov ťah, pokiaľ nekontruje Esom alebo kartou `Chronos Glass`).

### 3.2 Roguelite vrstva, Combo Slam a Skórovanie
- Cieľom nie je len vyprázdniť ruku, ale zároveň nazbierať **cieľové skóre etapy** (`150` až `260+` bodov podľa éry, stupňa a Ascension úrovne).
- **Combo Slam (`Right-Click` alebo `Shift+Click`):** Hráč môže označiť viac kariet rovnakej hodnoty naraz (alebo pridať `WILD` Power kartu) a odpáliť ich naraz ako **SLAM COMBO**, čo zvyšuje násobič (`Mult`) a spúšťa ohnivý Combo ciferník, kamerové otrasy a 3D plazmové blesky.
- **5 Edícií kariet:**
  - `Standard` (základná maľovaná karta)
  - `Foil` (**+25 Chips** pri skórovaní)
  - `Holographic` (**+0.5× Mult**)
  - `Polychrome` (**×1.5 Multiplikatívny Mult + 10 Chips**)
  - `Storm Charged` (**+20 Chips, +0.3× Mult + -10 bodov súperovi** zásahom blesku)
- **Redraw Mulligan (`[R]` / tlačidlo `REDRAW`):** Základne `2×` za duel (rozšíriteľné relikviou `Chrono Pendulum`) na výmenu nehrateľných kariet.
- **Arcane PUF Elixír:** Fialová fľaštička na stole; stojí `20 pts` a 1 náboj `PUF Flask`. Hráč ju hodí do súpera v krátkej filmovej 3D cutscéne zboku -> dymová explózia súpera na 1 kolo omráči.
- **`[SPACE]` Table Peek & 1.-person pohľad:** Stlačením medzerníka ruka plynule klesne na spodný okraj (~10–12 % horných okrajov kariet ostane viditeľných), odhodená kopa na stole sa vejárovito rozprestrie okolo zlatého prstenca pre kontrolu histórie a kamera sa nakloní nad stôl. Pravým tlačidlom myši sa dá rozhliadať po krčme aj pozrieť priamo nadol na vlastné 3D telo (tunika, golier, pás s prackou, kožený popruh, rukávy).
- **Duelové meče a Poprava (`VICTORY BY THE BLADE`):** Na ľavej a pravej strane stola odpočívajú 3D meče oboch duelantov. V momente víťazstva hráčov meč vyletí, rozžiari scénu a šikmo zrazí súperovu siluetu zo stoličky; pri prehre naopak zaútočí súperova čepeľ.

---

## 4. Obsah hry v Alfa verzii (z kódu `lialo_catalog.gd` & `downpour_root.gd`)

### 4.1 5 Historických Epôch × 3 Etapy (15 stretnutí + Boss modifikátory)
1. **Ancient Egypt & Greece** *(Cieľ 150b)*: Temple Guard → High Scribe (`SCROLL_TAX`: ťahanie z kopy stojí 4b) → **Pharaoh Ramesses (BOSS)** (`PHARAOH_SEAL`: sólo ťahy pod 15b strácajú 5b)
2. **Roman Empire** *(Cieľ 180b)*: Arena Gladiator → Centurion Captain (`IRON_WALL`: súper začína s +25b) → **Julius Caesar (BOSS)** (`CAESAR_TRIBUTE`: sólo karta pridá súperovi +12b)
3. **Medieval Realm** *(Cieľ 210b)*: Tavern Squire → Royal Joust Knight (`IRON_JOUST`: bez combo/7/power karty obrana uberie 3b) → **King Charles IV (BOSS)** (`CROWN_DECREE`: dvorné karty súpera dávajú +10b, ak nemáš štít)
4. **Age of Sail (Corsairs)** *(Cieľ 230b)*: Deck Quartermaster → Sea Navigator (`SHIFTING_WINDS`: každé 4 ťahy vietor náhodne zmení farbu) → **Pirate Queen Anne (BOSS)** (`PLUNDER`: každé súperovo Eso/7 ukradne 12b)
5. **1930s Prohibition** *(Cieľ 260b)*: Speakeasy Bouncer → Syndicate Accountant (`SYNDICATE_CUT`: sólo ťahy platia 15% daň) → **Al Capone (FINAL BOSS)** (`DON_RACKETEER`: +35b náskok a 2× trest za 7/+2)

### 4.2 5 Štartovacích Balíčkov (`PLAYER_DECKS`)
- **Classic Leather:** Vyvážený balíček + kožené rukavice
- **Pharaoh's Vault:** Zlaté náramky + `+15` štartovných bodov v každom kole
- **Legion's Aegis:** Železné rímske rukavice + `+10` štartovných bodov
- **Iron Crown:** Rytierske plátové rukavice + `+1` Arcane PUF náboj navyše
- **Corsair's Grip:** Námornícke rukavice + `+1` štartovná karta navyše

### 4.3 16 Špeciálnych Power Kariet (`POWER_CARDS`)
- **Uncommon/Common:** `Vampire Leech` (ukradne 15b súperovi), `Gold Transmuter` (vylepší kartu na Foil/Holo/Poly + 1 PUF), `Seer's Eye` (odhalí súperove karty na 2 ťahy + ťahá 1), `Midas Touch` (+14 Florinov + 2× gule/dvorné), `Shadow Hex` (-18b súperovi / +10b hráčovi), `Rune Magnet` (stiahne do ruky až 2 karty rovnakej hodnoty), `Iron Bastion` (+2 Arcane Shields), `Loaded Dice` *(WILD)* (hodí násobič ×1.5 / ×2.0 / ×3.5), `Frost Blight` (-14b + Stun súpera)
- **Rare:** `Thunder Strike` (3D blesk, súper +3 karty & +0.8× Surge), `Twin Mirror` *(WILD)* (zopakuje naposledy zahranú kartu a jej efekt), `Ash Phoenix` (zmaže aktívnu kliatbu ťahania, +30 Burn, vráti sa do balíčka), `Prší Jester` *(WILD)* (spustí všetky relikvie 2×), `Royal Decree` (+14 Chips za každú dvornú kartu v ruke)
- **Mythic:** `Chronos Glass` *(WILD)* (okamžitý extra ťah!), `Prismatic Core` *(WILD)* (+0.6× Mult za každú kartu v Slame + permanentný +4 pts rast)

### 4.4 14 Pasívnych Relikvií (`RELICS`)
`Chamois Horn`, `Copper Fujara`, `Storm Capacitor`, `Loaded Knucklebone`, `Phoenix Feather`, `Crimson Fang`, `Merchant Scale`, `Alchemy Alembic`, `King's Signet`, `Chrono Pendulum`, `Prismatic Lens`, `Voodoo Effigy`, `Legion Greaves`, `Tatra Rod`.

### 4.5 5 Odomykateľných Mečových Skinov (`SWORD_SKINS`)
`Tavern Falchion` (základný), `Royal Claymore` (55 🪙), `Vampire Saber` (72 🪙), `Tempest Runeblade` (88 🪙), `Dragonfire Greatsword` (115 🪙).

---

## 5. Technická architektúra, Shadery a Assety

### 5.1 Kódová základňa (`D:\downpour-godot`)
- `scenes/main.tscn` — minimalizovaná koreňová scéna, takmer všetko UI a 3D svet vzniká dynamicky v kóde
- `scripts/downpour_root.gd` (~3 304 riadkov) — state machine obrazoviek, Splash & Lobby animácie, procedurálna 3D mapa, audio manažér, Almanach & Merchant Shop UI
- `scripts/battle_table_3d.gd` (~5 533 riadkov) — kompletná 3D fyzika a pravidlá Prší, AI rival, Combo Slam, Power karty, relikvie, PUF cutscéna, ruky/telo, mečová poprava a HUD
- `scripts/lialo_catalog.gd` (~470 riadkov) — definície Power kariet, Relikvií, Edícií, Epôch, Mečov, generátor obchodu a ukladanie profilu (`user://lialo_profile.cfg`)
- `scripts/toon_style.gd` — pomocník pre cel-shading materiály s atramentovým obrysom

### 5.2 7 Vlastných Shaderov (`shaders/`)
1. `toon.gdshader` — 3-pásmové cel-shaded osvetlenie + rim light + papierový šum
2. `outline.gdshader` — inverted hull atramentový obrys (`next_pass`)
3. `mountain_toon.gdshader` — cel-shaded skaly hôr s organickou snehovou čiarou podľa výšky a sklonu svahu
4. `card_fx.gdshader` — dynamický materiál kariet podporujúci všetkých 5 edícií (`Foil`, `Holo`, `Polychrome`, `Storm`), náklon odlesku a pulz hrateľnosti
5. `table_inlay.gdshader` — procedurálna intarzovaná indigovo-mahagónová hracia podložka so zlatými prstencami, kompasom, vyrezanými lôžkami kariet a nárazovou vlnou
6. `combo_flame.gdshader` — 2D FBM ohnivý ciferník a rotujúce nabíjacie rúny so stúpajúcimi iskrami pre Combo HUD
7. `screen_juice.gdshader` — celoobrazovková chromatická rázová vlna (RGB rozštiepenie) a blesková vinetácia pri silných zásahoch

### 5.3 Assety (`assets/`)
- **`cards/`:** Kompletných **32 PNG ilustrovaných vintage kariet Prší** (`360×540 px`), inšpirovaných tradičnými stredoeurópskymi/českými kartami s dvornými drevorytmi a pipmi
- **`table/`, `gloves/`, `lobby/`, `map/`:** Textúry dreva, kamennej podlahy, kartového chrbta, kože/železa rukavíc, maľovaného rámu mapy, kompasu, drevených tabúľ a názvu LIALO
- **`fonts/`:** 5 typografických fontov (`ANTQUAB.TTF`, `BOOKOSB.TTF`, `LialoDisplay.ttf`, `LialoBody.ttf`, `LialoScript.ttf`)
- **`audio/`:** 18 WAV súborov — 4 hudobné a ambientné slučky (`bgm_lobby_znelka`, `bgm_campaign_map`, `bgm_battle_tavern`, `amb_tavern`) + 14 herných SFX (fujara splash, miešanie, rozdávanie, hodenie karty, úder, PUF výbuch, výhra/prehra)

---

## 6. Čo je ešte rozpracované v tejto Alfe (úprimný status pre recenzenta)

1. **Multiplayer je len uzamknutá tabuľa:** Online/LAN hranie proti živému hráčovi ešte nie je implementované.
2. **Finálne ilustrácie Power Kariet (16×):** Klasických 32 Prší kariet už má kompletnú kreslenú sériu (Alfa pass), no 16 špeciálnych Power kariet zatiaľ používa procedurálny pergamen + text + efektový shader (hra má pripravený automatický loader pre `res://assets/cards/SPEC_<ID>.png`).
3. **3D Modely sú procedurálne (Prototyp):** Krčmový nábytok, telo hráča, rukavice a meče sú poskladané z kódovaných Godot primitív (`BoxMesh`/`CylinderMesh`/`SphereMesh`) + Toon shader, zatiaľ bez Blender FBX/GLTF sôch a bez unikátnych 3D siluet pre všetkých 15 historických rivalov.
4. **Dolaďovanie UX a balansu:** Krivku obtiažnosti Ascension módov a vzájomné prekrývanie niektorých krátkodobých 2D správ v extrémne rýchlych reťazeniach treba ďalej ladiť na základe playtestingu.

---

## 7. Priložené zábery a animácie (`alpha_showcase/`)

### Animované GIF ukážky (`animations/`)
- `animations/anim_01_splash_and_lobby.gif` — Splash hora Fujara Studios + plynulé vychádzanie slnka a kartová choreografia v Lobby
- `animations/anim_02_map_3d_living_world.gif` — Prelet kamery nad 3D kampaňovou mapou (rieky, ovce, oblaky, 5 historických oblastí)
- `animations/anim_03_combat_slam_and_puf.gif` — Zahranie Combo Slamu s bleskami a ohnivým HUD + filmová 3D cutscéna hodu Arcane PUF elixíru
- `animations/anim_04_peek_and_sword_finisher.gif` — `[SPACE]` náhľad na rozložené karty na stole + finálna poprava súpera 3D mečom (`VICTORY BY THE BLADE`)

### Statické screenshoty vo vysokom rozlíšení `1366×768` (`screenshots/`)
- `screenshots/01_splash_fujara_studios.png`
- `screenshots/02_main_lobby.png`
- `screenshots/03_decks_selector.png`
- `screenshots/04_almanac_powers.png`
- `screenshots/04b_almanac_relics.png`
- `screenshots/05_almanac_swords.png`
- `screenshots/06_campaign_map_3d.png`
- `screenshots/07_battle_table_tutorial.png`
- `screenshots/08_battle_combo_lightning.png`
- `screenshots/09_puf_cutscene.png`
- `screenshots/10_space_peek_and_body.png`
- `screenshots/11_look_down_player_body.png`
- `screenshots/12_sword_execution_finisher.png`
- `screenshots/13_merchant_shop.png`
- `screenshots/14_cards_32_sample_sheet.png` — Ukážka z 32 ilustrovaných vintage Prší kariet
