-- =============================================================================
-- 06_sample_data.sql - Seed data for demonstration and testing
-- =============================================================================

-- Departments & employees
INSERT INTO department (department_id, department_code, department_name)
VALUES (seq_department.NEXTVAL, 'OPS', 'Warehouse Operations');

INSERT INTO department (department_id, department_code, department_name)
VALUES (seq_department.NEXTVAL, 'PROC', 'Procurement');

INSERT INTO employee (employee_id, department_id, employee_code, first_name, last_name, email, job_title, hire_date)
SELECT seq_employee.NEXTVAL, department_id, 'E001', 'Maria', 'Chen', 'maria.chen@wms.local', 'Warehouse Manager', DATE '2020-03-15'
FROM department WHERE department_code = 'OPS';

INSERT INTO employee (employee_id, department_id, employee_code, first_name, last_name, email, job_title, hire_date)
SELECT seq_employee.NEXTVAL, department_id, 'E002', 'James', 'Wilson', 'james.wilson@wms.local', 'Procurement Specialist', DATE '2021-06-01'
FROM department WHERE department_code = 'PROC';

INSERT INTO employee (employee_id, department_id, employee_code, first_name, last_name, email, job_title, hire_date)
SELECT seq_employee.NEXTVAL, department_id, 'E003', 'Aisha', 'Patel', 'aisha.patel@wms.local', 'Inventory Clerk', DATE '2022-01-10'
FROM department WHERE department_code = 'OPS';

-- Categories & products
INSERT INTO product_category (category_id, category_code, category_name, description)
VALUES (seq_product_category.NEXTVAL, 'ELEC', 'Electronics', 'Electronic components and devices');

INSERT INTO product_category (category_id, category_code, category_name, description)
VALUES (seq_product_category.NEXTVAL, 'PACK', 'Packaging', 'Boxes, labels, and packing materials');

INSERT INTO product_category (category_id, category_code, category_name, description)
VALUES (seq_product_category.NEXTVAL, 'RAW', 'Raw Materials', 'Base materials for manufacturing');

INSERT INTO product (product_id, category_id, sku, product_name, unit_cost, unit_price, reorder_level)
SELECT seq_product.NEXTVAL, category_id, 'SKU-1001', 'Wireless Router', 45.00, 89.99, 50
FROM product_category WHERE category_code = 'ELEC';

INSERT INTO product (product_id, category_id, sku, product_name, unit_cost, unit_price, reorder_level)
SELECT seq_product.NEXTVAL, category_id, 'SKU-1002', 'Ethernet Cable 10ft', 2.50, 7.99, 200
FROM product_category WHERE category_code = 'ELEC';

INSERT INTO product (product_id, category_id, sku, product_name, unit_cost, unit_price, reorder_level)
SELECT seq_product.NEXTVAL, category_id, 'SKU-2001', 'Corrugated Box Medium', 0.85, 2.49, 500
FROM product_category WHERE category_code = 'PACK';

INSERT INTO product (product_id, category_id, sku, product_name, unit_cost, unit_price, reorder_level)
SELECT seq_product.NEXTVAL, category_id, 'SKU-3001', 'Steel Bracket Assembly', 12.00, 24.50, 100
FROM product_category WHERE category_code = 'RAW';

-- Suppliers & customers
INSERT INTO supplier (supplier_id, supplier_code, supplier_name, contact_name, email, city, country)
VALUES (seq_supplier.NEXTVAL, 'SUP-01', 'Global Tech Supplies Inc.', 'Robert Kim', 'orders@globaltech.example', 'Dallas', 'USA');

INSERT INTO supplier (supplier_id, supplier_code, supplier_name, contact_name, email, city, country)
VALUES (seq_supplier.NEXTVAL, 'SUP-02', 'PackRight Materials LLC', 'Lisa Nguyen', 'sales@packright.example', 'Chicago', 'USA');

INSERT INTO customer (customer_id, customer_code, customer_name, contact_name, email, city, country)
VALUES (seq_customer.NEXTVAL, 'CUST-01', 'RetailMart Distribution', 'Tom Bradley', 'purchasing@retailmart.example', 'Atlanta', 'USA');

INSERT INTO customer (customer_id, customer_code, customer_name, contact_name, email, city, country)
VALUES (seq_customer.NEXTVAL, 'CUST-02', 'NetPro Solutions', 'Sandra Lee', 'orders@netpro.example', 'Seattle', 'USA');

