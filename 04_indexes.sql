-- -------------------------------------------------------------------------
-- Employee / Department
-- -------------------------------------------------------------------------
CREATE INDEX idx_employee_dept      ON employee (department_id);

-- -------------------------------------------------------------------------
-- Product
-- -------------------------------------------------------------------------
CREATE INDEX idx_product_category   ON product (category_id);
CREATE INDEX idx_product_name       ON product (product_name);

-- -------------------------------------------------------------------------
-- Warehouse locations
-- -------------------------------------------------------------------------
CREATE INDEX idx_location_wh        ON warehouse_location (warehouse_id);

-- -------------------------------------------------------------------------
-- Inventory  [FIX-14, FIX-18]
-- -------------------------------------------------------------------------
-- Single-column: used when filtering by one dimension only
CREATE INDEX idx_inventory_product  ON inventory (product_id);
CREATE INDEX idx_inventory_wh       ON inventory (warehouse_id);
-- [FIX-18] location_id is joined in v_inventory_by_warehouse
CREATE INDEX idx_inventory_location ON inventory (location_id);
-- [FIX-14] Composite: used by "stock for product X at warehouse Y" queries
CREATE INDEX idx_inventory_prod_wh  ON inventory (product_id, warehouse_id);

-- -------------------------------------------------------------------------
-- Purchase orders
-- -------------------------------------------------------------------------
CREATE INDEX idx_po_supplier        ON purchase_order (supplier_id, status);
CREATE INDEX idx_po_warehouse       ON purchase_order (warehouse_id, order_date);
CREATE INDEX idx_pol_product        ON po_line (product_id);
-- [FIX-16] goods_receipt_line had no indexes at all
CREATE INDEX idx_gr_po              ON goods_receipt (po_id, receipt_date);
CREATE INDEX idx_grl_receipt        ON goods_receipt_line (receipt_id);
CREATE INDEX idx_grl_pol            ON goods_receipt_line (po_line_id);

-- -------------------------------------------------------------------------
-- Sales orders
-- -------------------------------------------------------------------------
CREATE INDEX idx_so_customer        ON sales_order (customer_id, status);
CREATE INDEX idx_so_warehouse       ON sales_order (warehouse_id, order_date);
CREATE INDEX idx_sol_product        ON so_line (product_id);
CREATE INDEX idx_ship_so            ON shipment (so_id, status);
-- [FIX-16] shipment_line had no indexes at all
CREATE INDEX idx_shipl_shipment     ON shipment_line (shipment_id);
CREATE INDEX idx_shipl_sol          ON shipment_line (so_line_id);

-- -------------------------------------------------------------------------
-- Stock transfers  [FIX-17]
-- -------------------------------------------------------------------------
CREATE INDEX idx_xfer_from          ON stock_transfer (from_warehouse_id, status);
CREATE INDEX idx_xfer_to            ON stock_transfer (to_warehouse_id, status);
-- [FIX-17] Line lookup from header
CREATE INDEX idx_xfl_transfer       ON stock_transfer_line (transfer_id);
CREATE INDEX idx_xfl_product        ON stock_transfer_line (product_id);

-- -------------------------------------------------------------------------
-- Stock transactions  [FIX-15]
-- -------------------------------------------------------------------------
-- Original: (product_id, transaction_date) — good for per-product history
CREATE INDEX idx_stx_product_date   ON stock_transaction (product_id, transaction_date);
-- Original: (warehouse_id, transaction_date) — good for per-warehouse reports
CREATE INDEX idx_stx_wh_date        ON stock_transaction (warehouse_id, transaction_date);
-- [FIX-15] Added transaction_type to support "all ISSUE movements at WH-EAST this month"
CREATE INDEX idx_stx_wh_type_date   ON stock_transaction (warehouse_id, transaction_type, transaction_date);
-- Original: reference lookup (unchanged)
CREATE INDEX idx_stx_ref            ON stock_transaction (reference_type, reference_id);

PROMPT Indexes created.