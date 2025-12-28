// DPS-Parking UI
// Placeholder - Replace with your server's UI framework

let isOpen = false;
let vehicles = [];

// Listen for NUI messages
window.addEventListener('message', function(event) {
    const data = event.data;

    switch(data.action) {
        case 'open':
            openMenu(data.vehicles, data.stats);
            break;
        case 'close':
            closeMenu();
            break;
        case 'update':
            updateVehicles(data.vehicles);
            break;
    }
});

function openMenu(vehicleData, stats) {
    isOpen = true;
    vehicles = vehicleData || [];

    document.getElementById('parking-menu').classList.remove('hidden');

    if (stats) {
        document.getElementById('parked-count').textContent = `${stats.used}/${stats.max}`;
        document.getElementById('vip-status').textContent = stats.isVip ? 'Yes' : 'No';
    }

    renderVehicles();
}

function closeMenu() {
    isOpen = false;
    document.getElementById('parking-menu').classList.add('hidden');

    // Notify client
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function renderVehicles() {
    const list = document.getElementById('vehicle-list');
    list.innerHTML = '';

    if (vehicles.length === 0) {
        list.innerHTML = '<div class="vehicle-item"><div class="info">No parked vehicles</div></div>';
        return;
    }

    vehicles.forEach(vehicle => {
        const item = document.createElement('div');
        item.className = 'vehicle-item';
        item.innerHTML = `
            <div class="plate">${vehicle.plate}</div>
            <div class="info">${vehicle.model || 'Unknown'} - ${vehicle.street || 'Unknown location'}</div>
            <div class="actions">
                <button class="btn btn-primary" onclick="requestDelivery('${vehicle.plate}')">Request Delivery</button>
                <button class="btn btn-secondary" onclick="viewOnMap('${vehicle.plate}')">View on Map</button>
            </div>
        `;
        list.appendChild(item);
    });
}

function updateVehicles(vehicleData) {
    vehicles = vehicleData || [];
    if (isOpen) {
        renderVehicles();
    }
}

function requestDelivery(plate) {
    fetch(`https://${GetParentResourceName()}/requestDelivery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plate: plate })
    });
}

function viewOnMap(plate) {
    fetch(`https://${GetParentResourceName()}/viewOnMap`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plate: plate })
    });
}

// Escape to close
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && isOpen) {
        closeMenu();
    }
});

// Resource name helper
function GetParentResourceName() {
    return 'dps-parking';
}
