const app = document.getElementById('app');
let currentId = null;
let isNew = false;
let violations = [];

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

function setSegment(groupId, value) {
    const group = document.getElementById(groupId);
    if (!group) return;
    group.querySelectorAll('.seg').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.value === String(value));
    });
}

function getSegment(groupId) {
    const active = document.querySelector(`#${groupId} .seg.active`);
    return active ? active.dataset.value : null;
}

function bindSegments() {
    $$('.btn-group').forEach(group => {
        group.querySelectorAll('.seg').forEach(btn => {
            btn.addEventListener('click', () => {
                group.querySelectorAll('.seg').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                if (group.id === 'unit') {
                    $('#boardUnit').textContent = btn.dataset.value;
                }
            });
        });
    });
}

function openUI(data) {
    currentId = data.id || null;
    isNew = !!data.isNew;
    violations = [];
    const list = $('#violationsList');
    if (list) list.innerHTML = '';

    const r = data.radar || data.defaults || {};
    $('#signBadge').textContent = currentId ? `SIGN #${currentId}` : 'SIGN #NEW';
    $('#signName').value = r.signName || '';
    $('#boardText').value = r.boardText || '';
    $('#displayText').value = r.displayText || 'YOUR SPEED';
    $('#overspeedText').value = r.overspeedText || 'SLOW DOWN';
    $('#speedLimit').value = r.speedLimit || 40;
    $('#range').value = r.range || 60;
    $('#angle').value = r.angle || 50;
    $('#direction').value = r.direction || 0;
    $('#cameraFlash').checked = r.cameraFlash !== false;
    $('#radarEnabled').checked = r.radarEnabled !== false;
    $('#requireApproach').checked = r.requireApproach !== false;

    setSegment('signMode', r.signMode || 'radar');
    setSegment('unit', r.unit || 'MPH');
    setSegment('mapBlip', r.mapBlip || 'police');
    setSegment('emergencyLights', r.emergencyLights || 'on_violation');

    let detect = 'players';
    if (r.detectPlayers && r.detectNPCs) detect = 'both';
    else if (r.detectNPCs && !r.detectPlayers) detect = 'npcs';
    setSegment('detectTarget', detect);

    updateRangeLabels();
    $('#boardLabel').textContent = r.displayText || 'YOUR SPEED';
    $('#boardSpeed').textContent = '—';
    $('#boardUnit').textContent = r.unit || 'MPH';

    $('#deleteBtn').style.display = currentId ? 'block' : 'none';

    app.classList.remove('hidden');
    switchTab('settings');
}

function closeUI() {
    app.classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
}

function collectData() {
    const detect = getSegment('detectTarget');
    const speedLimit = Math.min(200, Math.max(1, parseInt($('#speedLimit').value, 10) || 40));
    const range = Math.min(200, Math.max(5, parseFloat($('#range').value) || 60));
    const angle = Math.min(160, Math.max(5, parseFloat($('#angle').value) || 50));
    const direction = Math.min(90, Math.max(-90, parseFloat($('#direction').value) || 0));

    return {
        id: currentId,
        signName: ($('#signName').value || '').substring(0, 48),
        boardText: ($('#boardText').value || '').substring(0, 24),
        displayText: ($('#displayText').value || 'YOUR SPEED').substring(0, 32),
        overspeedText: ($('#overspeedText').value || 'SLOW DOWN').substring(0, 32),
        speedLimit,
        range,
        angle,
        direction,
        unit: getSegment('unit') || 'MPH',
        signMode: getSegment('signMode') || 'radar',
        mapBlip: getSegment('mapBlip') || 'police',
        emergencyLights: getSegment('emergencyLights') || 'on_violation',
        cameraFlash: $('#cameraFlash').checked,
        radarEnabled: $('#radarEnabled').checked,
        requireApproach: $('#requireApproach').checked,
        detectPlayers: detect === 'players' || detect === 'both',
        detectNPCs: detect === 'npcs' || detect === 'both',
        coords: window._pendingCoords || undefined,
        heading: window._pendingHeading || undefined,
    };
}

function updateRangeLabels() {
    $('#rangeVal').textContent = $('#range').value + ' m';
    $('#angleVal').textContent = $('#angle').value + '°';
    const dir = parseInt($('#direction').value, 10) || 0;
    let label = 'Centre';
    if (dir < -5) label = 'Left ' + Math.abs(dir) + '°';
    else if (dir > 5) label = 'Right ' + dir + '°';
    $('#dirVal').textContent = label;
}

function switchTab(name) {
    $$('.tab').forEach(t => t.classList.toggle('active', t.dataset.tab === name));
    $('#settingsTab').classList.toggle('hidden', name !== 'settings');
    $('#violationsTab').classList.toggle('hidden', name !== 'violations');
}

function addViolation(v) {
    if (!v) return;
    violations.unshift(v);
    const row = document.createElement('div');
    row.className = 'violation-row';
    row.innerHTML = `
        <span>${escapeHtml(v.time || '—')}</span>
        <span>${escapeHtml(v.plate || '—')}</span>
        <span>${escapeHtml(v.model || '—')}</span>
        <span class="speed-over">${v.speed || 0} ${v.unit || 'MPH'} (+${v.over || 0})</span>
        <span>${escapeHtml(v.driver || '—')}</span>
    `;
    const list = $('#violationsList');
    if (list) list.insertBefore(row, list.firstChild);
}

function escapeHtml(s) {
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || !d.action) return;
    if (d.action === 'open') {
        if (d.radar && d.radar.coords) {
            window._pendingCoords = d.radar.coords;
            window._pendingHeading = d.radar.heading;
        } else {
            window._pendingCoords = undefined;
            window._pendingHeading = undefined;
        }
        openUI(d);
    } else if (d.action === 'close') {
        app.classList.add('hidden');
    } else if (d.action === 'violation') {
        addViolation(d.data);
    }
});

document.addEventListener('DOMContentLoaded', () => {
    bindSegments();

    $('#closeBtn').addEventListener('click', closeUI);
    $('#range').addEventListener('input', updateRangeLabels);
    $('#angle').addEventListener('input', updateRangeLabels);
    $('#direction').addEventListener('input', updateRangeLabels);

    // Live board label preview
    const displayInput = $('#displayText');
    if (displayInput) {
        displayInput.addEventListener('input', () => {
            $('#boardLabel').textContent = displayInput.value || 'YOUR SPEED';
        });
    }

    $$('.tab').forEach(t => {
        t.addEventListener('click', () => switchTab(t.dataset.tab));
    });

    $('#saveBtn').addEventListener('click', () => {
        const data = collectData();
        const endpoint = (isNew || !currentId) ? 'place' : 'save';
        fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).catch(() => {});
    });

    $('#deleteBtn').addEventListener('click', () => {
        if (!currentId) return;
        fetch(`https://${GetParentResourceName()}/delete`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: currentId })
        }).catch(() => {});
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !app.classList.contains('hidden')) {
            closeUI();
        }
    });
});

function GetParentResourceName() {
    try {
        return window.GetParentResourceName();
    } catch (_) {
        return 'radar_trailer';
    }
}
