TuningData = {}

TuningData.Shops = {
    {
        code    = 'LSC_BURTON',
        name    = 'LS Customs - Burton',
        coords  = vector3(-352.29, -133.94, 38.87),
        heading = 285.0,
    },
    {
        code    = 'LSC_ELYSIAN',
        name    = 'LS Customs - Elysian Island',
        coords  = vector3(709.72, -1082.87, 22.17),
        heading = 180.0,
    },
    {
        code    = 'LSC_SANDY',
        name    = 'LS Customs - Sandy Shores',
        coords  = vector3(1174.86, 2640.11, 37.78),
        heading = 90.0,
    },
}

-- nativeType: indexul GTA al mod type-ului. modType: 'index' | 'toggle' | 'wheel' | 'color' | 'livery'
TuningData.ModCategories = {
    { id = 'engine',       label = 'Motor',      nativeType = 11, modType = 'index',  maxTier = 4 },
    { id = 'brakes',       label = 'Frâne',       nativeType = 12, modType = 'index',  maxTier = 3 },
    { id = 'transmission', label = 'Transmisie',  nativeType = 13, modType = 'index',  maxTier = 3 },
    { id = 'turbo',        label = 'Turbo',       nativeType = 18, modType = 'toggle', maxTier = 1 },
    { id = 'suspension',   label = 'Suspensie',   nativeType = 15, modType = 'index',  maxTier = 5 },
    { id = 'armor',        label = 'Blindaj',     nativeType = 16, modType = 'index',  maxTier = 5 },
    { id = 'xenon',        label = 'Xenon',       nativeType = 22, modType = 'toggle', maxTier = 1 },
    { id = 'wheels',       label = 'Roți',         nativeType = -1, modType = 'wheel',  maxTier = 7 },
    { id = 'color',        label = 'Culoare',     nativeType = -2, modType = 'color',  maxTier = 0 },
    { id = 'livery',       label = 'Liverie',     nativeType = 48, modType = 'livery', maxTier = 0 },
}

TuningData.TierLabels = {
    engine = {
        [1] = { label = 'EMS Nivel I',    desc = '+4% putere motor, +4% cuplu' },
        [2] = { label = 'EMS Nivel II',   desc = '+8% putere motor, +8% cuplu' },
        [3] = { label = 'EMS Nivel III',  desc = '+12% putere motor, +12% cuplu' },
        [4] = { label = 'EMS Nivel IV',   desc = '+16% putere motor, +16% cuplu · Exclusiv VIP' },
    },
    brakes = {
        [1] = { label = 'Frâne Stradă',  desc = 'Distanță frânare redusă cu 10%' },
        [2] = { label = 'Frâne Sport',   desc = 'Distanță frânare redusă cu 20%' },
        [3] = { label = 'Frâne Cursă',   desc = 'Distanță frânare redusă cu 30%' },
    },
    transmission = {
        [1] = { label = 'Transmisie Stradă', desc = 'Schimbare viteze cu 5% mai rapidă' },
        [2] = { label = 'Transmisie Sport',  desc = 'Schimbare viteze cu 10% mai rapidă' },
        [3] = { label = 'Transmisie Cursă',  desc = 'Schimbare viteze cu 15% mai rapidă' },
    },
    turbo = {
        [1] = { label = 'Turbo Kit', desc = 'Boost semnificativ la turații înalte' },
    },
    suspension = {
        [1] = { label = 'Lowering',    desc = 'Centru de greutate coborât' },
        [2] = { label = 'Stradă',      desc = 'Handling îmbunătățit pe asfalt' },
        [3] = { label = 'Sport',       desc = 'Stabilitate sporită în curbe' },
        [4] = { label = 'Cursă',       desc = 'Aderență maximizată' },
        [5] = { label = 'Competiție',  desc = 'Suspensie de circuit profesional' },
    },
    armor = {
        [1] = { label = 'Blindaj Nivel I',   desc = '+20% rezistență la proiectile' },
        [2] = { label = 'Blindaj Nivel II',  desc = '+40% rezistență la proiectile' },
        [3] = { label = 'Blindaj Nivel III', desc = '+60% rezistență la proiectile' },
        [4] = { label = 'Blindaj Nivel IV',  desc = '+80% rezistență la proiectile' },
        [5] = { label = 'Blindaj Nivel V',   desc = 'Protecție completă · Exclusiv VIP' },
    },
    xenon = {
        [1] = { label = 'Faruri Xenon', desc = 'Intensitate ridicată, rază mai mare' },
    },
    wheels = {
        [0] = { label = 'Sport',    desc = 'Jante sport ușoare' },
        [1] = { label = 'Muscle',   desc = 'Jante musculare clasice' },
        [2] = { label = 'Lowrider', desc = 'Jante lowrider cu profil scăzut' },
        [3] = { label = 'SUV',      desc = 'Jante SUV robuste' },
        [4] = { label = 'Offroad',  desc = 'Jante pentru teren accidentat' },
        [5] = { label = 'Tuner',    desc = 'Jante tuner moderne' },
        [6] = { label = 'Bike',     desc = 'Jante pentru motociclete' },
        [7] = { label = 'High-End', desc = 'Jante premium de lux · Exclusiv VIP' },
    },
}

