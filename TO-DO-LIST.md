# LIALO — Sdílený To-Do List (v0.196 Plán pro kolegu)

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

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

## Kontrola & případné úpravy relikvií (Návrh z v0.195)
- `RelicMeshFactory` a `Catalog.TABLE_RELICS` byly přepracovány na ručně kreslené woodcut 3D stolní relikvie (`Tavern Ale Tankard`, `Loaded Bone Dice`, `Arcane Slate Rune`, `Crimson Blood Goblet`, `Executioner's Whetstone`, `Fate Hourglass`, `Guild Coin Purse`, `Graveyard Toll Bell`, `Alchemist's Ember Censer`, `Phoenix Ember Reliquary`).
- Po kontrole ve hře / v `F9` Dev Inspectoru upravit tvary, barvy nebo efekty podle zpětné vazby.

---

### 🔧 Zbývající build úkol
1. **Export Windows buildu (`build/windows/LIALO.exe`):** Po doladění finálních animací a relikvií vyexportovat `.exe`.
