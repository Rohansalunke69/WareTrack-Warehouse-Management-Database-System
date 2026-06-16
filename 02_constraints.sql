-- -------------------------------------------------------------------------
-- Employee
-- -------------------------------------------------------------------------
ALTER TABLE employee
  ADD CONSTRAINT fk_employee_department
  FOREIGN KEY (department_id) REFERENCES department (department_id);

ALTER TABLE employee
  ADD CONSTRAINT chk_employee_active
  CHECK (is_active IN ('Y', 'N'));

-- -------------------------------------------------------------------------
-- Product  [FIX-02: FK to uom_lookup]
-- -------------------------------------------------------------------------
ALTER TABLE product
  ADD CONSTRAINT fk_product_category
  FOREIGN KEY (category_id) REFERENCES product_category (category_id);

ALTER TABLE product
  ADD CONSTRAINT fk_product_uom
  FOREIGN KEY (unit_of_measure) REFERENCES uom_lookup (uom_code);

ALTER TABLE product
  ADD CONSTRAINT chk_product_active
  CHECK (is_active IN ('Y', 'N'));

ALTER TABLE product
  ADD CONSTRAINT chk_product_cost_nonneg
  CHECK (unit_cost >= 0 AND unit_price >= 0 AND reorder_level >= 0);

-- -------------------------------------------------------------------------
-- Supplier / Customer
-- -------------------------------------------------------------------------
ALTER TABLE supplier
  ADD CONSTRAINT chk_supplier_active CHECK (is_active IN ('Y', 'N'));

ALTER TABLE customer
  ADD CONSTRAINT chk_customer_active CHECK (is_active IN ('Y', 'N'));

-- -------------------------------------------------------------------------
-- Warehouse
-- -------------------------------------------------------------------------
ALTER TABLE warehouse
  ADD CONSTRAINT fk_warehouse_manager
  FOREIGN KEY (manager_id) REFERENCES employee (employee_id);

ALTER TABLE warehouse
  ADD CONSTRAINT chk_warehouse_active CHECK (is_active IN ('Y', 'N'));

ALTER TABLE warehouse_location
  ADD CONSTRAINT fk_location_warehouse
  FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id);

ALTER TABLE warehouse_location
  ADD CONSTRAINT chk_location_zone
  CHECK (zone_type IN ('STORAGE', 'PICKING', 'RECEIVING', 'SHIPPING', 'QUARANTINE'));

ALTER TABLE warehouse_location
  ADD CONSTRAINT chk_location_active CHECK (is_active IN ('Y', 'N'));

-- -------------------------------------------------------------------------
-- Inventory  [FIX-09: split into two named constraints for clarity]
-- -------------------------------------------------------------------------
ALTER TABLE inventory
  ADD CONSTRAINT fk_inv_product
  FOREIGN KEY (product_id) REFERENCES product (product_id);

ALTER TABLE inventory
  ADD CONSTRAINT fk_inv_warehouse
  FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id);

ALTER TABLE inventory
  ADD CONSTRAINT fk_inv_location
  FOREIGN KEY (location_id) REFERENCES warehouse_location (location_id);

-- qty_on_hand must be non-negative
ALTER TABLE inventory
  ADD CONSTRAINT chk_inv_qty_on_hand
  CHECK (qty_on_hand >= 0);

-- qty_reserved must be non-negative AND cannot exceed what is physically on hand
ALTER TABLE inventory
  ADD CONSTRAINT chk_inv_qty_reserved
  CHECK (qty_reserved >= 0 AND qty_reserved <= qty_on_hand);

-- -------------------------------------------------------------------------
-- Purchase orders
-- -------------------------------------------------------------------------
ALTER TABLE purchase_order
  ADD CONSTRAINT fk_po_supplier
  FOREIGN KEY (supplier_id) REFERENCES supplier (supplier_id);

ALTER TABLE purchase_order
  ADD CONSTRAINT fk_po_warehouse
  FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id);

ALTER TABLE purchase_order
  ADD CONSTRAINT fk_po_created_by
  FOREIGN KEY (created_by) REFERENCES employee (employee_id);

ALTER TABLE purchase_order
  ADD CONSTRAINT chk_po_status
  CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'PARTIAL', 'RECEIVED', 'CANCELLED'));

