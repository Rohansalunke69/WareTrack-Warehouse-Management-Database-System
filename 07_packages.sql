-- -------------------------------------------------------------------------
-- Package specification
-- apply_inventory_change is intentionally NOT declared here [FIX-31].
-- -------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_stock_movement AS

  -- Receive goods against a PO line into a warehouse location.
  -- Pass p_receipt_id => NULL to open a new goods_receipt header.
  -- Pass an existing receipt_id to append lines to the same session.  [FIX-33]
  PROCEDURE receive_stock (
    p_po_line_id    IN     NUMBER,
    p_location_id   IN     NUMBER,
    p_qty           IN     NUMBER,
    p_employee_id   IN     NUMBER,
    p_receipt_id    IN OUT NUMBER   -- NULL = create new; existing = append
  );

  -- Ship goods against a sales order line.
  -- Pass p_shipment_id => NULL to open a new shipment header.
  -- Pass an existing shipment_id to append lines to the same dispatch.  [FIX-34]
  PROCEDURE ship_stock (
    p_so_line_id    IN     NUMBER,
    p_location_id   IN     NUMBER,
    p_qty           IN     NUMBER,
    p_employee_id   IN     NUMBER,
    p_shipment_id   IN OUT NUMBER   -- NULL = create new; existing = append
  );

  -- Manual inventory adjustment (+/-).
  -- p_reason_code: structured code such as CYCLE_COUNT, DAMAGE_WRITE_OFF,
  --                FOUND_STOCK, SYSTEM_CORRECTION.            [FIX-36]
  PROCEDURE adjust_stock (
    p_product_id    IN  NUMBER,
    p_warehouse_id  IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty_change    IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_reason_code   IN  VARCHAR2 DEFAULT 'MANUAL_ADJUSTMENT',
    p_notes         IN  VARCHAR2 DEFAULT NULL
  );

END pkg_stock_movement;
/


