# SwitCore - Sugestii Module Viitoare

Analiză bazată pe modulele existente. Organizat pe 3 niveluri de prioritate.

---

## P1 - Fundație Roleplay

Module care lipsesc complet și blochează experiența de roleplay de bază.

---

### `housing` - Sistem Proprietăți

**Descriere:** Jucătorii pot cumpăra/închiria apartamente și case. Fiecare proprietate are stocare personală, lockuri, posibilitate de a invita alte personaje.

**Integrare cu module existente:**
- `banking` - cumpărare, chirie lunară automată, credite ipotecare via `createLoan`
- `inventory` - stocare iteme în proprietate (stash separat per locuință)
- `proximity` - interacțiuni la ușă (intră, bate la ușă, scoate cheie)
- `characters` - locația de spawn după relog dacă personajul era acasă
- `blips` - blip pe hartă pentru proprietatea personajului

**Tabele DB principale:**
```sql
properties (id, label, type, coords JSONB, interior_coords JSONB, price, rent_price, max_occupants, is_for_sale, is_for_rent)
property_ownerships (id, property_id, character_id, ownership_type, monthly_rent, acquired_at, expires_at)
property_keys (id, property_id, character_id, key_type) -- owner, guest
property_stash (id, property_id, item_name, amount, slot, metadata JSONB)
```

**Exporturi minime:**
```lua
exports.housing:getCharacterHome(characterId)          → property
exports.housing:hasAccess(characterId, propertyId)     → bool
exports.housing:enterProperty(source, propertyId)
exports.housing:exitProperty(source)
```

**Dependențe:** `core`, `postgres`, `characters`, `banking`, `proximity`, `inventory`

---

### `phone` - Telefon În Joc

**Descriere:** Telefon NUI cu aplicații integrate: contacte, SMS/apeluri, app bancă, app taxi, GPS, notificări MDT. Fiecare personaj are un număr unic.

**Integrare cu module existente:**
- `banking` - app bancă în telefon (vizualizare sold, transfer rapid)
- `taxi` - comandă taxi prin app
- `mdt` - notificări MDT pe telefon pentru police/ems
- `notifications` - notificările de sistem apar ca push notification pe telefon
- `characters` - număr de telefon generat la crearea personajului

**Tabele DB principale:**
```sql
phone_numbers (character_id PK, number UNIQUE, is_active)
phone_contacts (id, owner_character_id, contact_character_id, display_name, is_blocked)
phone_messages (id, from_number, to_number, body, is_read, sent_at)
phone_call_logs (id, from_number, to_number, duration_seconds, started_at)
phone_apps (id, character_id, app_name, is_installed, app_data JSONB)
```

**Exporturi minime:**
```lua
exports.phone:getCharacterNumber(characterId)          → string
exports.phone:sendMessage(fromCharId, toNumber, body)  → bool
exports.phone:sendNotification(characterId, app, title, body)
exports.phone:isPhoneOpen(source)                      → bool
```

**Dependențe:** `core`, `postgres`, `characters`, `notifications`

---

### `clothing` - Haine & Aspect Personaj

**Descriere:** Magazin haine cu categorii (casual, formal, sport), salvare outfit-uri per personaj, aplicare automată uniformă la intrarea în duty pentru joburi.

**Integrare cu module existente:**
- `jobs` - uniformă automată la `is_on_duty = true`, restore la off-duty
- `banking` - plata hainelor prin cont sau cash
- `proximity` - interacțiune la NPC magazin
- `characters` - outfit salvat per personaj, restaurat la spawn

**Tabele DB principale:**
```sql
clothing_stores (id, name, coords JSONB, currency_code)
clothing_items (id, store_id, label, category, component_id, drawable, texture, price, vip_only)
character_outfits (id, character_id, name, components JSONB, is_active)
job_uniforms (job_name PK, grade, components JSONB) -- uniformă per grad
```

