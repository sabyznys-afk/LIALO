# LIALO — Sdílený To-Do List (v0.196 Plán pro kolegu)

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## ⚡ Rychlý příkaz `/goal` pro hromadné dokončení všeho najednou

> Zkopíruj a pošli svému agentovi níže uvedený blok — vezme celý tento `TO-DO-LIST.md` od bodu #6 až po finální test & export a udělá ho kompletně v jednom běhu:

```text
/goal Proveď kompletní implementaci všech otevřených úkolů z TO-DO-LIST.md v tomto pořadí:
1) Úkol #6 — Přepracuj zbývajících 9 relikvií (TRELIC_*) + sdílené 3D textury/zbraně přesně podle schváleného etalonu TRELIC_WAR_HORN (viz docs/HANDDRAWN_3D_REWORK_PLAN.md, shaders/handdrawn_relic_3d.gdshader, shaders/handdrawn_outline_3d.gdshader, tools/generate_tankard_relic.py, scripts/battle/tankard_bubbles_fx.gd), ke každé relikvii udělej živý 3D efekt a vizuálně ji ověř přes capture screenshot.
2) Úkol #1 — Sjednoť styl animací karet na hybridní 2.5D woodcut-ink kompromis a omez spouštění meče/štítu u normálních základních karet.
3) Úkol #2 — Dovol třídu KNIGHT na jakoukoli ze 32 karet, přidej bonusové zlaťáky pro NORMAL karty, implementuj 3dílný KNIGHT štít (1/3 -> 3/3 = +1 celý štít blokující 1 DMG), Grand Seal Shield-Pierce Critical a UI štítu kolem/vedle srdce.
4) Úkol #3 & #4 — Přidej vlastní animované pozadí MP Lobby a ohnivě-magické animované pozadí Arzenálu/Deck Builderu.
5) Úkol #5 — Implementuj kampaňový příběh, 5 érových mikro-tutoriálů, 5 vícefázových bossů a krátké animované komiksové cutscény podle docs/CAMPAIGN_STORY_PLAN.md.
6) Priorita #0 — Dokonči zbývajících 11 animací Power Cards v jednotném hybridním 2.5D stylu.
Po každém kroku otestuj přes headless Godot (verify_ci_headless.gd, verify_progression_mp.gd, verify_battle_redesign.gd), odstraň hotové položky z TO-DO-LIST.md a na konci vše commitni a pushni na origin/main.
```

---

## ★ NOVÉ ÚKOLY — v0.196 (Zadání pro kolegu)

### 1. Sjednocení stylu animací karet — Hybridní 2.5D kompromis + konec spamu meče/štítu na normálních kartách
- **Soubory:**
  - `scripts/sword_card_animator.gd` (`_pick_weapon_style`, ř. `56–75`, `_build_visual_layers`, ř. `462+`)
  - `scripts/battle/power_card_vfx_showcase.gd`
  - `scripts/battle_table_3d.gd` (`SwordCardAnim.play_sword_card_score_anim`, ř. `13563, 13603, 14456, 14733`)
  - `scripts/mp/mp_battle_table_3d.gd` (`SwordCardAnim.play_sword_card_mp_strike`, ř. `1676, 1736, 1757`)
- **Co změnit:**
  - **Hybridní 2.5D woodcut-ink kompromis (jednotný styl):**
    - Sjednotit vizuální jazyk mezi velkými 3D Power Card efekty a plochým 2D kresleným mečem/štítem do jednoho **hybridního 2.5D stylu** — ubrat přehnaně „3D/plastický“ vzhled u velkých animací směrem ke vrstveným kresleným 2.5D woodcut cutoutům s inkoustovým obrysem a zároveň povýšit meč a štít z obyčejného 2D spritu na stejný hybridní kombo-efekt (vrstvená hloubka, kreslené stíny, světelný záblesk a inkoustové jiskry).
  - **Omezit spouštění meče a štítu u normálních karet:**
    - Při zahrání **normální základní karty** se už nemá pokaždé přehrávat animace kresleného meče ani štítu — běžný tah má jen čistý rychlý inkoustový dopad / bodový záblesk na stůl.
    - Hybridní **meč / štít** spouštět jen tehdy, když dává herní smysl: např. při zahrání **`KNIGHT`** karty (nabití štítu), při speciálních schopnostech karet (`7`, `D`, `K`, `E`), kombu `2+` karet nebo při skutečném **bloku štítem**.

---

