-- Verifica consistenta fisierelor de locale per modul: ro.lua si en.lua exista,
-- au exact aceleasi chei, aceleasi placeholdere {n} si namespace-ul de top
-- corespunde numelui modulului. Ruleaza cu busted din radacina repo-ului.

local LANGS = { 'ro', 'en' }

-- Module migrate pe sistemul de localizare (au locales/ro.lua + locales/en.lua).
-- Adauga aici fiecare modul pe masura ce e migrat.
-- loadscreen nu apare aici: foloseste ui/locales/*.json (ruleaza inainte de
-- sincronizarea normala a localelor), nu locales/*.lua
local MIGRATED = {
    'core',
    'notifications',
    'characters',
    'banking',
    'vehicles',
    'tuning',
    'admin',
    'clothing',
    'showroom',
    'shops',
    'settings',
    'jobs',
    'inventory',
    'garages',
    'government',
    'mdt',
    'police',
    'ems',
    'medical',
    'taxi',
    'mecanic',
    'garbage',
    'hud',
    'intro',
    'welcome',
    'needs',
    'proximity',
}

-- Toate modulele din [switcore]; folosit ca un modul cu locales/ dar absent
-- din MIGRATED sa pice testul in loc sa fie ignorat silentios.
local ALL_MODULES = {
    'admin', 'banking', 'blips', 'characters', 'clothing', 'core', 'ems',
    'garages', 'garbage', 'government', 'hud', 'interiors', 'intro',
    'inventory', 'jobs', 'loadscreen', 'mdt', 'mecanic', 'medical', 'needs',
    'notifications', 'police', 'postgres', 'proximity', 'settings',
    'settings-panel', 'shops', 'showroom', 'taxi', 'tuning', 'vehicles',
    'welcome',
}

-- core grupeaza namespace-uri istorice (comenzi, moderare etc.) in acelasi fisier
local NAMESPACE_EXCEPTIONS = {
    core = {
        commands = true, moderation = true, server = true, proximity = true,
        errors = true, language = true, core = true,
    },
}

local function localePath(module, lang)
    return ('[switcore]/%s/locales/%s.lua'):format(module, lang)
end

local function fileExists(path)
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
end

local function loadLocale(module, lang)
    local path = localePath(module, lang)
    local chunk, err = loadfile(path)
    assert(chunk, ('nu pot parsa %s: %s'):format(path, tostring(err)))
    local ok, data = pcall(chunk)
    assert(ok, ('eroare la executia %s: %s'):format(path, tostring(data)))
    assert(type(data) == 'table', ('%s nu returneaza un tabel'):format(path))
    return data
end

local function collectLeaves(tbl, prefix, out)
    for k, v in pairs(tbl) do
        local key = prefix == '' and tostring(k) or (prefix .. '.' .. tostring(k))
        if type(v) == 'table' then
            collectLeaves(v, key, out)
        else
            out[key] = v
        end
    end
    return out
end

local function placeholderSet(value)
    local set = {}
    for n in tostring(value):gmatch('{(%d+)}') do
        set[n] = true
    end
    return set
end

local function setToString(set)
    local parts = {}
    for n in pairs(set) do parts[#parts + 1] = '{' .. n .. '}' end
    table.sort(parts)
    return table.concat(parts, ' ')
end

describe('locale completeness', function()
    local migratedSet = {}
    for _, module in ipairs(MIGRATED) do migratedSet[module] = true end

    it('orice modul cu locales/ este listat in MIGRATED', function()
        for _, module in ipairs(ALL_MODULES) do
            if not migratedSet[module] and fileExists(localePath(module, 'ro')) then
                assert(false, ('modulul "%s" are locales/ro.lua dar nu e in MIGRATED; adauga-l in spec'):format(module))
            end
        end
    end)

    for _, module in ipairs(MIGRATED) do
        describe(module, function()
            local locales = {}

            setup(function()
                for _, lang in ipairs(LANGS) do
                    locales[lang] = loadLocale(module, lang)
                end
            end)

            it('are ro.lua si en.lua incarcabile', function()
                for _, lang in ipairs(LANGS) do
                    assert.is_table(locales[lang])
                end
            end)

            it('namespace-ul de top corespunde modulului', function()
                local allowed = NAMESPACE_EXCEPTIONS[module] or { [module] = true }
                for _, lang in ipairs(LANGS) do
                    for ns in pairs(locales[lang]) do
                        assert(allowed[ns],
                            ('%s/%s.lua: namespace de top neasteptat "%s"'):format(module, lang, tostring(ns)))
                    end
                end
            end)

            it('cheile ro si en coincid', function()
                local roKeys = collectLeaves(locales.ro, '', {})
                local enKeys = collectLeaves(locales.en, '', {})
                for key in pairs(roKeys) do
                    assert(enKeys[key] ~= nil, ('%s: cheia "%s" exista in ro dar lipseste din en'):format(module, key))
                end
                for key in pairs(enKeys) do
                    assert(roKeys[key] ~= nil, ('%s: cheia "%s" exista in en dar lipseste din ro'):format(module, key))
                end
            end)

            it('toate valorile sunt stringuri nevide', function()
                for _, lang in ipairs(LANGS) do
                    local leaves = collectLeaves(locales[lang], '', {})
                    for key, value in pairs(leaves) do
                        assert(type(value) == 'string' and value ~= '',
                            ('%s/%s.lua: valoarea cheii "%s" trebuie sa fie string nevid'):format(module, lang, key))
                    end
                end
            end)

            it('placeholderele {n} coincid intre ro si en', function()
                local roKeys = collectLeaves(locales.ro, '', {})
                local enKeys = collectLeaves(locales.en, '', {})
                for key, roValue in pairs(roKeys) do
                    local enValue = enKeys[key]
                    if enValue ~= nil then
                        local roSet, enSet = placeholderSet(roValue), placeholderSet(enValue)
                        assert(setToString(roSet) == setToString(enSet),
                            ('%s: placeholdere diferite la "%s" (ro: %s | en: %s)'):format(
                                module, key, setToString(roSet), setToString(enSet)))
                    end
                end
            end)
        end)
    end
end)
