Config = {}

Config.OrgCode      = 'mec_auto'
Config.JobName      = 'mecanic_auto'

Config.Prices = {
    inspect          = 200,
    oil_change       = 400,
    brakes           = 500,
    tire             = 300,
    suspension       = 800,
    battery          = 600,
    engine           = 1500,
    bodywork         = 800,
    roadside_engine  = 2000,
    roadside_tire    = 600,
    roadside_battery = 500,
    roadside_tow     = 1500,
}

Config.Bonus = { [0]=8, [1]=12, [2]=18, [3]=25 }

Config.WorkshopCoords = vector3(375.84, -1888.77, 29.41)
Config.WorkshopRadius = 25.0

Config.NearVehicleRadius = 8.0

Config.OilDegPer500km  = 5
Config.TireDegPer500km = 1

Config.Thresholds = {
    oil_warn    = 30,
    oil_crit    = 10,
    oil_fatal   = 0,
    battery_low = 20,
    battery_dead= 0,
    brakes_warn = 30,
    exhaust_low = 20,
    suspend_low = 20,
    tire_flat   = 0,
}
