# LIALO — Campaign Story, Progressive Tutorials, Multi-Phase Bosses & Motion-Comic Cutscenes (v0.196 Blueprint)

> **Purpose:** Complete, implementation-ready design blueprint for turning LIALO's 5-Era Campaign into a thriving story experience with progressive micro-tutorials, multi-phase bosses, and short animated woodcut-ink comic cutscenes.

---

## 1. Overarching Story Arc — *"The Five Seals of the Ouroboros Tavern"* (*Pět pečetí Krčmy Úroboru*)

### Core Premise
You awaken inside a rain-lashed, candlelit tavern suspended outside time. Across the oak table sits **Spirko — the Spectral Tavern Keeper**, bound by chains of ink and smoke. Five sovereigns and crime lords across history shattered the **Five Grand Seals of the Ouroboros**, locking their epochs in eternal twilight and trapping challenger souls inside their decks.

To escape the tavern and lift the curse, you must travel across the **5 Eras**, learn the art of blade, shield, and sigil, defeat each Era's **3 stages** (2 Lieutenants + 1 Multi-Phase Sovereign Boss), and shatter all five Grand Seals.

### 5-Act Narrative Escalation & Mid-Game Twist

| Act | Era ID & Setting | Title | Narrative Beat & Stakes |
| :--- | :--- | :--- | :--- |
| **Prologue** | `antika` (Tutorial) | **The Rain-Soaked Deal** | You wake in the timeless tavern. Spirko hands you his tattered starter deck and teaches survival before opening the first temporal door. |
| **Act I** | `antika` (Egypt & Greece) | **The Sun-Scorched Debt** | Beneath perpetual desert sandstorms, **Pharaoh Ramesses** hoards the 1st Seal inside a buried sun-temple tavern where weak solo plays are taxed. |
| **Act II** | `rim` (Roman Empire) | **The Senate of Blades** | Deep beneath the Colosseum, **Julius Caesar** commands armored legions at an iron marble table. Upon Caesar's defeat, Spirko suffers a haunted memory flash — he recognizes the Colosseum dealer markings as his own. |
| **Act III** | `stredovek` (Medieval Realm) | **The Broken Oath *(TWIST)*** | Beneath Prague's storm-lashed bells, **King Charles IV** recognizes Spirko's brass lantern and calls him *forger of the Five Seals*. Defeating Charles unlocks the sepia flashback: **centuries ago, Spirko forged the Ouroboros Seals to cheat Death, lost his own wager, and was cursed to guide challengers until someone breaks all five.** |
| **Act IV** | `objavy` (Age of Sail) | **The Tempest Compass** | Aboard a creaking galleon cabin tossed on black waves, **Pirate Queen Anne** rules shifting winds and pillages unguarded hands. Winning reveals a **brass 1930s speakeasy key** hidden inside the 4th Seal shard. |
| **Act V** | `prohibicia` (1930s Prohibition) | **The Syndicate's Last Hand** | In a smoke-choked Chicago speakeasy built directly over the timeless Tavern's foundations, **Al Capone** holds Spirko's soul contract in the **Ouroboros Ledger**. Breaking the 5th Seal burns the contract, brings sunrise to the tavern, frees Spirko, and unlocks **Endless Ascension ("The Eternal Table")**. |

---

## 2. Progressive Campaign Tutorial Curriculum (No Info-Dump!)

Instead of explaining every mechanic in one long intro, LIALO uses a **Prologue Duel + 5 Story-Embedded Micro-Tutorials** (60–90s guided Spirko prompts during **Stage 0 / Stage 1** of each Era, persisted in `run_profile["completed_micro_tutorials"]`).

### Prologue Duel (`battle_table_3d.gd` lines `6830–6930` — Keep Tight & Core)
Keep the existing 7-step Spirko Prologue focused purely on core combat survival:
1. Veto Hand (`[V]`) & Staking the 3D Oath Sword (`[TAB]`/`[SPACE]`)
2. Suit / Rank matching & Chalice scoring (`Ten`)
3. Seven (`7`: `+2` Draw & `3×` Points) & Queen (`H`: Suit Shift)
4. Combo chains (`8 ∞` & Ace `E` stacking with `[RMB]`)
5. 3D Hearts (`10 ♥ HP`, King `K` 1–3 DMG, Aces `1/4/Instant Kill`)
6. Power Card (`SPEC_VAMPIRE`) & 3D Hellfire Phial `IGNIS`
7. Win Conditions & Round 3 Bazaar transition