**Exporturi minime:**
```lua
exports.clothing:applyOutfit(source, outfitId)
exports.clothing:applyJobUniform(source, jobName, grade)
exports.clothing:restoreOutfit(source)
exports.clothing:getSavedOutfits(characterId)     → outfits[]
```

**Dependențe:** `core`, `postgres`, `characters`, `banking`, `proximity`, `jobs`

---

### `dispatch` - Sistem 911 & Dispecerat

**Descriere:** Cetățenii pot apela 911. Apelurile apar pe harta police/ems cu prioritate, locație, descriere. Include istoricul apelurilor și posibilitate de a prelua/închide un apel.

**Integrare cu module existente:**
- `police` - apelurile apar în MDT police cu blip pe hartă
- `ems` - apelurile medicale apar în MDT ems
- `mdt` - tab dedicat "Dispecerat" în MDT existent
- `blips` - blip temporar pe hartă la apel activ, dispare la preluare
- `phone` - apelul 911 se face din app telefon

**Tabele DB principale:**
```sql
dispatch_calls (id, caller_character_id, caller_number, call_type, description, coords JSONB, priority, status, assigned_unit_id, created_at, closed_at)
dispatch_units (id, character_id, job_name, unit_code, is_available, last_coords JSONB)
dispatch_call_log (id, call_id, character_id, action, note, created_at)
```

**Exporturi minime:**
```lua
exports.dispatch:createCall(characterId, callType, description, coords)  → callId
exports.dispatch:assignUnit(callId, characterId)
exports.dispatch:closeCall(callId, characterId, resolution)
exports.dispatch:getActiveCalls(jobName)                                  → calls[]
```

**Dependențe:** `core`, `postgres`, `characters`, `jobs`, `blips`, `mdt`

---

## P2 - Joburi & Economie

Module care extind sistemul de joburi și economia existentă.

---

### `trucking` - Transport Marfă

**Descriere:** Job legal de livrare marfă. Jucătorul preia o rută (origine → destinație), conduce camionul, primește plată per km parcurs și greutate. Include penalizări pentru daune vehicul.

**Integrare cu module existente:**
- `jobs` - `trucking` ca job whitelisted cu grade: șofer, dispatcher, manager
- `vehicles` - camioane din flotă cu urmărire `mileage` și `body_health`
- `banking` - salariu per livrare via `addCharacterCash`
- `inventory` - marfă ca item în inventarul camionului (stash vehicul)
- `mecanic` - uzura camionului după livrări

**Tabele DB principale:**
```sql
trucking_routes (id, name, origin_coords JSONB, destination_coords JSONB, distance_km, base_pay, cargo_type, is_active)
trucking_deliveries (id, character_id, route_id, vehicle_plate, started_at, completed_at, damage_penalty, final_pay, status)
trucking_fleet (id, vehicle_id, is_available, last_driver_id)
```

**Dependențe:** `core`, `postgres`, `characters`, `jobs`, `vehicles`, `banking`

---

### `fishing` - Pescuit

**Descriere:** Activitate liberă (free job) la locații de pescuit marcate. Jucătorul echipează undiță, așteaptă, prinde pești de raritate variabilă. Peștii se vând la NPC sau se procesează.

**Integrare cu module existente:**
- `inventory` - undița ca item usable, peștii ca iteme cu metadata (greutate, specie)
- `proximity` - interacțiune la punctele de pescuit
- `needs` - peștele gătit reduce foamea
- `shops` - NPC de cumpărat/vândut pește
- `banking` - plată la vânzare

**Tabele DB principale:**
```sql
fishing_spots (id, label, coords JSONB, fish_pool JSONB, is_active)
fishing_catches (id, character_id, spot_id, fish_name, weight_kg, caught_at)
fish_catalog (name PK, label, rarity, base_price, weight_min, weight_max)
```

**Dependențe:** `core`, `postgres`, `characters`, `inventory`, `proximity`, `banking`

---

