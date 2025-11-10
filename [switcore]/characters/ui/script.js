let currentCharacters = [];
let selectedCharacterId = null;
let locale = {}; // Locale data from server
let appearanceData = {
    headBlend: {
        shapeFirst: 0,
        shapeSecond: 0,
        shapeThird: 0,
        skinFirst: 0,
        skinSecond: 0,
        skinThird: 0,
        shapeMix: 0.5,
        skinMix: 0.5,
        thirdMix: 0.0
    },
    faceFeatures: {},
    overlays: {}
};

// Helper function to translate
function t(key, ...args) {
    let translation = locale[key];
    if (!translation) {
        return key;
    }
    
    if (args.length > 0) {
        args.forEach((arg, index) => {
            translation = translation.replace(`{${index + 1}}`, arg);
        });
    }
    
    return translation;
}

// Initialize UI
window.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    setupAppearanceSliders();
    updateUITexts();
});

// Update UI texts with locale
function updateUITexts() {
    // Update all elements with data-locale attribute
    document.querySelectorAll('[data-locale]').forEach(el => {
        const key = el.getAttribute('data-locale');
        if (locale[key]) {
            el.textContent = locale[key];
        }
    });
    
    // Update placeholders
    document.querySelectorAll('[data-placeholder]').forEach(el => {
        const key = el.getAttribute('data-placeholder');
        if (locale[key]) {
            el.placeholder = locale[key];
        }
    });
}

// Setup event listeners
function setupEventListeners() {
    // Create character button
    const createBtn = document.getElementById('create-character-btn');
    if (createBtn) {
        createBtn.addEventListener('click', () => {
            showCreateForm();
        });
    }
    
    // Cancel create button
    const cancelBtn = document.getElementById('cancel-create-btn');
    if (cancelBtn) {
        cancelBtn.addEventListener('click', () => {
            showCharacterList();
        });
    }
    
    // Confirm create button
    const confirmBtn = document.getElementById('confirm-create-btn');
    if (confirmBtn) {
        confirmBtn.addEventListener('click', () => {
            handleCreateCharacter();
        });
    }
    
    // Form inputs validation
    const firstNameInput = document.getElementById('first-name');
    const lastNameInput = document.getElementById('last-name');
    const ageInput = document.getElementById('age');
    
    if (firstNameInput) {
        firstNameInput.addEventListener('input', () => {
            validateFirstName();
        });
    }
    
    if (lastNameInput) {
        lastNameInput.addEventListener('input', () => {
            validateLastName();
        });
    }
    
    if (ageInput) {
        ageInput.addEventListener('input', () => {
            validateAge();
        });
    }
}

// Setup appearance sliders
function setupAppearanceSliders() {
    // Parent sliders
    setupSlider('parent1', 'parent1-value', 0, 45, (value) => {
        appearanceData.headBlend.shapeFirst = parseInt(value);
        appearanceData.headBlend.skinFirst = parseInt(value);
    });
    
    setupSlider('parent2', 'parent2-value', 0, 45, (value) => {
        appearanceData.headBlend.shapeSecond = parseInt(value);
        appearanceData.headBlend.skinSecond = parseInt(value);
    });
    
    setupSlider('parent-mix', 'parent-mix-value', 0, 100, (value) => {
        appearanceData.headBlend.shapeMix = value / 100;
        appearanceData.headBlend.skinMix = value / 100;
        updateSliderValue('parent-mix-value', value + '%');
    });
    
    // Face features
    setupSlider('nose-width', 'nose-width-value', 0, 100, (value) => {
        appearanceData.faceFeatures['Nose_Width'] = (value - 50) / 50;
    });
    
    setupSlider('mouth-width', 'mouth-width-value', 0, 100, (value) => {
        appearanceData.faceFeatures['Mouth_Width'] = (value - 50) / 50;
    });
    
    setupSlider('eyes-size', 'eyes-size-value', 0, 100, (value) => {
        appearanceData.faceFeatures['Eyes_Size'] = (value - 50) / 50;
    });
}

function setupSlider(sliderId, valueId, min, max, callback) {
    const slider = document.getElementById(sliderId);
    const valueDisplay = document.getElementById(valueId);
    
    if (!slider || !valueDisplay) return;
    
    slider.min = min;
    slider.max = max;
    slider.value = slider.value || min;
    
    updateSliderValue(valueId, slider.value);
    
    slider.addEventListener('input', () => {
        updateSliderValue(valueId, slider.value);
        if (callback) callback(slider.value);
    });
}

function updateSliderValue(valueId, value) {
    const valueDisplay = document.getElementById(valueId);
    if (valueDisplay) {
        valueDisplay.textContent = value;
    }
}

// Show character list
function showCharacterList() {
    const listEl = document.getElementById('character-list');
    const formEl = document.getElementById('create-form');
    
    if (listEl) listEl.classList.remove('hidden');
    if (formEl) formEl.classList.add('hidden');
}

