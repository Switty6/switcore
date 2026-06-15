let currentCharacters = [];
let selectedCharacterId = null;

let currentStep = 1;
let selectedGender = 0;
let currentFatherIdx = 0;
let currentMotherIdx = 0;

const fathers = [
    { id: 0, name: "Benjamin" }, { id: 1, name: "Daniel" }, { id: 2, name: "Joshua" }, { id: 3, name: "Noah" },
    { id: 4, name: "Andrew" }, { id: 5, name: "Joan" }, { id: 6, name: "Alex" }, { id: 7, name: "Isaac" },
    { id: 8, name: "Evan" }, { id: 9, name: "Ethan" }, { id: 10, name: "Vincent" }, { id: 11, name: "John" },
    { id: 12, name: "Michael" }, { id: 13, name: "Kevin" }, { id: 14, name: "Louis" }, { id: 15, name: "Samuel" },
    { id: 16, name: "Anthony" }, { id: 17, name: "Claude" }, { id: 18, name: "Niko" }, { id: 19, name: "John" }
];

const mothers = [
    { id: 21, name: "Hannah" }, { id: 22, name: "Audrey" }, { id: 23, name: "Jasmine" }, { id: 24, name: "Giselle" },
    { id: 25, name: "Amelia" }, { id: 26, name: "Isabella" }, { id: 27, name: "Zoe" }, { id: 28, name: "Ava" },
    { id: 29, name: "Camilla" }, { id: 30, name: "Violet" }, { id: 31, name: "Sophia" }, { id: 32, name: "Eveline" },
    { id: 33, name: "Nicole" }, { id: 34, name: "Ashley" }, { id: 35, name: "Grace" }, { id: 36, name: "Brianna" },
    { id: 37, name: "Natalie" }, { id: 38, name: "Olivia" }, { id: 39, name: "Elizabeth" }, { id: 40, name: "Charlotte" }
];

let appearanceData = {
    headBlend: {
        shapeFirst: fathers[0].id,
        shapeSecond: mothers[0].id,
        shapeThird: 0,
        skinFirst: fathers[0].id,
        skinSecond: mothers[0].id,
        skinThird: 0,
        shapeMix: 0.5,
        skinMix: 0.5,
        thirdMix: 0.0
    },
    gender: 0
};

// Traducere prin helperul standard SwI18n (core/ui/i18n.js); fallback pe cheie.
function t(key, ...args) {
    return SwI18n.t(`characters.${key}`, ...args);
}

window.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    setupAppearanceSliders();
    setupDeleteModal();
    if (window.lucide) lucide.createIcons();
});

// re-randare a stringurilor generate din JS la schimbarea dictionarului
document.addEventListener('sw:i18n', () => {
    if (currentCharacters.length > 0) {
        renderCharacters(currentCharacters);
    }
});

function setupEventListeners() {
    const createBtn = document.getElementById('create-character-btn');
    if (createBtn) {
        createBtn.addEventListener('click', () => {
            showCreateForm();
        });
    }

    const cancelBtn = document.getElementById('cancel-create-btn');
    if (cancelBtn) {
        cancelBtn.addEventListener('click', () => {
            showCharacterList();
        });
    }

    const nextStepBtn = document.getElementById('next-step-btn');
    if (nextStepBtn) {
        nextStepBtn.addEventListener('click', () => {
            if (!validateFirstName() || !validateLastName() || !validateAge()) {
                showError(t('error_fill_all_fields'));
                return;
            }
            const fn = document.getElementById('first-name').value.trim();
            const ln = document.getElementById('last-name').value.trim();
            const age = parseInt(document.getElementById('age').value);
            if (!fn || !ln || isNaN(age)) {
                showError(t('error_fill_fields'));
                return;
            }
            goToStep(2);
        });
    }

    const prevStepBtn = document.getElementById('prev-step-btn');
    if (prevStepBtn) {
        prevStepBtn.addEventListener('click', () => {
            goToStep(1);
        });
    }

    const confirmBtn = document.getElementById('confirm-create-btn');
    if (confirmBtn) {
        confirmBtn.addEventListener('click', () => {
            handleCreateCharacter();
        });
    }

    const firstNameInput = document.getElementById('first-name');
    const lastNameInput = document.getElementById('last-name');
    const ageInput = document.getElementById('age');
    
    if (firstNameInput) firstNameInput.addEventListener('input', validateFirstName);
    if (lastNameInput) lastNameInput.addEventListener('input', validateLastName);
    if (ageInput) ageInput.addEventListener('input', validateAge);

    const genderBtns = document.querySelectorAll('.gender-btn');
    genderBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            genderBtns.forEach(b => b.classList.remove('active'));
            e.target.classList.add('active');
            selectedGender = parseInt(e.target.getAttribute('data-gender'));
            appearanceData.gender = selectedGender;
        });
    });

    setupParentControl('father');
    setupParentControl('mother');
}