TuningData.VipOnlyMods = {
    engine = { 4 },
    armor  = { 5 },
    wheels = { 7 },
}

-- Inserate cu ON CONFLICT DO NOTHING: editările runtime în tuning_prices nu sunt suprascrise la restart.
TuningData.PriceSeed = {
    { category = 'engine',       tier = 1, price =  5000.0, vip_only = false },
    { category = 'engine',       tier = 2, price = 12000.0, vip_only = false },
    { category = 'engine',       tier = 3, price = 25000.0, vip_only = false },
    { category = 'engine',       tier = 4, price = 50000.0, vip_only = true  },

    { category = 'brakes',       tier = 1, price =  3500.0, vip_only = false },
    { category = 'brakes',       tier = 2, price =  8000.0, vip_only = false },
    { category = 'brakes',       tier = 3, price = 15000.0, vip_only = false },

    { category = 'transmission', tier = 1, price =  4000.0, vip_only = false },
    { category = 'transmission', tier = 2, price =  9000.0, vip_only = false },
    { category = 'transmission', tier = 3, price = 18000.0, vip_only = false },

    { category = 'turbo',        tier = 1, price = 10000.0, vip_only = false },

    { category = 'suspension',   tier = 1, price =  2500.0, vip_only = false },
    { category = 'suspension',   tier = 2, price =  5500.0, vip_only = false },
    { category = 'suspension',   tier = 3, price =  9500.0, vip_only = false },
    { category = 'suspension',   tier = 4, price = 14000.0, vip_only = false },
    { category = 'suspension',   tier = 5, price = 20000.0, vip_only = false },

    { category = 'armor',        tier = 1, price =  3000.0, vip_only = false },
    { category = 'armor',        tier = 2, price =  7000.0, vip_only = false },
    { category = 'armor',        tier = 3, price = 12000.0, vip_only = false },
    { category = 'armor',        tier = 4, price = 20000.0, vip_only = false },
    { category = 'armor',        tier = 5, price = 35000.0, vip_only = true  },

    { category = 'xenon',        tier = 1, price =  1500.0, vip_only = false },

    -- wheels: tier = wheelType index GTA (0-7), nu nivel de upgrade
    { category = 'wheels',       tier = 0, price =  2000.0, vip_only = false },
    { category = 'wheels',       tier = 1, price =  2000.0, vip_only = false },
    { category = 'wheels',       tier = 2, price =  2500.0, vip_only = false },
    { category = 'wheels',       tier = 3, price =  2000.0, vip_only = false },
    { category = 'wheels',       tier = 4, price =  2000.0, vip_only = false },
    { category = 'wheels',       tier = 5, price =  2500.0, vip_only = false },
    { category = 'wheels',       tier = 6, price =  1500.0, vip_only = false },
    { category = 'wheels',       tier = 7, price =  5000.0, vip_only = true  },
}
