# 🎯 SwitCore Proximity

Sistem ultra mega inteligent de interacțiuni pentru FiveM. Făcut pentru developerii care nu vor să reinventeze roata de fiecare dată.

## ⚡ Caracteristici

- 🎨 UI modern cu animații smooth
- 🖱️ Navigare mouse pentru interacțiuni multiple (ALT)
- 🧠 Stacking inteligent - max 3 interacțiuni per entitate
- 📊 Afișare pe coloane automată (2-3 coloane)
- 🎯 UI centrat pe entități (fără să floteze aiurea)
- 🎨 Culori personalizabile
- ⚡ Optimizat (nu o să-ți toace FPS-ul, sper, nu l-am testat full.)

## 🚀 Instalare

```cfg
ensure [switcore]/proximity
```

Asta e tot. Dacă ai nevoie de mai multe instrucțiuni, probabil că FiveM nu e pentru tine. 😉

## 📝 Configurare Rapidă

Editează `config.lua`:

```lua
Config.ProximityDistance = 2.0  -- Cât de aproape trebuie să fii
Config.MarkerColor = {r = 0, g = 255, b = 0, a = 200}  -- Verde default
Config.TextOffset = {x = 0.0, y = 0.0, z = 0.5}  -- Cât de sus să fie UI-ul (coord)
Config.EntityOffset = {x = 0.0, y = 0.0, z = 0.0}  -- Offset pentru entități
Config.MouseToggleKey = 'LMENU'  -- Tasta ALT pentru mouse navigation
```

## 💻 Utilizare

### Interacțiuni Statice (în config)

```lua
Config.Interactions = {
    {coords = vector3(25.0, -1347.0, 29.5), label = "Magazin", type = "shop", data = {shopId = 1}},
    {coords = vector3(150.0, -1038.0, 29.4), label = "ATM", type = "atm", data = {atmId = 1}},
}
```

### Interacțiuni Dinamice (runtime)

```lua
-- Simplu
exports['proximity']:AddInteraction(
    vector3(100.0, 100.0, 20.0),
    "Casierie",
    "checkout",
    {storeId = 5},
    function(interaction)
        print("Interacțiune: " .. interaction.label)
    end
)

-- Cu entitate (vehicul, NPC, obiect)
local vehicle = CreateVehicle(GetHashKey("adder"), 100.0, 200.0, 30.0, 90.0, true, false)
exports['proximity']:AddEntityInteraction(
    vehicle,
    "Vehicul Special",
    "vehicle",
    {vehicleId = vehicle},
    function(interaction)
        print("Bună mașina!")
    end,
    nil,
    {r = 255, g = 165, b = 0, a = 200}  -- Marker portocaliu
)

-- Pe toate entitățile de un anumit model
exports['proximity']:AddModelInteraction("adder", "Mașină", "vehicle", {})
exports['proximity']:AddModelInteraction("s_m_y_cop_01", "Polițist", "npc", {})
```

### Ascultă evenimente

```lua
RegisterNetEvent('switcore:proximity:interact', function(interaction)
    if interaction.type == "shop" then
        TriggerEvent('shop:open', interaction.data.shopId)
    elseif interaction.type == "atm" then
        TriggerEvent('bank:openATM', interaction.data.atmId)
    end
end)
```

## 📚 Export-uri

### Dinamice (runtime - pot fi șterse)
- `AddInteraction(coords, label, type, data, onInteract, entity, glowColor, markerColor)` - Coordonate
- `AddEntityInteraction(entity, label, type, data, onInteract, glowColor, markerColor)` - Entitate specifică
- `AddModelInteraction(modelName, label, type, data, onInteract, maxDistance, glowColor, markerColor)` - Toate entitățile de acel model
- `AddTriangleZone(v1, v2, v3, label, type, data, onInteract, glowColor, markerColor)` - Zonă triunghiulară
- `AddRectangleZone(corner1, corner2, label, type, data, onInteract, minZ, maxZ, glowColor, markerColor)` - Zonă dreptunghiulară

**Notă**: Interacțiunile dinamice pot fi șterse cu `RemoveInteraction(id)`. Perfecte pentru interacțiuni temporare sau care se schimbă în runtime.

### Statice (permanente - nu pot fi șterse individual)
- `AddStaticInteraction(coords, label, type, data, entity, glowColor, markerColor)` - Coordonate
- `AddStaticEntityInteraction(entity, label, type, data, glowColor, markerColor)` - Entitate specifică
- `AddStaticModelInteraction(modelName, label, type, data, maxDistance, glowColor, markerColor)` - Toate entitățile de acel model
- `AddStaticTriangleZone(v1, v2, v3, label, type, data, glowColor, markerColor)` - Zonă triunghiulară
- `AddStaticRectangleZone(corner1, corner2, label, type, data, minZ, maxZ, glowColor, markerColor)` - Zonă dreptunghiulară

**Notă**: Interacțiunile statice sunt adăugate în `Config.Interactions` și sunt mai eficiente pentru interacțiuni permanente/fixe. Nu pot fi șterse individual, doar prin modificarea config-ului.

### Utilitare
- `RemoveInteraction(id)` - Șterge o interacțiune dinamică
- `GetCurrentInteraction()` - Obține interacțiunea curentă
- `IsNearInteraction()` - Verifică dacă ești aproape de ceva

## 🎮 Funcționalități Speciale

### Navigare Mouse
Când sunt mai multe interacțiuni:
- Apasă **ALT** pentru a activa mouse-ul
- Selectează cu mouse-ul
- Click pentru interacțiune sau **ESC** pentru a închide

UI-ul se organizează automat pe coloane când ai 4+ interacțiuni.

### Stacking
- Max **3 interacțiuni per entitate** (să nu-ți explodeze ecranul)
- Sortate după distanță
- Se grupează automat după entitate/coordonate apropiate

### Poziționare
- Entități: UI centrat automat pe bounding box
- Coordonate: Folosește `TextOffset.z` pentru poziționare
- Ajustează cu offset-uri dacă e nevoie

## 🎨 Personalizare

```lua
Config.MarkerColor = {r = 0, g = 255, b = 0, a = 200}  -- Culoare marker
Config.ShowMarker = true  -- Show/hide marker
Config.ShowText = true  -- Show/hide text
Config.Debug = false  -- Debug mode (console spam)
```

## 💡 Exemple Complete

```lua
-- Event handler
RegisterNetEvent('switcore:proximity:interact', function(interaction)
    if interaction.type == "shop" then
        TriggerEvent('shop:open', interaction.data.shopId)
    end
end)

-- Adaugă interacțiune dinamic
CreateThread(function()
    Wait(1000)
    local ped = GetClosestPed(GetEntityCoords(PlayerPedId()), 10.0)
    if ped then
        exports['proximity']:AddEntityInteraction(
            ped,
            "Vorbește",
            "talk",
            {npcId = ped},
            function(i)
                print("Salut!")
            end
        )
    end
end)
```

## 🤝 Suport

Ai probleme? Verifică că ai instalat corect și că resursa rulează. Dacă tot nu merge, crează un issue pe Github -> https://github.com/Switty6/switcore/issues



---

**Made with ❤️ by Switty**