-- Warehouses & locations
INSERT INTO warehouse (warehouse_id, warehouse_code, warehouse_name, city, state_province, manager_id, capacity_units)
SELECT seq_warehouse.NEXTVAL, 'WH-EAST', 'East Coast Distribution Center', 'Newark', 'NJ',
       (SELECT employee_id FROM employee WHERE employee_code = 'E001'), 50000
FROM dual;

INSERT INTO warehouse (warehouse_id, warehouse_code, warehouse_name, city, state_province, manager_id, capacity_units)
SELECT seq_warehouse.NEXTVAL, 'WH-WEST', 'West Coast Fulfillment Hub', 'Los Angeles', 'CA',
       (SELECT employee_id FROM employee WHERE employee_code = 'E001'), 40000
FROM dual;

INSERT INTO warehouse_location (location_id, warehouse_id, location_code, aisle, rack, bin, zone_type)
SELECT seq_warehouse_location.NEXTVAL, warehouse_id, 'A-01-01', 'A', '01', '01', 'STORAGE'
FROM warehouse WHERE warehouse_code = 'WH-EAST';

INSERT INTO warehouse_location (location_id, warehouse_id, location_code, aisle, rack, bin, zone_type)
SELECT seq_warehouse_location.NEXTVAL, warehouse_id, 'A-01-02', 'A', '01', '02', 'STORAGE'
FROM warehouse WHERE warehouse_code = 'WH-EAST';

INSERT INTO warehouse_location (location_id, warehouse_id, location_code, aisle, rack, bin, zone_type)
SELECT seq_warehouse_location.NEXTVAL, warehouse_id, 'RCV-01', NULL, NULL, NULL, 'RECEIVING'
FROM warehouse WHERE warehouse_code = 'WH-EAST';

INSERT INTO warehouse_location (location_id, warehouse_id, location_code, aisle, rack, bin, zone_type)
SELECT seq_warehouse_location.NEXTVAL, warehouse_id, 'B-01-01', 'B', '01', '01', 'STORAGE'
FROM warehouse WHERE warehouse_code = 'WH-WEST';

-- Initial inventory (East warehouse)
INSERT INTO inventory (inventory_id, product_id, warehouse_id, location_id, qty_on_hand, qty_reserved)
SELECT seq_inventory.NEXTVAL, p.product_id, w.warehouse_id, wl.location_id, 120, 10
FROM product p, warehouse w, warehouse_location wl
WHERE p.sku = 'SKU-1001' AND w.warehouse_code = 'WH-EAST' AND wl.location_code = 'A-01-01';

INSERT INTO inventory (inventory_id, product_id, warehouse_id, location_id, qty_on_hand, qty_reserved)
SELECT seq_inventory.NEXTVAL, p.product_id, w.warehouse_id, wl.location_id, 800, 50
FROM product p, warehouse w, warehouse_location wl
WHERE p.sku = 'SKU-1002' AND w.warehouse_code = 'WH-EAST' AND wl.location_code = 'A-01-02';

INSERT INTO inventory (inventory_id, product_id, warehouse_id, location_id, qty_on_hand, qty_reserved)
SELECT seq_inventory.NEXTVAL, p.product_id, w.warehouse_id, wl.location_id, 30, 0
FROM product p, warehouse w, warehouse_location wl
WHERE p.sku = 'SKU-3001' AND w.warehouse_code = 'WH-EAST' AND wl.location_code = 'A-01-01';

-- West warehouse (low stock on router for v_low_stock demo)
INSERT INTO inventory (inventory_id, product_id, warehouse_id, location_id, qty_on_hand, qty_reserved)
SELECT seq_inventory.NEXTVAL, p.product_id, w.warehouse_id, wl.location_id, 25, 5
FROM product p, warehouse w, warehouse_location wl
WHERE p.sku = 'SKU-1001' AND w.warehouse_code = 'WH-WEST' AND wl.location_code = 'B-01-01';

-- Purchase order (approved, partial receipt pending)
INSERT INTO purchase_order (po_id, po_number, supplier_id, warehouse_id, order_date, expected_date, status, total_amount, created_by)
SELECT seq_purchase_order.NEXTVAL, 'PO-2025-0001', s.supplier_id, w.warehouse_id,
       DATE '2025-04-01', DATE '2025-04-15', 'APPROVED', 0,
       (SELECT employee_id FROM employee WHERE employee_code = 'E002')
