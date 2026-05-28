# 🗄️ SwitCore PostgreSQL - Resursă Ready-to-Use

Resursă completă pentru conexiunea la baza de date PostgreSQL în FiveM. **Gata de folosit** - doar configurează și pornește!

---

## 🚀 Instalare Rapidă

### 1. Copiază resursa
```bash
# Copiază folderul postgres în resources/[switcore]/postgres
```

### 2. Instalează dependențele (DOAR O DATĂ!)

**⚠️ IMPORTANT:** Rulează `npm install` doar prima dată, nu la fiecare pornire!

**Windows:**
```bash
cd resources/[switcore]/postgres
.\setup.bat
```

**Linux/Mac:**
```bash
cd resources/[switcore]/postgres
chmod +x setup.sh
./setup.sh
```

**Sau manual:**
```bash
npm install
```

**Așteaptă** până vezi `added X packages`. **Gata!** De acum înainte nu mai trebuie să rulezi npm install.

### 3. Configurează baza de date

**Trebuie să creezi fișierul cu datele tale de conexiune!**

#### Opțiunea 1: Configurare simplă (Recomandat) ⭐

**Pasul 1:** Creează fișierul `config.local.js` copiind din exemplu:

**Windows (PowerShell):**
```powershell
Copy-Item config.local.js.example config.local.js
```

**Windows (CMD):**
```cmd
copy config.local.js.example config.local.js
```

**Linux/Mac:**
```bash
cp config.local.js.example config.local.js
```

**Pasul 2:** Deschide `config.local.js` și modifică cu datele tale:

```javascript
module.exports = {
    host: 'localhost',              // IP-ul sau host-ul bazei tale
    port: 5432,                     // Port-ul (de obicei 5432)
    database: 'fivem',              // ⚠️ SCHIMBĂ cu numele bazei tale
    user: 'postgres',               // ⚠️ SCHIMBĂ cu utilizatorul tău
    password: 'parola_ta_aici',     // ⚠️ PUNE PAROLA TA AICI!
    ssl: false,                     // true pentru servere remote, false pentru local
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000
};
```

**Gata!** Resursa va folosi automat aceste setări.

**Exemplu de configurare pentru bază locală:**
```javascript
host: 'localhost',
port: 5432,
database: 'fivem',
user: 'postgres',
password: 'parola123',
ssl: false
```

**Exemplu pentru bază remote:**
```javascript
host: '192.168.1.100',  // IP-ul serverului
port: 5432,
database: 'fivem',
user: 'postgres',
password: 'parola_secreta',
ssl: true              // Activează SSL pentru conexiuni remote
```

#### Opțiunea 2: Variabile de mediu (Pentru avansați)

Dacă preferi să folosești variabile de mediu (pentru production), setează-le și resursa le va folosi automat. **Dacă variabilele de mediu sunt setate, `config.local.js` va fi ignorat.**

**Windows (PowerShell):**
```powershell
$env:POSTGRES_HOST="localhost"
$env:POSTGRES_PORT="5432"
$env:POSTGRES_DATABASE="fivem"
$env:POSTGRES_USER="postgres"
$env:POSTGRES_PASSWORD="parola_ta"
```

**Linux/Mac:**
```bash
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_DATABASE=fivem
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=parola_ta
```

### 4. Adaugă în server.cfg

```cfg
ensure postgres
```

### 5. Pornește serverul!

La pornire ar trebui să vezi:
```
[POSTGRES] Configurație încărcată din config.local.js
[POSTGRES] ✓ Conectat cu succes la baza de date PostgreSQL
```

---

## ✅ Verificare

După instalare, verifică dacă totul este OK:

```bash
cd resources/[switcore]/postgres
node check_dependencies.js
```

Ar trebui să vezi: `[POSTGRES] ✓ Toate dependențele sunt instalate`

---

## 💻 Utilizare

### Din Server-Side Lua

```lua
-- Obține datele unui jucător
local result = exports.postgres:query('SELECT * FROM players WHERE id = $1', {playerId})
if result and result.rows and result.rows[1] then
    print('Jucător: ' .. result.rows[1].name)
end

-- Obține un singur rând
local user = exports.postgres:queryOne('SELECT * FROM users WHERE id = $1', {userId})

-- Obține toate rândurile
local players = exports.postgres:queryAll('SELECT * FROM players')

-- Inserează date
local newPlayer = exports.postgres:insert('players', {
    name = 'Ion Popescu',
    money = 5000
})

-- Actualizează date
local updated = exports.postgres:update('players', {
    money = 10000
}, 'id = $1', {playerId})

-- Șterge date
local deleted = exports.postgres:delete('players', 'id = $1', {playerId})

-- Tranzacție (pentru operații complexe)
exports.postgres:transaction(function(client)
    client.query('UPDATE players SET money = money - 100 WHERE id = 1')
    client.query('UPDATE players SET money = money + 100 WHERE id = 2')
end)
```

### Din Resurse Node.js

```javascript
const postgres = exports.postgres;

const result = await postgres.query('SELECT * FROM users WHERE id = $1', [userId]);
const user = await postgres.queryOne('SELECT * FROM users WHERE id = $1', [userId]);
const users = await postgres.queryAll('SELECT * FROM users');
const newUser = await postgres.insert('users', { name: 'Ion', email: 'ion@example.com' });
const updated = await postgres.update('users', { name: 'Maria' }, 'id = $1', [userId]);
const deleted = await postgres.delete('users', 'id = $1', [userId]);
```

