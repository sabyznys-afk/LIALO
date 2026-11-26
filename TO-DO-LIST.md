# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

> Všechny úkoly z v0.196 i finální export Windows buildu (`build/windows/LIALO.exe`) jsou hotové.

---

## 🎯 LIALO v0.198 — Master `/goal` Plan: Pravé 3D Dynamické Power Karty (15/15) + Oprava & Detail Všech Relikvií

> **Kompletní detailní specifikace & exekuční blueprint pro více agentů:** [GOAL_V0198_3D_POWER_AND_RELICS_PLAN.md](docs/GOAL_V0198_3D_POWER_AND_RELICS_PLAN.md)
> **Zásada zpracování:** Nejprve schválit po dávkách přes multi-angle GPU náhledy (čelně + 60° boční orbit + detail okrajů). **Žádné ploché 2D quad náhražky pevných objektů a žádné statické VFX zapečené do textur!**

### 4 Neporušitelné Zákony v0.198
1. **Pravé 3D Hero Modely (konec ohýbání ze strany):** `_make_25d_diorama()` používá plochý 2D `QuadMesh`, který se při pohledu z boku deformuje. Všech 15 Power karet dostane vícedílný pravý **3D `.glb` model** ve stylu `TRELIC_WAR_HORN.glb` (410 KB, 1024px woodcut ink textury, `handdrawn_relic_3d.gdshader`), funkční ze všech 360° úhlů.
2. **Fyzikální dynamika & 0 % statických efektů:** Žádný model nesmí mít na textuře namalovaný kouř, blesky, pírko ani zmrzlou tekutinu.
   - *Tekutina (`Vampire Chalice`, `Crucible`, `Midas Gold`, `Blood Goblet`):* Dynamicky šplouchající/poskakující 3D hladina + padající/kapající 3D kapky na stůl.
   - *Kopí (`SPEC_STORM`):* Čistý 3D model — samostatný živý objemový kouř, procedurálně větvené 3D modré blesky skákající po čepeli a fyzikálně vlající pírko/střapec.
3. **Proměna celého prostředí krčmy (`TavernRealityShiftController` + `tavern_wall_shift.gdshader`):** Každá Power karta dočasně změní stěny, soumrak/světlo, okna, strop i stůl krčmy (např. *Vampire:* stékající krev po kamenných stěnách + hluboký soumrak; *Plague:* namrzající jinovatka; *Midas:* zlaté žíly; *Storm:* bouře a blesky v oknech) a po skončení je plynule vrátí.
4. **Relikvie bez průhledných bugů na úrovni Piva (`TRELIC_WAR_HORN`):** Automatický Python validátor `validate_mesh_winding_and_uvs()`, oprava převrácených normál a konkávních profilů u `add_lathe()`, náprava skla přesýpacích hodin (`handdrawn_glass_3d.gdshader`), podpora `normal_tex` a upgrade všech 10 stolních + 8 core relikvií.

### Checklist Fází `/goal` (připraveno k realizaci — zatím neimplementováno; přechod z 2.5D v0.197b/c na plné 3D + fyzika + krčma)
- [ ] **Fáze 0 — Core Engine & Validátory:**
  - [ ] Opravit `add_lathe()` v `tools/generate_all_handdrawn_relics.py` + přidat `validate_mesh_winding_and_uvs()` v `tools/generate_tankard_relic.py`
  - [ ] Vytvořit `shaders/handdrawn_glass_3d.gdshader` + přidat `normal_tex` do `shaders/handdrawn_relic_3d.gdshader`
  - [ ] Vytvořit `scripts/battle/tavern_reality_shift.gd` + `shaders/tavern_wall_shift.gdshader` (stékající krev, soumrak, bouře, jinovatka, zlaté žíly, zrcadlové praskliny)
- [ ] **Fáze 1 — Oprava průhledných textur & detailní resculpt Relikvií (10 Tabletop + 8 Core):**
  - [ ] Fix Bugů R1–R5 (převrácené normály dutých lemů, průsak `cull_front` obrysu, `DEPTH_DRAW_DISABLED` sklo)
  - [ ] Top opravy: `TRELIC_SOUL_BELL` (lem/klenba zvonu bez děr), `TRELIC_BLOOD_SEAL` (lem číše + dynamická kapající krev), `TRELIC_STAR_BOW` (hluboké runy + dráty bez průsaku), `TRELIC_ASH_GLASS` (oprava skla), `TRELIC_HOLLOW_MASK` (pohárek bez děr)
  - [ ] Detail upgrade k Tankardu: `TRELIC_CENSER`, `TRELIC_GOLD_SCALES`, `TRELIC_IRON_CHAIN`, `TRELIC_PHOENIX_BOX`, `TRELIC_WAR_HORN` (kapající pěna + normal map)
  - [ ] Upgrade 4 zastaralých legacy Core `.glb` (`REL_PHOENIX_F`, `REL_KNUCKLE`, `REL_CHAMOIS`, `REL_FANG`) na Tankard standard + kontrola zděděných 4 relikvií
