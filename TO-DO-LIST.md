# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly

- [ ] **Bug v tutoriálu (Krok 6/7 — chybí karta `SPEC_VAMPIRE`):**
  - V Kroku 6/7 tutoriál vyžaduje zahrání speciální karty `Vampire Leech (SPEC_VAMPIRE)`, ale hráč ji nemá v ruce (a lízání z balíčku je zablokované hláškou *"No need to draw — follow the highlighted task above!"*), takže tutoriál nejde dokončit.
  - Zajistit v `scripts/battle_table_3d.gd`, aby se při vstupu do Kroku 6/7 `SPEC_VAMPIRE` spolehlivě přidala do ruky a přestavěl se 3D vějíř karet.

- [ ] **Přesunout tlačítko `✕ Cancel` (`MapExitBtn`):**
  - Aktuálně koliduje / schovává se za horním panelem tutoriálu uprostřed.
  - Přesunout ho dolů doleva (ideálně vedle Ducha), aby nikde nepřekáželo ani se neschovávalo.

- [ ] **Překryv 3D Meče (wager itemů) a balíčku karet na stole:**
  - Při vsazení meče se 3D Meč překrývá s tahacím balíčkem na oranžové podložce.
  - Přesunout vsazený meč (a případné další wager itemy) níže na stůl **pod oranžovou podložku**, mimo kolizi s balíčkem karet.
