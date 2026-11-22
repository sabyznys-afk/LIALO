# LIALO — Kompletní Design Dokument Tutoriálu (Visual Redesign 2.0)

> **Status dokumentu:** Produkční návrh (Design Specification — Task #10)  
> **Cílová scéna & skripty:** `scripts/battle_table_3d.gd`, `scripts/heartbeat_hp_display.gd`, `scripts/cinematic_director.gd`, `scripts/cinematic_profiles.gd`, `scripts/lobby_options_3d.gd`, `scripts/scoring_engine.gd`, `scripts/lialo_catalog.gd`  
> **Celková délka (Pacing):** ~3,5 minuty (7 interaktivních kapitol + úvodní přivítání Krok 0)  
> **Hlavní průvodce:** 3D Krčmový Duch **„Spirko"** (`tutorial_ghost_3d`)

---

## 1. Přehled & Cíle tutoriálu

### 1.1 Filozofie: „Learning-by-Doing" s Krčmovým Duchem (Zero Wall-of-Text)
Tutoriál v **LIALO** opouští statické textové manuály a vyskakovací 2D okna. Hráč sedí přímo u svíčkami osvětleného 3D dubového stolu v deštivé noční krčmě (`BattleTable3D`) a učí se hru výhradně **vlastní akcí** pod vedením plně 3D animovaného Krčmového Ducha **Spirka** (`tutorial_ghost_3d` — skulptovaná lebka `ghost_skull.glb`, klapající čelist `ghost_jaw.glb`, průsvitná fresnelová kápě `ghost_shroud.glb` a kovaná lucerna `ghost_lantern.glb`).

* **Pravidlo 2 řádků (Zero Wall-of-Text):** Každá replika Ducha v centrálním pergamenovém štítku (`tutorial_ghost_center_panel`) má maximálně **2 krátké řádky** (1 věta kontextu + 1 jasný `ÚKOL:` / `TASK:`). Text se vypisuje živým efektem psaní brkem (`_start_handwriting_anim`, rychlost `44–54 znaků/s`) doprovázeným hlasovým formantovým pípáním (`sfx_ghost_speak`).
* **Okamžitá 3D odezva (`_trigger_ghost_ok_flash`):** Jakmile hráč splní úkol kroku, Duch Spirko vyšle smaragdový výboj částic (`Fx.burst`), nad hlavou mu vyskočí 3D nápis `"✓ OK!"` (`Color(0.42, 1.0, 0.66)`) a plynule odemkne další vrstvu stolu.
* **Progresivní odkrývání HUDu a 3D stolu (`_apply_staged_tutorial_state`):** Na začátku tutoriálu nejsou na obrazovce žádné rušivé prvky. Skóre, Kalich, 3D Srdce, Zápisník rovnic, 3D Meč, Ohnivá baňka `IGNIS` i Relikvie se zhmotňují postupně s magickými efekty (`_reveal_points_and_score_magic`, `_reveal_abilities_magic`, `_reveal_combo_hud_magic`, `_reveal_puf_bottle_magic`) přesně ve chvíli, kdy je hráč poprvé použije.

### 1.2 Klíčové pilíře Visual Redesignu integrované do tutoriálu
1. **Přepínání pohledu `[Tab]` / `[Space]` (`CameraViewMode` — Task #8):** Samostatný interaktivní krok učí hráče přepínat mezi **Kartami v ruce (`HAND_VIEW`)** a **3D Předměty na stole (`TABLE_ITEMS_VIEW`)**, aby si mohl zblízka prohlédnout a nakliknout hero modely Meče (`sword_oath.glb`), Korbelu (`tavern_mug.glb`), Baňky pekelného ohně (`phial_ignis.glb`) a Relikvií.
2. **Diegetická sázka (Wager) na 3D stole & Samostatné Veto (`[V]`) před 1. tahem (Task #7):** Žádné 2D sázkové okno! Hráč se učí vsadit Zlaťáky (`GOLD`), Ohnivou baňku (`ITEM`) nebo Krvavou přísahu Meče (`SWORD`) **přímo kliknutím na 3D předměty na stole**, sledovat kompaktní HUD indikátor sázky a využít samostatnou pilulku **Veto** (`⚖ Vetovat karty [V]` / `🏳 Vetovat hru`) před odehráním 1. tahu.
3. **Nový 3D animovaný systém životů (`HeartbeatHpDisplay` — Task #4):** Hráč i soupeř mají vlastní 3D skulptované bijící srdce (`heart_standard.glb`, `10 / 10 ♥ HP`). Tutoriál prakticky předvede poškození do srdcí přes **Krále (`K`, 1–3 ♥ HP)** a **Esa (`E`, 1/4/6 ♥ HP za 1/2/3 Esa)**, zrychlení srdečního tepu (`64 BPM → 98 BPM → 152–175 BPM`), žhnoucí praskliny (`CrackVeins`) jako varování před smrtí a **předznamená obří okované Boss Srdce (`heart_boss.glb`)**.
4. **Plné dramatické 2.5–4.0s cutscény (`CinematicDirector` — Task #9):** Skriptované vyvrcholení předvede plnou filmovou cutscénu při zahrání **Speciální Mocné Karty (`SPEC_VAMPIRE`)** i dramatickou **cutscénu tahu soupeře** s 3D modelem středověkého soupeře (`opp_stredovek.glb`) a jeho artikulovanými pivoty (`TorsoPivot`, `HeadPivot`, `ArmLPivot`, `ArmRPivot`, `EyeL`, `EyeR`).
5. **Čistý katalog aktivních předmětů (Clean Item Roster — Task #6):** Tutoriál využívá výhradně aktivní, plně podporované karty a relikvie:
   * **Speciální karty:** `SPEC_VAMPIRE` (*Upíří pijavice*), `SPEC_STORM` (*Úder blesku*), `SPEC_PHOENIX` (*Fénix z popela*), `SPEC_MIDAS` (*Midasův dotek*).
   * **Relikvie:** `REL_GREED` (*Kupecké váhy*), `REL_FANG` (*Rudý tesák*), `REL_ALEMBIC` (*Alchymistická baňka*).
6. **Spuštění z 3D Pracovny nastavení (`LobbyOptions3D` — Task #2):** Tutoriál se spouští automaticky při první bitvě (`tutorial_done == false`), z dřevěného štítu **TUTORIÁL** v hlavním menu, nebo kdykoliv tlačítkem **„Zopakovat Tutoriál" (`Replay Tutorial`)** přímo z 3D dubového stolu nastavení (`LobbyOptions3D`).

### 1.3 Časový rozpočet (Pacing ~3,5 minuty)

| Krok | Název kapitoly | Odhadovaný čas | Hlavní vyučovaná mechanika |
| :--- | :--- | :---: | :--- |
| **Krok 0** | Přivítání u Krčmového Ducha | `0:00 – 0:20` | 3D Duch Spirko, atmosféra krčmy, potvrzení `[Space]` / `[Tab]` |
| **Krok 1** | Pohled na stůl `[Tab]/[Space]`, 3D Sázka & Veto `[V]` | `0:20 – 0:55` | Samostatné Veto `[V]`, přepnutí na 3D stůl, klik na 3D Meč/Baňku pro sázku |
| **Krok 2** | Základ Prší & Párové bodování Kalicha | `0:55 – 1:25` | Shoda Barvy/Hodnoty, odhození karty (`[LMB]`/`[W]`), párový zápis do Kalicha |
| **Krok 3** | Útok Sedmičkou (`7`) & 3× Past (+21 b.) | `1:25 – 2:00` | Schopnost `7` (+2 karty soupeři, 3× body při lízání), Svršek (`H` = změna barvy) |
| **Krok 4** | Řetězení Osmiček (`8 ∞`) & Vzorec Komba | `2:00 – 2:35` | Označení komba `[RMB]`, pravidlo řetězení (`8 ∞` / `max 3 Esa`), `Chips × +Mult × ×Mult` |
| **Krok 5** | 3D Bijící Srdce (`HeartbeatHpDisplay`) & Úder Es | `2:35 – 3:10` | 3D Srdce (`10 ♥ HP`), Král (`1–3 HP`), 2× Eso (`-4 ♥ HP` + Stopka), praskliny & Boss Srdce |
| **Krok 6** | Filmová Cutscéna Speciální Karty & Baňka `IGNIS` | `3:10 – 3:40` | 3s cutscéna `SPEC_VAMPIRE`, aktivní relikvie (`REL_GREED`, `REL_FANG`), hod 3D Baňkou `IGNIS` |
| **Krok 7** | Vyprázdnění ruky (Finisher) & Poprava Mečem | `3:40 – 4:00` | Dohrání poslední karty (`0 v ruce`), bonus `+120 & ×2.0+`, Kupecký zvonec, poprava Mečem |

---

## 2. Kompletní struktura kroků (Krok 0 až Krok 7)

### 2.1 Souhrnná matice kroků tutoriálu

| Krok | Cíl kroku | Stav stolu & Kamery | Skriptovaná ruka hráče (`player_hand`) | Skriptovaná ruka soupeře (`ai_hand`) | Povolené akce | Podmínka přechodu | UI & 3D Zvýraznění |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **0** | Seznámení s 3D Duchem Spirkem a ovládáním dialogu | `GHOST_CLOSEUP`<br>Stůl zhasnutý, ruka dole (`cards_tucked = true`), svítí jen 3D Duch | Rozdána na pozadí (skrytá):<br>`[ZELEN_9, ZALUD_D, GULA_9, ZELEN_10, ZALUD_10]` | Skrytá (5 karet):<br>`[ZALUD_8, GULA_9, ZELEN_10, ZALUD_K, GULA_K]` | `[Space]`, `[Tab]`, klik na `tutorial_continue_btn`, `tutorial_skip_btn` | Stisk `[Space]` / `[Tab]` nebo klik na tlačítko **„Jdeme na to [SPACE] ▸"** | 3D Duch Spirko (`tutorial_ghost_3d`) s tyrkysovou aurou, animace brka v `tutorial_ghost_center_panel` |
| **1** | Naučit samostatné Veto `[V]`, přepínání pohledu `[Tab]`/`[Space]` a 3D volbu sázky klikem na Meč/Mince/Baňku | **1a:** `HAND_VIEW` (nevhodná ruka + Veto pilulka)<br>**1b:** `TABLE_ITEMS_VIEW` (detail 3D stolu)<br>**1c:** `HAND_VIEW` | **Před Vetem:**<br>`[ZELEN_9, ZALUD_D, GULA_9, ZELEN_10, ZALUD_10]`<br>**Po Vetu `[V]`:**<br>`[CERVEN_10, CERVEN_H, CERVEN_7, CERVEN_8, ZELEN_8]` | `[ZALUD_8, GULA_9, ZELEN_10, ZALUD_K, GULA_K]`<br>Vrchní karta stolu: `CERVEN_9` (`♥ 9`) | **1a:** `[V]` nebo klik na `wager_veto_hand_btn`<br>**1b:** `[Tab]`/`[Space]` nebo `quick_peek_btn`, klik na 3D Meč/Mince/Baňku<br>**1c:** `[Tab]`/`[Space]` zpět na karty | `opening_veto_used == true` **A** kliknuto na 3D sázkový předmět (`_tutorial_action_done == "wager_staked"`) **A** návrat do `HAND_VIEW` | Pulzující azurový okraj okolo `wager_veto_hand_btn`, poté `tutorial_beacon_mesh` nad 3D Mečem (`player_sword_root`) a 3D Měšcem (`tavern_coins_root`), `wager_3d_ring` |
| **2** | Základ Prší (shoda Barvy či Hodnoty) a párový zápis skóre | `HAND_VIEW`<br>Vrchní karta: `CERVEN_9` (`♥ 9`, aktivní barva `CERVEN ♥`) | `[CERVEN_10, CERVEN_H, CERVEN_7, CERVEN_8, ZELEN_8]` | `[ZALUD_8, GULA_9, ZELEN_10, ZALUD_K, GULA_K]`<br>(Soupeř odpoví `GULA_9` na `CERVEN_10` nebo lízne) | Klik/tah `[LMB]` nebo `[W]` na `CERVEN_10` (`♥ 10`) | Hráč zahraje `CERVEN_10`, soupeř odehraje svůj tah a proběhne `_resolve_turn_pair_scoring_fx` | Smaragdově svítící okraj (`Color(0.32, 0.96, 0.62)`) na `CERVEN_10`, zhmotnění Kalicha (`player_hud_grp`) |
| **3** | Útok Sedmičkou (`7` = `+2 karty` a `3× body = 21 b.` když soupeř líže) | `HAND_VIEW`<br>Vrchní karta: `CERVEN_10` (`♥ 10`), skóre odhaleno (`cards_points_revealed = true`) | `[CERVEN_H, CERVEN_7, CERVEN_8, ZELEN_8]`<br>(Vršek balíčku připraven: `CERVEN_10`, `GULA_8`) | `[ZALUD_8, GULA_9, ZELEN_10, ZALUD_K, GULA_K]`<br>(Garantováno 0 sedmiček přes `_ensure_tutorial_seven_setup`) | Klik/tah `[LMB]` nebo `[W]` na `CERVEN_7` (`♥ 7`) | `_tutorial_action_done == "played_seven"` + soupeř lízne `+2 karty` a spustí se `7 × 3 = +21 b.` | Tyrkysově svítící okraj (`Color(0.28, 0.92, 1.0)`) na `CERVEN_7`, animace `PtsLabel` a `AbilityLabel`, pulzující `pending_seven_banner_pill` |
| **4** | Řetězení Osmiček (`8 ∞`) do 2× Komba pravým klikem `[RMB]` & vzorec `Chips × +Mult × ×Mult` | `HAND_VIEW`<br>Aktivní barva: `CERVEN ♥`, zhmotněn Zápisník rovnic (`combo_hud_grp`) | `[CERVEN_H, CERVEN_8, ZELEN_8]` | `[ZALUD_8, GULA_9, ZELEN_10, ZALUD_K, GULA_K, ...]` | `[RMB]` (nebo klik) na obě Osmičky (`CERVEN_8` + `ZELEN_8`) a odpálení přes `stack_action_btn` nebo `[W]` | `_tutorial_action_done == "slammed_combo"` (`staged_card_indices.size() == 2`, obě `rank == "8"`) | Zlatý/azurový okraj na obou `8`, blesk `⚡` nad označenými kartami, živý přepočet `84 b. × 1.8× × 1.25 = +189 b.` v `combo_hud_grp` |
| **5** | 3D Bijící Srdce (`HeartbeatHpDisplay`), útok Králem/Esy, žhnoucí praskliny & náhled Boss Srdce | `HAND_VIEW` + `CINEMATIC_LOCK` (cutscéna soupeřova Krále)<br>Hráč: `10/10 → 8/10 ♥ HP`<br>Soupeř: `10/10 → 6/10 ♥ HP` | Skriptované doplnění pro krok 5:<br>`[CERVEN_E, ZELEN_E, SPEC_VAMPIRE, CERVEN_10]` | Soupeř v cutscéně zahraje `CERVEN_K` (`♥ Král`, `-2 ♥ HP` hráči), v ruce mu zůstávají `[ZALUD_9, GULA_D, ZELEN_10]` | Označení obou Es (`CERVEN_E` + `ZELEN_E`) přes `[RMB]`/`[LMB]` a odpálení 2× Eso Komba (`[W]`) | Hráč odehraje 2× Eso (`ace_hp_damage = 4`), soupeřovo 3D srdce klesne o `-4 ♥ HP` a zrychlí tep | Zhmotnění 3D `HeartbeatHpDisplay` pro hráče i soupeře, animace `DamageHit`, rozžhavení `CrackVeins`, 2s ukázka `heart_boss.glb` |
| **6** | Plná 3s filmová cutscéna Speciální Karty (`SPEC_VAMPIRE`), Relikvie & hod 3D Baňkou `IGNIS` | `HAND_VIEW` → `CINEMATIC_LOCK` (`SPEC_VAMPIRE`) → `TABLE_ITEMS_VIEW` (hod 3D Baňkou `IGNIS`) | `[SPEC_VAMPIRE, CERVEN_10]`<br>Aktivní relikvie na stole: `REL_GREED`, `REL_FANG`, `REL_ALEMBIC` | `[ZALUD_9, GULA_D, ZELEN_10]` (Omráčen Esem / Hoří 3 kola) | **6a:** Zahrát `SPEC_VAMPIRE`<br>**6b:** Kliknout na 3D Baňku `magic_puf_bottle` (přímo nebo po `[Tab]`/`[Space]`) | Odehrána `SPEC_VAMPIRE` (cutscéna dokončena) **A** hozena 3D Baňka pekelného ohně (`rival_burn_turns == 3`) | Karmínová záře `SPEC_VAMPIRE`, 3D cutscéna `cinematic_vampire_crimson.glb`, poté `tutorial_beacon_mesh` nad 3D Baňkou `magic_puf_bottle` |
| **7** | Vyprázdnění ruky на 0 karet (Shedding Finisher), Kupcův zvonec & Vítězná poprava Mečem | `HAND_VIEW` → `CINEMATIC_LOCK` (`_play_sword_execution_finisher(true)`) | Poslední karta v ruce:<br>`[CERVEN_10]` (`♥ Desítka`) | `[ZALUD_9, GULA_D, ZELEN_10]` | Zahrát poslední kartu `CERVEN_10` (`[LMB]` nebo `[W]`), poté klik na **„Hrát naplno! ▸"** (`[Space]`) | `player_hand.is_empty() == true` → spuštění Shedding Finisheru a přechod na vítězný stav (`step = 7/Won`) | Zlatá záře poslední karty, výbuch `★ SHEDDING FINISHER +120 & ×2.44!`, 4.3s animace popravy Mečem, vítězný panel Ducha |

---

### 2.2 Detailní rozpis mechanik a matematiky v jednotlivých krocích

#### Krok 0: Přivítání u stolu (`step == 0`)
* **Výchozí stav:** `tutorial_mode = true`, `tutorial_step = 0`, `cards_tucked = true`. Kamera míří v polodetailu na 3D Ducha Spirka po levici hráče (`Vector3(-0.32, 1.50, 0.76)`, rotace `Vector3(1.0, 44.0, 0.0)`, `fov = 50.0`).
* **Skryté prvky:** `player_hud_grp`, `rival_hud_grp`, `combo_hud_grp`, `draw_deck_root`, `discard_pile_root`, `magic_puf_bottle` i `tavern_bell_root` jsou zatím neviditelné, aby se hráč soustředil výhradně na 3D Ducha a jeho první větu.

#### Krok 1: Samostatné Veto `[V]`, Přepnutí pohledu `[Tab]`/`[Space]` & 3D Sázka (`step == 1`)
Tento krok je rozdělen na tři plynulé podkroky (`tutorial_substep` `0 → 1 → 2`), které hráče naučí kompletní předzápasovou přípravu bez jediného vyskakovacího okna:
1. **Podkrok 1a — Samostatná pilulka Veto (`tutorial_substep == 0`):**
   * Kamera přejde do `HAND_VIEW` (`Vector3(0.0, 1.64, 1.48)`). Hráč drží úvodních 5 karet (`ZELEN_9`, `ZALUD_D`, `GULA_9`, `ZELEN_10`, `ZALUD_10`), zatímco na stole leží `CERVEN_9` (`♥ Devítka`).
   * Pod levým horním rohem svítí samostatná pilulka **Veto** s tlačítky `⚖ Vetovat karty [V]` (`wager_veto_hand_btn`) a `🏳 Vetovat hru` (`wager_veto_duel_btn`).
   * Duch vysvětlí, že před 1. tahem lze jednou vetovat špatnou ruku (`[V]`) nebo celý duel odmítnout. Hráč stiskne `[V]` (nebo klikne na `⚖ Vetovat karty [V]`), zavolá se `_perform_opening_veto_hand()` (v tutoriálu odemčeno pro `tutorial_step == 1 && tutorial_substep == 0`) a hráči se rozdá skriptovaná ruka: `CERVEN_10`, `CERVEN_H`, `CERVEN_7`, `CERVEN_8`, `ZELEN_8` proti `CERVEN_9` na stole.
2. **Podkrok 1b — Přepnutí na 3D Předměty na stole `[Tab]` / `[Space]` a volba 3D Sázky (`tutorial_substep == 1`):**
   * Duch vyzve hráče, aby stiskl `[Tab]` nebo `[Space]` (případně kliknul na dolní středové tlačítko `POHLED STŮL [TAB / SPACE]`).
   * Karty se zasunou (`cards_tucked = true`, `HAND_POS_TUCKED`) a kamera se zvedne do přehledného pohledu na 3D stůl (`TABLE_ITEMS_VIEW`, `Vector3(0.0, 1.72, 1.48)`, `fov = 61.0`).
   * Na stole se rozsvítí hero 3D modely: **Meč přísahy** (`player_sword_root` / `sword_oath.glb`), **Korbel medoviny** (`tavern_mug_root` / `tavern_mug.glb`), **Baňka pekelného ohně** (`magic_puf_bottle` / `phial_ignis.glb`) a **Měšec florinů** (`tavern_coins_root` / `coins_pouch.glb`).
   * Při najetí myší se každý 3D předmět fyzicky vznese o `+0.075 m` a zobrazí informační štítek `prop_hover_pill`.
   * Kliknutím přímo na **3D Meč** (`SwordArea`), **3D Baňku** (`MagicPufArea`) nebo **3D Měšec** (`TavernCoinsArea`) hráč zvolí sázku duelu (`set_duel_wager("SWORD" / "ITEM" / "GOLD")`). Při kliknutí na 3D Meč se čepel přesune do bojové pozice `Vector3(-0.34, 0.832, 0.14)` s rudým pulzujícím prstencem `wager_3d_ring` a v kompaktním HUD indikátoru se rozsvítí `⚔ SWORD (+100g)`.
3. **Podkrok 1c — Návrat ke kartám v ruce (`tutorial_substep == 2`):**
   * Hráč znovu stiskne `[Tab]` nebo `[Space]` (nebo klikne na `POHLED KARTY [TAB / SPACE]`), 3D ruka se vlnou vrátí nahoru (`_animate_hand_return_wave()`) a tutoriál postoupí do `Kroku 2`.

#### Krok 2: Základní Prší & Párové bodování (`step == 2`)
* **Stav stolu:** Na odhazovací hromádce leží `CERVEN_9` (`♥ Devítka`, aktivní barva `CERVEN`).
* **Matematika tahu (`ScoringEngine.calculate_hand_score`):**
  * Hráč zahraje `CERVEN_10` (`♥ Desítka`, základ `10 Chips`).
  * `Single Strike` / `Tah kartou` (`cnt = 1`): `base_chips = 12`, `flat_mult = 1.0`.
  * Celkem za kartu v kroku 2 (před odemčením pokročilých schopností v kroku 3+): `(12 + 10) × 1.0 = +22 bodů` připravených v Zápisníku (`pending_player_exchange_pts = 22`).
  * Soupeř odehraje `GULA_9` (`● Devítka`, `+9 bodů`, `pending_ai_exchange_pts = 9`).
  * Okamžitě po tahu soupeře se spustí `_resolve_turn_pair_scoring_fx`: z obou stran vyletí světelné orby do Kalicha (`score_chalice_art`), zapíše se rovnice a Kalich stoupne na další stupeň nabití.

#### Krok 3: Útočná Sedmička (`7`) & 3× Past (`step == 3`)
* **Odhalení bodů a schopností:** Spustí se `_reveal_points_and_score_magic()` a `_reveal_abilities_magic()`. Na všech 3D kartách v ruce vyskočí zlaté štítky bodů (`PtsLabel`) a barevné odznaky schopností (`AbilityPillMesh` + `AbilityLabel`).
* **Garantovaný stav (`_ensure_tutorial_seven_setup`):** V ruce hráče svítí hratelná `CERVEN_7` (`♥ Sedma`, odznak `⚡ +2 LÍZÁNÍ (3×)`). Ze soupeřovy ruky jsou případné sedmičky nahrazeny devítkami, aby soupeř garantovaně nemohl přebít.
* **Matematika tahu:**
  * Hráč zahraje `CERVEN_7`: `base_chips = 12`, `card_chips = 7`, `PRSI_7_CHIPS = +7`, `PRSI_7_MULT = +0.4×` → `26 Chips × 1.4 Mult = 36 bodů` + aktivuje se past `pending_draw = 2` a `pending_seven_trap_bonus = 14`.
  * Vlevo se rozsvítí `pending_seven_banner_pill`: `"🃏 SEDMA NA STOLE: +7 BODŮ (Čeká na soupeře...)"`.
  * Soupeř nemá `7`, takže musí líznout `+2 karty` z balíčku! Past sklapne: `pending_seven_banner_pill` se přepne na zelený nápis `"⚡ 7 × 3 = +21 BODŮ! (Soupeř lízal +2!)"` a hráči se přičte dalších `+14 bodů` (celkem `50 bodů` za jediný tah Sedmičkou!).

#### Krok 4: Řetězení Osmiček (`8 ∞`) & Balatro Kombo (`step == 4`)
* **Odhalení Zápisníku rovnic (`_reveal_combo_hud_magic`):** Zhmotní se `combo_hud_grp` ukazující tříúrovňový vzorec `Body (Chips) × +Násobič (Flat Mult) × ×Násobič (X-Mult)`.
* **Zákon řetězení (Chain Law):** Duch zdůrazní klíčové pravidlo LIALO — **skládat více karet najednou lze pouze u Osmiček (`8 ∞`, v libovolném počtu) nebo u Es (`E`, max. 3 Esa najednou)**.
* **Akce hráče:** Hráč pravým tlačítkem myši `[RMB]` (nebo levým klikem v kombo režimu) označí obě Osmičky v ruce: `CERVEN_8` (`♥ Osma`) a `ZELEN_8` (`♠ Osma`).
* **Matematika 2× Osmičkového komba (`ScoringEngine`):**
  * `Dvojkombo` / `Pair Slam` (`cnt = 2`): `SLAM_BASE_CHIPS[2] = 36`, `SLAM_BASE_MULT[2] = 1.8×`.
  * Karty: `CERVEN_8` (`+8 b.`) + `ZELEN_8` (`+8 b.`) → `chips = 52`.
  * Schopnost `∞ Řetěz Osmiček!` (`eights_played = 2`): `e_chips = 16 × 2 = +32 b.`, `e_x = ×1.25 X-Mult`.
  * Výsledná rovnice: `(36 + 8 + 8 + 32) Chips × 1.8 Mult × 1.25 X-Mult = 84 × 1.8 × 1.25 = +189 bodů`!
  * Při odpálení (`[W]` nebo klik na `⚡ DVOJKOMBO (2× • ×2.3) +189 [W]`) se uprostřed stolu zhmotní 3D Astroláb (`scoring_astrolabe_stage.glb`), udeří 3D blesk a do Kalicha nalétají 3D žetony `Token_ChipCoin`, `Token_MultSigil` a `Token_ScoreCrown`.

#### Krok 5: 3D Animovaná Srdce (`HeartbeatHpDisplay`), Král, Esa & Předzvěst Boss Srdce (`step == 5`)
* **Zhmotnění 3D Srdcí:** V levém i pravém křídle HUDu se rozsvítí 3D widgety `HeartbeatHpDisplay` (`heart_standard.glb`, `10 / 10 ♥ HP`, klidový tep `64 BPM`, animace `Heartbeat`).
* **Dramatická cutscéna útoku soupeře Králem (`CinematicDirector.play_rival_turn_cinematic`):**
  * Soupeř (3D model středověkého zbrojnoše `opp_stredovek.glb`) zahraje v 2.8s dramatické cutscéně kartu `CERVEN_K` (`♥ Král`).
  * Královská výzva zasáhne hráče za `-2 ♥ HP` (`_apply_hp_damage(true, 2, "👑 SOUPEŘŮV KRÁL")`).
  * 3D srdce hráče přehraje animaci `DamageHit` (`0.60s`), zatřese se, HP klesne na `8 / 10 ♥ HP` (případně při ukázce nízkého HP se rozsvítí žhnoucí praskliny `CrackVeins` a tep zrychlí na `98–152 BPM`).
* **Protiúder hráče 2× Esem (`CERVEN_E` + `ZELEN_E`):**
  * Hráč má v ruce dvě Esa: `CERVEN_E` (`♥ Eso`) a `ZELEN_E` (`♠ Eso`).
  * Duch připomene pravidlo Es: **1 Eso = 1 ♥ HP, 2 Esa = 4 ♥ HP, 3 Esa = 6 ♥ HP poškození + Stopka (zmrazení soupeře)!** (4 Esa najednou jsou zakázána).
  * Hráč označí obě Esa (`[RMB]`) a odpálí je (`[W]`):
    * Matematika: `Dvojkombo` (`36 b., 1.8×`) + `2× Eso` (`20 + 20 = 40 b.`) + `Úder Esa` (`15 × 2 = +30 b.`, `+0.8× Mult`) = `106 Chips × 2.6 Mult = +276 bodů` **A** přímý zásah **`-4 ♥ HP` do 3D srdce soupeře + Stopka na 1 tah**!
  * Soupeřovo 3D srdce klesne na nízké HP, praskliny `CrackVeins` se rozžhnou rudým plamenem a tep jeho srdce vyskočí na `152+ BPM`.
* **Předzvěst Boss Srdce (`set_boss_mode(true)`):** Duch krátce (na 2,2 s) promění soupeřovo srdce v obří okované **Boss Srdce (`heart_boss.glb`, 1,4× větší silueta v trnové železno-zlaté kleci s korunou)**, aby hráč věděl, co ho čeká v boji s Faraonem Ramessem, Caesarem či Karlem IV., a poté ho vrátí na standardní srdce.

#### Krok 6: Filmová Cutscéna Speciální Karty (`SPEC_VAMPIRE`), Relikvie & Baňka `IGNIS` (`step == 6`)
* **Podkrok 6a — Speciální karta s 3s cutscénou (`CinematicDirector.play_special_card_cinematic`):**
  * V ruce hráče svítí aktivní Speciální karta **`SPEC_VAMPIRE`** (*Upíří pijavice* / *Vampire Leech*, `suit: "CERVEN"`, `22 b.`, vysaje `15 b.` soupeři a při aktivních Srdcích násobí `×1.4 X-Mult`).
  * Na stole zároveň leží 3D aktivní relikvie **`REL_GREED`** (*Kupecké váhy*) a **`REL_FANG`** (*Rudý tesák* — každé Srdce vysaje dalších `10 b.` ze soupeře).
  * Hráč zahraje `SPEC_VAMPIRE` → spustí se **plná 3.2s dramatická cutscéna** (`cinematic_vampire_crimson.glb`):
    * **Střih 1 (0.0–1.0s):** Detailní hero nájezd na vznášející se kartu `SPEC_VAMPIRE` a rotující krvavé runy.
    * **Střih 2 (1.0–2.2s):** Nízký dramatický úhel přes stůl — z karty vyrazí rubínové tesáky a vysají životní energii ze soupeře (`TorsoPivot` a `HeadPivot` soupeře provedou `recoil_stagger`).
    * **Střih 3 (2.2–3.2s):** Dopad energie do hráčova Kalicha + aktivace relikvie `REL_FANG` (`-10 b.` soupeři) a návrat kamery.
* **Podkrok 6b — Hod 3D Baňkou pekelného ohně (`IGNIS` / `magic_puf_bottle`):**
  * Na pravé straně stolu (`Vector3(0.76, 0.815, 0.34)`) se s fialovo-ohnivou tlakovou vlnou zhmotní 3D **Baňka pekelného ohně (`hellfire_phial_hero.glb`)** se zapáleným knotem `IgnitedPlume` a kompasovým prstencem `tutorial_beacon_mesh`.
  * Hráč přepne pohled na stůl (`[Tab]` / `[Space]`) nebo klikne přímo na 3D Baňku `IGNIS`.
  * Spustí se `_activate_magic_puf_3d()` → 4.1s třífázová filmová kamera sleduje parabolický let baňky (`BlenderVfx.play_hellfire_phial_throw`), roztříštění o ruce soupeře (`hellfire_explosion_anim.glb`) a vzplanutí plamenů (`opp_fire_fx_root`, soupeř hoří 3 kola: `-14 b./tah` a `-25 % síly`).

#### Krok 7: Finále — Vyprázdnění ruky (Shedding Finisher), Kupcův zvonec & Vítězná poprava Mečem (`step == 7`)
* **Závěrečný úkol:** Hráči zbývá v ruce poslední karta `CERVEN_10` (`♥ Desítka`). Na stole se zároveň zhmotní **Kupcův mosazný zvonec (`tavern_bell_root`)**, u něhož Duch připomene, že **každé 3. kolo se otevírá Kupecký obchod s 3D artefakty a automatickým uložením Checkpointu**.
* **Akce hráče:** Hráč zahraje poslední kartu `CERVEN_10` a vyprázdní ruku na **0 karet**.
* **Shedding Finisher & Vítězná poprava Mečem:**
  * Vyprázdnění ruky spustí **`★ SHEDDING FINISHER +120 & ×2.44!`** (`SHED_BASE_CHIPS = 120`, exponenciální násobič za ušetřené tahy).
  * Protože hráč v Kroku 1 vsadil svůj 3D Meč (nebo dosáhl cílového skóre), spustí se **`_play_sword_execution_finisher(true)`** (`defeat_execution_anim.glb` — 4.3s zlatá exekuce soupeře mečem za `+100g` kořisti!).
  * Duch Spirko pogratuluje, nastaví se `game_options["tutorial_done"] = true` (`Catalog.save_options(game_options)`) a tlačítko **„Hrát naplno! ▸" (`Play Now! ▸`)** plynule převede hráče do plné hry.

---

## 3. Přesné dialogy Ducha (CZ + EN) & Systém nápověd (Nudges)

### 3.1 Hlavní dialogy v centrálním panelu (`_get_tutorial_ghost_copy`)
Tyto texty se vykreslují s efektem psaní brkem v `tutorial_ghost_center_panel` (`tutorial_ghost_center_lbl`) a doprovodném tlačítku `tutorial_continue_btn`.

```gdscript
func _get_tutorial_ghost_copy(step: int, sub: int = 0) -> Dictionary:
	match step:
		0:
			return {
				"cs": "Čau! Vítej v LIALU — krčmových karetních soubojích na život a na smrt.\nJsem Spirko, duch této krčmy, a v rychlosti tě naučím všechny triky!",
				"en": "Hey! Welcome to LIALO — high-stakes tavern card duels of wit and blade.\nI'm Spirko, the tavern ghost, and I'll teach you every trick in a flash!",
				"btn_cs": "Jdeme na to [SPACE] ▸",
				"btn_en": "Start Learning [SPACE] ▸",
				"show_btn": true,
			}
		1:
			if sub == 0:
				return {
					"cs": "Před 1. tahem můžeš 1× vyměnit špatnou ruku (Veto) nebo duel odmítnout.\nÚKOL: Stiskni [V] (nebo klikni na ⚖ Vetovat karty) pro novou ruku!",
					"en": "Before Turn 1, you can Veto a bad opening hand once or decline the duel.\nTASK: Press [V] (or click ⚖ Veto Hand) to deal 5 fresh cards!",
					"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
				}
			elif sub == 1:
				return {
					"cs": "✓ OK! Klávesou [TAB] nebo [SPACE] kdykoliv přepneš mezi Kartami a 3D Stolem.\nÚKOL: Přepni na 3D Stůl [TAB / SPACE] a klikni na svůj 3D MEČ pro sázku!",
					"en": "✓ OK! Press [TAB] or [SPACE] anytime to toggle between Cards and 3D Table Items.\nTASK: Toggle to 3D Table [TAB / SPACE] and click your 3D SWORD to stake it!",
					"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
				}
			else:
				return {
					"cs": "✓ OK! Krvavá přísaha meče je vsazena (+100g při výhře)!\nÚKOL: Stiskni znovu [TAB] nebo [SPACE] a vrať se ke svým 3D kartám v ruce!",
					"en": "✓ OK! Blood Oath Sword staked (+100g on victory)!\nTASK: Press [TAB] or [SPACE] again to return to your 3D cards in hand!",
					"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
				}
		2:
			return {
				"cs": "Základ Prší: hoď kartu stejné Barvy (♥/●/♠/♣) nebo Hodnoty na stůl.\nÚKOL: Zahraj svítící ♥ Desítku z ruky (klikem nebo klávesou [W])!",
				"en": "Core rule: match the active Suit (♥/●/♠/♣) or Rank on the discard pile.\nTASK: Play your glowing ♥ Ten from hand (click or press [W])!",
				"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
			}
		3:
			return {
				"cs": "✓ OK! Sedmička (7) nutí soupeře lízat +2 karty a dává ti 3× BODY (21 b.)!\nÚKOL: Zahraj teď svou svítící ♥ Sedmičku (7)!",
				"en": "✓ OK! Seven (7) forces Rival to draw +2 cards and scores 3× POINTS (21 pts)!\nTASK: Play your glowing ♥ Seven (7) now!",
				"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
			}
		4:
			return {
				"cs": "✓ OK! Řetězit do komba lze jen Osmičky (8 ∞) nebo max. 3 Esa najednou!\nÚKOL: Označ pravým klikem [RMB] obě Osmičky (8) a odpal 2× Kombo [W]!",
				"en": "✓ OK! Only Eights (8 ∞) or up to 3 Aces can be stacked into a Combo!\nTASK: Right-click [RMB] both Eights (8) and slam a 2× Combo [W]!",
				"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
			}
		5:
			return {
				"cs": "✓ OK! Sleduj 3D Srdce (10 ♥ HP): Král bere 1–3 HP, 1/2/3 Esa berou 1/4/6 HP!\nÚKOL: Spoj obě Esa (E) do komba — zasáhneš soupeřovo 3D srdce za -4 ♥ HP!",
				"en": "✓ OK! Watch the 3D Hearts (10 ♥ HP): King hits 1–3 HP, 1/2/3 Aces hit 1/4/6 HP!\nTASK: Stack both Aces (E) into a combo to strike Rival's 3D heart for -4 ♥ HP!",
				"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
			}
		6:
			if sub == 0:
				return {
					"cs": "✓ OK! Jeho srdce praská a zběsile buší! Teď povolej Mocnou kartu s cutscénou.\nÚKOL: Zahraj speciální kartu 🦇 Upíří pijavice (SPEC_VAMPIRE)!",
					"en": "✓ OK! Rival's heart is cracking and racing! Now unleash a Special Card cutscene.\nTASK: Play your special card 🦇 Vampire Leech (SPEC_VAMPIRE)!",
					"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
				}
			else:
				return {
					"cs": "✓ OK! Na stole ti plane 3D Baňka pekelného ohně IGNIS (stojí 20 b.).\nÚKOL: Klikni na 3D Ohnivou baňku vpravo na stole (nebo přes [TAB]) a zapal soupeře!",
					"en": "✓ OK! Your 3D Hellfire Phial IGNIS glows on the table (costs 20 pts).\nTASK: Click the 3D Hellfire Phial on the right (or via [TAB]) to set Rival on FIRE!",
					"btn_cs": "Dál", "btn_en": "Next", "show_btn": false,
				}
		7:
			return {
				"cs": "✓ OK! Soupeř je v plamenech! Obchod se zvonečkem se otevírá každé 3. kolo.\nPOSLEDNÍ ÚKOL: Vyhoď poslední kartu z ruky (0 karet = Finisher + Poprava mečem)!",
				"en": "✓ OK! Rival is burning! The Peddler's Bell opens the Shop every 3rd round.\nFINAL TASK: Play your last card to empty your hand (0 cards = Finisher + Execution)!",
				"btn_cs": "Dokončit", "btn_en": "Finish", "show_btn": false,
			}
		_:
			return {
				"cs": "✓ OK! Kolo vyhráno a soupeř popraven mečem — ovládáš celé LIALO!\n(Tutoriál si můžeš kdykoliv zopakovat z 3D pracovny Nastavení ⚙.)",
				"en": "✓ OK! Round won and Rival executed by the blade — you master all of LIALO!\n(You can replay this tutorial anytime from the 3D Study Options desk ⚙.)",
				"btn_cs": "Hrát naplno! ▸",
				"btn_en": "Play Now! ▸",
				"show_btn": true,
			}
```

### 3.2 Diegetické repliky 3D Ducha vedle stolu (`_update_tutorial_callout_ui`)
Tyto krátké ambientní průpovídky se zobrazují přímo v bezrámečkovém plovoucím textu `tutorial_ghost_speech_lbl` vedle 3D Ducha Spirka a mění barvu jeho ektoplazmové aury (`tutorial_ghost_accent`):

| Krok | Barva aury Ducha (`tutorial_ghost_accent`) | Diegetická promluva Ducha — CZ (`opts_language == "cs"`) | Diegetická promluva Ducha — EN (`opts_language == "en"`) |
| :---: | :---: | :--- | :--- |
| **0** | `Color(0.56, 0.80, 0.96)` (Ledově modrá) | `"Psst, příteli! Sedni ke stolu — ukážu ti, jak v téhle krčmě vyhrát zlato i život!"` | `"Psst, friend! Pull up a chair — I'll show you how to win gold and keep your head!"` |
| **1** | `Color(1.0, 0.84, 0.34)` (Zlatá) | `"Špatné karty na startu? Vetuj je [V]! A klávesou [TAB] nebo [SPACE] koukni na 3D předměty na stole!"` | `"Bad opening deal? Veto it [V]! And press [TAB] or [SPACE] to inspect your 3D table items up close!"` |
| **2** | `Color(0.42, 0.96, 0.72)` (Smaragdová) | `"Barva na barvu, hodnota na hodnotu! Body obou tahů se po tahu soupeře slijí do Kalicha!"` | `"Suit on Suit, Rank on Rank! Both turns settle together into your Charge Chalice!"` |
| **3** | `Color(0.36, 0.92, 1.0)` (Azurová) | `"Sedma dává +2 karty (a 3× body, když soupeř líže)! Svršek mění barvu a Spodek dává Štít!"` | `"Seven deals +2 cards (and 3× pts if they draw)! Queen shifts Suit and Jack grants a Shield!"` |
| **4** | `Color(0.98, 0.52, 0.92)` (Magická purpurová) | `"Zákon řetězení: Skládej Osmičky (∞) nebo až 3 Esa! Pravým klikem [RMB] postavíš kombo!"` | `"Chain Law: Stack Eights (∞) or up to 3 Aces! Right-click [RMB] matching cards to build a Combo!"` |
| **5** | `Color(1.0, 0.34, 0.38)` (Karmínová) | `"Sleduj 3D Srdce! Když HP klesá, tep zrychluje a praskliny žhnou. A pozor na obří Srdce Bossů!"` | `"Watch the 3D Hearts! As HP drops, the heartbeat races and cracks glow. Beware the giant Boss Heart!"` |
| **6** | `Color(1.0, 0.54, 0.22)` (Ohnivě jantarová) | `"Mocné karty spouští filmové cutscény, Relikvie na stole zesilují komba a baňka IGNIS pálí soupeře!"` | `"Special Cards trigger dramatic cutscenes, Table Relics boost combos, and the IGNIS Phial burns rivals!"` |
| **7** | `Color(1.0, 0.90, 0.42)` (Sluneční zlatá) | `"Vyhoď poslední kartu pro Finisher bonus! Zápas má 6 kol a Obchod cinkne každé 3. kolo!"` | `"Empty your hand for a Finisher bonus! Duels last 6 rounds with the Crossroads Shop every 3rd round!"` |

### 3.3 Katalog jemných nápověd při chybném kliku (`_whisper_tutorial_nudge`)
Pokud hráč během tutoriálu klikne na kartu nebo předmět, který neodpovídá aktuálnímu úkolu, hra **nikdy nezamrzne ani hráče nepotrestá**. Místo toho přehraje jemný zvuk upozornění a Duch Spirko vypíše kontextovou nápovědu (nudge) v CZ/EN:

| Situace / Chybná akce hráče | Nudge CZ (`cs`) | Nudge EN (`en`) |
| :--- | :--- | :--- |
| **Krok 0:** Kliknutí na stůl nebo klávesu `[W]` před potvrzením úvodu | `"Stiskni [SPACE] nebo klikni na tlačítko pro zahájení výuky!"` | `"Press [SPACE] or click the button to start learning!"` |
| **Krok 1a:** Pokus o zahrání karty před vyzkoušením Veta `[V]` | `"Nejdřív si vyzkoušej výměnu úvodní ruky: stiskni [V] nebo klikni na ⚖ Vetovat karty!"` | `"Try vetoing your opening hand first: press [V] or click ⚖ Veto Hand!"` |
| **Krok 1a:** Kliknutí na `🏳 Vetovat hru` během tutoriálu | `"Tlačítko 🏳 Vetovat hru tě v kampani bezpečně vrátí na mapu. Teď ale klikni na ⚖ Vetovat karty [V]!"` | `"🏳 Veto Game safely returns you to the map in campaign. For now, click ⚖ Veto Hand [V]!"` |
| **Krok 1b:** Pokus o zahrání karty místo přepnutí pohledu `[Tab]` / `[Space]` | `"Stiskni [TAB] nebo [SPACE] (či tlačítko dole) a přepni pohled na 3D předměty na stole!"` | `"Press [TAB] or [SPACE] (or the bottom button) to switch to the 3D Table Items view!"` |
| **Krok 1b:** Kliknutí na jiný předmět na stole před vsazením 3D Meče | `"Pěkný úlovek! Teď ale klikni na svůj 3D Meč na stole a vsaď Krvavou přísahu!"` | `"Nice find! Now click your 3D Sword on the table to stake the Blood Oath!"` |
| **Krok 1c:** Zůstávání v pohledu na stůl po vsazení meče | `"Sázka je uzavřena! Stiskni [TAB] nebo [SPACE] pro návrat ke svým 3D kartám."` | `"Wager staked! Press [TAB] or [SPACE] to bring your 3D cards back up."` |
| **Krok 2:** Kliknutí na nehratelnou kartu (`ZELEN_8`) místo svítící karty | `"Tato karta nepasuje na ♥ Devítku! Zahraj svítící ♥ Desítku ze své ruky."` | `"That card doesn't match ♥ Nine! Play the glowing ♥ Ten from your hand."` |
| **Krok 2–6:** Kliknutí na Tahací balíček (`DrawDeckArea`) místo zahrání karty | `"Teď nelízej z balíčku — máš v ruce svítící kartu pro tento úkol!"` | `"No need to draw from the deck — play the highlighted card in your hand!"` |
| **Krok 3:** Kliknutí na jinou kartu než `CERVEN_7` (`♥ Sedma`) | `"Úkol: Zahraj teď svou svítící ♥ Sedmičku (7) a dej soupeři +2 karty!"` | `"Task: Play your glowing ♥ Seven (7) to hit your Rival with +2 cards!"` |
| **Krok 4:** Pokus o zahrání jen 1 Osmičky bez označení druhé | `"První Osma (8) je označena! Teď klikni pravým tlačítkem [RMB] i na DRUHOU Osmičku (8)!"` | `"First Eight (8) staged! Now right-click [RMB] the OTHER Eight (8) to build a 2× Combo!"` |
| **Krok 4:** Pokus o přidání Svrška (`CERVEN_H`) do komba k Osmičce | `"⛓ Řetězit do komba lze jen Osmičky (8 ∞) nebo max. 3 Esa! Spoj obě Osmičky."` | `"⛓ Only Eights (8 ∞) or up to 3 Aces can be stacked together! Stage both Eights."` |
| **Krok 5:** Pokus o zahrání jen 1 Esa místo komba 2× Esa | `"Označ pravým klikem [RMB] OBĚ Esa (E) v ruce — 2 Esa najednou uberou soupeři 4 ♥ HP!"` | `"Right-click [RMB] BOTH Aces (E) in hand — 2 Aces stacked deal 4 ♥ HP damage at once!"` |
| **Krok 6a:** Kliknutí na obyčejnou kartu místo `SPEC_VAMPIRE` | `"Úkol: Zahraj svou speciální kartu 🦇 Upíří pijavice (SPEC_VAMPIRE)!"` | `"Task: Play your special card 🦇 Vampire Leech (SPEC_VAMPIRE)!"` |
| **Krok 6b:** Pokus o zahrání poslední karty před hodem 3D Baňkou `IGNIS` | `"Nejdřív vyzkoušej 3D Baňku pekelného ohně IGNIS vpravo na stole (klikni na ni přímo nebo přes [TAB])!"` | `"First toss the 3D Hellfire Phial IGNIS on the right side of the table (click it directly or via [TAB])!"` |

---

## 4. Interaktivní 3D choreografie

### 4.1 Režimy kamery (`CameraViewMode`) a plynulé přechody
Kamera v `BattleTable3D` (`cam: Camera3D`) pracuje ve čtyřech jasně definovaných režimech, které nikdy nebojují s volným rozhlížením (`[RMB]`) ani s pružinovým zpětným rázem (`CameraRecoilSpring`):

| Režim (`CameraViewMode`) | Pozice kamery (`cam.position`) | Rotace kamery (`cam.rotation_degrees`) | FOV | Pozice 3D ruky (`player_hand_anchor`) | Kdy je aktivní |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **`GHOST_CLOSEUP`** | `Vector3(-0.32, 1.50, 0.76)` | `Vector3(1.0, 44.0, 0.0)` | `50.0°` | `HAND_POS_TUCKED`<br>`Vector3(0.0, 0.64, 1.34)` | Krok 0 (úvodní detailní pohled na 3D Ducha Spirka) |
| **`HAND_VIEW`** | `Vector3(0.0, 1.64, 1.48)` | `Vector3(-24.5, 0.0, 0.0)` + jemná paralaxa myši | `59.0°` | `HAND_POS_UP`<br>`Vector3(0.0, 1.295, 0.96)`, rot `(-16°, 0°, 0°)` | Výchozí hraní karet (`cards_tucked == false`) |
| **`TABLE_ITEMS_VIEW`** | `Vector3(0.0, 1.72, 1.48)` | `Vector3(-27.0, 0.0, 0.0)` + plný výhled na stůl | `61.0°` | `HAND_POS_TUCKED`<br>`Vector3(0.0, 0.64, 1.34)`, rot `(-34°, 0°, 0°)` | Po stisku `[Tab]` / `[Space]` nebo kliku na `quick_peek_btn` (`cards_tucked == true`) |
| **`CINEMATIC_LOCK`** | Řízeno keyframy `CinematicDirector` / `BlenderVfx` | Řízeno `look_at` / tweenem cutscény | `43.0° – 62.0°` | `HAND_POS_TUCKED` (skryto mimo záběr) | Během 2.5–4.0s cutscén Speciálních karet, tahu soupeře, hodu Baňkou `IGNIS` a popravy Mečem |

### 4.2 Choreografie přepnutí na 3D Předměty na stole (`[Tab]` / `[Space]`)
1. **Spuštění přepnutí:** Hráč stiskne `[Tab]` nebo `[Space]` (nebo klikne na dolní středové tlačítko `POHLED STŮL [TAB / SPACE]`).
2. **Animace 3D ruky a světla:**
   * `cards_tucked` se přepne na `true`. 3D rukavice a vějíř karet se plynule sklopí dolů pod hranu stolu (`HAND_POS_TUCKED`).
   * Stropní bodové světlo nad stolem (`table_spot_light`) zvýší intenzitu z `5.6` na `6.5`, aby vynikly kovové, skleněné a dřevěné PBR materiály rekvizit.
   * Spustí se `_animate_wager_showcase_3d(true)` — aktivní vsazený 3D předmět poskočí s částicovým efektem.
3. **Raycasting a fyzická odezva 3D rekvizit (`_update_prop_hover_and_edge_peek`):**
   * Fyzikální paprsek z kamery detekuje kolizní oblasti všech 3D předmětů na stole:
     * `SwordArea` (`player_sword_root` — hero model `sword_oath.glb` / `SWORD_IRON.glb` na `Vector3(1.02, 0.822, 0.22)` nebo v pozici přísahy `Vector3(-0.34, 0.832, 0.14)`).
     * `MagicPufArea` (`magic_puf_bottle` — hero model `phial_ignis.glb` / `hellfire_phial_hero.glb` s železnou filigránovou klecí a plamenem `IgnitedPlume` na `Vector3(0.76, 0.815, 0.34)`).
     * `TavernMugArea` (`tavern_mug_root` — hero model `tavern_mug.glb` s dubovými dužinami, mosaznými obručemi a krémovou pěnou).
     * `TavernCoinsArea` (`tavern_coins_root` — měšec florinů a sloupce zlatých mincí na `Vector3(-0.24, 0.816, -0.34)`).
     * `TavernDiceArea` (`tavern_dice_root` — kostené kostky štěstěny).
     * `TavernBellArea` (`tavern_bell_root` — Kupcův mosazný zvonec).
     * 3D podstavce aktivních relikvií (`relic_3d_nodes`: `REL_GREED`, `REL_FANG`, `REL_ALEMBIC`).
   * Najetím myší na libovolný 3D předmět se daný model **fyzicky vznese o `+0.075 m`**, zvětší měřítko o `+8 %` a v horní části obrazovky (`offset_top = 156`) zobrazí pergamenový štítek `prop_hover_pill` s názvem a funkcí předmětu.

### 4.3 Choreografie 3D Animovaných Srdcí (`HeartbeatHpDisplay`)
V Kroku 5 tutoriál detailně předvede nový 3D systém životů (`scripts/heartbeat_hp_display.gd`):

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  STAV 3D SRDCE (HeartbeatHpDisplay) PODLE % ŽIVOTŮ (HP)                      │
├──────────────────┬──────────────┬─────────────────┬──────────────────────────┤
│  Pásmo HP        │  Tep (BPM)   │  Speed Scale    │  Vizuální stav 3D GLB    │
├──────────────────┼──────────────┼─────────────────┼──────────────────────────┤
│  75 % – 100 %    │   ~64 BPM    │     1.05×       │  Sytý rubínový lesk,     │
│  (8–10 / 10 HP)  │  (Klidový)   │                 │  CrackVeins zhasnuté     │
├──────────────────┼──────────────┼─────────────────┼──────────────────────────┤
│  40 % – 74 %     │   ~98 BPM    │     1.65×       │  Teplý jantarový pulz,   │
│  (4–7 / 10 HP)   │  (Varovný)   │                 │  CrackVeins jemně žhnou  │
├──────────────────┼──────────────┼─────────────────┼──────────────────────────┤
│  1 % – 39 %      │ 152–175 BPM  │  2.55× – 2.90×  │  Zběsilý lub-dub tep,    │
│  (1–3 / 10 HP)   │  (Kritický!) │                 │  CrackVeins planou, třes │
├──────────────────┼──────────────┼─────────────────┼──────────────────────────┤
│  0 % (0 / 10 HP) │    0 BPM     │     0.00×       │  Zastavené srdce, temný  │
│  (K.O. / Smrt)   │  (Zástava)   │                 │  popelavý kámen          │
└──────────────────┴──────────────┴─────────────────┴──────────────────────────┘
```

* **Zásah do 3D srdce (`trigger_damage_pulse`):** Při zásahu Králem nebo Esy přehraje 3D model v `SubViewportContainer` (MSAA 4X) klip `"DamageHit"` (`18 snímků = 0.60 s`), kolem srdce projede rudý záblesk, číslo `"10 / 10"` se přepočítá s otřesem a po doznění se srdce plynule vrátí do smyčky `"Heartbeat"` s vyšší frekvencí BPM a jasnější emisí na meshi `CrackVeins`.
* **Ukázka Boss Srdce (`set_boss_mode(true)`):** V závěru Kroku 5 zavolá tutoriál na 2,2 sekundy `rival_heart_display.set_boss_mode(true, Color(1.0, 0.72, 0.24))`. Rámeček soupeřova srdce se zvětší z `88×88 px` na `132×132 px` a model se přepne na **`heart_boss.glb`** (temně obsidiánovo-karmínové srdce sevřené v trnové železno-zlaté kleci s královskými hroty a dunivým tepem), zatímco Duch varuje před souboji s Bossy epoch.

### 4.4 Choreografie Sázky (Wager) & Samostatného Veta (`[V]`)
* **Odstranění 2D sázkového okna:** Původní 2D lišta s tlačítky sázek (`wager_gold_btn`, `wager_item_btn`, `wager_sword_btn`) je nahrazena **přímou interakcí s 3D předměty na stole**.
* **Samostatná pilulka Veto (před 1. tahem):** Dokud `opening_turn_committed == false`, visí pod levým horním HUDem kompaktní samostatná pilulka Veto obsahující pouze:
  1. `⚖ Vetovat karty [V]` (`⚖ Veto Hand [V]`) — jednorázově vymění úvodních 5 karet i vrchní kartu na stole (`_perform_opening_veto_hand()`).
  2. `🏳 Vetovat hru` (`🏳 Veto Game`) — před prvním tahem bezpečně ukončí duel a vrátí hráče na mapu kampaně bez penalizace (`_perform_opening_veto_duel()`).
* **Volba sázky kliknutím na 3D předmět:**
  * Klik na **3D Měšec mincí** (`TavernCoinsArea`) → `set_duel_wager("GOLD")` (zlatý prstenec `wager_3d_ring` pod měšcem, kompaktní HUD štítek `💰 25g`).
  * Klik na **3D Baňku ohně** (`MagicPufArea`, před 1. tahem v režimu volby sázky nebo dvojklik/kontext) → `set_duel_wager("ITEM")` (fialovo-ohnivý odznak `🔥 IGNIS (+45g)`).
  * Klik na **3D Meč** (`SwordArea`) → `set_duel_wager("SWORD")` (3D Meč přeletí z pravého boku stolu `Vector3(1.02, 0.822, 0.22)` do čelní pozice Krvavé přísahy `Vector3(-0.34, 0.832, 0.14)` s rudým prstencem `wager_3d_ring` a zvukem tasení `anim_sword_unsheathe`; kompaktní HUD štítek ukazuje `⚔ SWORD (+100g)`).

### 4.5 Choreografie Plných Dramatických Cutscén (`CinematicDirector`)
Tutoriál obsahuje dvě plnohodnotné filmové cutscény řízené `CinematicDirector` (`scripts/cinematic_director.gd`):
1. **Cutscéna tahu soupeře (Krok 5 — `play_rival_turn_cinematic`):**
   * Délka: `2.8 s`. Horní a dolní okraj obrazovky orámují jemné zlatě lemované filmové letterbox pruhy.
   * Kamera provede dynamický nájezd na 3D postavu středověkého soupeře (`opp_stredovek.glb`).
   * `CinematicDirector` animuje pojmenované pivoty soupeře: `TorsoPivot` se nakloní dopředu (`lean_slam`), `HeadPivot` kývne, `EyeL` a `EyeR` zablýsknou a pravé rameno `ArmRPivot` prudce udeří kartou `CERVEN_K` (`♥ Král`) do středu stolu za doprovodu 3D efektu `cinematic_rival_slam.glb`.
2. **Cutscéna Speciální Mocné Karty (Krok 6a — `play_special_card_cinematic("SPEC_VAMPIRE")`):**
   * Délka: `3.2 s`. Stropní světlo krčmy se ztlumí (`dramatic_lighting_dim = 0.65`) a stůl zalije karmínový reflektor.
   * Zhmotní se Blender 3D animovaný rig **`cinematic_vampire_crimson.glb`** (rotující krvavé sigilové prstence, stoupající rubínové tesáky a sifonová koule energie).
   * Kamera prostřihne ze 3 úhlů: detail karty → nízký průlet tesáků přes stůl do hrudi soupeře (`recoil_stagger` na `TorsoPivot`/`HeadPivot`) → přílet vysátých `+15 bodů` (`×1.4 X-Mult`) do hráčova Kalicha.

---

## 5. Edge-cases & UX pojistky

### 5.1 Okamžité přeskočení tutoriálu (`_skip_tutorial_immediately`)
* **Vždy dostupné tlačítko:** V pravém dolním rohu (`offset_left = -208, offset_top = -54`) je po celou dobu tutoriálu viditelné tlačítko `tutorial_skip_btn` (**„Přeskočit ›" / „Skip ›"**).
* **Bezpečné ukončení běžících animací a cutscén:**
  * Kliknutí na `tutorial_skip_btn` okamžitě inkrementuje všechny asynchronní strážní tokeny: `_battle_session_token += 1`, `_ai_turn_seq += 1`, `_stagger_seq_token += 1`, `_score_resolve_token += 1`.
  * Pokud zrovna běží `CinematicDirector` (`cinematic_director.is_playing() == true`), zavolá se `cinematic_director.skip_current()`, který okamžitě skryje letterbox pruhy, uvolní dočasné 3D VFX rigy a vrátí kameru do výchozí transformace.
  * Uloží se `game_options["tutorial_done"] = true` přes `LialoCatalog.save_options(game_options)`, skryje se 3D Duch Spirko (`tutorial_ghost_3d.visible = false`, `tutorial_ghost_center_panel.visible = false`) a odemkne se plný herní HUD (`_apply_staged_tutorial_state(6, false)`).

### 5.2 Ochrana proti uváznutí (Soft-Lock Prevention)
1. **Ochrana životů hráče (`min_hp = 1`):** Ve funkci `_apply_hp_damage` platí během tutoriálu pojistka `var min_hp := 1 if (tutorial_mode and tutorial_step < 7) else 0`. Hráč tak v tutoriálu nikdy nemůže omylem zemřít na `0 ♥ HP`.
2. **Strop skóre před finálním krokem:** Ve funkci `_check_win_or_redeal` platí během kroků `1..6` pojistka `player_score = mini(player_score, target_score - 10)` a `ai_score = mini(ai_score, target_score - 20)`, takže duel nemůže předčasně skončit na body dříve, než hráč dojde do finálního **Kroku 7**.
3. **Garantované karty pro každý úkol:**
   * Před Krokem 3 funkce `_ensure_tutorial_seven_setup()` zkontroluje, zda má hráč v ruce hratelnou `7` (pokud ne, vloží ji) a odstraní případné `7` z ruky AI.
   * Před Krokem 4 funkce `_ensure_tutorial_combo_pair()` garantuje dvě Osmičky (`CERVEN_8` a `ZELEN_8`) v ruce hráče.
   * Před Krokem 5 a 6 funkce `_setup_tutorial_combat_climax()` garantuje dvě Esa (`CERVEN_E`, `ZELEN_E`), speciální kartu `SPEC_VAMPIRE`, nabitou Baňku `IGNIS` (`puf_charges = 1`, `player_score >= 25`) a závěrečnou kartu `CERVEN_10`.
4. **Rychlé zkrácení psaní brkem:** Pokud hráč stiskne `[Space]` nebo klikne na tlačítko Ducha v momentě, kdy se text ještě dopisuje brkem (`_get_handwriting_progress(tutorial_ghost_center_lbl)["active"] == true`), první stisk okamžitě dopíše celý text (`_finish_handwriting_anim`) nebo rovnou plynule posune krok, takže rychlí hráči nikdy nečekají.

### 5.3 Škálování UI: `1366×768` (Okno) vs. `1920×1080` (Full HD / Fullscreen)
Všechny prvky tutoriálu používají proporcionální kotvy (`Control.ANCHOR_*`) a bezpečné okraje testované na obou cílových rozlišeních:

| UI / 3D Prvek | Pozice & Kotvy při `1366×768` | Pozice & Kotvy při `1920×1080` | Ochrana proti překryvu (Zero Overlap Guarantee) |
| :--- | :--- | :--- | :--- |
| **Levý Score Board + 3D Srdce hráče** | `x: 14..488, y: 10..268` (`ANCHOR_TOP_LEFT`) | `x: 14..488, y: 10..268` (`ANCHOR_TOP_LEFT`) | Pevný levý sloupec; střední panel Ducha začíná až od `x >= 413` (`1366×768`) resp. `x >= 690` (`1920×1080`) |
| **Samostatná pilulka Veto (`[V]`)** | `x: 14..320, y: 274..312` (`ANCHOR_TOP_LEFT`) | `x: 14..320, y: 274..312` (`ANCHOR_TOP_LEFT`) | Čistě pod lištou relikvií (`relic_bar_hbox`), nikdy nezasahuje do 3D vějíře karet |
| **Centrální panel Ducha (`tutorial_ghost_center_panel`)** | **Krok 0:** `anchor_top=1.0`, `y: 624..732`<br>**Kroky 1–7:** `anchor_top=0.0`, `x: 413..953, y: 66..158` | **Krok 0:** `anchor_top=1.0`, `y: 936..1044`<br>**Kroky 1–7:** `anchor_top=0.0`, `x: 690..1230, y: 66..158` | Šířka `500–540 px` vycentrovaná na `anchor_left = 0.5`; zcela mimo levý Score Board (`x < 488` s posunem `+62 px` vpravo u 1366×768) i pravý Rival HUD (`offset_left = -372`) |
| **Pravý Rival HUD + 3D Srdce soupeře** | `x: 994..1350, y: 10..118` (`ANCHOR_TOP_RIGHT`) | `x: 1548..1904, y: 10..118` (`ANCHOR_TOP_RIGHT`) | Kotveno k pravému hornímu rohu (`anchor_left = 1.0, offset_left = -372`) |
| **Dolní akční lišta (`[W]` / `[Tab / Space]` / `Přeskočit ›`)** | `y: 712..754` (`ANCHOR_BOTTOM_CENTER` / `RIGHT`) | `y: 1024..1066` (`ANCHOR_BOTTOM_CENTER` / `RIGHT`) | 3D ruka v `HAND_VIEW` plave nad `y < 690` (`1366×768`), tlačítka leží v čistém spodním lemu |

### 5.4 Opětovné spuštění z 3D Pracovny nastavení (`LobbyOptions3D`)
Hráč může tutoriál kdykoliv zopakovat ze tří míst, přičemž všechna vedou přes jednotný tok v `scripts/downpour_root.gd` a `scripts/lobby_options_3d.gd`:
1. **Z 3D Pracovny nastavení (`LobbyOptions3D` — Task #2):**
   * Hráč otevře nastavení (tlačítkem `⚙ NASTAVENÍ` v hlavním menu, na mapě kampaně nebo ikonou `⚙` `settings_icon_btn` v pravém dolním rohu 3D bitvy).
   * Kamera v `LobbyOptions3D` sjede nad dubový stůl s 3D Kodexem ovládání (`settings_desk_ledger.glb`), voskovými pečetidly (`settings_wax_stamp.glb`), mosaznými číselníky (`settings_brass_dial.glb`) a přesýpacími hodinami (`settings_hourglass.glb`).
   * V dolním doku 3D pracovny klikne hráč na tlačítko **`_replay_tut_btn` („Zopakovat Tutoriál" / „Replay Tutorial")**.
   * `LobbyOptions3D` vyšle signál `replay_tutorial_requested`.
   * `downpour_root.gd` (řádek 2865) nastaví `game_options["tutorial_done"] = false`, uloží volby (`Catalog.save_options(game_options)`), zavře 3D pracovnu (`options_3d.close_3d()`) a přes sametový přechod (`_play_transition_to`) zavolá `_launch_era_battle(0, true)`.
2. **Z dřevěného štítu „TUTORIÁL" v hlavním menu (`_populate_menu_signs`):**
   * Hned vedle hlavního štítu **KAMPAŇ** visí v horní řadě dřevěný štít **TUTORIÁL** (`Vector2(252, 94)`), který přímo volá `_play_transition_to(func(): _launch_era_battle(0, true))`.
3. **Automatické spuštění při prvním vstupu do kampaně:**
   * Pokud `game_options.get("tutorial_done", false) == false` a `!first_battle_tutorial_done`, první kliknutí na libovolnou éru na 3D mapě automaticky spustí tutoriál s čistým výukovým profilem.

---

## 6. Technický implementační blueprint pro budoucí fázi

Tato sekce slouží jako exaktní technická specifikace pro implementační fázi (Wave 2 `battle-integrator`), aby bylo možné nový tutoriál napojit do `scripts/battle_table_3d.gd` bez jakéhokoliv hádání.

### 6.1 Stavové proměnné a Enum `CameraViewMode` v `scripts/battle_table_3d.gd`

```gdscript
enum CameraViewMode {
	GHOST_CLOSEUP,    # Krok 0: polodetail na 3D Ducha Spirka
	HAND_VIEW,        # Výchozí pohled na 3D karty v ruce (cards_tucked == false)
	TABLE_ITEMS_VIEW, # Pohled na 3D předměty na stole po [Tab]/[Space] (cards_tucked == true)
	CINEMATIC_LOCK,   # Řízení kamery převzato CinematicDirector / 3D VFX cutscénou
}

var camera_view_mode: CameraViewMode = CameraViewMode.HAND_VIEW
var player_heart_3d: HeartbeatHpDisplay = null
var rival_heart_3d: HeartbeatHpDisplay = null
var cinematic_director: CinematicDirector = null
var standalone_veto_pill: PanelContainer = null
```

### 6.2 Přepínač pohledu `[Tab]` / `[Space]` (`_toggle_camera_view_mode`)
V `_unhandled_input(event: InputEvent)` v `scripts/battle_table_3d.gd` se sjednotí obsluha kláves `KEY_TAB` a `KEY_SPACE` (a kliknutí na HUD tlačítko `quick_peek_btn`):

```gdscript
if event.keycode == KEY_SPACE or event.keycode == KEY_TAB:
	if tutorial_mode and (tutorial_step == 0 or tutorial_step >= 8):
		_finish_handwriting_anim(tutorial_ghost_center_lbl)
		_advance_tutorial_substep()
		get_viewport().set_input_as_handled()
		return
	_toggle_camera_view_mode()
	get_viewport().set_input_as_handled()
	return
```

```gdscript
func _toggle_camera_view_mode() -> void:
	if busy_animating or (cinematic_director != null and cinematic_director.is_playing()):
		return
	cards_tucked = not cards_tucked
	camera_view_mode = CameraViewMode.TABLE_ITEMS_VIEW if cards_tucked else CameraViewMode.HAND_VIEW
	auto_edge_peek = false
	emit_signal("play_sfx_pitched_requested", "card_hover", 0.82 if cards_tucked else 1.18)
	if cards_tucked:
		_animate_wager_showcase_3d(true)
	else:
		_animate_hand_return_wave()
	if quick_peek_btn:
		quick_peek_btn.text = _tr(
			"VIEW CARDS [TAB / SPACE]" if cards_tucked else "VIEW TABLE [TAB / SPACE]",
			"POHLED KARTY [TAB / SPACE]" if cards_tucked else "POHLED STŮL [TAB / SPACE]"
		)
	_sync_peek_ui_visibility()
	# Hook pro Krok 1 tutoriálu (přepnutí na stůl a zpět)
	if tutorial_mode and tutorial_step == 1:
		if tutorial_substep == 1 and cards_tucked:
			# Zvýrazni 3D Meč na stole kompasovým prstencem
			_update_tutorial_beacon_target(player_sword_root)
		elif tutorial_substep == 2 and not cards_tucked:
			_trigger_ghost_ok_flash()
			_advance_tutorial_to(2)
```

### 6.3 Integrace 3D Sázky kliknutím na 3D předměty a Samostatné Veto pilulky
1. **Kliknutí na 3D předměty pro volbu sázky (`_trigger_tavern_prop_click`):**
   Před odehráním 1. tahu (`not opening_turn_committed and current_round_num == 1`) kliknutí na 3D předměty na stole v `TABLE_ITEMS_VIEW` přímo mění sázku duelu:
   ```gdscript
   # V _trigger_tavern_prop_click(prop_id: String):
   var can_change_wager := (not opening_turn_committed and current_round_num == 1) or (tutorial_mode and tutorial_step == 1)
   if prop_id == "sword" and is_instance_valid(player_sword_root):
       if can_change_wager:
           set_duel_wager("SWORD", false)
           if tutorial_mode and tutorial_step == 1 and tutorial_substep == 1:
               tutorial_substep = 2
               _tutorial_action_done = "wager_staked"
               _trigger_ghost_ok_flash()
               _update_tutorial_callout_ui(1, true)
               return
   elif prop_id == "coins" and is_instance_valid(tavern_coins_root):
       if can_change_wager and not (tutorial_mode and tutorial_step == 1):
           set_duel_wager("GOLD", false)
   ```
2. **Odblokování Veta v Kroku 1a tutoriálu (`_perform_opening_veto_hand`):**
   ```gdscript
   func _perform_opening_veto_hand() -> void:
       var allow_in_tut := (tutorial_mode and tutorial_step == 1 and tutorial_substep == 0)
       if (tutorial_mode and not allow_in_tut) or busy_animating or not is_player_turn or opening_turn_committed or opening_veto_used:
           return
       opening_veto_used = true
       if allow_in_tut:
           _deal_tutorial_scripted_hand_after_veto()
           tutorial_substep = 1
           _trigger_ghost_ok_flash()
           _update_tutorial_callout_ui(1, true)
           return
       # ... standardní Veto logika pro kampaň ...
   ```

### 6.4 Integrace `HeartbeatHpDisplay` (`scripts/heartbeat_hp_display.gd`)
1. **Vytvoření v `_setup_minimal_overlay_hud()`:**
   * Místo plochého `player_hp_pill` a spodního pruhu v `ai_liquid_bar` se vytvoří dvě instance `HeartbeatHpDisplay`:
     ```gdscript
     player_heart_3d = HeartbeatHpDisplay.new()
     player_heart_3d.setup(_get_font(true), false, false)
     player_heart_3d.position = Vector2(14, 180)
     hud_root.add_child(player_heart_3d)

     rival_heart_3d = HeartbeatHpDisplay.new()
     rival_heart_3d.setup(_get_font(true), true, _get_opponent_visual_tier() >= 2)
     rival_heart_3d.anchor_left = 1.0
     rival_heart_3d.anchor_right = 1.0
     rival_heart_3d.offset_left = -112
     rival_heart_3d.offset_top = 86
     hud_root.add_child(rival_heart_3d)
     ```
2. **Propojení v `_apply_hp_damage(to_player: bool, dmg: int, reason: String)`:**
   ```gdscript
   if to_player and is_instance_valid(player_heart_3d):
       player_heart_3d.set_hp(player_hp, player_max_hp, true)
       player_heart_3d.trigger_damage_pulse(dmg)
   elif not to_player and is_instance_valid(rival_heart_3d):
       rival_heart_3d.set_hp(ai_hp, ai_max_hp, true)
       rival_heart_3d.trigger_damage_pulse(dmg)
   ```
3. **Ukázka Boss Srdce v Kroku 5 tutoriálu (`_preview_tutorial_boss_heart`):**
   ```gdscript
   func _preview_tutorial_boss_heart() -> void:
       if not is_instance_valid(rival_heart_3d):
           return
       rival_heart_3d.set_boss_mode(true, Color(1.0, 0.72, 0.24))
       var my_sess := _battle_session_token
       get_tree().create_timer(_pace(2.4)).timeout.connect(func():
           if my_sess == _battle_session_token and is_instance_valid(rival_heart_3d) and tutorial_mode:
               rival_heart_3d.set_boss_mode(false)
       )
   ```

### 6.5 Integrace `CinematicDirector` (`scripts/cinematic_director.gd`)
1. **Inicializace v `_ready()` / `_setup_minimal_overlay_hud()`:**
   ```gdscript
   cinematic_director = CinematicDirector.new()
   add_child(cinematic_director)
   cinematic_director.setup(self, cam, hud_root, _get_font(true))
   ```
2. **Napojení 3D modelu soupeře v `_build_opponent_silhouette_for_era(era_id: String)`:**
   ```gdscript
   if is_instance_valid(cinematic_director):
       cinematic_director.set_opponent_rig(opp_silhouette_root)
   ```
3. **Spuštění cutscény Speciální karty v Kroku 6a (`_play_player_cards_3d`):**
   * Když `chosen_cards` obsahuje kartu s `power_id != ""` (v Kroku 6a `SPEC_VAMPIRE`), před spuštěním `_execute_balatro_stagger_timeline` se zavolá:
     ```gdscript
     var lead_pid := str(chosen_cards[0].get("power_id", ""))
     if lead_pid != "" and is_instance_valid(cinematic_director):
         camera_view_mode = CameraViewMode.CINEMATIC_LOCK
         cinematic_director.play_special_card_cinematic(
             lead_pid,
             target_pos,
             opp_silhouette_root.global_position,
             opts_language == "cs",
             func(): _spawn_card_impact_dust(target_pos),
             func():
                 camera_view_mode = CameraViewMode.TABLE_ITEMS_VIEW if cards_tucked else CameraViewMode.HAND_VIEW
                 _execute_balatro_stagger_timeline(my_token, score_res, chosen_cards, _scored_display_nodes, s_obj, target_pos, force_lightning)
         )
         return
     ```
4. **Spuštění cutscény tahu soupeře v Kroku 5 (`_start_ai_3d_turn`):**
   * Když soupeř zahraje významnou kartu (v Kroku 5 `CERVEN_K` nebo v běžné hře figuru/speciální tah), zavolá se `cinematic_director.play_rival_turn_cinematic(era_id, is_boss, play_label, target_pos, opp_silhouette_root.global_position, opts_language == "cs", on_impact_cb, on_finished_cb)`.

### 6.6 Stavový automat přechodů `_advance_tutorial_to(next_step: int)`

```gdscript
func _advance_tutorial_to(next_step: int) -> void:
	tutorial_step = next_step
	tutorial_substep = 0
	_tutorial_action_done = ""
	staged_card_indices.clear()
	match next_step:
		1:
			# Krok 1: Samostatné Veto [V] -> Přepnutí pohledu [Tab]/[Space] -> 3D Sázka Meče
			cards_tucked = false
			camera_view_mode = CameraViewMode.HAND_VIEW
			_deal_tutorial_pre_veto_hand()
			_rebuild_all_3d_hands()
			_animate_hand_return_wave()
		2:
			# Krok 2: Základ Prší (♥ Desítka na ♥ Devítku) + Párové bodování Kalicha
			cards_tucked = false
			camera_view_mode = CameraViewMode.HAND_VIEW
			hud_score_revealed = true
			_rebuild_all_3d_hands()
		3:
			# Krok 3: Útočná Sedmička (7 = +2 karty a 3× body = 21 b.)
			cards_tucked = false
			cards_points_revealed = true
			abilities_revealed = true
			hud_score_revealed = true
			_ensure_tutorial_seven_setup()
			_reveal_points_and_score_magic()
			_reveal_abilities_magic()
		4:
			# Krok 4: Řetězení 2× Osmička (8 ∞) pravým klikem [RMB] + Zápisník rovnic
			cards_tucked = false
			hud_combo_revealed = true
			_ensure_tutorial_combo_pair()
			_reveal_combo_hud_magic()
		5:
			# Krok 5: 3D Bijící Srdce (HeartbeatHpDisplay) + 2× Eso (-4 ♥ HP) + Boss Srdce
			cards_tucked = false
			_setup_tutorial_hearts_and_aces_step()
			_preview_tutorial_boss_heart()
			_rebuild_all_3d_hands()
			_animate_deal_pop_in()
		6:
			# Krok 6: Filmová cutscéna SPEC_VAMPIRE (sub 0) + Hod 3D Baňkou IGNIS (sub 1)
			cards_tucked = false
			puf_revealed = true
			_setup_tutorial_special_and_phial_step()
			_reveal_puf_bottle_magic()
			_rebuild_all_3d_hands()
			_animate_deal_pop_in()
		7:
			# Krok 7: Poslední karta v ruce -> Shedding Finisher + Poprava Mečem
			cards_tucked = false
			_setup_tutorial_final_shed_card()
			_rebuild_all_3d_hands()
		_:
			# Vítězné dokončení tutoriálu (step >= 8)
			_trigger_ghost_ok_flash()
			emit_signal("play_sfx_requested", "win")
			_update_tutorial_callout_ui(8, true)
			_refresh_table_labels()
			var my_sess := _battle_session_token
			get_tree().create_timer(_pace(4.2)).timeout.connect(func():
				if my_sess == _battle_session_token and tutorial_mode and tutorial_step >= 8:
					_skip_tutorial_immediately()
			)
			return
	_update_tutorial_callout_ui(next_step, true)
	_refresh_table_labels()
```

---

## 7. Kontrolní seznam verifikace vůči kódu (Codebase Cross-Check)

* **ID Karet (`scripts/lialo_catalog.gd` & `scripts/scoring_engine.gd`):**
  * Barvy (`SUITS`): `CERVEN` (`♥ Srdce`), `ZELEN` (`♠ Listí`), `ZALUD` (`♣ Žaludy`), `GULA` (`● Koule`).
  * Hodnoty (`RANKS`): `7` (7 b.), `8` (8 b., `∞`), `9` (9 b.), `10` (10 b.), `D` (12 b., Spodek), `H` (16 b., Svršek), `K` (18 b., Král), `E` (20 b., Eso).
  * Aktivní Speciální karty použité v tutoriálu: `SPEC_VAMPIRE` (*Upíří pijavice*, 22 b., `CERVEN`), `SPEC_STORM` (*Úder blesku*, 25 b., `ZELEN`), `SPEC_PHOENIX` (*Fénix z popela*, 28 b., `CERVEN`), `SPEC_MIDAS` (*Midasův dotek*, 24 b., `GULA`).
  * Aktivní Relikvie použité v tutoriálu: `REL_GREED` (*Kupecké váhy*), `REL_FANG` (*Rudý tesák*), `REL_ALEMBIC` (*Alchymistická baňka*).
  * **Nulový výskyt archivovaných či dočasně skrytých položek:** V celém dokumentu i skriptovaných rukou tutoriálu je `0` odkazů na odstraněné či dočasně skryté předměty.
* **Klávesové zkratky (`scripts/battle_table_3d.gd` & `scripts/lobby_options_3d.gd`):**
  * `[Tab]` / `[Space]` — Přepnutí pohledu mezi 3D Kartami v ruce (`HAND_VIEW`) a 3D Předměty na stole (`TABLE_ITEMS_VIEW`) + potvrzení dialogu Ducha.
  * `[W]` — Rychlé zahrání vybrané karty nebo odpálení označeného komba (`PLAY CARD [W]` / `SLAM COMBO [W]`).
  * `[RMB]` (Pravé tlačítko myši) — Krátký klik: označení/odznačení karty do komba (`_toggle_stage_card`); tažení myší: volné 3D rozhlížení po krčmě (`freelook_yaw`, `freelook_pitch`).
  * `[V]` — Samostatné Veto úvodní ruky před 1. tahem (`_perform_opening_veto_hand`).
  * `[M]` — Výměna označených karet v kampani (`_redraw_staged_cards`).
  * `[1]` / `[2]` / `[3]` — Seřazení karet v ruce podle Hodnoty (`rank`), Barvy (`suit`) nebo Síly (`power`) přes `_sort_player_hand`.
  * `[F8]` — Cyklické přepnutí vizuálního režimu (`Liar's Bar PBR`, `Living Woodcut`, `Broadsheet Sepia`, `Classic 3D`).