### 2. Třída `KNIGHT` na jakékoli kartě + `NORMAL` buff (zlaťáky) + 3dílný Štít (1/3 nabití) & Grand Seal Critical Pierce
- **Soubory:**
  - `scripts/ui/deck_builder_panel.gd` (`CLASS_CYCLE_RANKS` / `_build_step_1_base_cards`)
  - `scripts/lialo_catalog.gd` (`CARD_CLASSES` — `NORMAL` a `KNIGHT`)
  - `scripts/battle_table_3d.gd` (`player_shields`, vyhodnocení karet, HP damage, Grand Seal)
  - `scripts/mp/mp_authority.gd` (synchronizace štítů, `knight_shield_charge` a damage/pierce v MP)
  - `scripts/heartbeat_hp_display.gd` (UI zobrazení srdce + štítu)
- **Co změnit:**
  - **Deck Builder — `KNIGHT` na jakoukoli kartu:**
    - Zrušit omezení výběru třídy jen na karty nad 10 (`D, H, K, E`) — hráč si může zvolit třídu **`KNIGHT`** (příp. obecně infuzi třídy) u **jakéhokoli typu karty** ze všech 32 karet v balíčku (`7, 8, 9, 10, D, H, K, E`).
  - **`NORMAL` třída buff (víc zlaťáků):**
    - Ponechání karty jako **`NORMAL`** má hráče odměňovat vlastní výhodou: každá zahraná `NORMAL` karta přidá **bonusové zlaťáky / Floriny** (např. `+5g` až `+8g` za kartu + přehledný zlatý pop-up nad stolem), takže volba mezi `NORMAL` (ekonomika/zlaťáky) a `KNIGHT` (obrana/štít) bude taktickým rozhodnutím.
  - **Nová mechanika 3dílného Štítu (`KNIGHT`):**
    - Přidat stav nabití štítu (`knight_shield_charge: int` v rozsahu `0..2`, pro SP i MP).
    - Každá zahraná karta typu **`KNIGHT`** nabije **1/3 štítu** (`+1` segment).
    - Po **3 zahraných `KNIGHT` kartách (`3/3`)** se vyrobí **+1 celý Štít** (`player_shields += 1`) a nabíjení se vynuluje zpět na `0/3`.
    - **1 celý Štít blokuje 1 HP damage** (při zásahu pohltí 1 poškození se štítovým efektem místo ztráty srdce).
    - **Grand Seal Critical Pierce:** Finisher **Grand Seal** (a kritické průrazné zásahy) umí **projít i přes aktivní štít** (`pierce_shield = true`) a udělit critical damage přímo do HP s výrazným calloutem `CRITICAL • SHIELD PIERCE!`.
  - **UI zobrazení štítu u srdce (`HeartbeatHpDisplay`):**
    - *Varianta A (Doporučená — v sobě kolem srdce):* 3dílný segmentovaný ocelovo-zlatý prstenec („Aegis Ring“) přímo kolem medailonu srdce (`1/3`, `2/3`, `3/3`) — každý zahraný Knight rozsvítí další třetinu prstence a po naplnění `3/3` přeteče do nabitého celého štítu s počtem štítů.
    - *Varianta B (Vedle srdce):* Erbovní kreslený štít vedle srdce rozdělený na 3 pole, která se postupně plní `1/3 -> 2/3 -> 3/3` + zřetelné počítadlo celých štítů.

---

### 3. Multiplayer Lobby — vlastní animované pozadí laděné pro MP
- **Soubory:**
  - `scripts/mp/mp_lobby_overlay.gd` (`_init_bg_fx_particles`, `_draw_bg_fx`, `_build_ui`, ř. `356–427`)
  - Nový/vlastní background asset např. `assets/ui/mp_arena_bg.png`
- **Co změnit:**
  - Oddělit vizuální atmosféru Multiplayer Hubu / Match Roomu od hlavního menu (jiná nálada a barevná paleta než klasické Lobby, přesto v jednotném woodcut/krčmovém stylu LIALO).
  - Přidat **živou animaci pozadí** za MP panelem (nízký kontrast a jemné ztmavení pod textem, aby nebrala čitelnost):
    - mihotající se louče / lucerny po stranách sálu,
    - pomalu stoupající kouř a žhavé uhlíky,
    - lehce se vlnící duelantské prapory / erby a decentní pohyb karet se zkříženými meči v hloubce pozadí.

---