FROM supplier s, warehouse w
WHERE s.supplier_code = 'SUP-01' AND w.warehouse_code = 'WH-EAST';

INSERT INTO po_line (po_line_id, po_id, line_number, product_id, qty_ordered, qty_received, unit_cost, line_total)
SELECT seq_po_line.NEXTVAL, po.po_id, 1, p.product_id, 100, 0, 42.00, 4200.00
FROM purchase_order po, product p
WHERE po.po_number = 'PO-2025-0001' AND p.sku = 'SKU-1001';

INSERT INTO po_line (po_line_id, po_id, line_number, product_id, qty_ordered, qty_received, unit_cost, line_total)
SELECT seq_po_line.NEXTVAL, po.po_id, 2, p.product_id, 500, 0, 0.80, 400.00
FROM purchase_order po, product p
WHERE po.po_number = 'PO-2025-0001' AND p.sku = 'SKU-2001';

UPDATE purchase_order SET total_amount = 4600.00 WHERE po_number = 'PO-2025-0001';

-- Sales order (confirmed)
INSERT INTO sales_order (so_id, so_number, customer_id, warehouse_id, order_date, required_date, status, total_amount, created_by)
SELECT seq_sales_order.NEXTVAL, 'SO-2025-0100', c.customer_id, w.warehouse_id,
       DATE '2025-04-20', DATE '2025-04-25', 'CONFIRMED', 0,
       (SELECT employee_id FROM employee WHERE employee_code = 'E003')
FROM customer c, warehouse w
WHERE c.customer_code = 'CUST-02' AND w.warehouse_code = 'WH-EAST';

INSERT INTO so_line (so_line_id, so_id, line_number, product_id, qty_ordered, qty_shipped, unit_price, line_total)
SELECT seq_so_line.NEXTVAL, so.so_id, 1, p.product_id, 20, 0, 89.99, 1799.80
FROM sales_order so, product p
WHERE so.so_number = 'SO-2025-0100' AND p.sku = 'SKU-1001';

INSERT INTO so_line (so_line_id, so_id, line_number, product_id, qty_ordered, qty_shipped, unit_price, line_total)
SELECT seq_so_line.NEXTVAL, so.so_id, 2, p.product_id, 100, 0, 7.99, 799.00
FROM sales_order so, product p
WHERE so.so_number = 'SO-2025-0100' AND p.sku = 'SKU-1002';

UPDATE sales_order SET total_amount = 2598.80 WHERE so_number = 'SO-2025-0100';

-- Stock transfer request
INSERT INTO stock_transfer (transfer_id, transfer_number, from_warehouse_id, to_warehouse_id, request_date, status, requested_by)
SELECT seq_stock_transfer.NEXTVAL, 'XFR-2025-0001', wf.warehouse_id, wt.warehouse_id,
       DATE '2025-04-18', 'REQUESTED',
       (SELECT employee_id FROM employee WHERE employee_code = 'E001')
FROM warehouse wf, warehouse wt
WHERE wf.warehouse_code = 'WH-EAST' AND wt.warehouse_code = 'WH-WEST';

INSERT INTO stock_transfer_line (transfer_line_id, transfer_id, product_id, from_location_id, to_location_id, qty_requested)
SELECT seq_stock_transfer_line.NEXTVAL, st.transfer_id, p.product_id, fl.location_id, tl.location_id, 30
FROM stock_transfer st, product p, warehouse_location fl, warehouse_location tl
WHERE st.transfer_number = 'XFR-2025-0001'
  AND p.sku = 'SKU-1001'
  AND fl.location_code = 'A-01-01'
  AND tl.location_code = 'B-01-01';

-- Sample audit transactions
INSERT INTO stock_transaction (transaction_id, product_id, warehouse_id, location_id, transaction_type,
                               qty_change, qty_before, qty_after, reference_type, reference_id, employee_id, notes)
SELECT seq_stock_transaction.NEXTVAL, p.product_id, w.warehouse_id, wl.location_id,
       'RECEIPT', 120, 0, 120, 'INITIAL_LOAD', NULL,
       (SELECT employee_id FROM employee WHERE employee_code = 'E003'),
       'Opening balance load'
FROM product p, warehouse w, warehouse_location wl
WHERE p.sku = 'SKU-1001' AND w.warehouse_code = 'WH-EAST' AND wl.location_code = 'A-01-01';

COMMIT;
PROMPT Sample data loaded.