-- -------------------------------------------------------------------------
-- Package body
-- -------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY pkg_stock_movement AS

  -- -----------------------------------------------------------------------
  -- PRIVATE: apply_inventory_change
  -- Atomically updates inventory.qty_on_hand and writes a stock_transaction
  -- audit row. Uses SELECT FOR UPDATE to prevent lost-update concurrency bugs.
  -- NOT declared in the spec — application code must never call this directly.
  -- -----------------------------------------------------------------------
  PROCEDURE apply_inventory_change (
    p_product_id       IN NUMBER,
    p_warehouse_id     IN NUMBER,
    p_location_id      IN NUMBER,
    p_qty_change       IN NUMBER,
    p_transaction_type IN VARCHAR2,
    p_reference_type   IN VARCHAR2,
    p_reference_id     IN NUMBER,
    p_employee_id      IN NUMBER,
    p_notes            IN VARCHAR2 DEFAULT NULL
  ) IS
    v_qty_before NUMBER(12,3);
    v_qty_after  NUMBER(12,3);
    v_inv_id     NUMBER(10);
    v_new_row    BOOLEAN := FALSE;
  BEGIN
    IF p_qty_change = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Quantity change cannot be zero.');
    END IF;

    -- Lock the inventory row for this product+warehouse+location.
    -- FOR UPDATE ensures no other session can modify qty_on_hand between
    -- our read and our write (prevents phantom negative stock).
    BEGIN
      SELECT inventory_id, qty_on_hand
      INTO   v_inv_id, v_qty_before
      FROM   inventory
      WHERE  product_id   = p_product_id
        AND  warehouse_id = p_warehouse_id
        AND  location_id  = p_location_id
      FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- Only allow auto-creation for positive (inbound) movements.
        IF p_qty_change < 0 THEN
          RAISE_APPLICATION_ERROR(-20002,
            'Cannot reduce stock: no inventory record exists for product_id='
            || p_product_id || ' at location_id=' || p_location_id);
        END IF;
        -- [FIX-32] v_qty_before is set to 0 BEFORE the INSERT so the
        -- stock_transaction audit row correctly shows qty_before = 0.
        -- This is the genuine opening balance, not an accident of ordering.
        v_qty_before := 0;
        v_new_row    := TRUE;
        INSERT INTO inventory
          (inventory_id, product_id, warehouse_id, location_id,
           qty_on_hand, qty_reserved)
        VALUES
          (seq_inventory.NEXTVAL, p_product_id, p_warehouse_id, p_location_id,
           0, 0)
        RETURNING inventory_id INTO v_inv_id;
    END;

    v_qty_after := v_qty_before + p_qty_change;

    IF v_qty_after < 0 THEN
      RAISE_APPLICATION_ERROR(-20003,
        'Insufficient stock. On hand: ' || v_qty_before
        || ', requested change: ' || p_qty_change);
    END IF;

    UPDATE inventory
    SET    qty_on_hand = v_qty_after
    WHERE  inventory_id = v_inv_id;

    INSERT INTO stock_transaction (
      transaction_id, product_id, warehouse_id, location_id,
      transaction_type, qty_change, qty_before, qty_after,
      reference_type, reference_id, employee_id, notes
    ) VALUES (
      seq_stock_transaction.NEXTVAL,
      p_product_id, p_warehouse_id, p_location_id,
      p_transaction_type, p_qty_change, v_qty_before, v_qty_after,
      p_reference_type, p_reference_id, p_employee_id, p_notes
    );
  END apply_inventory_change;


  -- -----------------------------------------------------------------------
  -- PUBLIC: receive_stock
  -- -----------------------------------------------------------------------
  PROCEDURE receive_stock (
    p_po_line_id    IN     NUMBER,
    p_location_id   IN     NUMBER,
    p_qty           IN     NUMBER,
    p_employee_id   IN     NUMBER,
    p_receipt_id    IN OUT NUMBER
  ) IS
    v_po_id        NUMBER(10);
    v_product_id   NUMBER(10);
    v_warehouse_id NUMBER(10);
    v_ordered      NUMBER(12,3);
    v_received     NUMBER(12,3);
    v_po_number    VARCHAR2(30);
    v_po_status    VARCHAR2(20);
  BEGIN
    IF p_qty <= 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Receive quantity must be positive.');
    END IF;

    -- Lock the PO line to prevent concurrent over-receipt
    SELECT pl.po_id, pl.product_id, po.warehouse_id,
           pl.qty_ordered, pl.qty_received, po.po_number
    INTO   v_po_id, v_product_id, v_warehouse_id,
           v_ordered, v_received, v_po_number
    FROM   po_line pl
    JOIN   purchase_order po ON po.po_id = pl.po_id
    WHERE  pl.po_line_id = p_po_line_id
    FOR UPDATE OF pl.qty_received;

    IF v_received + p_qty > v_ordered THEN
      RAISE_APPLICATION_ERROR(-20011,
        'Receive qty (' || p_qty || ') would exceed PO line outstanding ('
        || (v_ordered - v_received) || ').');
    END IF;

    -- [FIX-33] Create a new goods_receipt header only when the caller passes NULL.
    -- If an existing receipt_id is passed, append lines to that receipt.
    IF p_receipt_id IS NULL THEN
      INSERT INTO goods_receipt
        (receipt_id, receipt_number, po_id, received_by, reason_code)
      VALUES
        (seq_goods_receipt.NEXTVAL, NULL, v_po_id, p_employee_id, 'STANDARD')
      RETURNING receipt_id INTO p_receipt_id;
      -- receipt_number is auto-generated by trg_goods_receipt_bi [FIX-10]
    END IF;

    INSERT INTO goods_receipt_line
      (receipt_line_id, receipt_id, po_line_id, product_id, location_id, qty_received)
    VALUES
      (seq_goods_receipt_line.NEXTVAL, p_receipt_id, p_po_line_id,
       v_product_id, p_location_id, p_qty);

    UPDATE po_line
    SET    qty_received = qty_received + p_qty
    WHERE  po_line_id   = p_po_line_id;

    -- Promote PO status: RECEIVED when all lines fulfilled, else PARTIAL.
    -- [FIX-33] Also refresh updated_at so the header timestamp is accurate.
    SELECT CASE
             WHEN SUM(qty_ordered - qty_received) = 0 THEN 'RECEIVED'
             ELSE 'PARTIAL'
           END
    INTO   v_po_status
    FROM   po_line
    WHERE  po_id = v_po_id;

    UPDATE purchase_order
    SET    status     = v_po_status,
           updated_at = SYSTIMESTAMP          -- [FIX-33]
    WHERE  po_id = v_po_id;

    apply_inventory_change(
      p_product_id   => v_product_id,
      p_warehouse_id => v_warehouse_id,
      p_location_id  => p_location_id,
      p_qty_change   => p_qty,
      p_transaction_type => 'RECEIPT',
      p_reference_type   => 'GOODS_RECEIPT',
      p_reference_id     => p_receipt_id,
      p_employee_id      => p_employee_id,
      p_notes            => 'Receipt for PO ' || v_po_number
    );
  END receive_stock;


  -- -----------------------------------------------------------------------
  -- PUBLIC: ship_stock
  -- -----------------------------------------------------------------------
  PROCEDURE ship_stock (
    p_so_line_id    IN     NUMBER,
    p_location_id   IN     NUMBER,
    p_qty           IN     NUMBER,
    p_employee_id   IN     NUMBER,
    p_shipment_id   IN OUT NUMBER
  ) IS
    v_so_id        NUMBER(10);
    v_product_id   NUMBER(10);
    v_warehouse_id NUMBER(10);
    v_ordered      NUMBER(12,3);
    v_shipped      NUMBER(12,3);
    v_so_number    VARCHAR2(30);
    v_so_status    VARCHAR2(20);
    v_inv_reserved NUMBER(12,3);
    v_inv_id       NUMBER(10);
  BEGIN
    IF p_qty <= 0 THEN
      RAISE_APPLICATION_ERROR(-20020, 'Ship quantity must be positive.');
    END IF;

    -- Lock the SO line to prevent concurrent over-shipment
    SELECT sl.so_id, sl.product_id, so.warehouse_id,
           sl.qty_ordered, sl.qty_shipped, so.so_number
    INTO   v_so_id, v_product_id, v_warehouse_id,
           v_ordered, v_shipped, v_so_number
    FROM   so_line sl
    JOIN   sales_order so ON so.so_id = sl.so_id
    WHERE  sl.so_line_id = p_so_line_id
    FOR UPDATE OF sl.qty_shipped;

    IF v_shipped + p_qty > v_ordered THEN
      RAISE_APPLICATION_ERROR(-20021,
        'Ship qty (' || p_qty || ') would exceed SO line outstanding ('
        || (v_ordered - v_shipped) || ').');
    END IF;

    -- [FIX-34] Create a new shipment header only when caller passes NULL.
    IF p_shipment_id IS NULL THEN
      INSERT INTO shipment
        (shipment_id, shipment_number, so_id, shipped_by, status, reason_code)
      VALUES
        (seq_shipment.NEXTVAL, NULL, v_so_id, p_employee_id, 'PENDING', 'STANDARD')
      RETURNING shipment_id INTO p_shipment_id;
      -- shipment_number is auto-generated by trg_shipment_bi [FIX-11]
    END IF;

    INSERT INTO shipment_line
      (shipment_line_id, shipment_id, so_line_id, product_id,
       location_id, qty_shipped)
    VALUES
      (seq_shipment_line.NEXTVAL, p_shipment_id, p_so_line_id,
       v_product_id, p_location_id, p_qty);

    UPDATE so_line
    SET    qty_shipped = qty_shipped + p_qty
    WHERE  so_line_id  = p_so_line_id;

    -- Promote SO status: SHIPPED when all lines fulfilled, else PARTIAL.
    -- [FIX-35] Also refresh updated_at.
    SELECT CASE
             WHEN SUM(qty_ordered - qty_shipped) = 0 THEN 'SHIPPED'
             ELSE 'PARTIAL'
           END
    INTO   v_so_status
    FROM   so_line
    WHERE  so_id = v_so_id;

    UPDATE sales_order
    SET    status     = v_so_status,
           updated_at = SYSTIMESTAMP          -- [FIX-35]
    WHERE  so_id = v_so_id;

    -- [FIX-35] Decrement qty_reserved on inventory — this was MISSING entirely
    -- in the original. When an SO was confirmed, qty_reserved was incremented
    -- by the application. On dispatch, it was never released, causing
    -- qty_reserved to grow until it exceeded qty_on_hand, violating the
    -- CHECK constraint (qty_reserved <= qty_on_hand) and crashing.
    SELECT inventory_id, qty_reserved
    INTO   v_inv_id, v_inv_reserved
    FROM   inventory
    WHERE  product_id   = v_product_id
      AND  warehouse_id = v_warehouse_id
      AND  location_id  = p_location_id
    FOR UPDATE;

    IF v_inv_reserved >= p_qty THEN
      -- Normal case: release exactly what we are shipping
      UPDATE inventory
      SET    qty_reserved = qty_reserved - p_qty
      WHERE  inventory_id = v_inv_id;
    ELSE
      -- Edge case: reserved was never set (e.g. walk-in order, manual shipment).
      -- Release whatever reservation exists without going negative.
      UPDATE inventory
      SET    qty_reserved = 0
      WHERE  inventory_id = v_inv_id;
    END IF;

    -- Decrement qty_on_hand and write the audit row via the private procedure
    apply_inventory_change(
      p_product_id   => v_product_id,
      p_warehouse_id => v_warehouse_id,
      p_location_id  => p_location_id,
      p_qty_change   => -p_qty,
      p_transaction_type => 'ISSUE',
      p_reference_type   => 'SHIPMENT',
      p_reference_id     => p_shipment_id,
      p_employee_id      => p_employee_id,
      p_notes            => 'Shipment for SO ' || v_so_number
    );
  END ship_stock;


  -- -----------------------------------------------------------------------
  -- PUBLIC: adjust_stock
  -- -----------------------------------------------------------------------
  PROCEDURE adjust_stock (
    p_product_id    IN  NUMBER,
    p_warehouse_id  IN  NUMBER,
    p_location_id   IN  NUMBER,
    p_qty_change    IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_reason_code   IN  VARCHAR2 DEFAULT 'MANUAL_ADJUSTMENT',  -- [FIX-36]
    p_notes         IN  VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    -- [FIX-36] p_reason_code replaces the hardcoded 'MANUAL' reference_type,
    -- making all adjustments distinguishable in the stock_transaction audit log.
    -- Example values: CYCLE_COUNT, DAMAGE_WRITE_OFF, FOUND_STOCK, SYSTEM_CORRECTION
    apply_inventory_change(
      p_product_id       => p_product_id,
      p_warehouse_id     => p_warehouse_id,
      p_location_id      => p_location_id,
      p_qty_change       => p_qty_change,
      p_transaction_type => 'ADJUSTMENT',
      p_reference_type   => p_reason_code,
      p_reference_id     => NULL,
      p_employee_id      => p_employee_id,
      p_notes            => p_notes
    );
  END adjust_stock;

END pkg_stock_movement;
/

PROMPT Package PKG_STOCK_MOVEMENT created.