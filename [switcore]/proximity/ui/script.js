let currentInteraction = null;
let markerElement = null;
let textElement = null;
let containerElement = null;
let labelElement = null;
let keyBadgeElement = null;
let wrapperElement = null;
let counterElement = null;
let interactionsListElement = null;
let distanceDisplayElement = null;
let lastInteractionsListHash = null;
let currentIndexMap = null;

window.addEventListener('DOMContentLoaded', () => {
    containerElement = document.getElementById('interaction-container');
    wrapperElement = containerElement?.querySelector('.interaction-wrapper');
    markerElement = document.getElementById('interaction-container')?.querySelector('.compact-marker');
    textElement = containerElement?.querySelector('.compact-text');
    labelElement = document.getElementById('label');
    keyBadgeElement = document.getElementById('keyBadge');
    counterElement = document.getElementById('counter');
    interactionsListElement = document.getElementById('interactionsList');
    distanceDisplayElement = document.getElementById('distanceDisplay');
    
    window.addEventListener('keydown', handleKeyDown);
    
    if (interactionsListElement) {
        interactionsListElement.addEventListener('click', (e) => {
            const itemElement = e.target.closest('.interaction-item');
            if (!itemElement) return;
            
            e.preventDefault();
            e.stopPropagation();
            e.stopImmediatePropagation();
            
            const index = parseInt(itemElement.dataset.index) || 0;
            let targetIndex = index + 1;
            if (currentIndexMap && currentIndexMap[targetIndex]) {
                targetIndex = currentIndexMap[targetIndex];
            }
            
            let resourceName = 'proximity';
            try {
                if (typeof window.GetParentResourceName === 'function') {
                    resourceName = window.GetParentResourceName();
                } else if (typeof window.parent !== 'undefined' && typeof window.parent.GetParentResourceName === 'function') {
                    resourceName = window.parent.GetParentResourceName();
                } else {
                    resourceName = GetParentResourceName();
                }
            } catch(err) {
                resourceName = 'proximity';
            }
            
            fetch(`https://${resourceName}/selectInteraction`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ index: targetIndex })
            }).then(() => {
                return fetch(`https://${resourceName}/interact`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ index: targetIndex })
                });
            }).then((response) => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.text();
            }).then((text) => {
            }).catch((err) => {
            });
        });
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'showInteraction':
            showInteraction(data);
            break;
        case 'hideInteraction':
            hideInteraction();
            break;
        case 'updatePosition':
            updatePosition(data.screenX, data.screenY);
            break;
        case 'updateConfig':
            updateConfig(data.config);
            break;
        case 'setMouseEnabled':
            setMouseEnabled(data.enabled);
            break;
    }
});

