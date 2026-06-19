// SwI18n - helper de traducere pentru interfetele NUI SwitCore.
// Inclus de fiecare UI inainte de scriptul propriu:
//   <script src="nui://core/ui/i18n.js"></script>
// Lua trimite dictionarul cu SendNUIMessage({ action: 'sw:i18n', dict: ... })
// (vezi exports.core:getLocaleDict). HTML-ul se marcheaza cu data-i18n,
// data-i18n-placeholder sau data-i18n-title; textul existent ramane fallback.
// Pentru stringuri generate din JS: SwI18n.t('modul.cheie', arg1, arg2).
window.SwI18n = (() => {
    let dict = {};

    const get = (key) => String(key)
        .split('.')
        .reduce((obj, part) => (obj != null ? obj[part] : undefined), dict);

    const t = (key, ...args) => {
        let value = get(key);
        if (typeof value !== 'string') return key;
        args.forEach((arg, i) => {
            // split/join in loc de replace, ca argumentele cu caractere speciale sa ramana literale
            value = value.split('{' + (i + 1) + '}').join(String(arg));
        });
        return value;
    };

    const apply = (root = document) => {
        root.querySelectorAll('[data-i18n]').forEach((el) => {
            const value = t(el.dataset.i18n);
            if (value !== el.dataset.i18n) el.textContent = value;
        });
        root.querySelectorAll('[data-i18n-placeholder]').forEach((el) => {
            const value = t(el.dataset.i18nPlaceholder);
            if (value !== el.dataset.i18nPlaceholder) el.placeholder = value;
        });
        root.querySelectorAll('[data-i18n-title]').forEach((el) => {
            const value = t(el.dataset.i18nTitle);
            if (value !== el.dataset.i18nTitle) el.title = value;
        });
    };

    window.addEventListener('message', (event) => {
        const data = event.data || {};
        if (data.action === 'sw:i18n') {
            dict = data.dict || {};
            apply();
            // pentru stringurile randate din JS: re-randare la schimbarea limbii
            document.dispatchEvent(new CustomEvent('sw:i18n', { detail: dict }));
        }
    });

    return { t, apply, get };
})();