function setupParentControl(parent) {
    const prevBtn = document.getElementById(`prev-${parent}`);
    const nextBtn = document.getElementById(`next-${parent}`);
    
    if (prevBtn) {
        prevBtn.addEventListener('click', () => changeParent(parent, -1));
    }
    if (nextBtn) {
        nextBtn.addEventListener('click', () => changeParent(parent, 1));
    }
}

function changeParent(parent, direction) {
    if (parent === 'father') {
        currentFatherIdx = (currentFatherIdx + direction + fathers.length) % fathers.length;
        appearanceData.headBlend.shapeFirst = fathers[currentFatherIdx].id;
        appearanceData.headBlend.skinFirst = fathers[currentFatherIdx].id;
    } else {
        currentMotherIdx = (currentMotherIdx + direction + mothers.length) % mothers.length;
        appearanceData.headBlend.shapeSecond = mothers[currentMotherIdx].id;
        appearanceData.headBlend.skinSecond = mothers[currentMotherIdx].id;
    }
    updateParentUI();
    TriggerPreviewAppearance();
}

function updateParentUI() {
    const fatherNameEl = document.getElementById('father-name');
    const motherNameEl = document.getElementById('mother-name');
    
    if (fatherNameEl) fatherNameEl.textContent = fathers[currentFatherIdx].name;
    if (motherNameEl) motherNameEl.textContent = mothers[currentMotherIdx].name;
}

function setupAppearanceSliders() {
    setupSlider('parent-mix', 'parent-mix-value', 0, 100, (value) => {
        // GTA HeadBlend: shapeFirst=Father, shapeSecond=Mother, mix=0->100% Father, mix=1->100% Mother.
        // UI ruleaza invers (stanga=Mama, dreapta=Tata) -> invertim.
        let actualMix = 1.0 - (value / 100);

        appearanceData.headBlend.shapeMix = actualMix;
        appearanceData.headBlend.skinMix = actualMix;

        const valDisplay = document.getElementById('parent-mix-value');
        if (valDisplay) {
            if (value < 40) valDisplay.textContent = t('more_mother');
            else if (value > 60) valDisplay.textContent = t('more_father');
            else valDisplay.textContent = t('balanced');
        }

        TriggerPreviewAppearance();
    });
}

function setupSlider(sliderId, valueId, min, max, callback) {
    const slider = document.getElementById(sliderId);
    
    if (!slider) return;
    
    slider.min = min;
    slider.max = max;
    slider.value = slider.value || min;
    
    slider.addEventListener('input', () => {
        if (callback) callback(slider.value);
    });
}

function showCharacterList() {
    const listEl = document.getElementById('character-list');
    const formEl = document.getElementById('create-form');
    
    if (listEl) listEl.classList.remove('hidden');
    if (formEl) formEl.classList.add('hidden');
}

function showCreateForm() {
    const listEl = document.getElementById('character-list');
    const formEl = document.getElementById('create-form');

    if (listEl) listEl.classList.add('hidden');
    if (formEl) formEl.classList.remove('hidden');

    resetCreateForm();
    goToStep(1);
}

