-- -------------------------------------------------------------------------
-- Full inventory snapshot per warehouse / location  [FIX-19]
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_inventory_by_warehouse AS
SELECT
  w.warehouse_code,
  w.warehouse_name,
  wl.zone_type,                                        -- [FIX-19] added
  wl.location_code,
  p.sku,
  p.product_name,
  pc.category_name,
  i.qty_on_hand,
  i.qty_reserved,
  (i.qty_on_hand - i.qty_reserved)  AS qty_available,
  p.reorder_level,
  p.unit_cost,
  (i.qty_on_hand * p.unit_cost)     AS stock_value,
  i.last_count_date,
  i.updated_at
FROM inventory i
JOIN warehouse          w   ON w.warehouse_id   = i.warehouse_id
JOIN product            p   ON p.product_id     = i.product_id
JOIN product_category   pc  ON pc.category_id   = p.category_id
JOIN warehouse_location wl  ON wl.location_id   = i.location_id
WHERE p.is_active  = 'Y'
  AND w.is_active  = 'Y'
  AND wl.is_active = 'Y';                              

-- -------------------------------------------------------------------------
-- Products below reorder level  [FIX-20]
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_low_stock AS
SELECT
  w.warehouse_code,
  w.warehouse_name,                                    -- [FIX-20] added
  p.sku,
  p.product_name,
  SUM(i.qty_on_hand)                               AS total_on_hand,
  p.reorder_level,
  (p.reorder_level - SUM(i.qty_on_hand))           AS qty_shortage
FROM inventory i
JOIN warehouse w ON w.warehouse_id = i.warehouse_id
JOIN product   p ON p.product_id   = i.product_id
WHERE p.is_active = 'Y'
  AND w.is_active = 'Y'                               -- [FIX-20] added
GROUP BY
  w.warehouse_code, w.warehouse_name, p.sku, p.product_name, p.reorder_level
HAVING SUM(i.qty_on_hand) < p.reorder_level;

-- -------------------------------------------------------------------------
-- Open purchase orders (not yet fully received)  [FIX-21]
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_open_purchase_orders AS
SELECT
  po.po_number,
  s.supplier_name,
  w.warehouse_code,
  po.order_date,
  po.expected_date,
  po.updated_at,                                       -- [FIX-21] added
  po.status,
  po.total_amount,
  COUNT(pl.po_line_id)                             AS line_count,
  SUM(pl.qty_ordered - pl.qty_received)            AS qty_outstanding
FROM purchase_order po
JOIN supplier   s   ON s.supplier_id  = po.supplier_id
JOIN warehouse  w   ON w.warehouse_id = po.warehouse_id
JOIN po_line    pl  ON pl.po_id       = po.po_id
WHERE po.status IN ('SUBMITTED', 'APPROVED', 'PARTIAL')
GROUP BY
  po.po_number, s.supplier_name, w.warehouse_code,
  po.order_date, po.expected_date, po.updated_at,
  po.status, po.total_amount;

-- -------------------------------------------------------------------------
-- Stock valuation by warehouse and category  [FIX-22]
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_stock_valuation AS
SELECT
  w.warehouse_code,
  w.warehouse_name,
  pc.category_name,
  COUNT(DISTINCT p.product_id)              AS product_count,
  SUM(i.qty_on_hand)                        AS total_units,
  SUM(i.qty_on_hand * p.unit_cost)          AS total_cost_value,
  SUM(i.qty_on_hand * p.unit_price)         AS total_retail_value
FROM inventory i
JOIN product          p   ON p.product_id   = i.product_id
JOIN product_category pc  ON pc.category_id = p.category_id
JOIN warehouse        w   ON w.warehouse_id  = i.warehouse_id
WHERE p.is_active = 'Y'                              -- [FIX-22] added
  AND w.is_active = 'Y'
GROUP BY w.warehouse_code, w.warehouse_name, pc.category_name;

-- -------------------------------------------------------------------------
-- Pending / in-transit shipments  [FIX-23]
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pending_shipments AS
SELECT
  so.so_number,
  c.customer_name,
  w.warehouse_code,
  so.required_date,                                    -- [FIX-23] added for urgency
  sh.shipment_number,
  sh.ship_date,
  sh.status,
  sh.carrier,
  sh.tracking_number,
  sh.reason_code,                                      -- [FIX-23] added
  SUM(sl.qty_shipped)                              AS total_qty_shipped
FROM shipment sh
JOIN sales_order        so  ON so.so_id       = sh.so_id
JOIN customer           c   ON c.customer_id  = so.customer_id
JOIN warehouse          w   ON w.warehouse_id = so.warehouse_id
JOIN shipment_line      sl  ON sl.shipment_id = sh.shipment_id
WHERE sh.status IN ('PENDING', 'IN_TRANSIT')
GROUP BY
  so.so_number, c.customer_name, w.warehouse_code, so.required_date,
  sh.shipment_number, sh.ship_date, sh.status, sh.carrier,
  sh.tracking_number, sh.reason_code;

-- -------------------------------------------------------------------------
-- [FIX-24] NEW: Overdue purchase orders
-- POs where expected_date has passed and stock is not yet fully received.
-- Completely absent from the original — essential for procurement follow-up.
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_overdue_purchase_orders AS
SELECT
  po.po_number,
  s.supplier_name,
  s.email                                          AS supplier_email,
  w.warehouse_code,
  po.order_date,
  po.expected_date,
  TRUNC(SYSDATE) - po.expected_date                AS days_overdue,
  po.status,
  po.total_amount,
  SUM(pl.qty_ordered  - pl.qty_received)           AS qty_still_outstanding
FROM purchase_order po
JOIN supplier  s   ON s.supplier_id  = po.supplier_id
JOIN warehouse w   ON w.warehouse_id = po.warehouse_id
JOIN po_line   pl  ON pl.po_id       = po.po_id
WHERE po.status     IN ('SUBMITTED', 'APPROVED', 'PARTIAL')
  AND po.expected_date <  TRUNC(SYSDATE)
GROUP BY
  po.po_number, s.supplier_name, s.email, w.warehouse_code,
  po.order_date, po.expected_date, po.status, po.total_amount
ORDER BY days_overdue DESC;

PROMPT Views created.