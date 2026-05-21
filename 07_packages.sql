-- =============================================================================
-- 07_packages.sql - Stock movement procedures
-- =============================================================================

CREATE OR REPLACE PACKAGE pkg_stock_movement AS
  -- Receive goods against a PO line into a warehouse location
  PROCEDURE receive_stock (
    p_po_line_id    IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty           IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_receipt_id    OUT NUMBER
  );

  -- Ship stock against a sales order line
  PROCEDURE ship_stock (
    p_so_line_id    IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty           IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_shipment_id   OUT NUMBER
  );

  -- Manual inventory adjustment (+/-)
  PROCEDURE adjust_stock (
    p_product_id    IN  NUMBER,
    p_warehouse_id  IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty_change    IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_notes         IN  VARCHAR2 DEFAULT NULL
  );

  -- Log a stock transaction and update inventory
  PROCEDURE apply_inventory_change (
    p_product_id      IN NUMBER,
    p_warehouse_id    IN NUMBER,
    p_location_id     IN NUMBER,
    p_qty_change      IN NUMBER,
    p_transaction_type IN VARCHAR2,
    p_reference_type  IN VARCHAR2,
    p_reference_id    IN NUMBER,
    p_employee_id     IN NUMBER,
    p_notes           IN VARCHAR2 DEFAULT NULL
  );
END pkg_stock_movement;
/