function goToStep(step) {
    currentStep = step;
    const container = document.getElementById('character-container');

    const dot1 = document.getElementById('step-dot-1');
    const dot2 = document.getElementById('step-dot-2');
    if (dot1 && dot2) {
        dot1.className = 'step-dot ' + (step === 1 ? 'active' : 'done');
        dot2.className = 'step-dot ' + (step === 2 ? 'active' : '');
    }

    if (step === 1) {
        document.getElementById('step-1').classList.remove('hidden');
        document.getElementById('step-2').classList.add('hidden');
        container.classList.remove('sidebar-mode');

        fetch(`https://characters/cancelCharacterCreation`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).catch(() => {});
    } else if (step === 2) {
        document.getElementById('step-1').classList.add('hidden');
        document.getElementById('step-2').classList.remove('hidden');
        container.classList.add('sidebar-mode');

        updateParentUI();

        fetch(`https://characters/setupCharacterCreation`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ gender: selectedGender, appearance: appearanceData })
        }).catch(() => {});
    }
}

function TriggerPreviewAppearance() {
    if (currentStep !== 2) return;
    
    fetch(`https://characters/previewAppearance`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ appearance: appearanceData })
    }).catch(err => {
        console.error('Error previewing appearance:', err);
    });
}

function resetCreateForm() {
    const firstNameInput = document.getElementById('first-name');
    const lastNameInput = document.getElementById('last-name');
    const ageInput = document.getElementById('age');

    if (firstNameInput) firstNameInput.value = '';
    if (lastNameInput) lastNameInput.value = '';
    if (ageInput) ageInput.value = '';

    selectedGender = 0;
    document.querySelectorAll('.gender-btn').forEach(b => b.classList.remove('active'));
    const maleBtn = document.getElementById('gender-male');
    if (maleBtn) maleBtn.classList.add('active');

    currentFatherIdx = 0;
    currentMotherIdx = 0;
    
    appearanceData = {
        headBlend: {
            shapeFirst: fathers[0].id,
            shapeSecond: mothers[0].id,
            shapeThird: 0,
            skinFirst: fathers[0].id,
            skinSecond: mothers[0].id,
            skinThird: 0,
            shapeMix: 0.5,
            skinMix: 0.5,
            thirdMix: 0.0
        },
        gender: 0
    };

    const mixSlider = document.getElementById('parent-mix');
    if (mixSlider) mixSlider.value = 50;
    const mixVal = document.getElementById('parent-mix-value');
    if (mixVal) mixVal.textContent = t('balanced');

    clearHints();
}