ALTER TABLE po_line
  ADD CONSTRAINT fk_pol_po
  FOREIGN KEY (po_id) REFERENCES purchase_order (po_id) ON DELETE CASCADE;

ALTER TABLE po_line
  ADD CONSTRAINT fk_pol_product
  FOREIGN KEY (product_id) REFERENCES product (product_id);

-- [FIX-08] line_number must be a positive integer
ALTER TABLE po_line
  ADD CONSTRAINT chk_pol_line_number
  CHECK (line_number > 0);

ALTER TABLE po_line
  ADD CONSTRAINT chk_pol_qty
  CHECK (qty_ordered > 0 AND qty_received >= 0 AND qty_received <= qty_ordered);

-- -------------------------------------------------------------------------
-- Goods receipt  [FIX-05: reason_code CHECK]
-- -------------------------------------------------------------------------
ALTER TABLE goods_receipt
  ADD CONSTRAINT fk_gr_po
  FOREIGN KEY (po_id) REFERENCES purchase_order (po_id);

ALTER TABLE goods_receipt
  ADD CONSTRAINT fk_gr_received_by
  FOREIGN KEY (received_by) REFERENCES employee (employee_id);

ALTER TABLE goods_receipt
  ADD CONSTRAINT chk_gr_reason
  CHECK (reason_code IN ('STANDARD', 'INITIAL_LOAD', 'RETURN_TO_STOCK', 'DAMAGE_CLAIM'));

ALTER TABLE goods_receipt_line
  ADD CONSTRAINT fk_grl_receipt
  FOREIGN KEY (receipt_id) REFERENCES goods_receipt (receipt_id) ON DELETE CASCADE;

ALTER TABLE goods_receipt_line
  ADD CONSTRAINT fk_grl_pol
  FOREIGN KEY (po_line_id) REFERENCES po_line (po_line_id);

ALTER TABLE goods_receipt_line
  ADD CONSTRAINT fk_grl_product
  FOREIGN KEY (product_id) REFERENCES product (product_id);

ALTER TABLE goods_receipt_line
  ADD CONSTRAINT fk_grl_location
  FOREIGN KEY (location_id) REFERENCES warehouse_location (location_id);

ALTER TABLE goods_receipt_line
  ADD CONSTRAINT chk_grl_qty CHECK (qty_received > 0);

-- -------------------------------------------------------------------------
-- Sales orders
-- -------------------------------------------------------------------------
ALTER TABLE sales_order
  ADD CONSTRAINT fk_so_customer
  FOREIGN KEY (customer_id) REFERENCES customer (customer_id);

ALTER TABLE sales_order
  ADD CONSTRAINT fk_so_warehouse
  FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id);

ALTER TABLE sales_order
  ADD CONSTRAINT fk_so_created_by
  FOREIGN KEY (created_by) REFERENCES employee (employee_id);

ALTER TABLE sales_order
  ADD CONSTRAINT chk_so_status
  CHECK (status IN ('DRAFT', 'CONFIRMED', 'PICKING', 'PARTIAL', 'SHIPPED', 'CANCELLED'));

ALTER TABLE so_line
  ADD CONSTRAINT fk_sol_so
  FOREIGN KEY (so_id) REFERENCES sales_order (so_id) ON DELETE CASCADE;

ALTER TABLE so_line
  ADD CONSTRAINT fk_sol_product
  FOREIGN KEY (product_id) REFERENCES product (product_id);

-- [FIX-08] line_number must be a positive integer
ALTER TABLE so_line
  ADD CONSTRAINT chk_sol_line_number
  CHECK (line_number > 0);

ALTER TABLE so_line
  ADD CONSTRAINT chk_sol_qty
  CHECK (qty_ordered > 0 AND qty_shipped >= 0 AND qty_shipped <= qty_ordered);

-- -------------------------------------------------------------------------
-- Shipments  [FIX-05: reason_code CHECK]
-- -------------------------------------------------------------------------
ALTER TABLE shipment
  ADD CONSTRAINT fk_ship_so
  FOREIGN KEY (so_id) REFERENCES sales_order (so_id);

ALTER TABLE shipment
  ADD CONSTRAINT fk_ship_employee
  FOREIGN KEY (shipped_by) REFERENCES employee (employee_id);

