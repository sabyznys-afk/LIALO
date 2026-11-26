# LIALO v0.198 — Master `/goal` Plan: Pravé 3D Dynamické Power Karty (15/15) + Oprava & Detail Všech Relikvií

> **Stav dokumentu:** POUZE PLÁN (0 % kódu změněno v tomto commitu). Připraveno pro exekuci přes `/goal` za použití více paralelních agentů.
> **Referenční etalon kvality:** `TRELIC_WAR_HORN.glb` (Tavern Ale Tankard / Krčmový korbel piva, `409 932 B` v `assets/models/relics/`, generátor `tools/generate_tankard_relic.py`).

---

## 1. Filozofie & 4 Neporušitelné Zákony v0.198 („Žádné 2D placky, nic statického!“)

### Zákon #1 — Pravé 3D sochařské hero modely (konec 2D papírových kvadrátů při orbitu kamery)
- **Diagnostikovaný bug:** `_make_25d_diorama()` ve `scripts/battle/power_card_vfx_showcase.gd` vykresluje hlavní symbol Power karty (kalich, bouřkové kopí, fénix, zrcadlo) na plochý 2D `QuadMesh`. Jakmile kamera obíhá kolem stolu ze strany (`45°–90°`), objekt se zplošťuje a ohýbá jako papírová vystřihovánka.
- **Řešení:** Každý centrální hero objekt všech 15 Power karet musí být **pravý vícedílný 3D `.glb` model** v kvalitě `TRELIC_WAR_HORN.glb` se 1024×1024 ručně inkovanými texturami, materiálem `shaders/handdrawn_relic_3d.gdshader` + `shaders/handdrawn_outline_3d.gdshader` a kloubovými uzly (rigem), aby držel plný objem ze všech 360° bočních, nízkých i horních pohledů.
- **Role 2D/2.5D efektů:** Ručně kreslené 2D/2.5D vrstvy se nadále používají výhradně tam, kde fyzikálně dávají smysl — kaligrafické dopadové oblouky (cel-slashe), ručně kreslené jiskry (`ink_sparks_sheet`), kouřové víry a runové kruhy/dekaly na stole, **nikdy ne pro hlavní pevný 3D objekt**.

### Zákon #2 — Fyzikální logika & 0 % zapečených statických efektů (*Zero Baked Static VFX Law*)
- Na žádném 3D modelu ani na jeho textuře **nesmí být staticky namalovaný kouř, blesky, oheň, tekutina, pírka, stuhy ani kapky**. Vše, co se v realitě hýbe, musí být samostatná dynamická geometrie/shader řízený fyzikou a časem `t`:
  - **Tekutiny (`SPEC_VAMPIRE`, `SPEC_ALCHEMIST`, `SPEC_MIDAS`, `SPEC_CROWN`, `TRELIC_BLOOD_SEAL`, `TRELIC_WAR_HORN`):** Žádný statický ztuhlý kopec ani nehybné kapky na okraji. Každá tekutina má **dynamický 3D mesh hladiny** s vertex šploucháním/vlněním reagujícím na pohyb a náraz poháru + **samostatné 3D kapky a přetékající proudy** s gravitací, pádem a rozstřikem na desce stolu.
  - **Kouř, blesky & pírko (`SPEC_STORM`, `TRELIC_CENSER`, `TRELIC_STAR_BOW`):** Kopí `power_storm_spear.glb` musí být čistý kovaný 3D model bez zapečeného kouře, bez namalovaných modrých blesků a bez pevného pírka na čepeli.
    - *Kouř/mlha:* Živý scrolling volumetric/ribbon shader obtékající ratiště v reálném čase.
    - *Blesky:* Procedurálně větvené a přeskakující 3D elektrické výboje mezi hrotem, runami a stolem + ručně kreslené bleskové jiskry.
    - *Pírko / střapec na čepeli:* Nezávislý kloubový nebo vertex-wind fyzikální mesh vlající v nárazovém větru bouře.
  - **Oheň, křídla, látka & mechanika (`SPEC_PHOENIX`, `SPEC_CHRONOS`, `SPEC_JESTER`, `SPEC_SOUL_BELL`):** Křídla mají kloubové mávání, plameny živě olizují peří, řetězy/zvon/rolničky se kyvadlově houpou a ozubená kola astrolábu se točí v přesném převodu bez prokluzování.