- [ ] **Fáze 2 — Vlajkové Power Karty #1–#4 + Fénix v Pravém 3D + Krčma:**
  - [ ] `SPEC_VAMPIRE`: Pravý 3D kalich + rotující 3D prstenec + dynamicky šplouchající & kapající krev + mávající netopýři + **tekoucí krev po zdech & soumrak krčmy**
  - [ ] `SPEC_STORM`: Čisté 3D kopí + živý obíhající kouř + dynamické 3D blesky + vlající fyzikální pírko + bouřková proměna oken a stropu krčmy
  - [ ] `SPEC_PHOENIX`: Kloubový 3D Fénix s reálným máváním křídel + živé plameny + žhavé stěny krčmy
  - [ ] `SPEC_MIRROR`: 3D zrcadlový portál + vlnící se tekuté sklo + 3D rozlétající se střepy + praskliny v krčmě
  - [ ] `SPEC_ALCHEMIST`: 3D mosazný kelímek s trubkami a prstenci + vřící/přetékající elixír + mandala přes krčmu
- [ ] **Fáze 3 — Zbývajících 10 Power Karet po dávkách (vždy 3D `.glb` + dynamika + proměna krčmy):**
  - [ ] Dávka 3A: `SPEC_MIDAS` (3D rukavice + tekoucí roztavené zlato + padající 3D floriny), `SPEC_CHRONOS` (3D astroláb + písek proti gravitaci + zamrzlá krčma), `SPEC_ORACLE` (3D oko + světelné kužely + souhvězdí na zdech)
  - [ ] Dávka 3B: `SPEC_JESTER` (3D maska s houpajícími rolničkami + vír 3D karet), `SPEC_HEX` (3D grimoár + plazící se stínové úpony po stěnách), `SPEC_MAGNET` (3D podkova + dynamické siločáry)
  - [ ] Dávka 3C: `SPEC_SHIELD` (3D nýtované pavézy + nárazové třísky), `SPEC_GAMBLER` (kutálející se 3D kostky + kolo štěstěny), `SPEC_PLAGUE` (3D morová maska + namrzající jinovatka po krčmě), `SPEC_CROWN` (3D koruna + kapající pečetní vosk + prapory krčmy)
- [ ] **Fáze 4 — GPU Multi-Angle QA (čelně + 60° z boku) & 4/4 Godot Testy (`exit code 0`)**

---

### Předchozí mezikrok (v0.197b + v0.197c — živé 2.5D vrstvy)
- **v0.197b:** `SPEC_VAMPIRE`, `SPEC_STORM`, `SPEC_PHOENIX`, `SPEC_MIRROR` a `SPEC_ALCHEMIST` převedeny na vrstvený `power_25d_living.gdshader` bez rohových čárek.
- **v0.197c (commit `8e69293`):** Zbývajících 10 Power karet (`SPEC_MIDAS`, `SPEC_CHRONOS`, `SPEC_ORACLE`, `SPEC_JESTER`, `SPEC_HEX`, `SPEC_MAGNET`, `SPEC_SHIELD`, `SPEC_GAMBLER`, `SPEC_PLAGUE`, `SPEC_CROWN`) převedeno na 2.5D sprity (`anim_mode` 6–15) — ty v Fázi 3 výše přejdou rovnou na pravé 3D `.glb` + proměnu krčmy.

---


### Priorita #6 — Balík Audio / SFX & Epických Hudebních Promptů (47 vrstvených SFX & Epických Hudebních Promptů pro ElevenLabs SFX / Suno / Udio / Stable Audio)

> Anglické prompty zajišťují nejvyšší věrnost v generátorech AI zvuku; doporučené nastavení v **ElevenLabs SFX**: `duration_seconds` = `6.0` pro Master Cues a `1.5–3.0` pro stemy, `prompt_influence` = `0.65–0.80`. Po vygenerování uložit do `assets/audio/`.

