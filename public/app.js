/**
 * WareTrack WMS Web Application Controller
 */

// Global State
let AppState = {
  activeTab: 'dashboard',
  products: [],
  warehouses: [],
  locations: [],
  employees: [],
  inventory: []
};

// DOM Ready
document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  initModals();
  initThemeToggle();
  initSQLStudio();
  initQuickFilters();
  initResetDB();

  // Initial Load
  loadBootstrapData().then(() => {
    refreshCurrentTab();
  });
});

// Toast notification helper
function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `<span>${message}</span>`;
  container.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 300);
  }, 3500);
}

// Formatters
const formatCurrency = (num) => '$' + Number(num || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const formatNumber = (num) => Number(num || 0).toLocaleString('en-US');

// Navigation Tabs
function initNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  const tabPanes = document.querySelectorAll('.tab-pane');
  const heading = document.getElementById('page-heading');
  const subtitle = document.getElementById('page-subtitle');

  const titles = {
    dashboard: { h: 'Operations Dashboard', s: 'Real-time inventory levels, fulfillment pipelines, and analytics' },
    inventory: { h: 'Inventory & Bin Management', s: 'Multi-warehouse physical stock on hand, reserved quantities, and bin locations' },
    inbound: { h: 'Inbound Procurement & Receiving', s: 'Process goods receipts against purchase order lines (pkg_stock_movement.receive_stock)' },
    outbound: { h: 'Outbound Fulfillment & Shipments', s: 'Dispatch sales orders, release order reservations, and issue tracking IDs' },
    transfers: { h: 'Inter-Warehouse Stock Transfers', s: 'Relocate stock between facilities and storage bins' },
    audit: { h: 'Stock Transaction Audit Trail', s: 'Zero-loss immutable transaction logging with before/after audit states' },
    sql: { h: 'SQL Studio & View Explorer', s: 'Execute live SQL queries directly against database views and tables' }
  };

  navItems.forEach(btn => {
    btn.addEventListener('click', () => {
      const tab = btn.getAttribute('data-tab');
      AppState.activeTab = tab;

      navItems.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      tabPanes.forEach(p => p.classList.remove('active'));
      const targetPane = document.getElementById(`tab-${tab}`);
      if (targetPane) targetPane.classList.add('active');

      if (titles[tab]) {
        heading.textContent = titles[tab].h;
        subtitle.textContent = titles[tab].s;
      }

      refreshCurrentTab();
    });
  });
}

// Theme Toggle
function initThemeToggle() {
  const btn = document.getElementById('theme-toggle-btn');
  btn.addEventListener('click', () => {
    document.body.classList.toggle('light-theme');
    document.body.classList.toggle('dark-theme');
  });
}

// Bootstrap Static Dropdowns
async function loadBootstrapData() {
  try {
    const [prodRes, whRes, empRes] = await Promise.all([
      fetch('/api/products').then(r => r.json()),
      fetch('/api/warehouses').then(r => r.json()),
      fetch('/api/employees').then(r => r.json())
    ]);

    AppState.products = prodRes;
    AppState.warehouses = whRes.warehouses || [];
    AppState.locations = whRes.locations || [];
    AppState.employees = empRes || [];

    populateDropdowns();
  } catch (err) {
    console.error('Failed to load bootstrap data', err);
    showToast('Failed to load master metadata: ' + err.message, 'error');
  }
}