CREATE OR REPLACE PACKAGE BODY pkg_stock_movement AS

  PROCEDURE apply_inventory_change (
    p_product_id      IN NUMBER,
    p_warehouse_id    IN NUMBER,
    p_location_id     IN NUMBER,
    p_qty_change      IN NUMBER,
    p_transaction_type IN VARCHAR2,
    p_reference_type  IN VARCHAR2,
    p_reference_id    IN NUMBER,
    p_employee_id     IN NUMBER,
    p_notes           IN VARCHAR2 DEFAULT NULL
  ) IS
    v_qty_before NUMBER(12,3);
    v_qty_after  NUMBER(12,3);
    v_inv_id     NUMBER(10);
  BEGIN
    IF p_qty_change = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Quantity change cannot be zero.');
    END IF;

    BEGIN
      SELECT inventory_id, qty_on_hand
      INTO v_inv_id, v_qty_before
      FROM inventory
      WHERE product_id = p_product_id
        AND warehouse_id = p_warehouse_id
        AND location_id = p_location_id
      FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        IF p_qty_change < 0 THEN
          RAISE_APPLICATION_ERROR(-20002, 'Cannot reduce stock: no inventory record exists.');
        END IF;
        v_qty_before := 0;
        INSERT INTO inventory (inventory_id, product_id, warehouse_id, location_id, qty_on_hand, qty_reserved)
        VALUES (seq_inventory.NEXTVAL, p_product_id, p_warehouse_id, p_location_id, 0, 0)
        RETURNING inventory_id INTO v_inv_id;
    END;

    v_qty_after := v_qty_before + p_qty_change;

    IF v_qty_after < 0 THEN
      RAISE_APPLICATION_ERROR(-20003, 'Insufficient stock. Available: ' || v_qty_before);
    END IF;

    UPDATE inventory
    SET qty_on_hand = v_qty_after
    WHERE inventory_id = v_inv_id;

    INSERT INTO stock_transaction (
      transaction_id, product_id, warehouse_id, location_id,
      transaction_type, qty_change, qty_before, qty_after,
      reference_type, reference_id, employee_id, notes
    ) VALUES (
      seq_stock_transaction.NEXTVAL, p_product_id, p_warehouse_id, p_location_id,
      p_transaction_type, p_qty_change, v_qty_before, v_qty_after,
      p_reference_type, p_reference_id, p_employee_id, p_notes
    );
  END apply_inventory_change;

  PROCEDURE receive_stock (
    p_po_line_id    IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty           IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_receipt_id    OUT NUMBER
  ) IS
    v_po_id       NUMBER(10);
    v_product_id  NUMBER(10);
    v_warehouse_id NUMBER(10);
    v_ordered     NUMBER(12,3);
    v_received    NUMBER(12,3);
    v_po_number   VARCHAR2(30);
  BEGIN
    IF p_qty <= 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Receive quantity must be positive.');
    END IF;

    SELECT pl.po_id, pl.product_id, po.warehouse_id, pl.qty_ordered, pl.qty_received, po.po_number
    INTO v_po_id, v_product_id, v_warehouse_id, v_ordered, v_received, v_po_number
    FROM po_line pl
    JOIN purchase_order po ON po.po_id = pl.po_id
    WHERE pl.po_line_id = p_po_line_id;

    IF v_received + p_qty > v_ordered THEN
      RAISE_APPLICATION_ERROR(-20011, 'Receive quantity exceeds PO line outstanding.');
    END IF;

    INSERT INTO goods_receipt (receipt_id, receipt_number, po_id, received_by)
    VALUES (seq_goods_receipt.NEXTVAL, 'GR-' || TO_CHAR(SYSDATE, 'YYYYMMDD-HH24MISS'), v_po_id, p_employee_id)
    RETURNING receipt_id INTO p_receipt_id;

    INSERT INTO goods_receipt_line (receipt_line_id, receipt_id, po_line_id, product_id, location_id, qty_received)
    VALUES (seq_goods_receipt_line.NEXTVAL, p_receipt_id, p_po_line_id, v_product_id, p_location_id, p_qty);

    UPDATE po_line SET qty_received = qty_received + p_qty WHERE po_line_id = p_po_line_id;

    UPDATE purchase_order po
    SET status = CASE
          WHEN (SELECT SUM(qty_ordered - qty_received) FROM po_line WHERE po_id = v_po_id) = 0 THEN 'RECEIVED'
          ELSE 'PARTIAL'
        END
    WHERE po_id = v_po_id;

    apply_inventory_change(
      v_product_id, v_warehouse_id, p_location_id, p_qty,
      'RECEIPT', 'GOODS_RECEIPT', p_receipt_id, p_employee_id,
      'Receipt for PO ' || v_po_number
    );
  END receive_stock;

  PROCEDURE ship_stock (
    p_so_line_id    IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty           IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_shipment_id   OUT NUMBER
  ) IS
    v_so_id       NUMBER(10);
    v_product_id  NUMBER(10);
    v_warehouse_id NUMBER(10);
    v_ordered     NUMBER(12,3);
    v_shipped     NUMBER(12,3);
    v_so_number   VARCHAR2(30);
  BEGIN
    IF p_qty <= 0 THEN
      RAISE_APPLICATION_ERROR(-20020, 'Ship quantity must be positive.');
    END IF;

    SELECT sl.so_id, sl.product_id, so.warehouse_id, sl.qty_ordered, sl.qty_shipped, so.so_number
    INTO v_so_id, v_product_id, v_warehouse_id, v_ordered, v_shipped, v_so_number
    FROM so_line sl
    JOIN sales_order so ON so.so_id = sl.so_id
    WHERE sl.so_line_id = p_so_line_id;

    IF v_shipped + p_qty > v_ordered THEN
      RAISE_APPLICATION_ERROR(-20021, 'Ship quantity exceeds SO line outstanding.');
    END IF;

    INSERT INTO shipment (shipment_id, shipment_number, so_id, shipped_by, status)
    VALUES (seq_shipment.NEXTVAL, 'SH-' || TO_CHAR(SYSDATE, 'YYYYMMDD-HH24MISS'), v_so_id, p_employee_id, 'PENDING')
    RETURNING shipment_id INTO p_shipment_id;

    INSERT INTO shipment_line (shipment_line_id, shipment_id, so_line_id, product_id, location_id, qty_shipped)
    VALUES (seq_shipment_line.NEXTVAL, p_shipment_id, p_so_line_id, v_product_id, p_location_id, p_qty);

    UPDATE so_line SET qty_shipped = qty_shipped + p_qty WHERE so_line_id = p_so_line_id;

    UPDATE sales_order so
    SET status = CASE
          WHEN (SELECT SUM(qty_ordered - qty_shipped) FROM so_line WHERE so_id = v_so_id) = 0 THEN 'SHIPPED'
          ELSE 'PARTIAL'
        END
    WHERE so_id = v_so_id;

    apply_inventory_change(
      v_product_id, v_warehouse_id, p_location_id, -p_qty,
      'ISSUE', 'SHIPMENT', p_shipment_id, p_employee_id,
      'Shipment for SO ' || v_so_number
    );
  END ship_stock;

  PROCEDURE adjust_stock (
    p_product_id    IN  NUMBER,
    p_warehouse_id  IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty_change    IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_notes         IN  VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    apply_inventory_change(
      p_product_id, p_warehouse_id, p_location_id, p_qty_change,
      'ADJUSTMENT', 'MANUAL', NULL, p_employee_id, p_notes
    );
  END adjust_stock;

END pkg_stock_movement;
/

PROMPT Package PKG_STOCK_MOVEMENT created.
