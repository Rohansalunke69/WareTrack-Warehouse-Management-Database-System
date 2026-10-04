"""
WareTrack Database Engine & PL/SQL Logic Implementation
Replicates the Oracle WMS Schema, Views, Constraints, and pkg_stock_movement package.
"""

import sqlite3
import os
import json
from datetime import datetime

import shutil

BUNDLED_DB_PATH = os.path.join(os.path.dirname(__file__), "wms.db")

# In serverless environments (e.g. Vercel), the function filesystem is read-only.
# We use /tmp for SQLite database operations.
if os.environ.get("VERCEL") or not os.access(os.path.dirname(__file__), os.W_OK):
    DB_PATH = "/tmp/wms.db"
else:
    DB_PATH = BUNDLED_DB_PATH

def ensure_db():
    if not os.path.exists(DB_PATH):
        if os.path.exists(BUNDLED_DB_PATH) and BUNDLED_DB_PATH != DB_PATH:
            try:
                shutil.copyfile(BUNDLED_DB_PATH, DB_PATH)
                return
            except Exception:
                pass
        init_db()

def get_db_connection():
    ensure_db()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def init_db(reset=False):
    if reset and os.path.exists(DB_PATH):
        try:
            os.remove(DB_PATH)
        except Exception:
            pass

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("PRAGMA foreign_keys = ON;")

    # 1. Lookup & Org Tables
    cursor.executescript("""
    CREATE TABLE IF NOT EXISTS uom_lookup (
        uom_code TEXT PRIMARY KEY,
        uom_description TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS department (
        department_id INTEGER PRIMARY KEY AUTOINCREMENT,
        department_code TEXT UNIQUE NOT NULL,
        department_name TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS employee (
        employee_id INTEGER PRIMARY KEY AUTOINCREMENT,
        department_id INTEGER NOT NULL REFERENCES department(department_id),
        employee_code TEXT UNIQUE NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        job_title TEXT,
        hire_date TEXT NOT NULL,
        is_active TEXT DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
        created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS product_category (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_code TEXT UNIQUE NOT NULL,
        category_name TEXT NOT NULL,
        description TEXT
    );

    CREATE TABLE IF NOT EXISTS product (
        product_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES product_category(category_id),
        sku TEXT UNIQUE NOT NULL,
        product_name TEXT NOT NULL,
        description TEXT,
        unit_of_measure TEXT DEFAULT 'EA' REFERENCES uom_lookup(uom_code),
        unit_cost REAL DEFAULT 0 NOT NULL,
        unit_price REAL DEFAULT 0 NOT NULL,
        reorder_level REAL DEFAULT 0 NOT NULL,
        is_active TEXT DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS supplier (
        supplier_id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_code TEXT UNIQUE NOT NULL,
        supplier_name TEXT NOT NULL,
        contact_name TEXT,
        email TEXT,
        phone TEXT,
        address_line1 TEXT,
        city TEXT,
        state_province TEXT,
        postal_code TEXT,
        country TEXT DEFAULT 'USA',
        is_active TEXT DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS customer (
        customer_id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_code TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        contact_name TEXT,
        email TEXT,
        phone TEXT,
        address_line1 TEXT,
        city TEXT,
        state_province TEXT,
        postal_code TEXT,
        country TEXT DEFAULT 'USA',
        is_active TEXT DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS warehouse (
        warehouse_id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_code TEXT UNIQUE NOT NULL,
        warehouse_name TEXT NOT NULL,
        address_line1 TEXT,
        city TEXT,
        state_province TEXT,
        postal_code TEXT,
        country TEXT DEFAULT 'USA',
        manager_id INTEGER REFERENCES employee(employee_id),
        capacity_units REAL,
        is_active TEXT DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
        created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS warehouse_location (
        location_id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL REFERENCES warehouse(warehouse_id),
        location_code TEXT NOT NULL,
        aisle TEXT,
        rack TEXT,
        bin TEXT,
        zone_type TEXT DEFAULT 'STORAGE' CHECK (zone_type IN ('STORAGE', 'RECEIVING', 'SHIPPING', 'STAGING', 'QC', 'CROSS_DOCK')),
        max_capacity REAL,
        is_active TEXT DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
        UNIQUE(warehouse_id, location_code)
    );

    CREATE TABLE IF NOT EXISTS inventory (
        inventory_id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES product(product_id),
        warehouse_id INTEGER NOT NULL REFERENCES warehouse(warehouse_id),
        location_id INTEGER NOT NULL REFERENCES warehouse_location(location_id),
        qty_on_hand REAL DEFAULT 0 NOT NULL,
        qty_reserved REAL DEFAULT 0 NOT NULL,
        last_count_date TEXT,
        updated_at TEXT DEFAULT (datetime('now')),
        UNIQUE(product_id, warehouse_id, location_id),
        CONSTRAINT chk_inv_qty_reserved CHECK (qty_reserved >= 0 AND qty_reserved <= qty_on_hand)
    );

    CREATE TABLE IF NOT EXISTS purchase_order (
        po_id INTEGER PRIMARY KEY AUTOINCREMENT,
        po_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER NOT NULL REFERENCES supplier(supplier_id),
        warehouse_id INTEGER NOT NULL REFERENCES warehouse(warehouse_id),
        order_date TEXT DEFAULT (date('now')) NOT NULL,
        expected_date TEXT,
        status TEXT DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'PARTIAL', 'RECEIVED', 'CANCELLED')),
        total_amount REAL DEFAULT 0 NOT NULL,
        created_by INTEGER REFERENCES employee(employee_id),
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS po_line (
        po_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
        po_id INTEGER NOT NULL REFERENCES purchase_order(po_id) ON DELETE CASCADE,
        line_number INTEGER NOT NULL,
        product_id INTEGER NOT NULL REFERENCES product(product_id),
        qty_ordered REAL NOT NULL CHECK (qty_ordered > 0),
        qty_received REAL DEFAULT 0 NOT NULL CHECK (qty_received >= 0),
        unit_cost REAL NOT NULL CHECK (unit_cost >= 0),
        line_total REAL GENERATED ALWAYS AS (qty_ordered * unit_cost) STORED,
        UNIQUE(po_id, line_number)
    );

    CREATE TABLE IF NOT EXISTS goods_receipt (
        receipt_id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT UNIQUE NOT NULL,
        po_id INTEGER NOT NULL REFERENCES purchase_order(po_id),
        receipt_date TEXT DEFAULT (date('now')) NOT NULL,
        received_by INTEGER REFERENCES employee(employee_id),
        reason_code TEXT DEFAULT 'STANDARD' NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS goods_receipt_line (
        receipt_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES goods_receipt(receipt_id) ON DELETE CASCADE,
        po_line_id INTEGER NOT NULL REFERENCES po_line(po_line_id),
        product_id INTEGER NOT NULL REFERENCES product(product_id),
        location_id INTEGER NOT NULL REFERENCES warehouse_location(location_id),
        qty_received REAL NOT NULL CHECK (qty_received > 0)
    );

    CREATE TABLE IF NOT EXISTS sales_order (
        so_id INTEGER PRIMARY KEY AUTOINCREMENT,
        so_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER NOT NULL REFERENCES customer(customer_id),
        warehouse_id INTEGER NOT NULL REFERENCES warehouse(warehouse_id),
        order_date TEXT DEFAULT (date('now')) NOT NULL,
        required_date TEXT,
        status TEXT DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'CONFIRMED', 'ALLOCATED', 'PARTIAL', 'SHIPPED', 'CANCELLED')),
        total_amount REAL DEFAULT 0 NOT NULL,
        created_by INTEGER REFERENCES employee(employee_id),
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS so_line (
        so_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
        so_id INTEGER NOT NULL REFERENCES sales_order(so_id) ON DELETE CASCADE,
        line_number INTEGER NOT NULL,
        product_id INTEGER NOT NULL REFERENCES product(product_id),
        qty_ordered REAL NOT NULL CHECK (qty_ordered > 0),
        qty_shipped REAL DEFAULT 0 NOT NULL CHECK (qty_shipped >= 0),
        unit_price REAL NOT NULL CHECK (unit_price >= 0),
        line_total REAL GENERATED ALWAYS AS (qty_ordered * unit_price) STORED,
        UNIQUE(so_id, line_number)
    );

    CREATE TABLE IF NOT EXISTS shipment (
        shipment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        shipment_number TEXT UNIQUE NOT NULL,
        so_id INTEGER NOT NULL REFERENCES sales_order(so_id),
        ship_date TEXT DEFAULT (date('now')) NOT NULL,
        carrier TEXT,
        tracking_number TEXT,
        status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED')),
        shipped_by INTEGER REFERENCES employee(employee_id),
        reason_code TEXT DEFAULT 'STANDARD' NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS shipment_line (
        shipment_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
        shipment_id INTEGER NOT NULL REFERENCES shipment(shipment_id) ON DELETE CASCADE,
        so_line_id INTEGER NOT NULL REFERENCES so_line(so_line_id),
        product_id INTEGER NOT NULL REFERENCES product(product_id),
        location_id INTEGER NOT NULL REFERENCES warehouse_location(location_id),
        qty_shipped REAL NOT NULL CHECK (qty_shipped > 0)
    );

    CREATE TABLE IF NOT EXISTS stock_transfer (
        transfer_id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_number TEXT UNIQUE NOT NULL,
        from_warehouse_id INTEGER NOT NULL REFERENCES warehouse(warehouse_id),
        to_warehouse_id INTEGER NOT NULL REFERENCES warehouse(warehouse_id),
        request_date TEXT DEFAULT (date('now')) NOT NULL,
        ship_date TEXT,
        receive_date TEXT,
        status TEXT DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED')),
        requested_by INTEGER REFERENCES employee(employee_id),
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        CHECK (from_warehouse_id <> to_warehouse_id)
    );

    CREATE TABLE IF NOT EXISTS stock_transfer_line (
        transfer_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id INTEGER NOT NULL REFERENCES stock_transfer(transfer_id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES product(product_id),
        from_location_id INTEGER NOT NULL REFERENCES warehouse_location(location_id),
        to_location_id INTEGER NOT NULL REFERENCES warehouse_location(location_id),
        qty_requested REAL NOT NULL CHECK (qty_requested > 0),
        qty_shipped REAL DEFAULT 0 NOT NULL,
        qty_received REAL DEFAULT 0 NOT NULL,
        CHECK (from_location_id <> to_location_id)
    );

    CREATE TABLE IF NOT EXISTS stock_transaction (
        transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES product(product_id),
        warehouse_id INTEGER NOT NULL REFERENCES warehouse(warehouse_id),
        location_id INTEGER REFERENCES warehouse_location(location_id),
        transaction_type TEXT NOT NULL,
        qty_change REAL NOT NULL,
        qty_before REAL,
        qty_after REAL,
        reference_type TEXT,
        reference_id INTEGER,
        employee_id INTEGER REFERENCES employee(employee_id),
        transaction_date TEXT DEFAULT (datetime('now')) NOT NULL,
        notes TEXT
    );

    -- 2. Reporting Views
    DROP VIEW IF EXISTS v_inventory_by_warehouse;
    CREATE VIEW v_inventory_by_warehouse AS
    SELECT
        w.warehouse_code,
        w.warehouse_name,
        wl.zone_type,
        wl.location_code,
        p.sku,
        p.product_name,
        pc.category_name,
        i.qty_on_hand,
        i.qty_reserved,
        (i.qty_on_hand - i.qty_reserved) AS qty_available,
        p.reorder_level,
        p.unit_cost,
        (i.qty_on_hand * p.unit_cost) AS stock_value,
        i.last_count_date,
        i.updated_at
    FROM inventory i
    JOIN warehouse w ON w.warehouse_id = i.warehouse_id
    JOIN product p ON p.product_id = i.product_id
    JOIN product_category pc ON pc.category_id = p.category_id
    JOIN warehouse_location wl ON wl.location_id = i.location_id
    WHERE p.is_active = 'Y' AND w.is_active = 'Y' AND wl.is_active = 'Y';

    DROP VIEW IF EXISTS v_low_stock;
    CREATE VIEW v_low_stock AS
    SELECT
        w.warehouse_code,
        w.warehouse_name,
        p.sku,
        p.product_name,
        SUM(i.qty_on_hand) AS total_on_hand,
        p.reorder_level,
        (p.reorder_level - SUM(i.qty_on_hand)) AS qty_shortage
    FROM inventory i
    JOIN warehouse w ON w.warehouse_id = i.warehouse_id
    JOIN product p ON p.product_id = i.product_id
    WHERE p.is_active = 'Y' AND w.is_active = 'Y'
    GROUP BY w.warehouse_code, w.warehouse_name, p.sku, p.product_name, p.reorder_level
    HAVING SUM(i.qty_on_hand) < p.reorder_level;

    DROP VIEW IF EXISTS v_open_purchase_orders;
    CREATE VIEW v_open_purchase_orders AS
    SELECT
        po.po_number,
        s.supplier_name,
        w.warehouse_code,
        po.order_date,
        po.expected_date,
        po.updated_at,
        po.status,
        po.total_amount,
        COUNT(pl.po_line_id) AS line_count,
        SUM(pl.qty_ordered - pl.qty_received) AS qty_outstanding
    FROM purchase_order po
    JOIN supplier s ON s.supplier_id = po.supplier_id
    JOIN warehouse w ON w.warehouse_id = po.warehouse_id
    JOIN po_line pl ON pl.po_id = po.po_id
    WHERE po.status IN ('SUBMITTED', 'APPROVED', 'PARTIAL')
    GROUP BY po.po_number, s.supplier_name, w.warehouse_code, po.order_date, po.expected_date, po.updated_at, po.status, po.total_amount;

    DROP VIEW IF EXISTS v_stock_valuation;
    CREATE VIEW v_stock_valuation AS
    SELECT
        w.warehouse_code,
        w.warehouse_name,
        pc.category_name,
        COUNT(DISTINCT p.product_id) AS product_count,
        SUM(i.qty_on_hand) AS total_units,
        SUM(i.qty_on_hand * p.unit_cost) AS total_cost_value,
        SUM(i.qty_on_hand * p.unit_price) AS total_retail_value
    FROM inventory i
    JOIN product p ON p.product_id = i.product_id
    JOIN product_category pc ON pc.category_id = p.category_id
    JOIN warehouse w ON w.warehouse_id = i.warehouse_id
    WHERE p.is_active = 'Y' AND w.is_active = 'Y'
    GROUP BY w.warehouse_code, w.warehouse_name, pc.category_name;

    DROP VIEW IF EXISTS v_pending_shipments;
    CREATE VIEW v_pending_shipments AS
    SELECT
        so.so_number,
        c.customer_name,
        w.warehouse_code,
        so.required_date,
        sh.shipment_number,
        sh.ship_date,
        sh.status,
        sh.carrier,
        sh.tracking_number,
        sh.reason_code,
        SUM(sl.qty_shipped) AS total_qty_shipped
    FROM shipment sh
    JOIN sales_order so ON so.so_id = sh.so_id
    JOIN customer c ON c.customer_id = so.customer_id
    JOIN warehouse w ON w.warehouse_id = so.warehouse_id
    JOIN shipment_line sl ON sl.shipment_id = sh.shipment_id
    WHERE sh.status IN ('PENDING', 'IN_TRANSIT')
    GROUP BY so.so_number, c.customer_name, w.warehouse_code, so.required_date, sh.shipment_number, sh.ship_date, sh.status, sh.carrier, sh.tracking_number, sh.reason_code;

    DROP VIEW IF EXISTS v_overdue_purchase_orders;
    CREATE VIEW v_overdue_purchase_orders AS
    SELECT
        po.po_number,
        s.supplier_name,
        s.email AS supplier_email,
        w.warehouse_code,
        po.order_date,
        po.expected_date,
        CAST((julianday('now') - julianday(po.expected_date)) AS INTEGER) AS days_overdue,
        po.status,
        po.total_amount,
        SUM(pl.qty_ordered - pl.qty_received) AS qty_still_outstanding
    FROM purchase_order po
    JOIN supplier s ON s.supplier_id = po.supplier_id
    JOIN warehouse w ON w.warehouse_id = po.warehouse_id
    JOIN po_line pl ON pl.po_id = po.po_id
    WHERE po.status IN ('SUBMITTED', 'APPROVED', 'PARTIAL')
      AND date(po.expected_date) < date('now')
    GROUP BY po.po_number, s.supplier_name, s.email, w.warehouse_code, po.order_date, po.expected_date, po.status, po.total_amount;
    """)

    # Seed Sample Data if tables are empty
    check = cursor.execute("SELECT count(*) as c FROM product;").fetchone()
    if check['c'] == 0:
        seed_sample_data(cursor)

    conn.commit()
    conn.close()