### 5 Era Micro-Tutorials (Unlocked Organically With the Story)

| Era | Stage | Mechanic Introduced | Guided Spirko Task & Reward |
| :--- | :--- | :--- | :--- |
| **Era 1: `antika`** | Stage 0–1 | **Boss Stone Modifiers + `NORMAL` Gold Buff + Bazaar** | Spirko points at the 3D Stone Plaque (`SCROLL_TAX`), explains earning extra Florins via `NORMAL` cards, and walks the player through their first Bazaar upgrade after Round 3. |
| **Era 2: `rim`** | Stage 0–1 | **Card Classes & 3-Part `KNIGHT` Shield (`1/3 -> 3/3`)** | Before fighting Caesar's legions, Spirko explains `KNIGHT` (`1/3` shield charge per play -> `3/3 = +1 Full Shield`), `MAGE`, `THIEF`, and opens the Deck Builder Forge with 2D Spirko guidance. |
| **Era 3: `stredovek`** | Stage 0–1 | **Grand Seal (4-Card Combo) & Shield-Pierce Criticals** | Against heavily armored knights, Spirko demonstrates assembling 4 Grand Seal cards and unleashing a **Shield-Pierce Critical (`CRITICAL • SHIELD PIERCE!`)** that bypasses Iron Shields. |
| **Era 4: `objavy`** | Stage 0–1 | **3D Tabletop Relics & Dynamic Hazards (`SHIFTING_WINDS`)** | Spirko prompts the player to activate an equipped `TRELIC_*` tabletop prop (`1×/duel` & Overcharge) and adapt to rotating table suits. |
| **Era 5: `prohibicia`** | Stage 0–1 | **High-Stakes Endgame Synergy & Boss Phase Telegraphs** | No hand-holding tooltips; Spirko delivers crisp tactical callouts on reading Boss Phase 2 warnings, banking `3/3` Knight Shields against Seven chains, and timing Grand Seal finishers. |

---

## 3. Five Multi-Phase Story Bosses (Extended From `Catalog.ERA_STAGES`)

Each Era ends at **Stage 2 (BOSS)** in `scripts/lialo_catalog.gd` (`467–493`). Keep existing Phase 1 `boss_mod` IDs for full save/test compatibility, and add **Phase 2 Awakening** triggered when the Boss drops to **`<= 50% HP`** OR reaches **`>= 60% Chalice Score`** (accompanied by a snappy 2-panel **Mid-Battle Comic Flash**, table aura shift, and BGM escalation).

### Boss 1 — Pharaoh Ramesses (`antika`, `boss_mod: "PHARAOH_SEAL"`)
- **Table Signature Prop:** Carved golden Scarab Sun-Dial beside Rival's mat.
- **Opening Taunt:** *"Mortals scatter like sand before the First Seal. Show me a hand worthy of eternity!"*
- **Phase 1 (`PHARAOH_SEAL`):** Solo plays under 20 pts pay `-2` pt scarab tax; Power Cards & Combos gain `+15` pts.
- **Phase 2 Awakening — *"Sandstorm Decree"*** *(at <=50% HP or >=60% Chalice)*:
  - Scarab Sun-Dial cracks open; swirling sand locks **1 random suit for 1 turn** (`SEALED SUIT`) — only broken early by playing a Queen (`H`) or a `2×+` Combo.
- **Counterplay Lesson:** Rewards saving Queens (`H`) and building multi-card combos over weak single plays.
- **Defeat Reward:** First Seal Shard, Golden Pharaoh Bracers, `+200g`, unlocks `COMIC_ERA1_WIN`.

