Config = {}

-- Numarul maxim de caractere pe jucator
Config.MAX_CHARACTERS_PER_PLAYER = 3

-- Pozitia default de spawn cand se creeaza un nou caracter (x, y, z, heading)
Config.DEFAULT_SPAWN_POSITION = {
    x = -269.4,
    y = -955.3,
    z = 31.2,
    heading = 205.8
}

-- Limite de varsta pentru crearea unui caracter
Config.MIN_CHARACTER_AGE = 18
Config.MAX_CHARACTER_AGE = 80

-- Setari pentru stergerea unui caracter
Config.ENABLE_CHARACTER_DELETION = true

-- Setari pentru validarea numelui unui caracter
Config.CHARACTER_FIRST_NAME_MIN_LENGTH = 2
Config.CHARACTER_FIRST_NAME_MAX_LENGTH = 20
Config.CHARACTER_LAST_NAME_MIN_LENGTH = 2
Config.CHARACTER_LAST_NAME_MAX_LENGTH = 20

-- Pattern pentru validarea numelui unui caracter (alfanumeric, spatii, linii, apostroafe)
-- Va fi utilizat in Lua pattern matching
Config.CHARACTER_NAME_PATTERN = '^[%w%s%-%\'%.]+$'

return Config