function populateDropdowns() {
  // Populate warehouses in filter
  const whFilter = document.getElementById('inv-wh-filter');
  whFilter.innerHTML = '<option value="">All Warehouses</option>' + 
    AppState.warehouses.map(w => `<option value="${w.warehouse_code}">${w.warehouse_code} - ${w.warehouse_name}</option>`).join('');

  // Populate categories in filter
  const categories = [...new Set(AppState.products.map(p => p.category_name))];
  const catFilter = document.getElementById('inv-cat-filter');
  catFilter.innerHTML = '<option value="">All Categories</option>' +
    categories.map(c => `<option value="${c}">${c}</option>`).join('');

  // Adjustment Modal Product & Warehouse
  const adjProd = document.getElementById('adj-product-id');
  adjProd.innerHTML = AppState.products.map(p => `<option value="${p.product_id}">${p.sku} — ${p.product_name}</option>`).join('');

  const adjWh = document.getElementById('adj-warehouse-id');
  adjWh.innerHTML = AppState.warehouses.map(w => `<option value="${w.warehouse_id}">${w.warehouse_code} (${w.warehouse_name})</option>`).join('');

  const adjEmp = document.getElementById('adj-employee-id');
  adjEmp.innerHTML = AppState.employees.map(e => `<option value="${e.employee_id}">${e.employee_code} - ${e.first_name} ${e.last_name} (${e.job_title})</option>`).join('');

  // Update locations on warehouse change
  adjWh.addEventListener('change', () => updateLocationDropdown(adjWh.value, 'adj-location-id'));
  if (AppState.warehouses.length > 0) {
    updateLocationDropdown(AppState.warehouses[0].warehouse_id, 'adj-location-id');
  }

  // Transfer Modal
  const xferProd = document.getElementById('xfer-product-id');
  xferProd.innerHTML = AppState.products.map(p => `<option value="${p.product_id}">${p.sku} — ${p.product_name}</option>`).join('');

  const xferFromWh = document.getElementById('xfer-from-wh');
  const xferToWh = document.getElementById('xfer-to-wh');
  xferFromWh.innerHTML = AppState.warehouses.map(w => `<option value="${w.warehouse_id}">${w.warehouse_code} (${w.warehouse_name})</option>`).join('');
  xferToWh.innerHTML = AppState.warehouses.map(w => `<option value="${w.warehouse_id}">${w.warehouse_code} (${w.warehouse_name})</option>`).join('');

  xferFromWh.addEventListener('change', () => updateLocationDropdown(xferFromWh.value, 'xfer-from-loc'));
  xferToWh.addEventListener('change', () => updateLocationDropdown(xferToWh.value, 'xfer-to-loc'));

  if (AppState.warehouses.length > 1) {
    xferToWh.selectedIndex = 1;
  }
  if (AppState.warehouses.length > 0) {
    updateLocationDropdown(xferFromWh.value, 'xfer-from-loc');
    updateLocationDropdown(xferToWh.value, 'xfer-to-loc');
  }

  const xferEmp = document.getElementById('xfer-employee-id');
  xferEmp.innerHTML = AppState.employees.map(e => `<option value="${e.employee_id}">${e.employee_code} - ${e.first_name} ${e.last_name}</option>`).join('');
}

function updateLocationDropdown(warehouseId, targetElementId) {
  const locDropdown = document.getElementById(targetElementId);
  const filteredLocs = AppState.locations.filter(l => l.warehouse_id == warehouseId);
  if (filteredLocs.length === 0) {
    locDropdown.innerHTML = '<option value="">No locations available</option>';
  } else {
    locDropdown.innerHTML = filteredLocs.map(l => `<option value="${l.location_id}">${l.location_code} (${l.zone_type})</option>`).join('');
  }
}

// Tab Content Refresh
function refreshCurrentTab() {
  switch (AppState.activeTab) {
    case 'dashboard':
      loadDashboardData();
      break;
    case 'inventory':
      loadInventoryData();
      break;
    case 'inbound':
      loadPurchaseOrders();
      break;
    case 'outbound':
      loadSalesOrders();
      break;
    case 'transfers':
      loadTransfers();
      break;
    case 'audit':
      loadAuditLog();
      break;
  }
}