### Boss 2 — Julius Caesar (`rim`, `boss_mod: "CAESAR_TRIBUTE"`)
- **Table Signature Prop:** Crimson Legionnaire Standard & Marble Laurel Coin.
- **Opening Taunt:** *"A lone blade is a rebel's folly. Only a legion breaks the Senate!"*
- **Phase 1 (`CAESAR_TRIBUTE`):** Solo plays grant Caesar `+4` pts; Combos strike for `+25` bonus pts.
- **Phase 2 Awakening — *"Crossing the Rubicon"***:
  - Caesar slams his brass eagle onto the mat, gaining **`+2` Iron Shields** immediately and upgrading his remaining court cards to `KNIGHT` pressure.
- **Counterplay Lesson:** Rewards building the player's own **`KNIGHT` `3/3` Shields** and breaking Caesar's armor with stacked Combos/Aces.
- **Defeat Reward:** Second Seal Shard, Roman Legion Vambraces, `+230g`, triggers Spirko's Roman flashback (`COMIC_ERA2_WIN`).

### Boss 3 — King Charles IV (`stredovek`, `boss_mod: "CROWN_DECREE"`)
- **Table Signature Prop:** Velvet Cushion with Royal Wax Crown Stamp & Stone Goblet.
- **Opening Taunt:** *"I know that lantern, Ghost. So the forger finally sends another pawn!"*
- **Phase 1 (`CROWN_DECREE`):** Rival Court cards gain `+4` pts unless blocked by player Shields.
- **Phase 2 Awakening — *"Royal Verdict"***:
  - Charles stamps the player's **highest-rank card in hand** with a glowing red wax seal (cannot be played solo for 1 turn — must be chained in a Combo or cleared via Redraw/Grand Seal).
- **Counterplay Lesson:** Teaches unleashing the **4-Card Grand Seal** to trigger **Shield-Pierce Criticals** straight through royal defenses.
- **Defeat Reward:** Third Seal Shard, Knightly Iron Gauntlets, `+265g`, unlocks the **Mid-Game Story Twist** (`COMIC_ERA3_WIN`).

### Boss 4 — Pirate Queen Anne (`objavy`, `boss_mod: "PLUNDER"`)
- **Table Signature Prop:** Swaying Brass Ship Compass & Flintlock Pistol on the table.
- **Opening Taunt:** *"Hold onto your relics, landlubber — the storm decides the suit tonight!"*
- **Phase 1 (`PLUNDER`):** Rival Aces or `7`s raid `4` pts unless blocked by player Shields.
- **Phase 2 Awakening — *"Maelstrom Broadside"***:
  - Table lamps sway violently, camera micro-shakes, and **`SHIFTING_WINDS`** activates (**Active Suit rotates every 2 turns**) alongside a cannonball score barrage.
- **Counterplay Lesson:** Rewards timed **`TRELIC_*` 3D Tabletop Relics** + adaptive Suit switching (`H` / Wild Power Cards).
- **Defeat Reward:** Fourth Seal Shard + Brass Speakeasy Key, Corsair Hook & Cuff, `+300g`, unlocks `COMIC_ERA4_WIN`.

### Boss 5 (FINAL) — Al Capone (`prohibicia`, `boss_mod: "DON_RACKETEER"`)
- **Table Signature Prop:** Velvet Cigar Ashtray, Thompson Drum & the chained **Ouroboros Ledger**.
- **Opening Taunt:** *"Fifty years I ran this joint for the Ghost's debt. Put your soul on the felt, kid!"*
- **Phase 1 (`DON_RACKETEER`):** Opens with `+20` Chalice lead and heavy Seven (`7`) chain threats.
- **Phase 2 Awakening — *"Saint Valentine's Deal"*** *(at <=50% HP, triggers `COMIC_CAPONE_PHASE2`)*:
  - Ledger ignites; **`SYNDICATE_CUT`** (`-5%` solo tax) activates, double Seven pressure begins, and cigarette-smoke shadows vignette the rival side.
- **Phase 3 Climax — *"Last Breath"*** *(at `<= 2` Boss HP or `>= 85%` Chalice)*:
  - Table dims to deep crimson spotlight, Battle BGM locks into Climax stem, and the player receives an emergency **`+1` Grand Seal Resonance** charge so the final blow feels theatrical.
