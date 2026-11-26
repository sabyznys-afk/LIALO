# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

> Všechny úkoly z v0.196 i finální export Windows buildu (`build/windows/LIALO.exe`) jsou hotové.

---

## 🎯 LIALO v0.197 — Master Visual, VFX & Lobby Overhaul Plan

> **Zásada zpracování:** Nejprve pečlivě po jednom přebudovat a vizuálně schválit přes GPU náhledy (`3-angle` preview sheety jako `tankard_relic_preview.png`). Žádné primitivní `SphereMesh` / `PrismMesh` / `BoxMesh` náhražky ani ploché vektory.

---

### Priorita #3 — Velké Multiplayer Lobby & Animace Mečů na Ploše (`scripts/mp/mp_lobby_overlay.gd`)

- **Konec plochých vektorů na pozadí:** Odstranit primitivní `_draw_bg_fx()` trojúhelníky, kruhy a obdélníky (`mp_lobby_overlay.gd` ř. 396–460). Nahradit plnoobrazovkovou živou **3D Multiplayer Arena Stage** (vlastní `SubViewport` s gotickou halou, dynamickými shader pochodněmi, vrstveným texturovaným dýmem a jiskrami v `GPUParticles3D`, vlajícími 3D prapory s cloth vertex shaderem a objemovým světlem).
- **Konec „malých boxíků“ -> Velký AAA open-stage layout:** Zrušit uzavírající hlavní panel (`_main_panel` box). Rozvrhnout prvky volně po okrajích (štíhlá horní lišta, kompaktní levý dock Duelista & Buildu, výsuvný pravý panel míst a chatu, monumentální dolní středové tlačítko **READY / PLAY**), aby **50 %+ středu obrazovky patřilo živé 3D scéně**.
- **Animace mečů přímo NA PLOŠE (v popředí, ne v pozadí!):** Přímo na centrální interaktivní ploše stolu/arény před 3D postavami umístit **dva vysoce detailní 3D Oath Blady** (`handdrawn_oathblade.glb` + zvolený skin hráče). Při přepnutí módu, hledání hry nebo stisknutí **READY** se meče na ploše dramaticky tasí, zkříží se v jiskřivém střetu se zábleskem tušové rázové vlny a uzamknou připravenost k duelu.
- **Rozbalovací záložka pro přepínání módů („záložka, která se zvětší“):** Zrušit obří trvalou řadu 4 tlačítek (`_mode_tabs_hb`). Místo ní udělat elegantní kompaktní **rozbalovací záložku / pilulku** (např. `[ ⚔ UNRANKED ▾ ]`), která se při kliknutí/najetí plynule tweenem rozvine do vějíře/draweru 4 bohatě ilustrovaných karet módů (`Public`, `Private + Room Code`, `Ranked`, `Unranked`) a po volbě se zase úsporně stáhne.

---

### Priorita #4 — Fujira Studios Intro: Sculptovaný celočerný 3D dravec (`scripts/ui/fujira_studio_intro.gd`)

- **Diagnostikovaný stav:** `_build_all_black_bird()` (ř. 278–453) stále skládá ptáka z primitivních `SphereMesh`, `CylinderMesh`, `PrismMesh` a 20 hranatých `BoxMesh` destiček.
- **Rework:** Vygenerovat vysoce detailní vícedílný 3D `.glb` model celočerného dravce/havrana (`assets/models/fujira_black_bird.glb`, generátor v `tools/generate_fujira_bird.py`) s aerodynamickým prohnutým profilem křídel, individuálně zaoblenými špičatými letkami, zahnutým dravčím zobákem, hlavou a spáry, hladkými svařenými normálami, tmavě uhlovou peříčkovou texturou s jemným modročerným leskem a kaligrafickou obrysovou linkou; rozdělený do kloubových uzlů (`Body`, `WingL_In`, `WingL_Out`, `WingR_In`, `WingR_Out`, `TailFan`) + plynulé 3D/2D tušové proudnice za špičkami křídel místo trhaných úseček.

---

### Priorita #5 — Kompletní přestavba Vnitřku Krčmy (`scripts/battle_table_3d.gd` + `scripts/battle/tavern_scene_builder.gd`)

*(Sdílený pipeline pro Kampaň i Multiplayer — „posunout vnitřek na jiný level“)*