### `farming` - Agricultură

**Descriere:** Jucătorii plantează culturi pe loturi închiriate, le udă/îngrijesc, recoltează ingrediente care alimentează sistemul de crafting și shops. Include procesare la mori/ferme.

**Integrare cu module existente:**
- `inventory` - semințe și recoltă ca iteme, apă din inventar
- `housing` sau loturi dedicate - teren de plantat
- `crafting` - recolta devine ingredient pentru rețete
- `shops` - vânzare recoltă la NPC
- `needs` - legumele/fructele reduc foamea

**Tabele DB principale:**
```sql
farm_plots (id, character_id, coords JSONB, rented_until, is_active)
farm_crops (id, plot_id, seed_name, planted_at, watered_at, growth_stage, ready_at)
crop_catalog (seed_name PK, label, grow_time_minutes, yield_item, yield_amount_min, yield_amount_max, water_interval_minutes)
```

**Dependențe:** `core`, `postgres`, `characters`, `inventory`, `banking`

---

### `crafting` - Fabricare Iteme

**Descriere:** Jucătorii combină ingrediente din inventar la workbench-uri pentru a fabrica iteme. Rețetele pot fi locked pe job sau nivel. Include progres animat și timp de fabricare.

**Integrare cu module existente:**
- `inventory` - consumă ingrediente, adaugă item fabricat
- `jobs` - rețete exclusive per job (ems fabrică medicamente, mecanic fabrică piese)
- `proximity` - interacțiune la workbench
- `farming` / `fishing` - ingrediente organice
- `needs` - mâncare fabricată

**Tabele DB principale:**
```sql
crafting_benches (id, label, coords JSONB, bench_type, required_job)
crafting_recipes (id, bench_type, result_item, result_amount, craft_time_seconds, required_job, required_grade)
recipe_ingredients (recipe_id, item_name, amount)
crafting_logs (id, character_id, recipe_id, bench_id, crafted_at)
```

**Exporturi minime:**
```lua
exports.crafting:canCraft(characterId, recipeId)     → bool, reason
exports.crafting:craftItem(characterId, recipeId)    → bool
exports.crafting:getRecipes(benchType, characterId)  → recipes[]
```

**Dependențe:** `core`, `postgres`, `characters`, `inventory`, `proximity`, `jobs`

---

### `real-estate` - Piața Imobiliară

**Descriere:** Agent imobiliar ca job. Proprietăți listate pentru vânzare/cumpărare între jucători. Include comision agent, evaluare proprietate, istoricul tranzacțiilor.

**Integrare cu module existente:**
- `housing` - extinde sistemul de proprietăți cu piață secundară
- `banking` - tranzacții mari prin credit ipotecar sau transfer bancar
- `jobs` - job `real_estate` cu permisiuni de listare/vânzare
- `blips` - proprietăți de vânzare marcate pe hartă

**Tabele DB principale:**
```sql
property_listings (id, property_id, seller_character_id, asking_price, listed_at, sold_at, buyer_character_id, agent_character_id, commission_rate)
property_valuations (id, property_id, appraised_value, appraised_by, appraised_at)
property_transaction_history (id, property_id, from_character_id, to_character_id, price, transaction_date)
```

**Dependențe:** `core`, `postgres`, `characters`, `housing`, `banking`, `jobs`, `blips`

---

## P3 - Sisteme Avansate & Progresie

---

### `radio` - Comunicare Radio

**Descriere:** Radio in-game cu frecvențe/canale. Police și EMS au canale rezervate și criptate. Civili pot comunica pe frecvențe publice. Interferat de zona geografică (range limitat).

**Integrare cu module existente:**
- `police` - canal police implicit la intrarea în duty
- `ems` - canal ems implicit
- `jobs` - canal per job la clock-in
- `inventory` - stație radio ca item necesar pentru civili