---

## 📚 API Reference

### `query(queryText, params)`
Execută o interogare SQL și returnează rezultatul complet.

```lua
local result = exports.postgres:query('SELECT * FROM players WHERE id = $1', {5})
print(result.rowCount) -- numărul de rânduri
print(result.rows[1].name) -- primul rând
```

### `queryOne(queryText, params)`
Obține un singur rând sau `nil`.

```lua
local player = exports.postgres:queryOne('SELECT * FROM players WHERE id = $1', {5})
```

### `queryAll(queryText, params)`
Obține toate rândurile ca array.

```lua
local players = exports.postgres:queryAll('SELECT * FROM players')
```

### `insert(table, data)`
Inserează un rând nou și îl returnează.

```lua
local newPlayer = exports.postgres:insert('players', {
    name = 'Ion',
    money = 1000
})
print('ID: ' .. newPlayer.id)
```

### `update(table, data, where, whereParams)`
Actualizează rânduri și returnează rândurile actualizate.

```lua
local updated = exports.postgres:update('players', {
    money = 5000
}, 'id = $1', {1})
```

### `delete(table, where, params)`
Șterge rânduri și returnează numărul de rânduri șterse.

```lua
local deleted = exports.postgres:delete('players', 'id = $1', {999})
```

### `transaction(callback)`
Execută mai multe interogări într-o tranzacție (tot sau nimic).

```lua
exports.postgres:transaction(function(client)
    client.query('UPDATE players SET money = money - 100 WHERE id = 1')
    client.query('UPDATE players SET money = money + 100 WHERE id = 2')
end)
```

### `isReady()`
Verifică dacă conexiunea este gata.

```lua
if exports.postgres:isReady() then
    print('Baza de date este gata!')
end
```

---

## ⚠️ Securitate & Best Practices

### ✅ Protecție SQL Injection

**Toate interogările folosesc statement-uri parametrizate automat.** NICIODATĂ nu folosi string concatenation!

```lua
-- ❌ GRESIT - PERICULOS!
local query = "SELECT * FROM players WHERE name = '" .. playerName .. "'"

-- ✅ CORECT - SIGUR!
local result = exports.postgres:query('SELECT * FROM players WHERE name = $1', {playerName})
```

### 📁 Fișiere de configurare

- **`config.local.js`** - NU este urcat pe git (este în .gitignore). Conține datele tale sensibile.
- **`config.local.js.example`** - Template fără date sensibile, urcat pe git.

**Asigură-te că ai creat `config.local.js` din exemplu!**

---

## 🐛 Troubleshooting

### Eroare: "Dependențele nu sunt instalate!"

**Soluție:** Rulează `npm install` în folderul resursei (DOAR O DATĂ!)

### Eroare: "Eșec la conectarea la baza de date"

**Verifică:**
1. ✅ PostgreSQL rulează?
2. ✅ Datele din `config.local.js` sunt corecte?
3. ✅ Parola este corectă?
4. ✅ Baza de date există?
5. ✅ Firewall-ul permite conexiunea? (pentru remote)

### Eroare: "Configurație lipsă!"

**Soluție:** 
- Fie creează `config.local.js` din `config.local.js.example`
- Fie setează variabile de mediu

### Eroare: "npm: command not found"

**Soluție:** Instalează Node.js de pe https://nodejs.org/

---

## ❓ FAQ

**Q: Trebuie să rulez npm install de fiecare dată?**
A: **NU!** Doar prima dată la instalare sau când ștergi `node_modules`.

**Q: Pot să șterg folderul node_modules?**
A: **NU!** Este necesar pentru funcționare. Dacă îl ștergi, rulează `npm install` din nou.

**Q: De ce nu trebuie să urc config.local.js pe git?**
A: Conține date sensibile (parole). Este deja în `.gitignore`, deci nu va fi urcat.

**Q: Când trebuie să rulez npm install?**
A: Doar prima dată sau când primești actualizări care schimbă `package.json`.

---

## 📦 Structura Resursei

```
postgres/
├── config.local.js          ← Creează tu din exemplu! (NU pe git)
├── config.local.js.example  ← Template (pe git)
├── config.js                ← Logică configurare
├── server.js                ← Server principal
├── check_dependencies.js    ← Verificare dependențe
├── setup.bat / setup.sh    ← Scripturi instalare
├── node_modules/            ← Creat de npm install (NU șterge!)
└── package.json             ← Dependențe
```

---

## 🎯 Quick Start Checklist

- [ ] Am copiat resursa în folderul corect
- [ ] Am rulat `npm install` (sau `setup.bat`/`setup.sh`)
- [ ] Am creat `config.local.js` din `config.local.js.example`
- [ ] Am editat `config.local.js` cu datele mele de conexiune
- [ ] Am adăugat `ensure postgres` în `server.cfg`
- [ ] Serverul pornește fără erori

**Dacă toate sunt bifate, ești gata! 🎉**

---

## 📝 Note

- Toate interogările folosesc parametri pentru protecție SQL injection
- Pool-ul de conexiuni este gestionat automat
- Resursa verifică automat dependențele la pornire
- Tranzacțiile asigură consistența datelor

---

**Parte din SwitCore Framework pentru FiveM**