#### A. 4 Relikvie (12 promptů)
- **`TRELIC_SOUL_BELL` (Graveyard Toll Bell)**
  1. *Idle/Ambient:* `Haunting low wind whistle through a cracked weathered bronze bell, faint wooden creak of gallows rope, dark gothic tavern silence, subtle spectral hum, seamless loop, dry close mic`
  2. *Activation/Click:* `Heavy iron latch click followed by a deep cracked cast bronze toll bell strike, dark metallic dissonance, lingering ghostly overtone, crisp transient`
  3. *Impact/Effect:* `Shattering spectral shockwave from a huge graveyard bell ring, sub-bass rumble, brittle armor crack and chilling wraith exhale, cavernous decay`
- **`TRELIC_BLOOD_SEAL` (Crimson Blood Goblet)**
  4. *Idle/Ambient:* `Thick crimson wine gently swirling in a silver chalice with delicate wet surface bubbles popping, soft resonant silverware ring, intimate close foley, seamless loop`
  5. *Activation/Click:* `Ornate silver goblet lifted from oak wood, wax seal snap and rich ruby liquid splash, sharp crystalline gem chime`
  6. *Impact/Effect:* `Visceral dark blood siphon whoosh, pulsing heartbeat sub-thump, magical ruby resonance swell and boiling liquid hiss`
- **`TRELIC_STAR_BOW` (Arcane Slate Rune)**
  7. *Idle/Ambient:* `Faint scraping stones slowly levitating in stone air, quiet low-frequency arcane hum and tiny crystalline static crackles, seamless loop`
  8. *Activation/Click:* `Heavy chiseled slate stone monolith grinding awake, ancient carved rune igniting with bright ethereal harp shimmer and crisp electrical spark`
  9. *Impact/Effect:* `Sharp lightning-etched rune seal detonation, piercing crystalline chord, deep stone thud and revealing mystical chime`
- **`TRELIC_ASH_GLASS` (Fate Hourglass)**
  10. *Idle/Ambient:* `Fine dry golden sand whispering softly through a narrow glass hourglass neck, delicate brass gear tick, serene mystical ticking, seamless loop`
  11. *Activation/Click:* `Brass hourglass flipped sharply on oak table, crisp glass clink, swirling sand rush and mechanical zodiac lock click`
  12. *Impact/Effect:* `Chronos time-freeze vacuum drop, reversed shimmering harp swell, suspended crystalline chimes and heavy clockwork echo`

#### B. 4 Vlajkové Power Karty — God-Tier Filmové SFX (20 promptů: 1× 6s Master + 4 vrstvené stemy na kartu)
- **`SPEC_VAMPIRE` (Vampire Leech — „Krvavé zatmění“)**
  13. *6s Full Master Cue:* **[HOTOVO — integrováno: `assets/audio/sfx_power_vampire_master.mp3`]** `Cinema trailer gothic blood magic climax, sharp card snap and rising reverse vacuum suction into split-second dead silence, colossal sub-bass braaam, hundred bat wings exploding outward, twin razor-sharp anime sword-sickle slashes, shattering crystal blood-moon impact with cavernous cathedral decay, wide stereo`
  14. *Stem 1 — Act I Cast & Gauntlet Transform:* **[HOTOVO — integrováno: `assets/audio/sfx_power_vampire_cast.mp3`]** `Sharp tarot card slam onto ancient oak followed by cold obsidian blade unsheathe, dark crimson armor plates locking over fingers, ominous low sub-bass swell`
  15. *Stem 2 — Act II Eclipse Reality Shift:* **[HOTOVO — integrováno: `assets/audio/sfx_power_vampire_shift.mp3`]** `Massive cathedral blackout vacuum drop, howling crimson eclipse wind, chaotic flock of leather bat wings panning violently across stereo field, eerie dissonant drone`
  16. *Stem 3 — Act III Climax Twin Crescent Impact:* **[HOTOVO — integrováno: `assets/audio/sfx_power_vampire_impact.mp3`]** `Half-second breath of total silence followed by twin supersonic calligraphic blade slashes, visceral crimson splash explosion, bone-chilling spectral shriek layer and chest-rattling sub-drop`
  17. *Stem 4 — Act IV Blood Siphon Tail:* **[HOTOVO — integrováno: `assets/audio/sfx_power_vampire_tail.mp3`]** `Swirling liquid ruby soul-ribbons spiraling backward into crystal phial, heavy slowing heartbeat thump dissolving into cold howling graveyard wind`
