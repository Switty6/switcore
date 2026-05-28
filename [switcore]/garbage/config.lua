Config = {}

Config.JobName      = 'garbage'
Config.HiringCoords = vector3(730.93, -2014.38, 29.29)
Config.VehicleModel = 'trash'
Config.VehicleSpawnOffset = vector3(6.0, 0.0, 0.0)

Config.GradePay = {
    [0] = { perPoint = 50,  bonus = 200 },
    [1] = { perPoint = 65,  bonus = 200 },
    [2] = { perPoint = 80,  bonus = 350 },
}

Config.PromotionThresholds = {
    [1] = 10,
    [2] = 40,
}

Config.Routes = {
    {
        id        = 1,
        name      = 'Ruta Demo Cypress Flats',
        waypoints = {
            { x = 755.29, y = -2001.53, z = 29.30, label = 'Container Demo 1' },
            { x = 757.47, y = -1990.29, z = 29.30, label = 'Container Demo 2' },
            { x = 759.42, y = -1981.30, z = 29.30, label = 'Container Demo 3' },
            { x = 760.55, y = -1974.37, z = 29.32, label = 'Container Demo 4' },
        },
    },
    {
        id        = 2,
        name      = 'Ruta Rezidentiala Davis',
        waypoints = {
            { x =  200.0, y = -1850.0, z = 27.0, label = 'Tomberon Casa 1' },
            { x =  140.0, y = -1820.0, z = 28.5, label = 'Container Bloc 2' },
            { x =   80.0, y = -1790.0, z = 29.0, label = 'Tomberon Casa 3' },
            { x =   20.0, y = -1760.0, z = 29.5, label = 'Container Bloc 4' },
            { x =  -40.0, y = -1730.0, z = 30.0, label = 'Tomberon Casa 5' },
            { x = -100.0, y = -1700.0, z = 31.0, label = 'Container Bloc 6' },
            { x = -160.0, y = -1670.0, z = 32.0, label = 'Tomberon Casa 7' },
            { x = -220.0, y = -1640.0, z = 32.5, label = 'Container Bloc 8' },
            { x = -280.0, y = -1610.0, z = 33.5, label = 'Container Final 9' },
        },
    },
    {
        id        = 3,
        name      = 'Ruta Comerciala Mission Row',
        waypoints = {
            { x = -300.0, y = -1170.0, z = 25.5, label = 'Container Magazin 1' },
            { x = -260.0, y = -1140.0, z = 26.0, label = 'Tomberon Strada 2' },
            { x = -220.0, y = -1110.0, z = 26.5, label = 'Container Magazin 3' },
            { x = -180.0, y = -1075.0, z = 27.5, label = 'Container Birou 4' },
            { x = -140.0, y = -1045.0, z = 28.5, label = 'Tomberon Birou 5' },
            { x = -100.0, y = -1010.0, z = 29.5, label = 'Container Comercial 6' },
            { x =  -60.0, y =  -975.0, z = 30.5, label = 'Container Comercial 7' },
            { x =  -20.0, y =  -940.0, z = 30.0, label = 'Tomberon Strada 8' },
            { x =   20.0, y =  -905.0, z = 29.5, label = 'Container Final 9' },
            { x =   60.0, y =  -870.0, z = 30.0, label = 'Container Final 10' },
        },
    },
}