**Tabele DB principale:**
```sql
radio_channels (id, name, frequency, is_encrypted, password_hash, job_restricted, job_name)
character_radio_state (character_id PK, frequency, is_active, channel_id)
radio_transmissions_log (id, character_id, frequency, duration_seconds, transmitted_at)
```

**Exporturi minime:**
```lua
exports.radio:setCharacterFrequency(source, frequency)
exports.radio:getCharacterFrequency(source)      → frequency
exports.radio:isOnChannel(source, channelId)     → bool
```

**Dependențe:** `core`, `postgres`, `characters`, `jobs`

---

### `drugs` - Sistem Ilegal

**Descriere:** Cultivare, procesare și distribuție droguri ca activitate ilegală cu zone de risc. Include zone de cultivare controlate de factions, procesare la laboratoare, vânzare la NPC sau jucători.

**Integrare cu module existente:**
- `inventory` - semințe, droguri brute, droguri procesate ca iteme
- `jobs` - factions ilegale (ballas, lost_mc) au acces la zone și rețete
- `police` - confiscare la arrest via `inventory`, flag `is_drug` pe item
- `crafting` - procesarea folosește același sistem de crafting
- `medical` - efecte de adicție, supradoză ca boli în modulul `medical`

**Tabele DB principale:**
```sql
drug_zones (id, name, coords JSONB, radius, controlling_faction, last_captured_at)
drug_sales_points (id, coords JSONB, drug_name, buy_price, sell_price, is_active)
drug_transactions (id, character_id, drug_name, amount, transaction_type, price_per_unit, created_at)
```

**Dependențe:** `core`, `postgres`, `characters`, `inventory`, `jobs`, `crafting`

---

### `heists` - Jafuri

**Descriere:** Activități ilegale cu risc ridicat: jaf bancă, magazin, transport valori. Include faze (planificare, execuție, retragere), alertare automată police, cooldown per locație, împărțire reward.

**Integrare cu module existente:**
- `police` - alertă automată la dispatch, blip pe hartă
- `banking` - reward din seiful băncii via `orgWithdraw` sau reward direct
- `inventory` - bag de bani ca item, echipament necesar (drill, mască)
- `dispatch` - apel automat la police cu prioritate maximă

**Tabele DB principale:**
```sql
heist_locations (id, name, type, coords JSONB, reward_min, reward_max, cooldown_minutes, last_robbed_at, required_players)
heist_attempts (id, location_id, leader_character_id, participants JSONB, started_at, completed_at, reward_amount, was_successful)
heist_phases (id, location_id, phase_order, phase_type, duration_seconds, minigame_type)
```

**Dependențe:** `core`, `postgres`, `characters`, `police`, `banking`, `inventory`, `dispatch`

---

### `prison` - Sistem Pușcărie

**Descriere:** Extinde modulul `police` cu activități în pușcărie: muncă forțată (reduce sentința), celule, vizitatori, posibilitate de evadare cu cooldown și penalizare.

**Integrare cu module existente:**
- `police` - `JailCharacter` trimite în prison, sentința din arrests
- `jobs` - gardieni ca grad police cu permisiuni speciale
- `inventory` - confiscarea inventarului la intrarea în pușcărie, restituire la eliberare
- `needs` - mâncare servită în pușcărie la ore fixe
- `medical` - tratament medical de bază disponibil

**Tabele DB principale:**
```sql
prison_sentences (id, character_id, arresting_officer_id, crime_description, sentence_minutes, time_served, status, jailed_at, released_at)
prison_work_logs (id, character_id, work_type, minutes_reduced, completed_at)
prison_visitors (id, prisoner_character_id, visitor_character_id, visited_at, duration_minutes)
```

**Exporturi minime:**
```lua
exports.prison:jailCharacter(characterId, officerId, reason, sentenceMinutes)
exports.prison:releaseCharacter(characterId)
exports.prison:getRemainingTime(characterId)   → minutes
exports.prison:isJailed(characterId)           → bool
```