- **`SPEC_STORM` (Thunder Strike — „Nebeská bouře“)**
  18. *6s Full Master Cue:* **[HOTOVO — integrováno: `assets/audio/sfx_power_storm_master.mp3`]** `Anime lightning ultimate attack sound design, sizzling high-voltage rune rings spinning faster, roaring hurricane gale freezing into stark electric silence, seven celestial plasma spears whistling down, earth-shattering close-range thunderclap and orbital railgun arc impact, crackling ionized air tail`
  19. *Stem 1 — Act I Cast & Overcharge:* **[HOTOVO — integrováno: `assets/audio/sfx_power_storm_cast.mp3`]** `Snapping parchment card engulfed in high-voltage plasma arcs, rising ozone static hiss, heavy steel sword humming with electrical resonance`
  20. *Stem 2 — Act II Sky Shatter & Spears:* **[HOTOVO — integrováno: `assets/audio/sfx_power_storm_shift.mp3`]** `Tavern timber ceiling exploding into roaring storm gale that snaps into frozen time vacuum, seven crystalline lightning spears humming with deep sci-fi fantasy bass`
  21. *Stem 3 — Act III Cataclysmic Bolt Impact:* **[HOTOVO — integrováno: `assets/audio/sfx_power_storm_impact.mp3`]** `Blinding close-range lightning bolt whip-crack stacked with colossal mountain thunderclap, seared wood sizzle, metallic rune ring shockwave and deep sub-bass punch`
  22. *Stem 4 — Act IV Charged Aftermath:* **[HOTOVO — integrováno: `assets/audio/sfx_power_storm_tail.mp3`]** `Three electrified cursed cards whipping through heavy rain across stone floor, long rolling cathedral thunder tail fading into pouring storm`
- **`SPEC_MIRROR` (Twin Mirror — „Síň tříštících se zrcadel“)**
  23. *6s Full Master Cue:* `Surreal cosmic mirror dimension awakening, delicate silver glass bell turning into deafening crystalline dimension crack, swirling illusory echoes panning 360 degrees, colossal sixty-mirror symphony shatter explosion with massive sub-bass drop and sparkling prismatic glass rain`
  24. *Stem 1 — Act I Cast & Echo Split:* `Piercing silver hand-mirror chime, eerie harmonic glass bowl bend, ghostly doubled card snap and icy crystalline shimmer`
  25. *Stem 2 — Act II Reality Fracture:* `Dimension cracking along giant ice and mirror seams, eight towering cathedral mirrors rising out of oak floor with sweeping reverse shimmer and deep stone groan`
  26. *Stem 3 — Act III Sixty-Mirror Shatter Impact:* `Monumental stereo wall of sixty heavy bevelled mirrors exploding simultaneously, bright angelic prismatic chord detonation, whip-crack shockwave and chest-thumping sub hit`
  27. *Stem 4 — Act IV Prismatic Shard Rain:* `Thousands of glittering crystal glass fragments sprinkling across velvet and oak table, long haunting icy cathedral reverb tail`
- **`SPEC_ALCHEMIST` (Gold Transmuter — „Alchymistický kelímek“)**
  28. *6s Full Master Cue:* `Grand medieval alchemy transmutation climax, massive stone rune mandala igniting in roaring emerald firestorm, rhythmic heavy forging anvil strikes synced with bubbling molten gold vortex, blinding transmutation chime explosion and luminous glass phial clinking onto wood`
  29. *Stem 1 — Act I Cast & Mandala Ignite:* `Ancient vellum card igniting with roaring gunpowder ember whoosh, heavy bronze astrolabe lock slam, liquid gold sizzling in crucible`
  30. *Stem 2 — Act II Emerald Vortex:* `Massive arcane brass circle burning across stone floor, swirling emerald plasma cauldron roar, ascending harmonic alchemy bells building relentless tension`
  31. *Stem 3 — Act III Golden Transmutation Impact:* `Blinding golden flash impact, colossal mythical blacksmith hammer strike on sacred anvil stacked with cascading brass chimes, sparkling gold coin shower and deep sub-boom`
  32. *Stem 4 — Act IV Phial Materialize:* `Crystalline alchemy potion phial sparkling into existence and landing cleanly on solid oak, warm effervescent magical glow tail`

#### C. Multiplayer Lobby & Interiér Krčmy (7 promptů)
- **MP Stage Meče & Záložka módů**
  33. *MP Swords Unsheathe:* `Two heavy medieval longswords drawn simultaneously from leather scabbards, crisp steel hiss, deep dramatic leather strap snap`
  34. *MP Swords Clash & Lock:* `Powerful crossed-swords steel-on-steel parry clang on an oak table, flying metal sparks sizzle and long noble blade resonance`
  35. *MP Mode Drawer Slide:* `Smooth precision oiled oak and brass mechanical drawer sliding open, subtle felt rustle and crisp detent click`
  36. *MP Ready Wax Stamp:* `Heavy brass signet ring slamming into hot sealing wax on wooden desk, low triumphant horn chord swells underneath`
