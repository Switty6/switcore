@echo off
echo ============================================
echo  SwitCore PostgreSQL - Setup Script
echo ============================================
echo.

REM Verificam daca npm este instalat
where npm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERORARE] npm nu este instalat sau nu este in PATH!
    echo Instaleaza Node.js de pe https://nodejs.org/
    pause
    exit /b 1
)

echo [1/2] Verificam dependentele...
if exist "node_modules\" (
    echo       Dependentele sunt deja instalate!
    echo       Daca vrei sa reinstalezi, sterge folderul node_modules si ruleaza din nou.
) else (
    echo [2/2] Instalare dependente...
    call npm install
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Instalarea dependentelor a esuat!
        pause
        exit /b 1
    )
    echo.
    echo [SUCCES] Dependentele au fost instalate cu succes!
)

echo.
echo ============================================
echo  Setup completat!
echo ============================================
echo.
echo Urmatorii pasi:
echo  1. Editează config.local.js cu datele tale de conexiune
echo  2. Adaugă "ensure postgres" in server.cfg
echo  3. Porneste serverul FiveM
echo.
pause