### Zákon #3 — Proměna Celého Prostředí Krčmy (`TavernRealityShiftController`)
- Power karta nesmí hrát „ve vzduchoprázdnu“ nad běžným stolem. Každá z 15 karet musí po dobu své manifestace dočasně přeměnit **skutečný interiér 3D krčmy kolem stolu** (kamenné stěny, intenzitu světla a soumrak, krb, okna, strop, povrch dubového stolu i částice ve vzduchu) a na konci plynule vrátit krčmu do normálu.
- **Nová sdílená architektura:**
  - `scripts/battle/tavern_reality_shift.gd` (`TavernRealityShiftController`): deterministicky řízený z normalizovaného času `t` (funguje totožně v boji SP/MP i v `PowerCardVfxShowcase` / `DevAssetInspector` bez kumulativního driftu).
  - `shaders/tavern_wall_shift.gdshader`: shader překryvu/deformace pro stěny, okna a podlahu krčmy s parametry `shift_mode`, `shift_amount`, `time_sec`, `drip_speed`, `tint_color`:
    - *Dripping Blood & Dusk* (stékající/kapající temná krev po kamenných zdech + prudké stmívání krčmy a zhasínání krbu — `SPEC_VAMPIRE`)
    - *Tempest Blackout & Lightning Windows* (bleskové záblesky v gotických oknech, bouřková mračna místo stropu, šikmý déšť uvnitř — `SPEC_STORM`)
    - *Voronoi Mirror Fracture* (stříbrné fraktální praskliny po zdech & studená zrcadlová mlha — `SPEC_MIRROR`)
    - *Alchemy Mandala & Emerald Steam* (zářící rytá mandala přes stůl a zdi, stoupající smaragdová pára — `SPEC_ALCHEMIST`)
    - *Cinder Embers & Scorched Stone* (žhnoucí praskliny ve zdech, žhavý popel, uhlíkové žíly — `SPEC_PHOENIX`)
    - *Molten Gold Veins* (`SPEC_MIDAS`), *Chronos Frozen Sepia* (`SPEC_CHRONOS`), *Astral Constellations* (`SPEC_ORACLE`), *Cabaret Dutch Dusk* (`SPEC_JESTER`), *Crawling Shadow Roots* (`SPEC_HEX`), *Magnetic Pulse Waves* (`SPEC_MAGNET`), *Bastion Light Pillars* (`SPEC_SHIELD`), *Smoky Gambler Spotlight* (`SPEC_GAMBLER`), *Crawling Frost & Rime Ice* (`SPEC_PLAGUE`), *Royal Throne Room Banners* (`SPEC_CROWN`).

### Zákon #4 — Tankard Standard & Bezchybné Vodotěsné Textury Relikvií (0 průhledných děr)
- Každý `.glb` model relikvie i Power karty musí před exportem v Python generátoru projít striktním automatickým validátorem `validate_mesh_winding_and_uvs()` (kontrola orientace trojúhelníků vůči normálám, kontrola uzavřenosti/tloušťky stěn u dutých nádob, zákaz nulových/degenerovaných ploch a UV mimo rozsah) + vizuální kontrolou přes RTX GPU **3-angle + close-up sheet** bez jediné průhledné díry či artefaktu.

---

## 2. Kompletní Plán Všech 15 Power Karet (`LialoCatalog.POWER_CARDS[0..14]`)

> **Jednotná 5-aktová multi-kamera struktura (5.8–6.2s, deterministicky z `t`):**
> *Akt I (0.0–1.0s):* Úzký záběr na sesilatele a probouzející se kartu + aura zbraně -> *Akt II (1.0–2.4s):* Široký záběr na proměnu celé krčmy (`TavernRealityShiftController`) -> *Akt III (2.4–3.9s):* 360° boční/nízký orbit kolem **pravého 3D hero modelu** a fyzikálních dynamických efektů -> *Akt IV (3.9–4.9s):* Klimax a zásah soupeře + ink Impact Frame -> *Akt V (4.9–6.0s):* Doznění kapek/popela/střepů a plynulý návrat krčmy.