- **Interiér Krčmy (Oheň, Duch, Okna)**
  37. *Hearth Fire Loop:* `Warm cozy medieval stone fireplace roaring softly, snapping oak logs, popping embers and chimney draft rumble, seamless 15s loop`
  38. *Ghost Spirko Whisper:* `Gentle breathy spectral tavern keeper chuckle, soft hollow wind through ghostly cloth folds and tiny brass spirit-lantern glass rattle`
  39. *Storm Window Rain & Thunder:* `Heavy nocturnal rain pattering against leaded diamond window glass, muffled wooden shutters creak and distant rolling mountain thunder, seamless loop`

#### D. Epická Hudba — Power Card Stingery & Dynamic Battle BGM (8 promptů pro Suno / Udio / ElevenLabs Music)

> Nastavení pro **Suno / Udio**: zapnout `Instrumental`, držet přesné BPM z promptu kvůli synchronizaci se hrou.

- **4× 6s Power Card Hudební Stingery** (pozn.: ElevenLabs music stingery byly odstraněny — v soubojích hraje čistě původní BGM + 10 foley SFX stemů `sfx_power_vampire_*` a `sfx_power_storm_*`)
  40. **`SPEC_VAMPIRE` — Crimson Eclipse Drop (138 BPM, 6s stinger):** `Explosive 6-second dark-fantasy orchestral anime climax stinger, 138 BPM, D minor, screaming gothic pipe organ and solo cello screech building into a half-beat stop followed by furious Latin mixed choir burst, colossal taiko drums and earth-shaking brass braaam, instrumental only`
  41. **`SPEC_STORM` — Tempest Firmament Drop (150 BPM, 6s stinger):** `Electrifying 6-second symphonic anime ultimate attack stinger, 150 BPM, F# minor, blistering high-speed violin ostinato with roaring war horns and snare roll, abrupt electric gap then monumental thunderclap brass hit and distorted sub-bass drop, instrumental only`
  42. **`SPEC_MIRROR` — Hall of Shattered Glass Drop (132 BPM, 6s stinger):** `Surreal 6-second dark cosmic orchestral climax stinger, 132 BPM, C minor, eerie crystalline glass harmonica and reversed harp glissando exploding into staccato cathedral choir, shimmering celesta cascade and colossal orchestral brass hit, instrumental only`
  43. **`SPEC_ALCHEMIST` — Philosopher's Crucible Drop (128 BPM, 6s stinger):** `Majestic 6-second medieval arcane orchestral stinger, 128 BPM, G minor shifting to G major triumph, heavy metallic anvil percussion synced with soaring golden French horns, roaring brass swells, cathedral chimes and victorious choir chord, instrumental only`
- **4× Plná Epická Dynamic Battle & Boss BGM** (obnoveny originální battle BGM stopy z commitu `7b0b531`; ElevenLabs BGM soubory odstraněny)
  44. **`bgm_battle_calm_v2` (Taktické napětí v krčmě — 112 BPM):** `Dark medieval fantasy card duel soundtrack, 112 BPM, D minor, broody bowed cellos, gritty hurdy-gurdy drone, crisp harpsichord arpeggios, ominous tavern lute motif and deep tribal frame drum pulse, tense cunning atmosphere, seamless loop, instrumental only`
  45. **`bgm_battle_epic_v2` (Eskalace souboje — 128 BPM):** `Escalating dark-fantasy orchestral duel theme, 128 BPM, D minor, driving staccato string ostinato, heroic yet sinister brass horn countermelodies, pounding war drums and anvil strikes, brooding low male choir swells, high-stakes medieval showdown, seamless loop, instrumental only`
  46. **`bgm_battle_climax_v2` (Finální kolo / Overdrive — 142 BPM):** `Massive symphonic dark-fantasy anime final-blow soundtrack, 142 BPM, D minor, blazing full mixed choir chanting over roaring French horns, blistering solo violin, colossal taiko and timpani battery, cinematic trailer brass braaams and soaring tragic heroic melody, seamless loop, instrumental only`
  47. **`bgm_boss_awakening` (Boss Phase 2 & Velká Pečeť — 136 BPM):** `Apocalyptic gothic boss battle theme, 136 BPM, E minor, thundering cathedral pipe organ chords, furious Latin choir chant, earth-shaking orchestral brass slams, metallic sword-clash percussion and relentless dramatic string fury, Dark Souls meets anime climax energy, instrumental only`