def seed_sample_data(cursor):
    # UOM
    cursor.executemany("INSERT INTO uom_lookup (uom_code, uom_description) VALUES (?, ?);", [
        ('EA', 'Each'), ('KG', 'Kilogram'), ('LTR', 'Litre'),
        ('BOX', 'Box'), ('PLT', 'Pallet'), ('MTR', 'Metre'), ('PKT', 'Packet')
    ])

    # Departments
    cursor.execute("INSERT INTO department (department_code, department_name) VALUES ('OPS', 'Warehouse Operations');")
    cursor.execute("INSERT INTO department (department_code, department_name) VALUES ('PROC', 'Procurement');")

    # Employees
    cursor.execute("INSERT INTO employee (department_id, employee_code, first_name, last_name, email, job_title, hire_date) VALUES (1, 'E001', 'Maria', 'Chen', 'maria.chen@wms.local', 'Warehouse Manager', '2020-03-15');")
    cursor.execute("INSERT INTO employee (department_id, employee_code, first_name, last_name, email, job_title, hire_date) VALUES (2, 'E002', 'James', 'Wilson', 'james.wilson@wms.local', 'Procurement Specialist', '2021-06-01');")
    cursor.execute("INSERT INTO employee (department_id, employee_code, first_name, last_name, email, job_title, hire_date) VALUES (1, 'E003', 'Aisha', 'Patel', 'aisha.patel@wms.local', 'Inventory Clerk', '2022-01-10');")

    # Categories
    cursor.execute("INSERT INTO product_category (category_code, category_name, description) VALUES ('ELEC', 'Electronics', 'Electronic components and devices');")
    cursor.execute("INSERT INTO product_category (category_code, category_name, description) VALUES ('PACK', 'Packaging', 'Boxes, labels, and packing materials');")
    cursor.execute("INSERT INTO product_category (category_code, category_name, description) VALUES ('RAW', 'Raw Materials', 'Base materials for manufacturing');")

    # Products
    cursor.execute("INSERT INTO product (category_id, sku, product_name, unit_of_measure, unit_cost, unit_price, reorder_level) VALUES (1, 'SKU-1001', 'Wireless Router Pro AX3000', 'EA', 45.00, 89.99, 50);")
    cursor.execute("INSERT INTO product (category_id, sku, product_name, unit_of_measure, unit_cost, unit_price, reorder_level) VALUES (1, 'SKU-1002', 'Ethernet Cable Cat6 10ft', 'EA', 2.50, 7.99, 200);")
    cursor.execute("INSERT INTO product (category_id, sku, product_name, unit_of_measure, unit_cost, unit_price, reorder_level) VALUES (2, 'SKU-2001', 'Corrugated Box Medium 18x12x10', 'EA', 0.85, 2.49, 500);")
    cursor.execute("INSERT INTO product (category_id, sku, product_name, unit_of_measure, unit_cost, unit_price, reorder_level) VALUES (3, 'SKU-3001', 'Steel Bracket Assembly Heavy Duty', 'EA', 12.00, 24.50, 100);")

    # Suppliers
    cursor.execute("INSERT INTO supplier (supplier_code, supplier_name, contact_name, email, city, country) VALUES ('SUP-01', 'Global Tech Supplies Inc.', 'Robert Kim', 'orders@globaltech.example', 'Dallas', 'USA');")
    cursor.execute("INSERT INTO supplier (supplier_code, supplier_name, contact_name, email, city, country) VALUES ('SUP-02', 'PackRight Materials LLC', 'Lisa Nguyen', 'sales@packright.example', 'Chicago', 'USA');")

    # Customers
    cursor.execute("INSERT INTO customer (customer_code, customer_name, contact_name, email, city, country) VALUES ('CUST-01', 'RetailMart Distribution', 'Tom Bradley', 'purchasing@retailmart.example', 'Atlanta', 'USA');")
    cursor.execute("INSERT INTO customer (customer_code, customer_name, contact_name, email, city, country) VALUES ('CUST-02', 'NetPro Solutions', 'Sandra Lee', 'orders@netpro.example', 'Seattle', 'USA');")

    # Warehouses
    cursor.execute("INSERT INTO warehouse (warehouse_code, warehouse_name, city, state_province, manager_id, capacity_units) VALUES ('WH-EAST', 'East Coast Distribution Center', 'Newark', 'NJ', 1, 50000);")
    cursor.execute("INSERT INTO warehouse (warehouse_code, warehouse_name, city, state_province, manager_id, capacity_units) VALUES ('WH-WEST', 'West Coast Fulfillment Hub', 'Los Angeles', 'CA', 1, 40000);")

    # Locations
    cursor.execute("INSERT INTO warehouse_location (warehouse_id, location_code, aisle, rack, bin, zone_type) VALUES (1, 'A-01-01', 'A', '01', '01', 'STORAGE');")
    cursor.execute("INSERT INTO warehouse_location (warehouse_id, location_code, aisle, rack, bin, zone_type) VALUES (1, 'A-01-02', 'A', '01', '02', 'STORAGE');")
    cursor.execute("INSERT INTO warehouse_location (warehouse_id, location_code, aisle, rack, bin, zone_type) VALUES (1, 'RCV-01', 'RCV', '01', '01', 'RECEIVING');")
    cursor.execute("INSERT INTO warehouse_location (warehouse_id, location_code, aisle, rack, bin, zone_type) VALUES (1, 'SHP-01', 'SHP', '01', '01', 'SHIPPING');")
    cursor.execute("INSERT INTO warehouse_location (warehouse_id, location_code, aisle, rack, bin, zone_type) VALUES (2, 'B-01-01', 'B', '01', '01', 'STORAGE');")
    cursor.execute("INSERT INTO warehouse_location (warehouse_id, location_code, aisle, rack, bin, zone_type) VALUES (2, 'RCV-02', 'RCV', '02', '01', 'RECEIVING');")

    # Initial Inventory
    cursor.execute("INSERT INTO inventory (product_id, warehouse_id, location_id, qty_on_hand, qty_reserved) VALUES (1, 1, 1, 120, 10);")
    cursor.execute("INSERT INTO inventory (product_id, warehouse_id, location_id, qty_on_hand, qty_reserved) VALUES (2, 1, 2, 800, 50);")
    cursor.execute("INSERT INTO inventory (product_id, warehouse_id, location_id, qty_on_hand, qty_reserved) VALUES (4, 1, 1, 30, 0);")
    cursor.execute("INSERT INTO inventory (product_id, warehouse_id, location_id, qty_on_hand, qty_reserved) VALUES (1, 2, 5, 25, 5);")

    # Purchase Orders
    cursor.execute("INSERT INTO purchase_order (po_number, supplier_id, warehouse_id, order_date, expected_date, status, total_amount, created_by) VALUES ('PO-2025-0001', 1, 1, '2025-04-01', '2025-04-15', 'APPROVED', 4600.00, 2);")
    cursor.execute("INSERT INTO po_line (po_id, line_number, product_id, qty_ordered, qty_received, unit_cost) VALUES (1, 1, 1, 100, 0, 42.00);")
    cursor.execute("INSERT INTO po_line (po_id, line_number, product_id, qty_ordered, qty_received, unit_cost) VALUES (1, 2, 3, 500, 0, 0.80);")

    # Sales Orders
    cursor.execute("INSERT INTO sales_order (so_number, customer_id, warehouse_id, order_date, required_date, status, total_amount, created_by) VALUES ('SO-2025-0100', 2, 1, '2025-04-20', '2025-04-25', 'CONFIRMED', 2598.80, 3);")
    cursor.execute("INSERT INTO so_line (so_id, line_number, product_id, qty_ordered, qty_shipped, unit_price) VALUES (1, 1, 1, 20, 0, 89.99);")
    cursor.execute("INSERT INTO so_line (so_id, line_number, product_id, qty_ordered, qty_shipped, unit_price) VALUES (1, 2, 2, 100, 0, 7.99);")

    # Stock Transfers
    cursor.execute("INSERT INTO stock_transfer (transfer_number, from_warehouse_id, to_warehouse_id, request_date, status, requested_by) VALUES ('XFR-2025-0001', 1, 2, '2025-04-18', 'REQUESTED', 1);")
    cursor.execute("INSERT INTO stock_transfer_line (transfer_id, product_id, from_location_id, to_location_id, qty_requested) VALUES (1, 1, 1, 5, 30);")

    # Initial Audit Trail
    cursor.execute("INSERT INTO stock_transaction (product_id, warehouse_id, location_id, transaction_type, qty_change, qty_before, qty_after, reference_type, reference_id, employee_id, notes) VALUES (1, 1, 1, 'RECEIPT', 120, 0, 120, 'INITIAL_LOAD', NULL, 3, 'Opening balance load');")
    cursor.execute("INSERT INTO stock_transaction (product_id, warehouse_id, location_id, transaction_type, qty_change, qty_before, qty_after, reference_type, reference_id, employee_id, notes) VALUES (2, 1, 2, 'RECEIPT', 800, 0, 800, 'INITIAL_LOAD', NULL, 3, 'Opening balance load');")


