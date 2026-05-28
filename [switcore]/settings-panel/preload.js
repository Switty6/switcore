{
    const { execSync } = require('child_process');
    const fs   = require('fs');
    const path = require('path');

    const dir = GetResourcePath(GetCurrentResourceName());

    if (!fs.existsSync(path.join(dir, 'node_modules'))) {
        console.log('[SwitCore Panel] Prima pornire - instalez dependintele (poate dura ~30s)...');
        try {
            execSync('npm install --silent', { cwd: dir, stdio: 'inherit' });
            console.log('[SwitCore Panel] Dependinte instalate cu succes!');
        } catch (err) {
            console.error('[SwitCore Panel] EROARE la npm install:', err.message);
            console.error('[SwitCore Panel] Asigura-te ca Node.js este instalat: https://nodejs.org/');
        }
    }
}