**Dependențe:** `core`, `postgres`, `characters`, `police`, `inventory`, `jobs`

---

### `achievements` - Realizări & Progresie

**Descriere:** Sistem de realizări per personaj: pescuit X pești, parcurs Y km, X livrări etc. Include XP per activitate, titluri, recompense (iteme, reduceri la shops, acces VIP temporar).

**Integrare cu module existente:**
- Toate modulele de activitate - hook pe evenimentele lor (livrare completă, pește prins etc.)
- `inventory` - recompense ca iteme
- `banking` - recompense monetare
- `hud` - afișare nivel XP și realizare nouă

**Tabele DB principale:**
```sql
achievement_definitions (id, name, label, description, category, xp_reward, item_reward, item_reward_amount, trigger_type, trigger_threshold)
character_achievements (id, character_id, achievement_id, progress, completed_at)
character_xp (character_id PK, total_xp, level, title)
xp_transactions (id, character_id, amount, source, description, created_at)
```

**Exporturi minime:**
```lua
exports.achievements:addProgress(characterId, triggerType, amount)
exports.achievements:getCharacterLevel(characterId)   → level, xp, title
exports.achievements:getUnlocked(characterId)         → achievements[]
```

**Dependențe:** `core`, `postgres`, `characters`, `notifications`

---

### `events` - Evenimente Server

**Descriere:** Panou admin pentru evenimente speciale: treasure hunt, course de mașini, asediu zonă, tombole. Include cronometru, reward pool, leaderboard temporar, anunț server.

**Integrare cu module existente:**
- `admin` - tab "Evenimente" în panoul admin
- `blips` - blip pentru locația evenimentului
- `banking` - prize pool din fondul organizatorului
- `notifications` - anunț la toți jucătorii la start/end
- `achievements` - participare eveniment ca trigger achievement

**Tabele DB principale:**
```sql
server_events (id, name, type, config JSONB, prize_pool, currency_code, started_by, started_at, ended_at, status)
event_participants (id, event_id, character_id, joined_at, score, rank)
event_rewards (id, event_id, character_id, reward_type, reward_amount, awarded_at)
```

**Dependențe:** `core`, `postgres`, `characters`, `admin`, `banking`, `blips`, `notifications`

---

### `minigames` - Minijocuri Refolosibile

**Descriere:** Librărie de minijocuri NUI reutilizabile de orice modul: lockpicking (skill check), hacking (grid puzzle), safecracking (dial combination), wire cutting. Exportă o funcție simplă cu callback success/fail.

**Integrare cu module existente:**
- `heists` - safecracking, hacking terminal
- `drugs` - hackuire sistem securitate la laborator
- `housing` - lockpicking la proprietate (dacă nu ai cheie)
- `police` - confiscare cu rezistență (minijoc pentru suspect)

**Exporturi minime:**
```lua
-- Apelat din client, callback cu result
exports.minigames:startLockpick(difficulty, callback)
exports.minigames:startHack(gridSize, callback)
exports.minigames:startSafecrack(combination, callback)
exports.minigames:startWireCut(wires, callback)
```

**Dependențe:** - (modul standalone, zero dependențe externe)

---

### `marketplace` - Piață Jucător-la-Jucător

**Descriere:** Jucătorii pot lista iteme din inventar la prețuri propuse. Alții cumpără async (nu trebuie să fie online simultan). Include taxă de listare, expirare automată, istoricul tranzacțiilor.

**Integrare cu module existente:**
- `inventory` - item scos din inventar la listare, adăugat cumpărătorului la achiziție
- `banking` - plată prin cont bancar, taxă de listare ca procent
- `phone` - notificare la vânzarea unui item listat
- `shops` - listingurile apar ca alternativă la shop-urile NPC

**Tabele DB principale:**
```sql
marketplace_listings (id, seller_character_id, item_name, amount, price_per_unit, currency_code, listing_fee, expires_at, status, created_at)
marketplace_transactions (id, listing_id, buyer_character_id, amount_bought, total_price, bought_at)
```