# --------------------------------------------------------------------------
# PL/SQL Engine (pkg_stock_movement translation)
# --------------------------------------------------------------------------

class StockMovementEngine:
    @staticmethod
    def apply_inventory_change(conn, product_id, warehouse_id, location_id, qty_change,
                               transaction_type, reference_type, reference_id=None, employee_id=1, notes=None):
        if qty_change == 0:
            raise ValueError("Quantity change cannot be zero.")

        cursor = conn.cursor()
        # Find inventory row
        row = cursor.execute("""
            SELECT inventory_id, qty_on_hand, qty_reserved
            FROM inventory
            WHERE product_id = ? AND warehouse_id = ? AND location_id = ?
        """, (product_id, warehouse_id, location_id)).fetchone()

        if row is None:
            if qty_change < 0:
                raise ValueError(f"Cannot reduce stock: no inventory record exists for product_id={product_id} at location_id={location_id}")
            qty_before = 0
            cursor.execute("""
                INSERT INTO inventory (product_id, warehouse_id, location_id, qty_on_hand, qty_reserved)
                VALUES (?, ?, ?, 0, 0)
            """, (product_id, warehouse_id, location_id))
            inv_id = cursor.lastrowid
        else:
            inv_id = row['inventory_id']
            qty_before = row['qty_on_hand']

        qty_after = qty_before + qty_change
        if qty_after < 0:
            raise ValueError(f"Insufficient stock. On hand: {qty_before}, requested change: {qty_change}")

        cursor.execute("""
            UPDATE inventory
            SET qty_on_hand = ?, updated_at = datetime('now')
            WHERE inventory_id = ?
        """, (qty_after, inv_id))

        cursor.execute("""
            INSERT INTO stock_transaction (
                product_id, warehouse_id, location_id,
                transaction_type, qty_change, qty_before, qty_after,
                reference_type, reference_id, employee_id, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            product_id, warehouse_id, location_id,
            transaction_type, qty_change, qty_before, qty_after,
            reference_type, reference_id, employee_id, notes
        ))

    @classmethod
    def receive_stock(cls, po_line_id, location_id, qty, employee_id=1, receipt_id=None):
        if qty <= 0:
            raise ValueError("Receive quantity must be positive.")

        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            line = cursor.execute("""
                SELECT pl.po_id, pl.product_id, po.warehouse_id,
                       pl.qty_ordered, pl.qty_received, po.po_number
                FROM po_line pl
                JOIN purchase_order po ON po.po_id = pl.po_id
                WHERE pl.po_line_id = ?
            """, (po_line_id,)).fetchone()

            if not line:
                raise ValueError("Purchase Order Line not found.")

            po_id = line['po_id']
            product_id = line['product_id']
            warehouse_id = line['warehouse_id']
            ordered = line['qty_ordered']
            received = line['qty_received']
            po_number = line['po_number']

            if received + qty > ordered:
                raise ValueError(f"Receive qty ({qty}) would exceed PO line outstanding ({ordered - received}).")

            if receipt_id is None:
                rec_count = cursor.execute("SELECT count(*) as c FROM goods_receipt").fetchone()['c'] + 1
                rec_num = f"GR-{rec_count:010d}"
                cursor.execute("""
                    INSERT INTO goods_receipt (receipt_number, po_id, received_by, reason_code)
                    VALUES (?, ?, ?, 'STANDARD')
                """, (rec_num, po_id, employee_id))
                receipt_id = cursor.lastrowid

            cursor.execute("""
                INSERT INTO goods_receipt_line (receipt_id, po_line_id, product_id, location_id, qty_received)
                VALUES (?, ?, ?, ?, ?)
            """, (receipt_id, po_line_id, product_id, location_id, qty))

            cursor.execute("""
                UPDATE po_line
                SET qty_received = qty_received + ?
                WHERE po_line_id = ?
            """, (qty, po_line_id))

            tot = cursor.execute("""
                SELECT SUM(qty_ordered - qty_received) as remaining
                FROM po_line
                WHERE po_id = ?
            """, (po_id,)).fetchone()['remaining']

            po_status = 'RECEIVED' if tot == 0 else 'PARTIAL'
            cursor.execute("""
                UPDATE purchase_order
                SET status = ?, updated_at = datetime('now')
                WHERE po_id = ?
            """, (po_status, po_id))

            cls.apply_inventory_change(
                conn, product_id, warehouse_id, location_id,
                qty, 'RECEIPT', 'GOODS_RECEIPT', receipt_id, employee_id,
                f"Receipt for PO {po_number}"
            )

            conn.commit()
            return {"receipt_id": receipt_id, "po_status": po_status, "received_qty": qty}
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    @classmethod
    def ship_stock(cls, so_line_id, location_id, qty, employee_id=1, shipment_id=None, carrier="FedEx", tracking_no=None):
        if qty <= 0:
            raise ValueError("Ship quantity must be positive.")

        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            line = cursor.execute("""
                SELECT sl.so_id, sl.product_id, so.warehouse_id,
                       sl.qty_ordered, sl.qty_shipped, so.so_number
                FROM so_line sl
                JOIN sales_order so ON so.so_id = sl.so_id
                WHERE sl.so_line_id = ?
            """, (so_line_id,)).fetchone()

            if not line:
                raise ValueError("Sales Order Line not found.")

            so_id = line['so_id']
            product_id = line['product_id']
            warehouse_id = line['warehouse_id']
            ordered = line['qty_ordered']
            shipped = line['qty_shipped']
            so_number = line['so_number']

            if shipped + qty > ordered:
                raise ValueError(f"Ship qty ({qty}) would exceed SO line outstanding ({ordered - shipped}).")

            if shipment_id is None:
                shp_count = cursor.execute("SELECT count(*) as c FROM shipment").fetchone()['c'] + 1
                shp_num = f"SH-{shp_count:010d}"
                tracking = tracking_no or f"TRK-{shp_count:06d}-US"
                cursor.execute("""
                    INSERT INTO shipment (shipment_number, so_id, shipped_by, status, carrier, tracking_number, reason_code)
                    VALUES (?, ?, ?, 'PENDING', ?, ?, 'STANDARD')
                """, (shp_num, so_id, employee_id, carrier, tracking))
                shipment_id = cursor.lastrowid

            cursor.execute("""
                INSERT INTO shipment_line (shipment_id, so_line_id, product_id, location_id, qty_shipped)
                VALUES (?, ?, ?, ?, ?)
            """, (shipment_id, so_line_id, product_id, location_id, qty))

            cursor.execute("""
                UPDATE so_line
                SET qty_shipped = qty_shipped + ?
                WHERE so_line_id = ?
            """, (qty, so_line_id))

            tot = cursor.execute("""
                SELECT SUM(qty_ordered - qty_shipped) as remaining
                FROM so_line
                WHERE so_id = ?
            """, (so_id,)).fetchone()['remaining']

            so_status = 'SHIPPED' if tot == 0 else 'PARTIAL'
            cursor.execute("""
                UPDATE sales_order
                SET status = ?, updated_at = datetime('now')
                WHERE so_id = ?
            """, (so_status, so_id))

            inv = cursor.execute("""
                SELECT inventory_id, qty_reserved
                FROM inventory
                WHERE product_id = ? AND warehouse_id = ? AND location_id = ?
            """, (product_id, warehouse_id, location_id)).fetchone()

            if inv:
                curr_reserved = inv['qty_reserved']
                new_reserved = max(0, curr_reserved - qty)
                cursor.execute("""
                    UPDATE inventory
                    SET qty_reserved = ?
                    WHERE inventory_id = ?
                """, (new_reserved, inv['inventory_id']))

            cls.apply_inventory_change(
                conn, product_id, warehouse_id, location_id,
                -qty, 'ISSUE', 'SHIPMENT', shipment_id, employee_id,
                f"Shipment for SO {so_number}"
            )

            conn.commit()
            return {"shipment_id": shipment_id, "so_status": so_status, "shipped_qty": qty}
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    @classmethod
    def adjust_stock(cls, product_id, warehouse_id, location_id, qty_change,
                     employee_id=1, reason_code='MANUAL_ADJUSTMENT', notes=None):
        conn = get_db_connection()
        try:
            cls.apply_inventory_change(
                conn, product_id, warehouse_id, location_id,
                qty_change, 'ADJUSTMENT', reason_code, None, employee_id, notes
            )
            conn.commit()
            return {"status": "success", "qty_change": qty_change, "reason_code": reason_code}
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    @classmethod
    def transfer_stock(cls, from_warehouse_id, to_warehouse_id, product_id,
                       from_location_id, to_location_id, qty, employee_id=1, notes=None):
        if from_warehouse_id == to_warehouse_id and from_location_id == to_location_id:
            raise ValueError("Source and destination locations must be different.")
        if qty <= 0:
            raise ValueError("Transfer quantity must be positive.")

        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            xfer_count = cursor.execute("SELECT count(*) as c FROM stock_transfer").fetchone()['c'] + 1
            xfer_num = f"XFR-2025-{xfer_count:04d}"

            cursor.execute("""
                INSERT INTO stock_transfer (transfer_number, from_warehouse_id, to_warehouse_id, status, requested_by, notes)
                VALUES (?, ?, ?, 'COMPLETED', ?, ?)
            """, (xfer_num, from_warehouse_id, to_warehouse_id, employee_id, notes or "Direct transfer"))
            xfer_id = cursor.lastrowid

            cursor.execute("""
                INSERT INTO stock_transfer_line (transfer_id, product_id, from_location_id, to_location_id, qty_requested, qty_shipped, qty_received)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (xfer_id, product_id, from_location_id, to_location_id, qty, qty, qty))

            # Deduct from source
            cls.apply_inventory_change(
                conn, product_id, from_warehouse_id, from_location_id,
                -qty, 'TRANSFER_OUT', 'TRANSFER', xfer_id, employee_id,
                f"Transfer {xfer_num} OUT to WH-{to_warehouse_id}"
            )

            # Add to destination
            cls.apply_inventory_change(
                conn, product_id, to_warehouse_id, to_location_id,
                qty, 'TRANSFER_IN', 'TRANSFER', xfer_id, employee_id,
                f"Transfer {xfer_num} IN from WH-{from_warehouse_id}"
            )

            conn.commit()
            return {"transfer_id": xfer_id, "transfer_number": xfer_num, "qty": qty}
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()
