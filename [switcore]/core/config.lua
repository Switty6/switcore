Config = {}

-- Limba implicita a serverului. Prioritatea reala la pornire:
-- convar-ul sw_locale (server.cfg) > setarea core.default_language > valoarea de aici.
Config.DEFAULT_LANGUAGE = 'ro'

-- Pe public limba e setata de owner pentru tot serverul (sw_locale).
-- Pe premium se pune true ca jucatorii sa isi aleaga limba individual
-- (comanda /language, persistata in coloana players.language).
Config.ALLOW_PLAYER_LANGUAGE = false

return Config