// 1. DASHBOARD
async function loadDashboardData() {
  try {
    const data = await fetch('/api/dashboard').then(r => r.json());
    const m = data.metrics;

    document.getElementById('kpi-cost-val').textContent = formatCurrency(m.total_cost_value);
    document.getElementById('kpi-retail-val').textContent = formatCurrency(m.total_retail_value);
    document.getElementById('kpi-total-units').textContent = formatNumber(m.total_units);
    document.getElementById('kpi-wh-count').textContent = m.warehouse_count;
    document.getElementById('kpi-low-stock').textContent = m.low_stock_count;
    document.getElementById('kpi-overdue-pos').textContent = m.overdue_pos;

    // Badges
    document.getElementById('open-pos-badge').textContent = m.overdue_pos > 0 ? `${m.overdue_pos} alert` : '0';
    document.getElementById('pending-sos-badge').textContent = m.pending_shipments;

    // Valuation table
    const valBody = document.getElementById('valuation-table-body');
    if (data.valuation && data.valuation.length > 0) {
      valBody.innerHTML = data.valuation.map(v => `
        <tr>
          <td><strong>${v.warehouse_code}</strong></td>
          <td><span class="badge badge-purple">${v.category_name}</span></td>
          <td>${v.product_count}</td>
          <td><strong>${formatNumber(v.total_units)}</strong></td>
          <td>${formatCurrency(v.total_cost_value)}</td>
          <td>${formatCurrency(v.total_retail_value)}</td>
        </tr>
      `).join('');
    } else {
      valBody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">No inventory records found</td></tr>';
    }

    // Low stock table
    const lowBody = document.getElementById('low-stock-table-body');
    if (data.low_stock_items && data.low_stock_items.length > 0) {
      lowBody.innerHTML = data.low_stock_items.map(item => `
        <tr>
          <td><span class="badge badge-warning">${item.warehouse_code}</span></td>
          <td><code>${item.sku}</code></td>
          <td>${item.product_name}</td>
          <td><strong style="color:var(--accent-danger)">${item.total_on_hand}</strong></td>
          <td>${item.reorder_level}</td>
          <td><span class="badge badge-danger">-${item.qty_shortage}</span></td>
        </tr>
      `).join('');
    } else {
      lowBody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">All inventory levels above reorder threshold</td></tr>';
    }

    // Recent transactions
    const txBody = document.getElementById('dashboard-recent-tx');
    if (data.recent_transactions && data.recent_transactions.length > 0) {
      txBody.innerHTML = data.recent_transactions.map(tx => renderTransactionRow(tx)).join('');
    } else {
      txBody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">No audit transactions recorded yet</td></tr>';
    }

  } catch (err) {
    console.error('Failed to load dashboard data', err);
  }
}

// 2. INVENTORY
async function loadInventoryData() {
  try {
    const data = await fetch('/api/inventory').then(r => r.json());
    AppState.inventory = data;
    document.getElementById('inv-count-badge').textContent = data.length;
    renderFilteredInventory();
  } catch (err) {
    console.error('Failed to load inventory', err);
  }
}

function renderFilteredInventory() {
  const search = document.getElementById('inv-search-input').value.toLowerCase().trim();
  const whFilter = document.getElementById('inv-wh-filter').value;
  const catFilter = document.getElementById('inv-cat-filter').value;

  const filtered = AppState.inventory.filter(item => {
    const matchSearch = !search ||
      item.sku.toLowerCase().includes(search) ||
      item.product_name.toLowerCase().includes(search) ||
      item.location_code.toLowerCase().includes(search);
    const matchWh = !whFilter || item.warehouse_code === whFilter;
    const matchCat = !catFilter || item.category_name === catFilter;
    return matchSearch && matchWh && matchCat;
  });

  const tbody = document.getElementById('inventory-table-body');
  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="12" class="text-center text-muted">No matching inventory rows found</td></tr>';
    return;
  }

  tbody.innerHTML = filtered.map(item => `
    <tr>
      <td><strong>${item.warehouse_code}</strong></td>
      <td><code>${item.location_code}</code></td>
      <td><span class="badge ${item.zone_type === 'STORAGE' ? 'badge-info' : 'badge-warning'}">${item.zone_type}</span></td>
      <td><strong>${item.sku}</strong></td>
      <td>${item.product_name}</td>
      <td><span class="badge badge-purple">${item.category_name}</span></td>
      <td><strong>${formatNumber(item.qty_on_hand)}</strong></td>
      <td><span style="color:var(--accent-warning)">${item.qty_reserved}</span></td>
      <td><span class="badge badge-success">${item.qty_available}</span></td>
      <td>${formatCurrency(item.unit_cost)}</td>
      <td>${formatCurrency(item.stock_value)}</td>
      <td>
        <button class="btn btn-sm btn-secondary" onclick="openQuickAdjust(${item.product_id}, ${item.warehouse_id}, ${item.location_id})">Adjust</button>
      </td>
    </tr>
  `).join('');
}

function initQuickFilters() {
  document.getElementById('inv-search-input').addEventListener('input', renderFilteredInventory);
  document.getElementById('inv-wh-filter').addEventListener('change', renderFilteredInventory);
  document.getElementById('inv-cat-filter').addEventListener('change', renderFilteredInventory);
}