1. **Detailní živý oheň (Krb, svíčky, lucerny):**
   - *Diagnostika:* `_spawn_tavern_hearth()` v `battle_table_3d.gd` i `tavern_scene_builder.gd` dnes **nemá vůbec žádné plameny** — pouze oranžový materiál na `hearthembercore` a `OmniLight3D` bez stínů! Svíčky na stole jsou statické žluté `SphereMesh` kuličky.
   - *Plán:* Nový multi-vrstvý shader ohně (`shaders/tavern_hearth_fire.gdshader` — scrolling fBM turbulence, teplotní přechod bílozlaté jádro -> jantar -> oranžová -> karmínové špičky, eroze a pohyb plamenných jazyků) + žhnoucí uhlíky (`shaders/ember_bed.gdshader`) + 6–8 prohnutých křížících se plamenných pásů v krbu + `GPUParticles3D` texturovaných jisker a jemného kouře stoupajícího do komína + **stíny vrhající mihotavé světlo krbu** (`shadow_enabled = true`) tančící po podlaze a zdi. Upgrade plamenů svíček na stole a nástěnných luceren na mini shaderové kapky ohně.
2. **Duch / Spirko — hlubší stíny a vyšší rozlišení (`_build_detailed_tutorial_ghost`):**
   - *Diagnostika:* Všechny GLB části ducha mají `cast_shadow = false`, `phantom_shader` (`battle_table_3d.gd` ř. 6125–6156) je plochá zářící tyrkysová bez temných stínů v záhybech látky a bez textur, lebka (`ghost_skull.glb`) je bez textury a kolem létá 12 `SphereMesh` koulí.
   - *Plán:* Vyšší rozlišení modelů `ghost_shroud.glb`, `ghost_skull.glb`, `ghost_jaw.glb`, `ghost_hand_l.glb`, `ghost_hand_r.glb` + 1024×1024 ručně inkované textury (popraskaná slonovina lebky, hluboké stínované očnice, roztrhané tkané sukno kápě s normal/roughness mapou). Nový chiaroscuro shader (`shaders/spirit_chiaroscuro.gdshader`) kombinující **hluboké tmavé stíny a šrafování v záhybech látky** (reagující na reálné teplé/studené světlo krčmy) s chladným spektrálním Fresnel obrysem + měkký stín/mlžná louže pod duchem + výměna `SphereMesh` wispů za texturované mlhové stuhy.
3. **Osvětlení z oken (krásné světlo, čistý jednoduchý výhled ven):**
   - *Diagnostika:* Okna mají jen plochou modrou tabulku, `OmniLight3D` bez stínů a hranaté `BoxMesh` kapky; chybí světelné paprsky a vržené stíny rámů.
   - *Plán:* Venkovní pozadí zjednodušit na čistou malířskou atmosféru (měsíc/slunce/mlhavý obzor bez rušivé hranaté geometrie) a hlavní důraz dát na **světlo uvnitř**:
     - Šikmé **objemové světelné paprsky (god-rays)** (`shaders/window_godray.gdshader`) prostupující z obou gotických oken zakouřenou krčmou na podlahu a okraj stolu.
     - Nahradit `OmniLight3D` směrovými **stíny vrhajícími `SpotLight3D`** procházejícími skrz gotické mřížování okna, aby na podlahu a sudy dopadal reálný vzor světla a stínu okenních příček.
     - Nový shader okenního skla (`shaders/tavern_window_glass.gdshader`) se stékajícími kapkami deště / refrakcí v bouřce a měkkým zářícím halem na okraji skla.
     - Výměna `SphereMesh` prachových částic za jemné podsvícené billboard částice `GPUParticles3D` viditelné hlavně v kuželech světla z oken a lustru.
4. **Celkové detaily vnitřku a materiálová hloubka (včetně stropního háku / lustru):**
   - Přidat **Normal + Roughness + AO mapy (1024×1024)** pro kamenné zdi, dubové trámy, kamennou podlahu, koberec a sametový stůl.
   - Detailní kovaný stropní **hák + řetěz lustru** (`tavern_chandelier.glb`) se svíčkami s opravdovými shaderovými plameny a vrstveným kuželem světla; kovaný krbový hák / kotlík, pohrabáč a stojan na polena u krbu.
   - Víc živých krčmových detailů: zkosené kamenné ostění, dřevěné konzole trámů, pavučiny v rozích stropu, zavěšené bylinky/korbely nad barem, různorodé vymodelované lahve na policích (ne stejné válce), dřevěné lavice, nástěnné vyhlášky/pergameny a vyvážený `WorldEnvironment` (ACES tonemapping, selektivní Bloom na oheň/měsíc/runy, hluboký kontrast teplého ohně vs chladného měsíčního světla).

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
