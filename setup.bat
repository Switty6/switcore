@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================
echo   SwitCore - Setup rapid
echo ============================================
echo.
echo Acest script:
echo   1. Instaleaza dependentele Node (postgres + settings-panel)
echo   2. Creeaza config.local.js pentru baza de date si pentru panoul de setari
echo.

where npm >nul 2>nul
if errorlevel 1 (
    echo [EROARE] Node.js / npm nu sunt instalate sau nu sunt in PATH.
    echo Instaleaza Node.js LTS de pe https://nodejs.org/ si reia.
    echo.
    pause
    exit /b 1
)

echo [1/3] Modulul postgres...
if exist "[switcore]\postgres\node_modules\" (
    echo       Dependentele exista deja, sar peste.
) else (
    pushd "[switcore]\postgres"
    call npm install
    if errorlevel 1 (
        echo [EROARE] npm install a esuat in postgres.
        popd
        pause
        exit /b 1
    )
    popd
    echo       Gata.
)

echo [2/3] Modulul settings-panel...
if exist "[switcore]\settings-panel\node_modules\" (
    echo       Dependentele exista deja, sar peste.
) else (
    pushd "[switcore]\settings-panel"
    call npm install
    if errorlevel 1 (
        echo [EROARE] npm install a esuat in settings-panel.
        popd
        pause
        exit /b 1
    )
    popd
    echo       Gata.
)

echo [3/3] Configurare baza de date si panou setari...
set "PGCFG=[switcore]\postgres\config.local.js"
set "PANELCFG=[switcore]\settings-panel\config.local.js"

if exist "%PGCFG%" if exist "%PANELCFG%" (
    echo       Ambele config.local.js exista deja, nu le suprascriu.
    goto :done
)

echo.
echo       Introdu datele de conectare la PostgreSQL.
echo       Apasa Enter ca sa accepti valoarea din [paranteze].
echo.
set "DBHOST=localhost"
set "DBPORT=5432"
set "DBNAME=switcore"
set "DBUSER=postgres"
set "PANELUSER=admin"
set "PANELPASS="
set /p "DBHOST=Host [localhost]: "
set /p "DBPORT=Port [5432]: "
set /p "DBNAME=Nume baza [switcore]: "
set /p "DBUSER=Utilizator [postgres]: "
set /p "DBPASS=Parola DB: "
echo.
echo       Panou web de setari (modulul settings-panel):
set /p "PANELUSER=Utilizator panou [admin]: "
set /p "PANELPASS=Parola panou (Enter = generez una aleatoare): "

if "%DBPASS%"=="" (
    echo.
    echo       Nu ai pus parola DB. Copiez exemplele, le editezi manual mai tarziu.
    if not exist "%PGCFG%" copy /y "[switcore]\postgres\config.local.js.example" "%PGCFG%" >nul
    if not exist "%PANELCFG%" copy /y "[switcore]\settings-panel\config.js.example" "%PANELCFG%" >nul
    goto :done
)

if exist "%PGCFG%" goto :panelcfg
set "OUT=%PGCFG%"
node -e "const fs=require('fs');const c={host:process.env.DBHOST,port:+process.env.DBPORT,database:process.env.DBNAME,user:process.env.DBUSER,password:process.env.DBPASS,ssl:false,max:20,idleTimeoutMillis:30000,connectionTimeoutMillis:2000};fs.writeFileSync(process.env.OUT,'module.exports = '+JSON.stringify(c,null,4)+';\n');"
if errorlevel 1 (
    echo [EROARE] Nu am putut scrie postgres\config.local.js. Copiez exemplul.
    copy /y "[switcore]\postgres\config.local.js.example" "%PGCFG%" >nul
) else (
    echo       Am scris postgres\config.local.js.
)

:panelcfg
if exist "%PANELCFG%" goto :done
set "OUT=%PANELCFG%"
node -e "const fs=require('fs'),crypto=require('crypto');const jwt=crypto.randomBytes(48).toString('hex');let ap=process.env.PANELPASS||'';const gen=ap.length===0;if(gen)ap=crypto.randomBytes(9).toString('base64').replace(/[+/=]/g,'').slice(0,12);const c={port:8080,jwtSecret:jwt,jwtExpiry:'24h',admin:{username:process.env.PANELUSER||'admin',password:ap},database:{host:process.env.DBHOST,port:+process.env.DBPORT,database:process.env.DBNAME,user:process.env.DBUSER,password:process.env.DBPASS},corsOrigins:['http://localhost:8080']};fs.writeFileSync(process.env.OUT,'module.exports = '+JSON.stringify(c,null,4)+';\n');if(gen)console.log('       Parola generata pentru panou, noteaz-o: '+ap);"
if errorlevel 1 (
    echo [EROARE] Nu am putut scrie settings-panel\config.local.js. Copiez exemplul.
    copy /y "[switcore]\settings-panel\config.js.example" "%PANELCFG%" >nul
) else (
    echo       Am scris settings-panel\config.local.js.
)

:done
echo.
echo ============================================
echo   Setup terminat!
echo ============================================
echo.
echo Ce mai ai de facut manual:
echo   - In pgAdmin: creeaza baza de date (numele pe care l-ai pus mai sus).
echo   - In server-data\server.cfg: pune cheia de licenta la sv_licenseKey.
echo   - Porneste serverul (run.bat). Tabelele se creeaza singure la primul start.
echo.
pause
endlocal