function showInteraction(data) {
    if (!containerElement || !markerElement || !textElement || !labelElement || !keyBadgeElement) return;
    
    currentInteraction = data.interaction;
    
    if (data.showText !== false) {
        if (textElement) textElement.style.display = 'flex';
        if (data.label) {
            labelElement.textContent = data.label;
        }
        if (data.keyName) {
            keyBadgeElement.textContent = data.keyName;
        }
    } else {
        if (textElement) textElement.style.display = 'none';
    }
    
    if (data.distance !== undefined && distanceDisplayElement) {
        distanceDisplayElement.textContent = `${data.distance.toFixed(1)}m`;
        distanceDisplayElement.classList.add('visible');
    } else if (distanceDisplayElement) {
        distanceDisplayElement.classList.remove('visible');
    }
    
    if (data.multipleInteractions && data.totalCount > 1 && counterElement) {
        if (data.mouseEnabled) {
            counterElement.textContent = `${data.currentIndex} / ${data.totalCount}`;
            counterElement.className = 'interaction-counter';
        } else {
            const counterNumber = document.createElement('span');
            counterNumber.className = 'counter-number';
            counterNumber.textContent = data.totalCount;
            const counterText = document.createElement('span');
            counterText.className = 'counter-text';
            counterText.textContent = ' interactiuni';
            counterElement.innerHTML = '';
            counterElement.appendChild(counterNumber);
            counterElement.appendChild(counterText);
            counterElement.className = 'interaction-counter counter-simple';
            if (data.markerColor) {
                const r = data.markerColor.r || 0;
                const g = data.markerColor.g || 255;
                const b = data.markerColor.b || 0;
                counterNumber.style.color = `rgb(${r}, ${g}, ${b})`;
                counterNumber.style.textShadow = `0 0 8px rgba(${r}, ${g}, ${b}, 0.6)`;
            }
        }
        counterElement.classList.add('visible');
    } else if (counterElement) {
        counterElement.classList.remove('visible');
    }
    
    if (data.mouseEnabled !== undefined) {
        setMouseEnabled(data.mouseEnabled);
    }
    
    if (data.showList && data.multipleInteractions && data.interactionsList && interactionsListElement) {
        const currentHash = JSON.stringify(data.interactionsList.map(item => ({
            label: item.label,
            selected: item.selected
        })));
        
        currentIndexMap = data.indexMap || null;
        
        const markerColor = data.markerColor || data.color;
        const r = markerColor ? (markerColor.r || 0) : 0;
        const g = markerColor ? (markerColor.g || 255) : 255;
        const b = markerColor ? (markerColor.b || 0) : 0;
        
        if (currentHash !== lastInteractionsListHash) {
            interactionsListElement.innerHTML = '';
            
            const itemCount = data.interactionsList.length;
            interactionsListElement.classList.remove('multi-column', 'columns-2', 'columns-3');
            if (itemCount > 3) {
                interactionsListElement.classList.add('multi-column');
                if (itemCount <= 6) {
                    interactionsListElement.classList.add('columns-2');
                } else {
                    interactionsListElement.classList.add('columns-3');
                }
            }
            
            data.interactionsList.forEach((item, index) => {
                const itemElement = document.createElement('div');
                itemElement.className = `interaction-item ${item.selected ? 'selected' : ''}`;
                itemElement.dataset.index = index;
                itemElement.innerHTML = `
                    <span class="interaction-item-label">${item.label}</span>
                `;
                if (item.selected) {
                    itemElement.style.background = `rgba(${r}, ${g}, ${b}, 0.2)`;
                    itemElement.style.borderColor = `rgba(${r}, ${g}, ${b}, 0.6)`;
                } else {
                    itemElement.style.borderColor = `rgba(${r}, ${g}, ${b}, 0.3)`;
                }
                itemElement.addEventListener('mouseenter', function() {
                    this.style.background = `rgba(${r}, ${g}, ${b}, 0.15)`;
                    this.style.borderColor = `rgba(${r}, ${g}, ${b}, 0.4)`;
                });
                itemElement.addEventListener('mouseleave', function() {
                    if (!this.classList.contains('selected')) {
                        this.style.background = `rgba(0, 0, 0, 0.5)`;
                        this.style.borderColor = `rgba(${r}, ${g}, ${b}, 0.3)`;
                    }
                });
                interactionsListElement.appendChild(itemElement);
            });
            lastInteractionsListHash = currentHash;
        } else {
            const existingItems = interactionsListElement.querySelectorAll('.interaction-item');
            existingItems.forEach((itemElement, index) => {
                if (data.interactionsList[index]) {
                    const item = data.interactionsList[index];
                    if (item.selected) {
                        itemElement.classList.add('selected');
                        itemElement.style.background = `rgba(${r}, ${g}, ${b}, 0.2)`;
                        itemElement.style.borderColor = `rgba(${r}, ${g}, ${b}, 0.6)`;
                    } else {
                        itemElement.classList.remove('selected');
                        itemElement.style.background = `rgba(0, 0, 0, 0.5)`;
                        itemElement.style.borderColor = `rgba(${r}, ${g}, ${b}, 0.3)`;
                    }
                }
            });
        }
        interactionsListElement.classList.add('visible');
    } else if (interactionsListElement) {
        interactionsListElement.classList.remove('visible', 'multi-column', 'columns-2', 'columns-3');
        lastInteractionsListHash = null;
        currentIndexMap = null;
    }
    
    if (data.screenX !== undefined && data.screenY !== undefined) {
        updatePosition(data.screenX, data.screenY);
    }
    
    if (data.color || data.markerColor) {
        updateColors(data.markerColor || data.color);
    }
    
    containerElement.classList.remove('hidden');
    if (markerElement) {
        markerElement.classList.add('active');
    }
}

function hideInteraction() {
    if (!containerElement || !markerElement) return;
    
    containerElement.classList.add('hidden');
    markerElement.classList.remove('active');
    currentInteraction = null;
}

function updatePosition(screenX, screenY) {
    if (!containerElement) return;
    
    containerElement.style.left = screenX + 'px';
    containerElement.style.top = screenY + 'px';
    containerElement.style.transform = 'translate(-50%, -50%)';
}

