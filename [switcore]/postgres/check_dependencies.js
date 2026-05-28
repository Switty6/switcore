const fs = require('fs');
const path = require('path');

const nodeModulesPath = path.join(__dirname, 'node_modules');
const packageJsonPath = path.join(__dirname, 'package.json');

function checkDependencies() {
    if (!fs.existsSync(packageJsonPath)) {
        console.error('[POSTGRES] ✗ Fișierul package.json nu există!');
        return false;
    }

    if (!fs.existsSync(nodeModulesPath)) {
        console.error('[POSTGRES] ✗ Dependențele nu sunt instalate!');
        console.error('[POSTGRES] Rulează: npm install');
        return false;
    }

    const pgPath = path.join(nodeModulesPath, 'pg');
    if (!fs.existsSync(pgPath)) {
        console.error('[POSTGRES] ✗ Pachetul pg nu este instalat!');
        console.error('[POSTGRES] Rulează: npm install');
        return false;
    }

    return true;
}

module.exports = checkDependencies;

if (require.main === module) {
    if (checkDependencies()) {
        console.log('[POSTGRES] ✓ Toate dependențele sunt instalate');
        process.exit(0);
    } else {
        console.error('[POSTGRES] ✗ Dependențele lipsesc!');
        process.exit(1);
    }
}