1. **`SPEC_VAMPIRE` (Vampire Leech / Upíří pijavice)**
   - **Pravý 3D Hero Model:** `power_vampire_chalice.glb` — kovaný gotický pohár s plastickými žebry, osazenými 3D broušenými rubíny v drápkových lůžkách a samostatným rotujícím 3D runovým prstencem zatmění za pohárem (čistá 3D geometrie z každého úhlu, žádné ohýbání 2D placky).
   - **Dynamické fyzikální prvky:** Živá 3D hladina krve v číši s vlněním a šploucháním podle náklonu poháru; samostatné 3D kapky a tenké proudy krve přetékající přes okraj a dopadající na stůl; 12 kloubových 3D/2.5D netopýrů s reálným máváním křídel proletujících okolo; pulzující odlesky rubínů.
   - **Proměna Krčmy:** Celá krčma se prudce **setmí do hlubokého karmínového soumraku**, oheň v krbu pohasne a **po všech kamenných stěnách krčmy začne stékat a kapat hustá temná krev** (`tavern_wall_shift.gdshader`), přes dubový stůl vyraší krvavé trny.

2. **`SPEC_STORM` (Thunder Strike / Úder blesku)**
   - **Pravý 3D Hero Model:** `power_storm_spear.glb` — čisté kované 3D nebeské kopí se středovým žebrem, runovou záštitou a kovovým ratištěm (**nulový zapečený kouř, nulové namalované blesky, nulové statické pírko na čepeli**).
   - **Dynamické fyzikální prvky:** Samostatný fyzikálně animovaný střapec s pírkem pod hrotem divoce vlající ve větru; živý objemový vířící kouř/mlha obtáčející kopí v reálném čase; procedurálně větvené 3D elektrické výboje skákající po čepeli do stolu + 32 ručně kreslených 2.5D bleskových jisker.
   - **Proměna Krčmy:** Okna krčmy rozsvítí oslepující modrobílé záblesky blesků, strop pohltí valící se bouřková mračna, uvnitř šlehá šikmý déšť kolem stolu a dřevo stolu ztmavne mokrým leskem se spáleným runovým kráterem.

3. **`SPEC_MIRROR` (Twin Mirror / Zrcadlo ozvěn)**
   - **Pravý 3D Hero Model:** `power_mirror_gate.glb` — monumentální 3D gotický dvojitý zrcadlový portál s plastickým kamenným a zlatým rámem, panty, rubovou stranou a 6 menšími zrcadly v kruhu.
   - **Dynamické fyzikální prvky:** Hladina skla vlnící se jako tekutá rtuť; při klimaxu se zrcadla roztříští na 40+ pravých 3D fasetovaných rotujících střepů se stříbrným leskem.
   - **Proměna Krčmy:** Stěny i podlaha krčmy popraskají zářivými stříbrnými Voronoi trhlinami, světlo krbu přejde do studené stříbrno-azurové zrcadlové mlhy.

4. **`SPEC_ALCHEMIST` (Gold Transmuter / Alchymista)**
   - **Pravý 3D Hero Model:** `power_alchemist_crucible.glb` — kovaný mosazno-skleněný alchymistický kelímek s měděnými trubkami, ventily a 2 protichůdně se točícími 3D prstenci zvěrokruhu.
   - **Dynamické fyzikální prvky:** Dynamicky vřící a přetékající smaragdový elixír uvnitř skla (vyskakující kapky), husté stoupající alchymistické dýmy a proud tekutého zlata přetavující kartu v ruce.
   - **Proměna Krčmy:** Přes celý stůl i kamennou podlahu krčmy se zažehne svítící alchymistická mandala, zdi zahalí smaragdově-zlatá pára.

