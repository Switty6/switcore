Config = {}

Config.JobName = 'taxi'

-- Suprascrise de settings DB la startup
Config.DispatchRadius = 5000.0
Config.HiringCoords   = vector3(-69.0, -1763.0, 29.0)
Config.VehicleModel   = 'taxi'

-- Tarif per km (unitati GTA * 0.001 ≈ km) per grad
Config.GradeRate = {
    [0] = 80,
    [1] = 100,
    [2] = 130,
    [3] = 130,
}

Config.PromotionThresholds = {
    [1] = 20,
    [2] = 75,
}