- **Counterplay Lesson:** Full synthesis of Shields (`KNIGHT` `3/3`), Florin economy (`NORMAL`), Relics, Power Cards, Veto timing, and Grand Seal Shield-Pierce finishers.
- **Defeat Reward:** Fifth Seal shattered, **Ouroboros Contract burned**, Cosa Nostra Black Gloves, `+350g`, `COMIC_EPILOGUE_FINALE`, unlocks **Endless Ascension Mode**.

---

## 4. Short Animated Comic-Strip Cutscene System (`ComicCutscenePlayer`)

### Design Philosophy
Keep cinematics **snappy, stylized, and cheap to produce**: **3–4 inked woodcut comic panels per scene** (`8–15 seconds` total), never blocking impatient players (`SPACE` / `ESC` / `Click` skips or advances panel-by-panel; auto-advances on relaxed timer).

### 5 Motion-Comic Animation Techniques (2D in Godot — Fast & Atmospheric)
1. **Sequential Ink Panel Reveal:** Panels slam or brush-wipe in `1 -> 2 -> 3 -> 4` onto a dark parchment page (`-1.5°` to `+1.5°` comic tilt, crisp ink borders, paper grain overlay, brush-stroke SFX).
2. **2.5D Ken Burns Parallax:** Each panel supports `1–3` transparent PNG layers (`bg`, `subject`, `fg`) smoothly drifting & zooming (`1.00 -> 1.07`) at distinct speeds.
3. **Comic Action Stamps & Camera Micro-Shake:** Hand-drawn ink bursts (`CRACK!`, `SHING!`, `SLAM!`, `BOOM!`) pop elastically (`TRANS_BACK`) right when key story beats hit.
4. **Hand-Lettered Speech Bubbles & Captions:** Styled ink speech balloons pointing toward speaker + parchment narrator strip using `LialoQuill.ttf` / `LialoBody.ttf` with typewriter reveal and speaker voice chimes.
5. **Atmospheric Weather Pass:** Lightweight 2D particles layered inside individual panels (desert sand, colosseum embers, Prague rain, ocean lightning flashes, 1930s cigar smoke).

---

### Complete 12-Scene Comic Storyboard

#### 1. `COMIC_PROLOGUE_INTRO` *(4 Panels — Triggers once on first Campaign Launch)*
- **P1:** Heavy midnight rain hammers cracked tavern shutters (`SFX: rain_thunder`). *Caption: "Somewhere outside time, the rain never stops falling..."*
- **P2:** Lantern ignites across oak wood, illuminating **Spirko** adjusting tattered cuffs with glowing eyes (`Ken Burns zoom`). *Spirko: "Awake at last? Take a seat — only a winning hand opens the door."*
- **P3:** Close-up on the table crack showing **five shattered glowing Seal fragments** etched with Pharaoh, Eagle, Crown, Compass, and Dagger icons (`Stamp: SHING!`).
- **P4:** Hands slam starter cards onto the felt as a crisp card fan flares (`Stamp: DEAL!`). *Spirko: "Five tyrants stole the Seals. Let's see if you survive Lesson One."*

#### 2. `COMIC_ERA1_INTRO` *(3 Panels — Entering Era 1: Egypt)*
- **P1:** Golden desert dunes swallow a half-buried obelisk tavern (`Weather: sand`).
- **P2:** Sandstone doors slide open to a torchlit table strewn with gold weights.
- **P3:** **Pharaoh Ramesses** slams his golden scarab seal onto the felt (`Stamp: THUD!`). *Ramesses: "Weak hands turn to dust here!"*

#### 3. `COMIC_ERA1_WIN` *(3 Panels — Defeating Ramesses)*
- **P1:** Player's winning Ace/Combo strikes; **1st Seal cracks down the middle** (`Stamp: CRACK!`).
- **P2:** Ramesses steps back as his scarab dissolves into drifting golden sand.
- **P3:** First glowing sun-shard snaps into your Deck Box; **Roman brass footsteps echo from the next archway**.

#### 4. `COMIC_ERA2_INTRO` *(3 Panels — Entering Era 2: Rome)*
- **P1:** Colosseum arches lit by roaring braziers above a sunken gambling pit (`Weather: embers`).
- **P2:** Iron-shielded legionnaires rattle spears around a red marble table.
- **P3:** **Julius Caesar** spins a blood-stained denarius (`Stamp: CLINK!`). *Caesar: "Raise your shield, challenger — the Senate takes no weaklings!"*

