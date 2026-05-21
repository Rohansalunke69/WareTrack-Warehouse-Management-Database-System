-- =============================================================================
-- 03_sequences_triggers.sql - Surrogate key sequences and ID triggers
-- =============================================================================

CREATE SEQUENCE seq_department        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_employee          START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_product_category  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_product           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_supplier          START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_customer          START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_warehouse         START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_warehouse_location START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_inventory         START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_purchase_order    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_po_line           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_goods_receipt     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_goods_receipt_line START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_sales_order       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_so_line           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_shipment          START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_shipment_line     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_stock_transfer    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_stock_transfer_line START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_stock_transaction START WITH 1 INCREMENT BY 1 NOCACHE;

-- Generic trigger pattern: assign PK from sequence when NULL on insert
CREATE OR REPLACE TRIGGER trg_department_bi
BEFORE INSERT ON department FOR EACH ROW
BEGIN
  IF :NEW.department_id IS NULL THEN
    :NEW.department_id := seq_department.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_employee_bi
BEFORE INSERT ON employee FOR EACH ROW
BEGIN
  IF :NEW.employee_id IS NULL THEN
    :NEW.employee_id := seq_employee.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_product_category_bi
BEFORE INSERT ON product_category FOR EACH ROW
BEGIN
  IF :NEW.category_id IS NULL THEN
    :NEW.category_id := seq_product_category.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_product_bi
BEFORE INSERT ON product FOR EACH ROW
BEGIN
  IF :NEW.product_id IS NULL THEN
    :NEW.product_id := seq_product.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_supplier_bi
BEFORE INSERT ON supplier FOR EACH ROW
BEGIN
  IF :NEW.supplier_id IS NULL THEN
    :NEW.supplier_id := seq_supplier.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_customer_bi
BEFORE INSERT ON customer FOR EACH ROW
BEGIN
  IF :NEW.customer_id IS NULL THEN
    :NEW.customer_id := seq_customer.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_warehouse_bi
BEFORE INSERT ON warehouse FOR EACH ROW
BEGIN
  IF :NEW.warehouse_id IS NULL THEN
    :NEW.warehouse_id := seq_warehouse.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_warehouse_location_bi
BEFORE INSERT ON warehouse_location FOR EACH ROW
BEGIN
  IF :NEW.location_id IS NULL THEN
    :NEW.location_id := seq_warehouse_location.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_inventory_bi
BEFORE INSERT ON inventory FOR EACH ROW
BEGIN
  IF :NEW.inventory_id IS NULL THEN
    :NEW.inventory_id := seq_inventory.NEXTVAL;
  END IF;
  :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_inventory_bu
BEFORE UPDATE ON inventory FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_purchase_order_bi
BEFORE INSERT ON purchase_order FOR EACH ROW
BEGIN
  IF :NEW.po_id IS NULL THEN
    :NEW.po_id := seq_purchase_order.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_po_line_bi
BEFORE INSERT ON po_line FOR EACH ROW
BEGIN
  IF :NEW.po_line_id IS NULL THEN
    :NEW.po_line_id := seq_po_line.NEXTVAL;
  END IF;
  IF :NEW.line_total IS NULL OR :NEW.line_total = 0 THEN
    :NEW.line_total := :NEW.qty_ordered * :NEW.unit_cost;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_goods_receipt_bi
BEFORE INSERT ON goods_receipt FOR EACH ROW
BEGIN
  IF :NEW.receipt_id IS NULL THEN
    :NEW.receipt_id := seq_goods_receipt.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_goods_receipt_line_bi
BEFORE INSERT ON goods_receipt_line FOR EACH ROW
BEGIN
  IF :NEW.receipt_line_id IS NULL THEN
    :NEW.receipt_line_id := seq_goods_receipt_line.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_sales_order_bi
BEFORE INSERT ON sales_order FOR EACH ROW
BEGIN
  IF :NEW.so_id IS NULL THEN
    :NEW.so_id := seq_sales_order.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_so_line_bi
BEFORE INSERT ON so_line FOR EACH ROW
BEGIN
  IF :NEW.so_line_id IS NULL THEN
    :NEW.so_line_id := seq_so_line.NEXTVAL;
  END IF;
  IF :NEW.line_total IS NULL OR :NEW.line_total = 0 THEN
    :NEW.line_total := :NEW.qty_ordered * :NEW.unit_price;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_shipment_bi
BEFORE INSERT ON shipment FOR EACH ROW
BEGIN
  IF :NEW.shipment_id IS NULL THEN
    :NEW.shipment_id := seq_shipment.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_shipment_line_bi
BEFORE INSERT ON shipment_line FOR EACH ROW
BEGIN
  IF :NEW.shipment_line_id IS NULL THEN
    :NEW.shipment_line_id := seq_shipment_line.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_stock_transfer_bi
BEFORE INSERT ON stock_transfer FOR EACH ROW
BEGIN
  IF :NEW.transfer_id IS NULL THEN
    :NEW.transfer_id := seq_stock_transfer.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_stock_transfer_line_bi
BEFORE INSERT ON stock_transfer_line FOR EACH ROW
BEGIN
  IF :NEW.transfer_line_id IS NULL THEN
    :NEW.transfer_line_id := seq_stock_transfer_line.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_stock_transaction_bi
BEFORE INSERT ON stock_transaction FOR EACH ROW
BEGIN
  IF :NEW.transaction_id IS NULL THEN
    :NEW.transaction_id := seq_stock_transaction.NEXTVAL;
  END IF;
END;
/

PROMPT Sequences and triggers created.