function validateFirstName() {
    const input = document.getElementById('first-name');
    const hint = document.getElementById('first-name-hint');
    
    if (!input || !hint) return true;
    
    const value = input.value.trim();
    const minLen = 2;
    const maxLen = 20;
    
    if (value.length === 0) {
        hint.textContent = '';
        hint.classList.remove('error');
        return false;
    }
    
    if (value.length < minLen) {
        hint.textContent = t('error_first_name_min', minLen);
        hint.classList.add('error');
        return false;
    }
    
    if (value.length > maxLen) {
        hint.textContent = t('error_first_name_max', maxLen);
        hint.classList.add('error');
        return false;
    }
    
    if (!/^[\w\s\-'\.]+$/.test(value)) {
        hint.textContent = t('error_first_name_invalid');
        hint.classList.add('error');
        return false;
    }
    
    hint.textContent = '';
    hint.classList.remove('error');
    return true;
}

function validateLastName() {
    const input = document.getElementById('last-name');
    const hint = document.getElementById('last-name-hint');
    
    if (!input || !hint) return true;
    
    const value = input.value.trim();
    const minLen = 2;
    const maxLen = 20;
    
    if (value.length === 0) {
        hint.textContent = '';
        hint.classList.remove('error');
        return false;
    }
    
    if (value.length < minLen) {
        hint.textContent = t('error_last_name_min', minLen);
        hint.classList.add('error');
        return false;
    }
    
    if (value.length > maxLen) {
        hint.textContent = t('error_last_name_max', maxLen);
        hint.classList.add('error');
        return false;
    }
    
    if (!/^[\w\s\-'\.]+$/.test(value)) {
        hint.textContent = t('error_last_name_invalid');
        hint.classList.add('error');
        return false;
    }
    
    hint.textContent = '';
    hint.classList.remove('error');
    return true;
}

function validateAge() {
    const input = document.getElementById('age');
    const hint = document.getElementById('age-hint');
    
    if (!input || !hint) return true;
    
    const value = parseInt(input.value);
    const minAge = 18;
    const maxAge = 80;
    
    if (isNaN(value) || value === '') {
        hint.textContent = '';
        hint.classList.remove('error');
        return false;
    }
    
    if (value < minAge) {
        hint.textContent = t('error_age_min', minAge);
        hint.classList.add('error');
        return false;
    }
    
    if (value > maxAge) {
        hint.textContent = t('error_age_max', maxAge);
        hint.classList.add('error');
        return false;
    }
    
    hint.textContent = '';
    hint.classList.remove('error');
    return true;
}

function clearHints() {
    const hints = document.querySelectorAll('.form-hint');
    hints.forEach(hint => {
        hint.textContent = '';
        hint.classList.remove('error');
    });
}

function handleCreateCharacter() {
    const firstName = document.getElementById('first-name').value.trim();
    const lastName = document.getElementById('last-name').value.trim();
    const age = parseInt(document.getElementById('age').value);

    if (!validateFirstName() || !validateLastName() || !validateAge()) {
        showError(t('error_fill_all_fields'));
        return;
    }

    if (!firstName || !lastName || isNaN(age)) {
        showError(t('error_fill_fields'));
        return;
    }

    fetch(`https://characters/createCharacter`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            firstName: firstName,
            lastName: lastName,
            age: age,
            appearance: appearanceData
        })
    }).catch(err => {
        console.error('Error creating character:', err);
    });
}

function showError(message) {
    const errorEl = document.getElementById('error-message');
    if (errorEl) {
        errorEl.textContent = message;
        errorEl.classList.remove('hidden');
        setTimeout(() => {
            errorEl.classList.add('hidden');
        }, 5000);
    }
}

function renderCharacters(characters) {
    const grid = document.getElementById('characters-grid');
    if (!grid) return;
    
    grid.innerHTML = '';
    currentCharacters = characters || [];
    
    if (currentCharacters.length === 0) {
        showCreateForm();
        return;
    }
    
    currentCharacters.forEach(character => {
        const card = createCharacterCard(character);
        grid.appendChild(card);
    });
}