ALTER TABLE shipment
  ADD CONSTRAINT chk_ship_status
  CHECK (status IN ('PENDING', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'));

ALTER TABLE shipment
  ADD CONSTRAINT chk_ship_reason
  CHECK (reason_code IN ('STANDARD', 'PARTIAL_SHIP', 'URGENT', 'RETURN'));

ALTER TABLE shipment_line
  ADD CONSTRAINT fk_shipl_shipment
  FOREIGN KEY (shipment_id) REFERENCES shipment (shipment_id) ON DELETE CASCADE;

ALTER TABLE shipment_line
  ADD CONSTRAINT fk_shipl_sol
  FOREIGN KEY (so_line_id) REFERENCES so_line (so_line_id);

ALTER TABLE shipment_line
  ADD CONSTRAINT fk_shipl_product
  FOREIGN KEY (product_id) REFERENCES product (product_id);

ALTER TABLE shipment_line
  ADD CONSTRAINT fk_shipl_location
  FOREIGN KEY (location_id) REFERENCES warehouse_location (location_id);

ALTER TABLE shipment_line
  ADD CONSTRAINT chk_shipl_qty CHECK (qty_shipped > 0);

-- -------------------------------------------------------------------------
-- Stock transfer
-- -------------------------------------------------------------------------
ALTER TABLE stock_transfer
  ADD CONSTRAINT fk_xfer_from_wh
  FOREIGN KEY (from_warehouse_id) REFERENCES warehouse (warehouse_id);

ALTER TABLE stock_transfer
  ADD CONSTRAINT fk_xfer_to_wh
  FOREIGN KEY (to_warehouse_id) REFERENCES warehouse (warehouse_id);

ALTER TABLE stock_transfer
  ADD CONSTRAINT fk_xfer_requested_by
  FOREIGN KEY (requested_by) REFERENCES employee (employee_id);

ALTER TABLE stock_transfer
  ADD CONSTRAINT chk_xfer_different_wh
  CHECK (from_warehouse_id <> to_warehouse_id);

ALTER TABLE stock_transfer
  ADD CONSTRAINT chk_xfer_status
  CHECK (status IN ('REQUESTED', 'IN_TRANSIT', 'RECEIVED', 'CANCELLED'));

ALTER TABLE stock_transfer_line
  ADD CONSTRAINT fk_xfl_transfer
  FOREIGN KEY (transfer_id) REFERENCES stock_transfer (transfer_id) ON DELETE CASCADE;

ALTER TABLE stock_transfer_line
  ADD CONSTRAINT fk_xfl_product
  FOREIGN KEY (product_id) REFERENCES product (product_id);

ALTER TABLE stock_transfer_line
  ADD CONSTRAINT fk_xfl_from_loc
  FOREIGN KEY (from_location_id) REFERENCES warehouse_location (location_id);

ALTER TABLE stock_transfer_line
  ADD CONSTRAINT fk_xfl_to_loc
  FOREIGN KEY (to_location_id) REFERENCES warehouse_location (location_id);

-- [FIX-06] Prevent self-transfer within the same bin
ALTER TABLE stock_transfer_line
  ADD CONSTRAINT chk_xfl_different_loc
  CHECK (from_location_id <> to_location_id);

ALTER TABLE stock_transfer_line
  ADD CONSTRAINT chk_xfl_qty
  CHECK (qty_requested > 0 AND qty_shipped >= 0 AND qty_received >= 0);

-- -------------------------------------------------------------------------
-- Stock transactions
-- -------------------------------------------------------------------------
ALTER TABLE stock_transaction
  ADD CONSTRAINT fk_stx_product
  FOREIGN KEY (product_id) REFERENCES product (product_id);

ALTER TABLE stock_transaction
  ADD CONSTRAINT fk_stx_warehouse
  FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id);

ALTER TABLE stock_transaction
  ADD CONSTRAINT fk_stx_location
  FOREIGN KEY (location_id) REFERENCES warehouse_location (location_id);

ALTER TABLE stock_transaction
  ADD CONSTRAINT fk_stx_employee
  FOREIGN KEY (employee_id) REFERENCES employee (employee_id);

ALTER TABLE stock_transaction
  ADD CONSTRAINT chk_stx_type
  CHECK (transaction_type IN (
    'RECEIPT', 'ISSUE', 'ADJUSTMENT', 'TRANSFER_IN', 'TRANSFER_OUT', 'RETURN'
  ));

PROMPT Constraints applied.