#### 5. `COMIC_ERA2_WIN` *(3 Panels — Defeating Caesar)*
- **P1:** Laurel crown splinters; **2nd Seal shatters** across the marble.
- **P2:** **Spirko** clutches his chest beside the table — a brief sepia silhouette flashes of *a mortal dealer shuffling Roman cards centuries ago*.
- **P3:** Second shard locks in; Spirko shakes off the vision: *"Forgive me... the next door leads home. To Prague."*

#### 6. `COMIC_ERA3_INTRO` *(3 Panels — Entering Era 3: Medieval)*
- **P1:** Rain pours over Gothic spires and booming cathedral bells (`Weather: rain`).
- **P2:** Vaulted stone hall with knights' shields lining the rafters.
- **P3:** **King Charles IV** locks eyes on Spirko's lantern (`Stamp: GASP!`). *Charles IV: "So the cursed forger dares return to my hall?"*

#### 7. `COMIC_ERA3_WIN` *(4 Panels — Defeating Charles IV: MID-GAME TWIST)*
- **P1:** Royal wax crown snaps; **3rd Seal bursts open** (`Stamp: SHATTER!`).
- **P2:** Full **sepia flashback**: young mortal Spirko carving the Five Ouroboros Seals in secret to cheat Death at cards.
- **P3:** Death claims the table — Spirko turns into spectral smoke, chained to the lantern while Charles watches in shadow.
- **P4:** Back in the present, Spirko bows his head: *"I forged the Seals. Break the last two... and free us both."* A drenched nautical chart unrolls to an ocean storm.

#### 8. `COMIC_ERA4_INTRO` *(3 Panels — Entering Era 4: Age of Sail)*
- **P1:** Jagged lightning silhouettes a galleon cresting black waves (`Weather: lightning`).
- **P2:** Lanterns swing violently inside the captain's oak cabin over a wet map.
- **P3:** **Pirate Queen Anne** pins a flintlock beside the deck (`Stamp: SLAM!`). *Anne: "Winds change fast at sea — adapt or drown!"*

#### 9. `COMIC_ERA4_WIN` *(3 Panels — Defeating Queen Anne)*
- **P1:** Compass shatters; the **4th Seal lifts** and morning horizon peeks through storm clouds.
- **P2:** Anne grins and tosses a **tarnished 1930s brass key** onto the felt (`Stamp: CLANG!`). *Anne: "The Ghost's real debt waits ashore, kid."*
- **P3:** Keyhole widens into rain-slicked neon & Art Deco silhouettes in the mist.

#### 10. `COMIC_ERA5_INTRO` *(4 Panels — Entering Era 5: Prohibition)*
- **P1:** Neon puddles reflect trenchcoats in a dark 1930s alley (`Weather: rain`).
- **P2:** Heavy iron speakeasy door slides its peephole shut and swings open (`Stamp: CREAK!`).
- **P3:** Thick cigar smoke parts (`Weather: smoke`), revealing the timeless tavern ceiling overhead — it was the same building all along.
- **P4:** **Al Capone** rests his hand on the chained **Ouroboros Ledger**. *Capone: "Last Seal. Last hand. Let's settle the Ghost's tab."*

#### 11. `COMIC_CAPONE_PHASE2` *(2 Panels — Mid-Battle Flash at Capone <=50% HP)*
- **P1:** Red ink erupts out of the Ouroboros Ledger, wrapping the table in crimson flames (`Stamp: BURN!`).
- **P2:** **Spirko** flares blinding blue & gold beside you (`Shake!`). *Spirko: "Now! Unleash your Grand Seal through his armor!"*

#### 12. `COMIC_EPILOGUE_FINALE` *(4 Panels — Defeating Al Capone)*
- **P1:** All Five Seals snap together and explode in blinding sunrise gold (`Stamp: BREAK!`).
- **P2:** Heavy oak tavern shutters burst open — real warm dawn sunlight floods the room for the first time.
- **P3:** Spectral chains dissolve off **Spirko**, who tips his hat in peace before fading into morning mist. *Spirko: "Thank you, friend. The table is yours."*
- **P4:** You sit alone at the sun-warmed oak table shuffling an infinite golden deck (**Endless Ascension Unlocked**).