### 4. Arzenál (Collection & Deck Builder) — živé animované pozadí s ohněm a magií
- **Soubory:**
  - `scripts/downpour_root.gd` (`arsenal_layer` / `deck_modal`, ř. `2121–2145`)
  - `scripts/ui/deck_builder_panel.gd` (`_bg_fx`, `_draw_animated_bg`, ř. `159–179`)
- **Co změnit:**
  - Nahradit fádní tmavé pozadí Arzenálu (ve všech záložkách sbírky i v Deck Builderu) živou **ohnivě-magickou atmosférou**:
    - **Hořící oheň / výheň kovárny:** animované plameny u spodní hrany a v rozích (shader nebo vrstvená 2D woodcut animace), teplé dýchající světlo výhně, stoupající žhavé jiskry a jemný kouř.
    - **Magie a kouzla:** pomalu rotující arkánové runové kruhy v pozadí, plovoucí azurovo-zlaté magické prachové částice a jemné magické záblesky při najetí nebo přepnutí karet.

---

### 5. Kampaň — Živý příběh, progresivní tutoriály, vícefázoví Bossové & krátké komiksové cutscény
- **Kompletní návrh a scénář (12 komiksových scén + boss fáze + tutoriály):** [`docs/CAMPAIGN_STORY_PLAN.md`](docs/CAMPAIGN_STORY_PLAN.md)
- **Dotčené soubory:**
  - Nové: `scripts/campaign/campaign_story_data.gd`, `scripts/ui/comic_cutscene_player.gd`, vrstvy v `assets/story/comics/` (s procedurálním ink fallbackem pro okamžité testování)
  - Integrace: `scripts/lialo_catalog.gd` (`seen_comics`, `completed_micro_tutorials`), `scripts/downpour_root.gd`, `scripts/battle_table_3d.gd`, `scripts/ui/dev_asset_inspector.gd`
- **Co udělat:**
  - **Hlavní příběh (*Pět pečetí Krčmy Úroboru*):** 5-aktový příběh s **Spirko – duchem krčmáře** napříč epochami (`antika` -> `rim` -> `stredovek` s mid-game twistem o Spirkově prokletí -> `objavy` -> `prohibicia` finále proti Al Caponovi a odemčení Endless režimu).
  - **Progresivní tutoriály přímo v kampani:** Zachovat úvodní 7-krokový Prologue duel (`battle_table_3d.gd`) pro základy + přidat **5 krátkých Spirkových mikro-tutoriálů** v `Stage 0/1` každé éry (Era 1: modifikátory & `NORMAL` zlaťáky/Bazar; Era 2: `KNIGHT` 3dílný štít & Deck Builder; Era 3: Grand Seal & Shield-Pierce Critical; Era 4: 3D Relikvie & `SHIFTING_WINDS`; Era 5: taktické finále bez držení za ruku).
  - **5 vícefázových Story Bossů (nad `Catalog.ERA_STAGES`):** Každý ze 5 bossů (Ramesse, Caesar, Karel IV., Královna Anna, Al Capone) má vlastní stolní rekvizitu a **Phase 2 probuzení při `<= 50 %` HP nebo `>= 60 %` Kalicha** (Capone navíc Phase 3 Climax s červeným reflektorem a nouzovým nabitím Grand Sealu).
  - **Animované krátké komiksové cutscény (`ComicCutscenePlayer`):** 3–4 woodcut-ink panely na scénu (`8–15 s`, přeskočitelné přes `SPACE`/`ESC`/klik) s **2.5D Ken Burns paralaxem**, sekvenčním inkoustovým zobrazením panelů, bublinami s písmem `LialoQuill`/`LialoBody`, komiksovými výbuchy (`CRACK!`, `SHING!`, `SLAM!`) a vrstvou počasí (písek, jiskry, déšť, blesky, doutníkový kouř) + **Chronicle Replay** galerie a náhled všech 12 scén v **`F9` Dev Inspectoru**.

---

## ★ HLAVNÍ PRIORITA #0: Hand-Drawn ~4.2s animace pro zbývající Power Cards (4 / 15 hotovo)

> Poznámka: Všech zbývajících **11 Power Cards** už tvořit v jednotném **hybridním 2.5D woodcut-ink stylu** podle úkolu #1 výše (kompromis mezi epickou siluetou a ruční kresbou, bez laciného „plastického 3D“ vzhledu).