5. **`SPEC_PHOENIX` (Ash Phoenix / Fénix z popela)**
   - **Pravý 3D Hero Model:** `power_ash_phoenix.glb` — kloubový 3D Fénix s vymodelovaným trupem, drápy a oddělenými leteckými články křídel (`WingL_In/Out`, `WingR_In/Out`, `TailPlumes`) bez namalovaných statických plamenů.
   - **Dynamické fyzikální prvky:** Silné kloubové mávání 3D křídel, živý shaderový oheň olizující peří a ocas, 40+ hořících rotujících per a žhavý popel unášený průvanem křídel.
   - **Proměna Krčmy:** Kamenné stěny krčmy se rozžhaví uhlíkovými žilami, krb vzplane do bílého žáru, vzduch zaplní hustý vír stoupajících žhavíků.

6. **`SPEC_MIDAS` (Midas Touch / Midasův dotek — #1 priorita nové desítky)**
   - **Pravý 3D Hero Model:** `power_midas_gauntlet.glb` — vysoce detailní 3D kloubová zlacená rytířská rukavice s rytou manžetou a přetékajícím pokladovým kalichem.
   - **Dynamické fyzikální prvky:** Prsty rukavice se nad kartou sevřou; z dlaně kape a stéká živé roztavené zlato (dynamický fluid mesh + kapky); sprcha 35+ 3D ražených zlatých florinů dopadajících a poskakujících po stole.
   - **Proměna Krčmy:** Po stole a kamenných stěnách krčmy se rychle rozlévají zářící zlaté žíly, teplý zlatý odlesk pohltí celou místnost a vzduchem tančí zlaté šupinky.

7. **`SPEC_CHRONOS` (Chronos Glass / Přesýpací hodiny)**
   - **Pravý 3D Hero Model:** `power_chronos_astrolabe.glb` — mosazný 3D astroláb s centrálními křišťálovými hodinami, 4 nezávisle rotujícími ozubenými prstenci a ručičkami.
   - **Dynamické fyzikální prvky:** Proud zlatých zrnek písku se náhle zastaví ve vzduchu a obrátí se **vzhůru proti gravitaci**; prstence se prudce přetočí pozpátku; kolem plují zmrazené kapky a časové krystaly.
   - **Proměna Krčmy:** Celá krčma zamrzne v sépiově-stříbrném bezčasí (plamen krbu i prach v okenních paprscích se úplně zastaví), po zdech kloužou obří stíny hodinových kol.

8. **`SPEC_ORACLE` (Seer's Eye / Oko věštce)**
   - **Pravý 3D Hero Model:** `power_oracle_eye.glb` — 3D oční bulva zasazená do zlatého slunečního prstence s pohyblivými kovovými víčky a otáčejícími se runovými disky.
   - **Dynamické fyzikální prvky:** Víčka se rozevřou, krystalická zornice se rozšíří a otočí přímo k soupeři; ze zornice vyrazí dynamické světelné paprsky odhalující soupeřovy karty + plovoucí inkoustové glyfy.
   - **Proměna Krčmy:** Na stěnách krčmy se rozsvítí mapa nebeských souhvězdí, místnost ztmavne do smaragdově-tyrkysové mlhy a světelný kužel ozáří soupeřovu stranu.

9. **`SPEC_JESTER` (Tavern Jester / Krčmový šašek)**
   - **Pravý 3D Hero Model:** `power_jester_mask.glb` — prostorová 3D šaškovská maska s třírohou čapkou, zavěšenými mosaznými rolničkami a žezlem chaosu.
   - **Dynamické fyzikální prvky:** Rolničky a cípy čapky se fyzicky kývají a zvoní při pohybu masky; kolem stolu víří hurikán 3D ohnutých hracích karet a diamantových konfet.
   - **Proměna Krčmy:** Osvětlení přejde do purpurově-zlatého kabaretu se záludným náklonem kamery, po stěnách krčmy tančí obří groteskní stíny šaška.

10. **`SPEC_HEX` (Shadow Hex / Kletba stínu)**
    - **Pravý 3D Hero Model:** `power_hex_grimoire.glb` — těžký 3D kovaný grimoár se zámkem, otvíracími deskami a železnými řetězy.
    - **Dynamické fyzikální prvky:** Řetězy prasknou, kniha se rozevře, stránky víří a z vazby vylézají živé 3D stínové trnové úpony směřující k soupeři.
    - **Proměna Krčmy:** Krčma zčerná fialovo-černou stínovou mlhou, po kamenných zdech šplhají pohyblivé tmavé kořeny a pulzující fialové kletbové znaky.

11. **`SPEC_MAGNET` (Rune Magnet / Runový magnet)**
    - **Pravý 3D Hero Model:** `power_rune_magnet.glb` — kovaná 3D runová podkova z černé oceli a měděných cívek s pólovým žárem.
    - **Dynamické fyzikální prvky:** Podkova vibruje magnetickým rázem; mezi ní a balíčkem vznikají dynamické 3D magnetické siločáry a létající jiskry přitahující 2 karty do ruky.
    - **Proměna Krčmy:** Drobné kovové předměty a prach v krčmě se rozvibrují ke středu stolu, stěnami projíždějí ocelově-azurové vlny magnetického pole.

12. **`SPEC_SHIELD` (Iron Bastion / Železná bašta)**
    - **Pravý 3D Hero Model:** `power_iron_bastion.glb` — dva monumentální nýtované 3D rytířské pavézy se zlacenými erbovními kříži a podstavci.
    - **Dynamické fyzikální prvky:** Štíty s těžkým nárazem zapadnou do dubu (vyrazí 3D třísky a jiskry), po oceli přeběhne živá zlatá runová bariéra.
    - **Proměna Krčmy:** Kolem hráčovy poloviny stolu a zadních pilířů krčmy vyrostou ochranné ocelově-zlaté sloupy světla.

13. **`SPEC_GAMBLER` (Loaded Dice / Cinknuté kostky)**
    - **Pravý 3D Hero Model:** `power_gambler_dice.glb` — dvě obří 3D vyřezávané kostěné kostky se zlatým intarzováním + 3D mosazné kolo štěstěny.
    - **Dynamické fyzikální prvky:** Kostky se reálně dynamicky kutálejí, odskakují od desky stolu se jiskrami a na zlomek sekundy se „cinknutě“ dotočí na šestku/eso; kolo zapadne do násobiče.
    - **Proměna Krčmy:** V hlubokém kouřovém šeru krčmy se nad stolem rozsvítí ostrý „hazardní“ kužel lucerny a stěny odrážejí zlatý třpyt žetonů.

14. **`SPEC_PLAGUE` (Frost Blight / Mrazivá zhouba)**
    - **Pravý 3D Hero Model:** `power_frost_plague.glb` — 3D morová doktorská maska s křišťálovými čočkami, koženými popruhy a mrazovou korunou.
    - **Dynamické fyzikální prvky:** Z zobáku uniká těžká ledová mlha plazící se po stole; ze stolu dynamicky vyrůstají 3D rampouchy a ledové krystaly obalující soupeře.
    - **Proměna Krčmy:** Celá krčma zamrzne — teplý krb zbledne do ledové modři, **po kamenných zdech i oknech rychle naroste jinovatka a ledové květy**, vzduchem padá sníh.

15. **`SPEC_CROWN` (Royal Decree / Královský glejt)**
    - **Pravý 3D Hero Model:** `power_royal_crown.glb` — imperiální 3D koruna se vsazenými drahokamy, sametem a zkříženými žezly + rozbalující se svitek.
    - **Dynamické fyzikální prvky:** Koruna sestupuje v proudu zlatého prachu, žezla se zaklesnou, na pergamen skápne horký červený pečetní vosk (fluid kapky) a drahokamy vrhají paprsky světla.
    - **Proměna Krčmy:** Krčma se promění ve slavnostní trůnní síň — ze stropu proniknou zlaté god-rays, na zdech se rozvinou iluzorní královské karmínové prapory.

---

## 3. Hloubkový Audit & Plán Opravy VŠECH Relikvií (0 Průhledných Děr + Tankard Detail)

### A. Diagnostikované Root Causes bugnutých textur a detailu
1. **Bug R1 — Převrácené normály & winding u dutých profilů (`tools/generate_all_handdrawn_relics.py`):**
   - `add_lathe()` (ř. 111–113) počítá radiální normálu vzorcem `nr, ny = dy / ln, -dr / ln`, což platí jen pro striktně stoupající `+Y` profily. U dutých, zahnutých nebo sestupných úseků (`TRELIC_BLOOD_SEAL` vnitřní lem číše ř. 769–770, `TRELIC_SOUL_BELL` spodní lem a vnitřní klenba zvonu ř. 996–1015, `TRELIC_HOLLOW_MASK` kožený pohár) způsobí následné `finalize_mesh()` (`weld_positions=True` + `enforce_outward_winding_from_normals()`) otočení části trojúhelníků dovnitř -> `cull_back` v `handdrawn_relic_3d.gdshader` je nevykreslí a **plocha zeje průhlednou dírou**.
2. **Bug R2 — Průsak `cull_front` obrysu (`shaders/handdrawn_outline_3d.gdshader`):**
   - U tenkostěnných dílů nebo švů se špatnou normálou (`BronzeBell` lem, `GobletBody` ústí, `CenserChains`, `CopperWire`) prosvítá černý zadní obrysový pass přímo skrz přední plochu.
3. **Bug R3 — Rozbitá průhlednost skla u `TRELIC_ASH_GLASS` (`scripts/relic_mesh_factory.gd` ř. 233–244):**
   - `glass_mat` používá `TRANSPARENCY_ALPHA` + `CULL_DISABLED` + `DEPTH_DRAW_DISABLED`, takže baňky hodin mizí nebo problikávají přes písek a mosazné sloupky. Náprava: nový dedikovaný dvoufázový Fresnel glass shader `shaders/handdrawn_glass_3d.gdshader`.
4. **Bug R4 — Zastaralé nízkopolygonové modely 8 pasivních Core Relikvií (`REL_*`):**
   - `REL_PHOENIX_F.glb` (`12.8 KB`), `REL_GREED.glb` (`23.7 KB`), `REL_ALEMBIC.glb` (`26.5 KB`), `REL_KNUCKLE.glb` (`33.1 KB`), `REL_CHAMOIS.glb` (`44.1 KB`), `REL_FUJARA.glb` (`44.9 KB`), `REL_STORMCAP.glb` (`45.2 KB`), `REL_FANG.glb` (`49.3 KB`) jsou o řád jednodušší než `TRELIC_WAR_HORN.glb` (`410 KB`) a nepoužívají jednotný Tankard standard.
5. **Bug R5 — Chybějící validace vodotěsnosti a Normal mapy:**
   - Do `export_glb()` chybí kontrola uzavřenosti/windingu (`validate_mesh_winding_and_uvs()`) a v `handdrawn_relic_3d.gdshader` chybí volitelná `normal_tex` mapa pro vyryté reliéfy bez nutnosti extrémního polycountu.

### B. Přestavba Všech 10 Stolních Relikvií (`TABLE_RELICS`) na Tankard Standard (`~300–450 KB`)
1. **`TRELIC_WAR_HORN` (Tavern Ale Tankard — etalon):** Zachovat referenční model, doplnit kapající dynamickou pěnu na okraji a normal mapu na dubové dužiny.
2. **`TRELIC_SOUL_BELL` (Graveyard Toll Bell — top priorita opravy):** Samostatná vodotěsná vnější a vnitřní stěna zvonu s tlustým profilovaným lemem (0 průhledných děr!), gotické reliéfy a nápisy na plášti zvonu, hluboká prasklina se žhnoucím jádrem, kovaná šibenice se šrouby a řetězem, živě se houpající 3D zvon + kouř z praskliny.
3. **`TRELIC_BLOOD_SEAL` (Crimson Blood Goblet — top priorita opravy):** Opravit horní lem číše na čistý uzavřený profil, vysochat filigránovou gotickou stopku a drápky kolem 4 broušených rubínů, nahradit statické krápníky vína **dynamickou vlnící se hladinou + kapajícími 3D kapkami krve** a vlající voskovou pečetí.
4. **`TRELIC_STAR_BOW` (Arcane Slate Rune — top priorita opravy):** Vícevrstvá štípaná břidlice s ostrými sraženými hranami, hluboko vysekané 3D runové drážky se světelným shaderem, kované svorky bez průsaku černého obrysu a živé elektrické jiskry kolem 3 plujících krystalů.
5. **`TRELIC_ASH_GLASS` (Fate Hourglass):** Nahradit rozbité `glass_mat` za `handdrawn_glass_3d.gdshader`, přidat vyřezané zvěrokruhové reliéfy na horní/dolní desku, kapitely sloupků a animovaný proud padajících zlatých zrnek písku.
6. **`TRELIC_HOLLOW_MASK` (Loaded Bone Dice):** Opravit vnitřní stěnu koženého pohárku na kostky (čistý uzavřený double-wall mesh), ručně inkované švy a cvočky, prohloubené ošoupané kostky + zlatý záblesk při hodu.
7. **`TRELIC_CENSER` (Alchemist's Ember Censer):** Skutečné vyřezávané gotické otvory v kouli kadidelnice s tloušťkou stěny (bez backface děr), článkované houpající se řetězy, žhavé 3D uhlíky (`ember_bed.gdshader`) a živý stoupající dým.
8. **`TRELIC_GOLD_SCALES` (Guild Coin Purse):** Plastické záhyby kůže, výrazné stehy, kovaná spona měšce, hluboko ražené erby na každém z 14 zlaťáků (normal + ink albedo) a dynamický odlesk zlata.
9. **`TRELIC_IRON_CHAIN` (Executioner's Whetstone):** Čepovaný dubový stojan s kovovými úhelníky a hřeby, viditelně vybrousený žlábek v žule, detailní damašková dýka s drátovanou rukojetí + dynamické jiskry při broušení.
10. **`TRELIC_PHOENIX_BOX` (Phoenix Ember Reliquary):** Propracované kovové panty, klíčová dírka, reliéfní křídla po obvodu truhličky, pootevřené víko s žhnoucím ohnivým jádrem uvnitř a živě stoupajícími uhlíky.

### C. Upgrade 8 Pasivních Core Build Relikvií (`RELICS`)
- Vlastní 4 zastaralé legacy modely nahradit plnohodnotnými Tankard-grade `.glb` modely (`250–400 KB`) s 1024px ručně inkovanými texturami:
  - `REL_FINAL_TOLL` (*Katova přísaha* — nahradit `REL_PHOENIX_F.glb`): Kovaná popravčí dýka / sekera zapíchnutá do dubového špalku se zpečetěným pergamenem.
  - `REL_IRON_BOOT` (*Královské holeně* — nahradit `REL_KNUCKLE.glb`): Nýtované rytířské plátové holennice se zlatým lemem a heraldickým štítkem.
  - `REL_SEVEN_GRIMOIRE` (*Grimoár sedmiček* — nahradit `REL_CHAMOIS.glb`): Otevřený kovaný grimoár s mosaznými rohy, voskovou pečetí a římským číslem VII.
  - `REL_FANG` (*Stínový tesák* — nahradit `REL_FANG.glb`): Obří rituální tesák v kovové objímce zakousnutý do krvavého runového podstavce.
- Zbylé 4 Core Build Relikvie (`REL_FORGEMASTER`, `REL_ROYAL`, `REL_GREED`, `REL_OVERCHARGE`) po přestavbě svých mateřských stolních modelů (`TRELIC_IRON_CHAIN`, `TRELIC_BLOOD_SEAL`, `TRELIC_GOLD_SCALES`, `TRELIC_CENSER`) automaticky zdědí opravený bezchybný 3D detail (případně dostanou drobné vizuální variace kovů).

---

## 4. Multi-Agent `/goal` Exekuční Plán (5 Fází + QA Brány)

| Fáze | Paralelní Agenti & Odpovědnost | Výstup & Tvrdá QA Brána |
|---|---|---|
| **Fáze 0 — Core Engine & Validátory** | **Agent A (Geometry & Shaders):** Opravit `add_lathe()`, přidat `validate_mesh_winding_and_uvs()` v `generate_tankard_relic.py`, napsat `shaders/handdrawn_glass_3d.gdshader`, rozšířit `handdrawn_relic_3d.gdshader` o `normal_tex`.<br>**Agent B (Tavern Reality Shift):** Vytvořit `scripts/battle/tavern_reality_shift.gd` + `shaders/tavern_wall_shift.gdshader` pro deterministickou proměnu stěn/světla/oken krčmy. | Žádný export neprojde bez `0 winding/UV errors`; Reality Shift přepíná testovací režimy bez erroru. |
| **Fáze 1 — Relikvie (Oprava & Detail)** | **Agent C:** Resculpt `TRELIC_SOUL_BELL`, `TRELIC_BLOOD_SEAL`, `TRELIC_STAR_BOW`, `TRELIC_ASH_GLASS`, `TRELIC_HOLLOW_MASK`.<br>**Agent D:** Resculpt `TRELIC_CENSER`, `TRELIC_GOLD_SCALES`, `TRELIC_IRON_CHAIN`, `TRELIC_PHOENIX_BOX` + 4 legacy `REL_*`.<br>**Agent E (GPU QA):** 3-angle + close-up bottom-lip GPU render všech relikvií. | **0 průhledných děr**, každá relikvie dosahuje ostrosti & detailu `TRELIC_WAR_HORN`. |
| **Fáze 2 — Vlajkové Power Karty #1–#4 v Pravém 3D** | **Agent F (3D Hero Sculptor):** Čisté 3D `.glb` (`Vampire Chalice`, `Storm Spear`, `Mirror Gate`, `Alchemist Crucible`, `Ash Phoenix`) bez zapečených VFX.<br>**Agent G (Physics & Reality Shift):** Dynamické tekutiny (šplouchání + kapání), vlající pírko, objemový kouř, 3D blesky, 3D střepy + plná proměna krčmy (vč. stékající krve a soumraku).<br>**Agent E (GPU QA):** Front + **60° boční orbit** + pohled na stěny krčmy. | Důkaz z bočního úhlu, že se nic neohýbá jako 2D papír a stěny/světlo krčmy se mění. |
| **Fáze 3 — Zbývajících 10 Power Karet po Dávkách** | **Dávka 3A:** `SPEC_MIDAS`, `SPEC_CHRONOS`, `SPEC_ORACLE`<br>**Dávka 3B:** `SPEC_JESTER`, `SPEC_HEX`, `SPEC_MAGNET`<br>**Dávka 3C:** `SPEC_SHIELD`, `SPEC_GAMBLER`, `SPEC_PLAGUE`, `SPEC_CROWN`<br>(stejný 3-agentní pipeline na dávku + boční GPU kontrola) | 15/15 karet má čistý 3D model, dynamické efekty a unikátní proměnu krčmy. |
| **Fáze 4 — Finální Ověření & Release** | Kontrola VRAM/FPS v GL Compatibility rendereru, `--import --quit`, všech 4 automatických testů a finální čistý push. | `verify_ci_headless.gd`, `verify_progression_mp.gd`, `verify_battle_redesign.gd`, `verify_hearts_3d.gd` = `EXIT 0`. |

### Definition of Done (DoD) pro `/goal`
1. **15/15 Power karet** používá pravý 3D `.glb` hero model ověřený ze **60° bočního pohledu** (žádné ploché ohýbání 2D karet).
2. **15/15 Power karet** má **100 % dynamické** tekutiny (šplouchání, skákání, kapání), kouř, blesky, pírka, oheň a mechaniku (**0 statických efektů na textuře**).
3. **15/15 Power karet** viditelně proměňuje okolní **3D krčmu** (stěny, soumrak/světlo, okna, stůl).
4. **10/10 Stolních Relikvií + 8/8 Core Build Relikvií** má opravené normály/průhlednost (**0 děr**) a detail srovnatelný s pivním korbelem (`TRELIC_WAR_HORN`).
5. Všech **4/4 Godot testy** i GPU screenshoty každé dávky jsou zelené.