---

## 5. Technical Implementation Architecture (For Godot 4.7)

### New Files to Add
1. **`scripts/campaign/campaign_story_data.gd`** (`LialoStoryData`):
   - Pure data catalog containing:
     - `COMIC_SCENES: Dictionary` (12 scene IDs, panel arrays with `panel_tex`, `layers`, `caption_en/cs`, `speaker`, `bubble_en/cs`, `stamp_txt`, `shake`, `weather`, `duration_sec`, `sfx`).
     - `ERA_MICRO_TUTORIALS: Dictionary` (Stage 0/1 Spirko prompt steps per era).
     - `BOSS_PHASES: Dictionary` (Phase 2 HP/Chalice thresholds, `COMIC_CAPONE_PHASE2` trigger, phase mechanic IDs, pre/mid/post localized lines).
2. **`scripts/ui/comic_cutscene_player.gd`** (`class_name ComicCutscenePlayer`, `extends Control`):
   - Signals: `scene_finished(scene_id: String)`, `sfx_requested(sfx_key: String)`.
   - Renders inked parchment backdrop + animated multi-panel grid with tweened slam/wipe reveal, 2.5D Ken Burns zoom/pan, comic action stamp pop, typewriter speech bubbles, and 2D atmospheric particles.
   - **Procedural Fallback Mode:** When PNG panels under `res://assets/story/comics/<scene_id>_p<N>.png` do not exist yet, auto-generates crisp stylized woodcut ink compositions (colors, silhouettes, card motifs, Spirko/Boss emblems) so the whole story flow can be tested immediately in Godot and `F9` Dev Inspector before final art painting!

### Existing Files to Integrate
- **`scripts/lialo_catalog.gd`:** Add `"seen_comics": []`, `"completed_micro_tutorials": []` to `get_default_profile()` + sanitize cleanly.
- **`scripts/downpour_root.gd`:**
  - Mount `ComicCutscenePlayer` on a high `CanvasLayer`.
  - Play `COMIC_PROLOGUE_INTRO` on first Campaign entry; play `COMIC_ERA<N>_INTRO` on entering Stage 0 of each Era (first time); play `COMIC_ERA<N>_WIN` / `COMIC_EPILOGUE_FINALE` after defeating each Era Boss.
  - Add **"Chronicle / Příběh"** replay gallery inside Campaign Map / Almanac so any unlocked comic strip can be rewatched anytime.
- **`scripts/battle_table_3d.gd`:**
  - Check Era micro-tutorial triggers on Stage 0/1 turns (`_check_campaign_micro_tutorial`).
  - Track `boss_phase: int = 1 -> 2 -> 3` in Boss battles (`stage_idx == 2`): trigger Boss Phase 2 modifier + optional 2-panel `ComicCutscenePlayer` flash (`COMIC_CAPONE_PHASE2`) without losing battle state.
- **`scripts/ui/dev_asset_inspector.gd`:**
  - Add `CAT_ANIM` entries for all `COMIC_*` scenes so you and your friend can preview and tune every comic cutscene directly from Lobby **`F9`**.

---

## 6. Phased Delivery Checklist
- [ ] **Phase A (Data & Player):** Create `campaign_story_data.gd` + `comic_cutscene_player.gd` with procedural ink fallback & wire into `F9` Dev Inspector.
- [ ] **Phase B (Persistence & Triggers):** Add `seen_comics` / `completed_micro_tutorials` to `lialo_catalog.gd` and hook Era Intro / Win comic triggers into `downpour_root.gd`.
- [ ] **Phase C (Micro-Tutorials & Multi-Phase Bosses):** Implement the 5 Era Spirko micro-tutorials and Boss Phase 2/3 awakenings in `battle_table_3d.gd`.
- [ ] **Phase D (Comic Art Pass & Polish):** Paint & slice final woodcut PNG layers (`assets/story/comics/`), add Chronicle Replay modal, and extend `tools/verify_progression_mp.gd` with headless smoke assertions.
