-- =============================================================================
-- 05_views.sql - Reporting and operational views
-- =============================================================================

CREATE OR REPLACE VIEW v_inventory_by_warehouse AS
SELECT
  w.warehouse_code,
  w.warehouse_name,
  p.sku,
  p.product_name,
  pc.category_name,
  wl.location_code,
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
WHERE p.is_active = 'Y' AND w.is_active = 'Y';

CREATE OR REPLACE VIEW v_low_stock AS
SELECT
  w.warehouse_code,
  p.sku,
  p.product_name,
  SUM(i.qty_on_hand) AS total_on_hand,
  p.reorder_level,
  (p.reorder_level - SUM(i.qty_on_hand)) AS qty_shortage
FROM inventory i
JOIN warehouse w ON w.warehouse_id = i.warehouse_id
JOIN product p ON p.product_id = i.product_id
WHERE p.is_active = 'Y'
GROUP BY w.warehouse_code, p.sku, p.product_name, p.reorder_level
HAVING SUM(i.qty_on_hand) < p.reorder_level;

CREATE OR REPLACE VIEW v_open_purchase_orders AS
SELECT
  po.po_number,
  s.supplier_name,
  w.warehouse_code,
  po.order_date,
  po.expected_date,
  po.status,
  po.total_amount,
  COUNT(pl.po_line_id) AS line_count,
  SUM(pl.qty_ordered - pl.qty_received) AS qty_outstanding
FROM purchase_order po
JOIN supplier s ON s.supplier_id = po.supplier_id
JOIN warehouse w ON w.warehouse_id = po.warehouse_id
JOIN po_line pl ON pl.po_id = po.po_id
WHERE po.status IN ('SUBMITTED', 'APPROVED', 'PARTIAL')
GROUP BY
  po.po_number, s.supplier_name, w.warehouse_code,
  po.order_date, po.expected_date, po.status, po.total_amount;

CREATE OR REPLACE VIEW v_stock_valuation AS
SELECT
  w.warehouse_code,
  pc.category_name,
  COUNT(DISTINCT p.product_id) AS product_count,
  SUM(i.qty_on_hand) AS total_units,
  SUM(i.qty_on_hand * p.unit_cost) AS total_cost_value,
  SUM(i.qty_on_hand * p.unit_price) AS total_retail_value
FROM inventory i
JOIN product p ON p.product_id = i.product_id
JOIN product_category pc ON pc.category_id = p.category_id
JOIN warehouse w ON w.warehouse_id = i.warehouse_id
GROUP BY w.warehouse_code, pc.category_name;

CREATE OR REPLACE VIEW v_pending_shipments AS
SELECT
  so.so_number,
  c.customer_name,
  w.warehouse_code,
  sh.shipment_number,
  sh.ship_date,
  sh.status,
  sh.carrier,
  sh.tracking_number,
  SUM(sl.qty_shipped) AS total_qty_shipped
FROM shipment sh
JOIN sales_order so ON so.so_id = sh.so_id
JOIN customer c ON c.customer_id = so.customer_id
JOIN warehouse w ON w.warehouse_id = so.warehouse_id
JOIN shipment_line sl ON sl.shipment_id = sh.shipment_id
WHERE sh.status IN ('PENDING', 'IN_TRANSIT')
GROUP BY
  so.so_number, c.customer_name, w.warehouse_code,
  sh.shipment_number, sh.ship_date, sh.status, sh.carrier, sh.tracking_number;

PROMPT Views created.