**Exporturi minime:**
```lua
exports.marketplace:createListing(characterId, itemName, amount, pricePerUnit, currencyCode)  → listingId
exports.marketplace:buyListing(characterId, listingId, amount)                                → bool
exports.marketplace:cancelListing(characterId, listingId)                                     → bool
exports.marketplace:getListings(filters)                                                       → listings[]
```

**Dependențe:** `core`, `postgres`, `characters`, `inventory`, `banking`

---

### `tattoo` - Aspect Personaj Permanent

**Descriere:** Salon de tatuaje și frizerie. Tatuajele sunt permanente (plătești să le elimini). Include colecții per zonă corp, preview înainte de confirmare, salvare în profilul personajului.

**Integrare cu module existente:**
- `banking` - plată tatuaj/tunsoare
- `proximity` - interacțiune la NPC salon
- `characters` - aspect salvat per personaj, restaurat la spawn
- `clothing` - același flux UI pentru aspect general

**Tabele DB principale:**
```sql
tattoo_shops (id, name, coords JSONB)
tattoo_catalog (id, shop_id, name, label, zone, collection, overlay, price, vip_only)
character_tattoos (id, character_id, tattoo_id, applied_at)
haircut_catalog (id, label, hair_index, overlay_index, price)
character_appearance (character_id PK, hair_id, hair_color_primary, hair_color_secondary, face_features JSONB, applied_at)
```

**Dependențe:** `core`, `postgres`, `characters`, `banking`, `proximity`

---

### `social` - Rețea Socială In-Game ("SwitBook")

**Descriere:** Rețea socială în joc: profil personaj, postări cu text/imagini (URL), like-uri, comentarii, urmărire alte personaje. Accesibil din `phone` sau terminal public.

**Integrare cu module existente:**
- `phone` - app "SwitBook" în telefon
- `characters` - profilul e legat de personaj, nu de cont
- `achievements` - postări automate la realizări mari ("X a prins cel mai mare pește!")
- `jobs` - postări oficiale de la organizații (police, gov)

**Tabele DB principale:**
```sql
social_profiles (character_id PK, bio, avatar_url, is_public, followers_count, following_count)
social_posts (id, character_id, body, image_url, likes_count, created_at, is_deleted)
social_likes (post_id, character_id, liked_at) -- PK (post_id, character_id)
social_comments (id, post_id, character_id, body, created_at)
social_follows (follower_id, following_id, followed_at) -- PK (follower_id, following_id)
```

**Dependențe:** `core`, `postgres`, `characters`, `phone`

---

## Rezumat Prioritizare

| Prioritate | Modul | Efort estimat | Impact |
|------------|-------|---------------|--------|
| P1 | `housing` | Mare | Fundație RP |
| P1 | `phone` | Mare | Hub comunicare |
| P1 | `clothing` | Mediu | Imersie vizuală |
| P1 | `dispatch` | Mediu | Police/EMS flow |
| P2 | `trucking` | Mediu | Job legal nou |
| P2 | `fishing` | Mic | Activitate relaxantă |
| P2 | `farming` | Mediu | Alimentează crafting |
| P2 | `crafting` | Mare | Sistem transversal |
| P2 | `real-estate` | Mediu | Extinde housing |
| P3 | `radio` | Mic | Comunicare realistă |
| P3 | `drugs` | Mare | Economie ilegală |
| P3 | `heists` | Mare | Activitate high-risk |
| P3 | `prison` | Mediu | Extinde police |
| P3 | `achievements` | Mediu | Retenție jucători |
| P3 | `events` | Mediu | Conținut admin |
| P3 | `minigames` | Mic | Librărie refolosibilă |
| P3 | `marketplace` | Mediu | Economie player-driven |
| P3 | `tattoo` | Mic | Aspect personaj |
| P3 | `social` | Mare | Community building |