function updateColors(color) {
    if (!markerElement || !textElement) return;
    
    const r = color.r || 0;
    const g = color.g || 255;
    const b = color.b || 0;
    const a = color.a !== undefined ? color.a : 0.8;
    
    const rgbColor = `rgb(${r}, ${g}, ${b})`;
    const rgbColorAlpha = `rgba(${r}, ${g}, ${b}, ${a})`;
    const rgbColorLight = `rgba(${r}, ${g}, ${b}, 0.15)`;
    const rgbColorBorder = `rgba(${r}, ${g}, ${b}, 0.6)`;
    const rgbColorGlow = `rgba(${r}, ${g}, ${b}, 1)`;
    
    const dot = markerElement.querySelector('.marker-dot');
    const ring = markerElement.querySelector('.marker-ring');
    const pulse = markerElement.querySelector('.marker-pulse');
    
    if (dot) {
        dot.style.background = rgbColor;
        dot.style.boxShadow = `
            0 0 10px ${rgbColorGlow},
            0 0 20px ${rgbColorAlpha},
            0 0 30px rgba(${r}, ${g}, ${b}, 0.6)
        `;
        dot.style.display = 'none';
        dot.offsetHeight;
        dot.style.display = 'block';
    }
    
    if (ring) {
        ring.style.borderColor = rgbColorBorder;
        ring.style.borderTopColor = rgbColorGlow;
        ring.style.transform = 'translate(-50%, -50%) rotate(0deg)';
        ring.offsetHeight;
    }
    
    if (pulse) {
        pulse.style.borderColor = `rgba(${r}, ${g}, ${b}, 0.4)`;
    }
    
    if (keyBadgeElement) {
        keyBadgeElement.style.background = rgbColorLight;
        keyBadgeElement.style.borderColor = rgbColorBorder;
        keyBadgeElement.style.color = rgbColor;
        keyBadgeElement.style.boxShadow = `
            0 0 8px rgba(${r}, ${g}, ${b}, 0.4),
            inset 0 0 8px rgba(${r}, ${g}, ${b}, 0.1)
        `;
    }
}

function GetParentResourceName() {
    if (typeof window.GetParentResourceName === 'function') {
        return window.GetParentResourceName();
    }
    if (typeof window.parent !== 'undefined' && typeof window.parent.GetParentResourceName === 'function') {
        return window.parent.GetParentResourceName();
    }
    return window.location.hostname.replace('nui-game-internal', '').replace(/^.*\/([^\/]+)\/.*$/, '$1') || 'proximity';
}

function updateConfig(config) {
    if (config.showMarker !== undefined) {
        if (markerElement) {
            markerElement.style.display = config.showMarker ? 'flex' : 'none';
        }
    }
    
    if (config.showText !== undefined) {
        if (textElement) {
            textElement.style.display = config.showText ? 'flex' : 'none';
        }
    }
}

function setMouseEnabled(enabled) {
    window.mouseNavigationEnabled = enabled;
    
    if (containerElement) {
        if (enabled) {
            containerElement.classList.add('mouse-enabled');
        } else {
            containerElement.classList.remove('mouse-enabled');
        }
    }
    
    if (keyBadgeElement && currentInteraction) {
        if (enabled) {
            keyBadgeElement.textContent = 'Click';
        } else {
        }
    }
}

function handleKeyDown(event) {
    if (!window.mouseNavigationEnabled) return;
    
    let resourceName = 'proximity';
    try {
        if (typeof window.GetParentResourceName === 'function') {
            resourceName = window.GetParentResourceName();
        } else if (typeof window.parent !== 'undefined' && typeof window.parent.GetParentResourceName === 'function') {
            resourceName = window.parent.GetParentResourceName();
        } else {
            resourceName = GetParentResourceName();
        }
    } catch(err) {
        resourceName = 'proximity';
    }
    
    if (event.key === 'Escape' || event.keyCode === 27) {
        event.preventDefault();
        event.stopPropagation();
        fetch(`https://${resourceName}/closeMouse`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).catch(() => {});
        return;
    }
    
    if ((event.key === 'Alt' || event.keyCode === 18) && !event.ctrlKey && !event.shiftKey) {
        event.preventDefault();
        event.stopPropagation();
        fetch(`https://${resourceName}/toggleMouse`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).catch(() => {});
        return;
    }
}
