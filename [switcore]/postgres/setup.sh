#!/bin/bash

echo "============================================"
echo " SwitCore PostgreSQL - Setup Script"
echo "============================================"
echo ""

# Verificam daca npm este instalat
if ! command -v npm &> /dev/null; then
    echo "[ERORARE] npm nu este instalat sau nu este in PATH!"
    echo "Instaleaza Node.js de pe https://nodejs.org/"
    exit 1
fi

echo "[1/2] Verificare dependente..."
if [ -d "node_modules" ]; then
    echo "      Dependentele sunt deja instalate!"
    echo "      Daca vrei sa reinstalezi, sterge folderul node_modules si ruleaza din nou."
else
    echo "[2/2] Instalare dependente..."
    npm install
    if [ $? -ne 0 ]; then
        echo "[ERORARE] Instalarea dependentelor a esuat!"
        exit 1
    fi
    echo ""
    echo "[SUCCES] Dependentele au fost instalate cu succes!"
fi

echo ""
echo "============================================"
echo " Setup completat!"
echo "============================================"
echo ""
echo "Urmatorii pasi:"
echo " 1. Editeaza config.local.js cu datele tale de conexiune"
echo " 2. Adauga \"ensure postgres\" in server.cfg"
echo " 3. Porneste serverul FiveM"
echo ""