- **Hotové referenční animace (`scripts/battle/power_card_vfx_showcase.gd`):**
  - `SPEC_STORM`, `SPEC_VAMPIRE`, `SPEC_PHOENIX`, `SPEC_CHRONOS` — všechny 4 jsou připnuté nahoře v Lobby Dev Inspectoru (`F9`) v pohledu 1. osoby (~4.2 s, kreslený woodcut inkoustový styl) a zapojené v `BattleTable3D`.
- **Zbývajících 11 Power Cards k dodělání:**
  1. `SPEC_MIRROR` — praskající zrcadlová brána před soupeřem, zdvojení odrazu zahrané karty.
  2. `SPEC_ALCHEMIST` — zlatý transmutační kruh, bublající alchymistická baňka, zlatý déšť jisker nad rukou.
  3. `SPEC_ORACLE` — obří otvírající se třetí oko nad stolem, runové paprsky odkrývající karty soupeře.
  4. `SPEC_MIDAS` — exploze zlatých mincí a krystalizace soupeřovy strany stolu ve zlato.
  5. `SPEC_JESTER` — chaotický vír karet a masek, zdvojený výboj na všechny relikvie na stole.
  6. `SPEC_HEX` — fialové stíny a inkoustové řetězy svazující soupeře + voodoo jehly.
  7. `SPEC_MAGNET` — magnetický vír přitahující karty z balíčku v zářících obloucích do ruky hráče.
  8. `SPEC_SHIELD` — masivní železná bašta a dva rotující runové štíty obklopující hráče.
  9. `SPEC_GAMBLER` — obří zlaté kostky letící přes stůl s jiskrami multiplikátoru `×2 / ×3`.
  10. `SPEC_PLAGUE` — mrazivá vánice, ledové krystaly vyrůstající kolem soupeře a zamrznutí tahu.
  11. `SPEC_CROWN` — sestoupení levitující zlaté koruny se svatozáří paprsků pro každou figuru v ruce.

---

## ★ PRIORITA #6: Kompletní Hand-Drawn ("Kreslený") 3D Rework všech Relikvií & 3D Textur
- **Schválený referenční etalon:** **`TRELIC_WAR_HORN` (Tavern Ale Tankard / Krčmový korbel piva)** s bublající pěnou!
  - Generátor & textura pipeline: [`tools/generate_tankard_relic.py`](tools/generate_tankard_relic.py) -> [`assets/models/relics/TRELIC_WAR_HORN.glb`](assets/models/relics/TRELIC_WAR_HORN.glb) + [`assets/textures/relics/tankard_*.png`](assets/textures/relics/)
  - Shader & inkoustové obrysy: [`shaders/handdrawn_relic_3d.gdshader`](shaders/handdrawn_relic_3d.gdshader) + [`shaders/handdrawn_outline_3d.gdshader`](shaders/handdrawn_outline_3d.gdshader)
  - Živý bublací efekt: [`scripts/battle/tankard_bubbles_fx.gd`](scripts/battle/tankard_bubbles_fx.gd) (`TankardBubblesFx`)
  - Vizuální GPU kontrola: [`tools/capture_relic_screenshot.gd`](tools/capture_relic_screenshot.gd)
- **Detailní plán pro zbývajících 9 relikvií + 3D meče, stolní rekvizity a textury stolu:** [`docs/HANDDRAWN_3D_REWORK_PLAN.md`](docs/HANDDRAWN_3D_REWORK_PLAN.md)
- **Norma, kterou musí splnit každá další 3D relikvie a textura:**
  1. Vysoce detailní model (cca 6 000–12 000 trojúhelníků v `.glb`, zkosené hrany, nýty, rýhy, vyhlazené normály přes UV švy, zapečené vertex AO `COLOR_0` v prohlubních).
  2. Ručně kreslené 1024×1024 textury v `assets/textures/relics/` s inkoustovými konturami a šrafováním.
  3. Materiály výhradně přes `handdrawn_relic_3d.gdshader` + `handdrawn_outline_3d.gdshader` + sjednocený podstavec přes `_apply_handdrawn_coaster`.
  4. Každá relikvie musí mít vlastní živý kreslený 3D FX skript (kostky jiskří, runa točí úlomky, hodiny sypou písek, zvonec se houpe s mlhou, kadidelnice kouří, fénix sype pírka).
  5. Povinná vizuální kontrola vícepohledového GPU screenshotu před dokončením.

---

### 🔧 Zbývající build úkol
1. **Export Windows buildu (`build/windows/LIALO.exe`):** Po doladění finálních animací a relikvií vyexportovat `.exe`.
