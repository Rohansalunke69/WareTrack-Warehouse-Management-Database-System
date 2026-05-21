-- =============================================================================
-- 04_indexes.sql - Query performance indexes
-- =============================================================================

CREATE INDEX idx_employee_dept ON employee (department_id);
CREATE INDEX idx_product_category ON product (category_id);
CREATE INDEX idx_product_name ON product (product_name);
CREATE INDEX idx_location_wh ON warehouse_location (warehouse_id);
CREATE INDEX idx_inventory_product ON inventory (product_id);
CREATE INDEX idx_inventory_wh ON inventory (warehouse_id);
CREATE INDEX idx_po_supplier ON purchase_order (supplier_id, status);
CREATE INDEX idx_po_warehouse ON purchase_order (warehouse_id, order_date);
CREATE INDEX idx_pol_product ON po_line (product_id);
CREATE INDEX idx_gr_po ON goods_receipt (po_id, receipt_date);
CREATE INDEX idx_so_customer ON sales_order (customer_id, status);
CREATE INDEX idx_so_warehouse ON sales_order (warehouse_id, order_date);
CREATE INDEX idx_sol_product ON so_line (product_id);
CREATE INDEX idx_ship_so ON shipment (so_id, status);
CREATE INDEX idx_xfer_from ON stock_transfer (from_warehouse_id, status);
CREATE INDEX idx_xfer_to ON stock_transfer (to_warehouse_id, status);
CREATE INDEX idx_stx_product_date ON stock_transaction (product_id, transaction_date);
CREATE INDEX idx_stx_wh_date ON stock_transaction (warehouse_id, transaction_date);
CREATE INDEX idx_stx_ref ON stock_transaction (reference_type, reference_id);

PROMPT Indexes created.