// 3. PURCHASE ORDERS (INBOUND)
async function loadPurchaseOrders() {
  try {
    const pos = await fetch('/api/purchase-orders').then(r => r.json());
    const tbody = document.getElementById('po-table-body');
    if (pos.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No Purchase Orders available</td></tr>';
      return;
    }

    tbody.innerHTML = pos.map(po => {
      const statusBadge = po.status === 'RECEIVED' ? 'badge-success' : (po.status === 'PARTIAL' ? 'badge-warning' : 'badge-info');
      
      const linesHtml = po.lines.map(line => {
        const remaining = line.qty_ordered - line.qty_received;
        return `
          <div style="display:flex; justify-content:space-between; align-items:center; padding:0.4rem 0; border-bottom:1px solid rgba(255,255,255,0.05);">
            <div>
              <strong>${line.sku}</strong> — ${line.product_name}
              <span class="text-muted" style="margin-left:8px;">(${line.qty_received} / ${line.qty_ordered} ${line.unit_of_measure})</span>
            </div>
            <div>
              ${remaining > 0 ? `
                <button class="btn btn-sm btn-primary" onclick="openReceiveModal(${line.po_line_id}, '${po.po_number}', '${line.sku} - ${line.product_name}', ${line.qty_ordered}, ${line.qty_received}, ${po.warehouse_id})">
                  Receive Stock
                </button>
              ` : `<span class="badge badge-success">Fulfilled</span>`}
            </div>
          </div>
        `;
      }).join('');

      return `
        <tr>
          <td><strong>${po.po_number}</strong></td>
          <td>${po.supplier_name}</td>
          <td><span class="badge badge-info">${po.warehouse_code}</span></td>
          <td>${po.order_date}</td>
          <td>${po.expected_date || 'N/A'}</td>
          <td><span class="badge ${statusBadge}">${po.status}</span></td>
          <td><strong>${formatCurrency(po.total_amount)}</strong></td>
          <td style="min-width:320px;">${linesHtml}</td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to load purchase orders', err);
  }
}

// 4. SALES ORDERS (OUTBOUND)
async function loadSalesOrders() {
  try {
    const sos = await fetch('/api/sales-orders').then(r => r.json());
    const tbody = document.getElementById('so-table-body');
    if (sos.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No Sales Orders available</td></tr>';
      return;
    }

    tbody.innerHTML = sos.map(so => {
      const statusBadge = so.status === 'SHIPPED' ? 'badge-success' : (so.status === 'PARTIAL' ? 'badge-warning' : 'badge-purple');

      const linesHtml = so.lines.map(line => {
        const remaining = line.qty_ordered - line.qty_shipped;
        return `
          <div style="display:flex; justify-content:space-between; align-items:center; padding:0.4rem 0; border-bottom:1px solid rgba(255,255,255,0.05);">
            <div>
              <strong>${line.sku}</strong> — ${line.product_name}
              <span class="text-muted" style="margin-left:8px;">(${line.qty_shipped} / ${line.qty_ordered} ${line.unit_of_measure})</span>
            </div>
            <div>
              ${remaining > 0 ? `
                <button class="btn btn-sm btn-primary" onclick="openShipModal(${line.so_line_id}, '${so.so_number}', '${line.sku} - ${line.product_name}', ${line.qty_ordered}, ${line.qty_shipped}, ${so.warehouse_id})">
                  Dispatch & Ship
                </button>
              ` : `<span class="badge badge-success">Shipped</span>`}
            </div>
          </div>
        `;
      }).join('');

      return `
        <tr>
          <td><strong>${so.so_number}</strong></td>
          <td>${so.customer_name}</td>
          <td><span class="badge badge-info">${so.warehouse_code}</span></td>
          <td>${so.order_date}</td>
          <td>${so.required_date || 'N/A'}</td>
          <td><span class="badge ${statusBadge}">${so.status}</span></td>
          <td><strong>${formatCurrency(so.total_amount)}</strong></td>
          <td style="min-width:320px;">${linesHtml}</td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to load sales orders', err);
  }
}

// 5. TRANSFERS
async function loadTransfers() {
  try {
    const xfers = await fetch('/api/transfers').then(r => r.json());
    const tbody = document.getElementById('transfer-table-body');
    if (xfers.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">No stock transfers executed</td></tr>';
      return;
    }

    tbody.innerHTML = xfers.map(x => `
      <tr>
        <td><strong>${x.transfer_number}</strong></td>
        <td><span class="badge badge-info">${x.from_warehouse_code}</span></td>
        <td><span class="badge badge-purple">${x.to_warehouse_code}</span></td>
        <td><span class="badge badge-success">${x.status}</span></td>
        <td>${x.request_date}</td>
        <td>
          ${x.lines.map(l => `<code>${l.sku}</code> (${l.qty_requested} units: ${l.from_location_code} &rarr; ${l.to_location_code})`).join('<br>')}
        </td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load transfers', err);
  }
}

// 6. AUDIT LOG
async function loadAuditLog() {
  try {
    const txs = await fetch('/api/transactions').then(r => r.json());
    const tbody = document.getElementById('audit-table-body');
    if (txs.length === 0) {
      tbody.innerHTML = '<tr><td colspan="11" class="text-center text-muted">No audit transactions found</td></tr>';
      return;
    }
    tbody.innerHTML = txs.map(tx => renderTransactionRow(tx)).join('');
  } catch (err) {
    console.error('Failed to load audit transactions', err);
  }
}

function renderTransactionRow(tx) {
  const typeBadges = {
    RECEIPT: 'badge-success',
    ISSUE: 'badge-danger',
    ADJUSTMENT: 'badge-warning',
    TRANSFER_IN: 'badge-info',
    TRANSFER_OUT: 'badge-purple'
  };
  const badgeClass = typeBadges[tx.transaction_type] || 'badge-info';
  const deltaFormatted = tx.qty_change > 0 ? `+${tx.qty_change}` : `${tx.qty_change}`;

  return `
    <tr>
      <td><code>#${tx.transaction_id}</code></td>
      <td><strong>${tx.sku}</strong></td>
      <td>${tx.warehouse_code}</td>
      <td><code>${tx.location_code || 'N/A'}</code></td>
      <td><span class="badge ${badgeClass}">${tx.transaction_type}</span></td>
      <td><strong style="color:${tx.qty_change > 0 ? 'var(--accent-success)' : 'var(--accent-danger)'}">${deltaFormatted}</strong></td>
      <td>${tx.qty_before != null ? tx.qty_before : '-'} &rarr; <strong>${tx.qty_after != null ? tx.qty_after : '-'}</strong></td>
      <td><span class="badge">${tx.reference_type || 'N/A'}</span></td>
      <td>${tx.employee_name || 'System'}</td>
      <td class="text-muted" style="max-width:200px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;" title="${tx.notes || ''}">${tx.notes || '-'}</td>
      <td><small>${tx.transaction_date}</small></td>
    </tr>
  `;
}

// MODAL CONTROLLERS
function initModals() {
  // Close buttons
  document.querySelectorAll('[data-close-modal]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.modal-overlay').forEach(m => m.classList.remove('open'));
    });
  });

  // Open Adjust Modal from Header
  document.getElementById('btn-open-adjust-modal').addEventListener('click', () => {
    document.getElementById('modal-adjust').classList.add('open');
  });
  document.getElementById('btn-adjust-from-inv').addEventListener('click', () => {
    document.getElementById('modal-adjust').classList.add('open');
  });

  // Open Transfer Modal
  document.getElementById('btn-open-transfer-modal').addEventListener('click', () => {
    document.getElementById('modal-transfer').classList.add('open');
  });
  document.getElementById('btn-open-transfer-modal-2').addEventListener('click', () => {
    document.getElementById('modal-transfer').classList.add('open');
  });

  // Form: Receive Stock
  document.getElementById('form-receive').addEventListener('submit', async (e) => {
    e.preventDefault();
    const po_line_id = document.getElementById('rec-po-line-id').value;
    const location_id = document.getElementById('rec-location-id').value;
    const qty = document.getElementById('rec-qty').value;
    const employee_id = document.getElementById('rec-employee-id').value;

    try {
      const res = await fetch('/api/receive-stock', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ po_line_id, location_id, qty, employee_id })
      }).then(r => r.json());

      if (res.error) throw new Error(res.error);

      showToast(`Successfully received ${qty} units! (Receipt ID: ${res.receipt_id})`, 'success');
      document.getElementById('modal-receive').classList.remove('open');
      loadBootstrapData().then(() => refreshCurrentTab());
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Form: Ship Stock
  document.getElementById('form-ship').addEventListener('submit', async (e) => {
    e.preventDefault();
    const so_line_id = document.getElementById('ship-so-line-id').value;
    const location_id = document.getElementById('ship-location-id').value;
    const qty = document.getElementById('ship-qty').value;
    const employee_id = document.getElementById('ship-employee-id').value;
    const carrier = document.getElementById('ship-carrier').value;
    const tracking_number = document.getElementById('ship-tracking').value;

    try {
      const res = await fetch('/api/ship-stock', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ so_line_id, location_id, qty, employee_id, carrier, tracking_number })
      }).then(r => r.json());

      if (res.error) throw new Error(res.error);

      showToast(`Stock shipped! Dispatch created (Shipment ID: ${res.shipment_id})`, 'success');
      document.getElementById('modal-ship').classList.remove('open');
      loadBootstrapData().then(() => refreshCurrentTab());
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Form: Adjust Stock
  document.getElementById('form-adjust').addEventListener('submit', async (e) => {
    e.preventDefault();
    const product_id = document.getElementById('adj-product-id').value;
    const warehouse_id = document.getElementById('adj-warehouse-id').value;
    const location_id = document.getElementById('adj-location-id').value;
    const qty_change = document.getElementById('adj-qty').value;
    const reason_code = document.getElementById('adj-reason').value;
    const notes = document.getElementById('adj-notes').value;
    const employee_id = document.getElementById('adj-employee-id').value;

    try {
      const res = await fetch('/api/adjust-stock', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ product_id, warehouse_id, location_id, qty_change, reason_code, notes, employee_id })
      }).then(r => r.json());

      if (res.error) throw new Error(res.error);

      showToast(`Stock adjustment of ${qty_change} units applied!`, 'success');
      document.getElementById('modal-adjust').classList.remove('open');
      document.getElementById('form-adjust').reset();
      loadBootstrapData().then(() => refreshCurrentTab());
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Form: Transfer Stock
  document.getElementById('form-transfer').addEventListener('submit', async (e) => {
    e.preventDefault();
    const product_id = document.getElementById('xfer-product-id').value;
    const from_warehouse_id = document.getElementById('xfer-from-wh').value;
    const to_warehouse_id = document.getElementById('xfer-to-wh').value;
    const from_location_id = document.getElementById('xfer-from-loc').value;
    const to_location_id = document.getElementById('xfer-to-loc').value;
    const qty = document.getElementById('xfer-qty').value;
    const employee_id = document.getElementById('xfer-employee-id').value;
    const notes = document.getElementById('xfer-notes').value;

    try {
      const res = await fetch('/api/transfer-stock', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ product_id, from_warehouse_id, to_warehouse_id, from_location_id, to_location_id, qty, employee_id, notes })
      }).then(r => r.json());

      if (res.error) throw new Error(res.error);

      showToast(`Transfer ${res.transfer_number} completed for ${qty} units!`, 'success');
      document.getElementById('modal-transfer').classList.remove('open');
      document.getElementById('form-transfer').reset();
      loadBootstrapData().then(() => refreshCurrentTab());
    } catch (err) {
      showToast(err.message, 'error');
    }
  });
}

// Helper to open Receive Modal for a specific PO line
window.openReceiveModal = function(poLineId, poNumber, prodInfo, ordered, received, warehouseId) {
  document.getElementById('rec-po-line-id').value = poLineId;
  document.getElementById('rec-po-info').value = `${poNumber} — ${prodInfo}`;
  document.getElementById('rec-qty-ordered').value = ordered;
  document.getElementById('rec-qty-already').value = received;
  document.getElementById('rec-qty').value = ordered - received;
  document.getElementById('rec-qty').max = ordered - received;

  // Filter locations for this warehouse
  const locDropdown = document.getElementById('rec-location-id');
  const locs = AppState.locations.filter(l => l.warehouse_id == warehouseId);
  locDropdown.innerHTML = locs.map(l => `<option value="${l.location_id}">${l.location_code} (${l.zone_type})</option>`).join('');

  const empDropdown = document.getElementById('rec-employee-id');
  empDropdown.innerHTML = AppState.employees.map(e => `<option value="${e.employee_id}">${e.employee_code} - ${e.first_name} ${e.last_name}</option>`).join('');

  document.getElementById('modal-receive').classList.add('open');
};

// Helper to open Ship Modal for a specific SO line
window.openShipModal = function(soLineId, soNumber, prodInfo, ordered, shipped, warehouseId) {
  document.getElementById('ship-so-line-id').value = soLineId;
  document.getElementById('ship-so-info').value = `${soNumber} — ${prodInfo}`;
  document.getElementById('ship-qty-ordered').value = ordered;
  document.getElementById('ship-qty-already').value = shipped;
  document.getElementById('ship-qty').value = ordered - shipped;
  document.getElementById('ship-qty').max = ordered - shipped;

  const locDropdown = document.getElementById('ship-location-id');
  const locs = AppState.locations.filter(l => l.warehouse_id == warehouseId);
  locDropdown.innerHTML = locs.map(l => `<option value="${l.location_id}">${l.location_code} (${l.zone_type})</option>`).join('');

  const empDropdown = document.getElementById('ship-employee-id');
  empDropdown.innerHTML = AppState.employees.map(e => `<option value="${e.employee_id}">${e.employee_code} - ${e.first_name} ${e.last_name}</option>`).join('');

  document.getElementById('modal-ship').classList.add('open');
};

window.openQuickAdjust = function(productId, warehouseId, locationId) {
  const modal = document.getElementById('modal-adjust');
  document.getElementById('adj-product-id').value = productId;
  document.getElementById('adj-warehouse-id').value = warehouseId;
  updateLocationDropdown(warehouseId, 'adj-location-id');
  document.getElementById('adj-location-id').value = locationId;
  modal.classList.add('open');
};

// SQL STUDIO CONTROLLER
function initSQLStudio() {
  const btnRun = document.getElementById('btn-run-sql');
  const queryInput = document.getElementById('sql-query-input');
  const statusSpan = document.getElementById('sql-status');
  const resultsContainer = document.getElementById('sql-results-table-container');

  // Presets
  document.querySelectorAll('.sql-presets button').forEach(btn => {
    btn.addEventListener('click', () => {
      queryInput.value = btn.getAttribute('data-sql');
      executeSQL();
    });
  });

  btnRun.addEventListener('click', executeSQL);

  queryInput.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      executeSQL();
    }
  });

  async function executeSQL() {
    const query = queryInput.value.trim();
    if (!query) return;

    statusSpan.textContent = 'Executing query...';
    try {
      const res = await fetch('/api/sql', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query })
      }).then(r => r.json());

      if (res.error) {
        statusSpan.textContent = `Error: ${res.error}`;
        statusSpan.style.color = 'var(--accent-danger)';
        resultsContainer.innerHTML = `<div class="card alert-danger" style="color:var(--accent-danger); font-family:var(--font-mono);">${res.error}</div>`;
        return;
      }

      statusSpan.style.color = 'var(--accent-success)';
      if (res.rows) {
        statusSpan.textContent = `Returned ${res.count} rows`;
        if (res.rows.length === 0) {
          resultsContainer.innerHTML = `<p class="text-muted text-center py-4">0 rows returned</p>`;
          return;
        }

        const cols = res.columns;
        const thHtml = cols.map(c => `<th>${c}</th>`).join('');
        const trHtml = res.rows.map(r => `<tr>${cols.map(c => `<td>${r[c] !== null ? r[c] : '<span class="text-muted">null</span>'}</td>`).join('')}</tr>`).join('');

        resultsContainer.innerHTML = `
          <table class="data-table">
            <thead><tr>${thHtml}</tr></thead>
            <tbody>${trHtml}</tbody>
          </table>
        `;
      } else {
        statusSpan.textContent = res.message || 'Query executed successfully';
        resultsContainer.innerHTML = `<div class="card" style="color:var(--accent-success);">${res.message}</div>`;
      }
    } catch (err) {
      statusSpan.textContent = `Execution failed: ${err.message}`;
      statusSpan.style.color = 'var(--accent-danger)';
    }
  }
}

// RESET DATABASE
function initResetDB() {
  document.getElementById('btn-reset-db').addEventListener('click', async () => {
    if (!confirm('Are you sure you want to reset and reseed the WMS database? All non-seed transactions will be cleared.')) return;
    try {
      const res = await fetch('/api/reset', { method: 'POST' }).then(r => r.json());
      showToast(res.message, 'success');
      loadBootstrapData().then(() => refreshCurrentTab());
    } catch (err) {
      showToast('Reset failed: ' + err.message, 'error');
    }
  });
}