// Show create form
function showCreateForm() {
    const listEl = document.getElementById('character-list');
    const formEl = document.getElementById('create-form');
    
    if (listEl) listEl.classList.add('hidden');
    if (formEl) formEl.classList.remove('hidden');
    
    // Reset form
    resetCreateForm();
}

// Reset create form
function resetCreateForm() {
    const firstNameInput = document.getElementById('first-name');
    const lastNameInput = document.getElementById('last-name');
    const ageInput = document.getElementById('age');
    
    if (firstNameInput) firstNameInput.value = '';
    if (lastNameInput) lastNameInput.value = '';
    if (ageInput) ageInput.value = '';
    
    // Reset appearance
    appearanceData = {
        headBlend: {
            shapeFirst: 0,
            shapeSecond: 0,
            shapeThird: 0,
            skinFirst: 0,
            skinSecond: 0,
            skinThird: 0,
            shapeMix: 0.5,
            skinMix: 0.5,
            thirdMix: 0.0
        },
        faceFeatures: {},
        overlays: {}
    };
    
    // Reset sliders
    document.getElementById('parent1').value = 0;
    document.getElementById('parent2').value = 0;
    document.getElementById('parent-mix').value = 50;
    document.getElementById('nose-width').value = 50;
    document.getElementById('mouth-width').value = 50;
    document.getElementById('eyes-size').value = 50;
    
    updateSliderValue('parent1-value', 0);
    updateSliderValue('parent2-value', 0);
    updateSliderValue('parent-mix-value', '50%');
    updateSliderValue('nose-width-value', 50);
    updateSliderValue('mouth-width-value', 50);
    updateSliderValue('eyes-size-value', 50);
    
    // Clear hints
    clearHints();
}

// Validate first name
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

// Validate last name
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

// Validate age
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

// Clear all hints
function clearHints() {
    const hints = document.querySelectorAll('.form-hint');
    hints.forEach(hint => {
        hint.textContent = '';
        hint.classList.remove('error');
    });
}

// Handle create character
function handleCreateCharacter() {
    const firstName = document.getElementById('first-name').value.trim();
    const lastName = document.getElementById('last-name').value.trim();
    const age = parseInt(document.getElementById('age').value);
    
    // Validate
    if (!validateFirstName() || !validateLastName() || !validateAge()) {
        showError(t('error_fill_all_fields'));
        return;
    }
    
    if (!firstName || !lastName || isNaN(age)) {
        showError(t('error_fill_fields'));
        return;
    }
    
    // Send to server
    fetch(`https://${GetParentResourceName()}/createCharacter`, {
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

// Show error message
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

// Render characters
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

// Create character card
function createCharacterCard(character) {
    const card = document.createElement('div');
    card.className = 'character-card';
    if (selectedCharacterId === character.id) {
        card.classList.add('selected');
    }
    
    const playtimeHours = Math.floor((character.playtime || 0) / 3600);
    const playtimeMinutes = Math.floor(((character.playtime || 0) % 3600) / 60);
    const playtimeStr = playtimeHours > 0 
        ? t('hours_minutes', playtimeHours, playtimeMinutes)
        : t('minutes_only', playtimeMinutes);
    
    const lastPlayed = character.last_played 
        ? new Date(character.last_played).toLocaleDateString('ro-RO')
        : t('never');
    
    card.innerHTML = `
        <div class="character-name">${character.first_name} ${character.last_name}</div>
        <div class="character-info"><strong>${t('age_label')}:</strong> ${character.age} ani</div>
        <div class="character-info"><strong>${t('playtime_label')}:</strong> ${playtimeStr}</div>
        <div class="character-info"><strong>${t('last_played_label')}:</strong> ${lastPlayed}</div>
        <div class="character-actions">
            <button class="character-button select-btn" data-id="${character.id}">${t('select')}</button>
            <button class="character-button delete delete-btn" data-id="${character.id}">${t('delete')}</button>
        </div>
    `;
    
    // Add event listeners
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

// Handle select character
function handleSelectCharacter(characterId) {
    selectedCharacterId = characterId;
    
    fetch(`https://${GetParentResourceName()}/selectCharacter`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ characterId: characterId })
    }).catch(err => {
        console.error('Error selecting character:', err);
    });
}

// Handle delete character
function handleDeleteCharacter(characterId) {
    if (!confirm(t('delete_confirm'))) {
        return;
    }
    
    fetch(`https://${GetParentResourceName()}/deleteCharacter`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ characterId: characterId })
    }).catch(err => {
        console.error('Error deleting character:', err);
    });
}

// Get parent resource name
function GetParentResourceName() {
    if (typeof window.GetParentResourceName === 'function') {
        return window.GetParentResourceName();
    }
    if (typeof window.parent !== 'undefined' && typeof window.parent.GetParentResourceName === 'function') {
        return window.parent.GetParentResourceName();
    }
    return window.location.hostname.replace('nui-game-internal', '').replace(/^.*\/([^\/]+)\/.*$/, '$1') || 'characters';
}

// Listen for messages from client
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'setLocale':
            locale = data.locale || {};
            updateUITexts();
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