function createCharacterCard(character) {
    const card = document.createElement('div');
    card.className = 'character-card';
    if (selectedCharacterId === character.id) {
        card.classList.add('selected');
    }
    
    const playtimeHours = Math.floor((character.playtime || 0) / 3600);
    const playtimeMinutes = Math.floor(((character.playtime || 0) % 3600) / 60);
    
    let playtimeStr = '';
    if (playtimeHours > 0) {
        playtimeStr = t('hours_minutes', playtimeHours, playtimeMinutes);
    } else if (playtimeMinutes > 0) {
        playtimeStr = t('minutes_only', playtimeMinutes);
    } else {
        playtimeStr = t('sub_one_minute');
    }
    
    let lastPlayed = t('never');
    if (character.last_played) {
        const d = new Date(String(character.last_played).replace(' ', 'T'));
        if (!isNaN(d.getTime())) {
            const day   = String(d.getDate()).padStart(2, '0');
            const month = String(d.getMonth() + 1).padStart(2, '0');
            const year  = d.getFullYear();
            lastPlayed  = `${day}/${month}/${year}`;
        }
    }

    const cashStr = (character.cash || 0).toLocaleString('ro-RO');
    const bankStr = (character.bank || 0).toLocaleString('ro-RO');
    
    card.innerHTML = `
        <div class="character-name">${character.first_name} ${character.last_name}</div>
        <div class="character-info"><strong>${t('age_label')}:</strong> ${t('age_years', character.age)}</div>
        <div class="character-info"><strong>${t('playtime_label')}:</strong> ${playtimeStr}</div>
        <div class="character-info"><strong>${t('cash_label')}:</strong> $${cashStr}</div>
        <div class="character-info"><strong>${t('bank_label')}:</strong> $${bankStr}</div>
        <div class="character-info"><strong>${t('last_played_label')}:</strong> ${lastPlayed}</div>
        <div class="character-actions">
            <button class="character-button select-btn" data-id="${character.id}">${t('select')}</button>
            <button class="character-button delete delete-btn" data-id="${character.id}">${t('delete')}</button>
        </div>
    `;

    const selectBtn = card.querySelector('.select-btn');
    const deleteBtn = card.querySelector('.delete-btn');
    
    if (selectBtn) {
        selectBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            handleSelectCharacter(character.id);
        });
    }
    
    if (deleteBtn) {
        deleteBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            handleDeleteCharacter(character.id);
        });
    }
    
    card.addEventListener('click', () => {
        handleSelectCharacter(character.id);
    });
    
    return card;
}

function handleSelectCharacter(characterId) {
    selectedCharacterId = characterId;
    
    fetch(`https://characters/selectCharacter`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ characterId: characterId })
    }).catch(err => {
        console.error('Error selecting character:', err);
    });
}

// window.confirm blocheaza thread-ul NUI in CEF -> folosim modal custom
let pendingDeleteId = null;

function setupDeleteModal() {
    const overlay = document.getElementById('delete-modal');
    const confirmBtn = document.getElementById('modal-confirm-btn');
    const cancelBtn = document.getElementById('modal-cancel-btn');

    cancelBtn.addEventListener('click', () => {
        overlay.classList.add('hidden');
        pendingDeleteId = null;
    });

    confirmBtn.addEventListener('click', () => {
        overlay.classList.add('hidden');
        if (pendingDeleteId === null) return;
        const id = pendingDeleteId;
        pendingDeleteId = null;
        fetch(`https://characters/deleteCharacter`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ characterId: id })
        }).catch(err => {
            console.error('Error deleting character:', err);
        });
    });
}

function handleDeleteCharacter(characterId) {
    const character = currentCharacters.find(c => c.id === characterId);
    const name = character ? `${character.first_name} ${character.last_name}` : '';

    const titleEl = document.getElementById('delete-modal-title');
    const bodyEl  = document.getElementById('delete-modal-body');
    if (titleEl) titleEl.textContent = name ? t('delete_title_named', name) : t('delete_title');
    if (bodyEl)  bodyEl.textContent  = t('delete_warning');

    pendingDeleteId = characterId;
    document.getElementById('delete-modal').classList.remove('hidden');
}

function GetParentResourceName() {
    if (typeof window.GetParentResourceName === 'function') {
        return window.GetParentResourceName();
    }
    if (typeof window.parent !== 'undefined' && typeof window.parent.GetParentResourceName === 'function') {
        return window.parent.GetParentResourceName();
    }
    return window.location.hostname.replace('nui-game-internal', '').replace(/^.*\/([^\/]+)\/.*$/, '$1') || 'characters';
}

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'open':
            document.getElementById('character-container').classList.remove('hidden');
            break;
        case 'updateCharacters':
            renderCharacters(data.characters);
            showCharacterList();
            break;
        case 'showCharacterList':
            renderCharacters(data.characters);
            showCharacterList();
            break;
        case 'showCreateForm':
            showCreateForm();
            break;
        case 'showError':
            showError(data.error);
            break;
        case 'close':
            document.getElementById('character-container').classList.add('hidden');
            break;
    }
});
