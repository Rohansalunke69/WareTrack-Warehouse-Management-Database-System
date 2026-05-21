-- Drop all warehouse management objects (reverse dependency order)
SET SERVEROUTPUT ON

BEGIN
  FOR r IN (
    SELECT object_type, object_name
    FROM user_objects
    WHERE object_name IN (
      'PKG_STOCK_MOVEMENT',
      'V_LOW_STOCK', 'V_INVENTORY_BY_WAREHOUSE', 'V_OPEN_PURCHASE_ORDERS',
      'V_STOCK_VALUATION', 'V_PENDING_SHIPMENTS',
      'STOCK_TRANSACTION', 'SHIPMENT_LINE', 'SHIPMENT',
      'SO_LINE', 'SALES_ORDER', 'CUSTOMER',
      'GOODS_RECEIPT_LINE', 'GOODS_RECEIPT',
      'PO_LINE', 'PURCHASE_ORDER',
      'STOCK_TRANSFER_LINE', 'STOCK_TRANSFER',
      'INVENTORY', 'WAREHOUSE_LOCATION', 'WAREHOUSE',
      'PRODUCT', 'PRODUCT_CATEGORY', 'SUPPLIER',
      'EMPLOYEE', 'DEPARTMENT'
    )
    AND object_type IN ('PACKAGE', 'VIEW', 'TABLE', 'SEQUENCE', 'TRIGGER')
    ORDER BY
      CASE object_type
        WHEN 'PACKAGE' THEN 1
        WHEN 'VIEW' THEN 2
        WHEN 'TRIGGER' THEN 3
        WHEN 'TABLE' THEN 4
        WHEN 'SEQUENCE' THEN 5
      END
  ) LOOP
    BEGIN
      IF r.object_type = 'PACKAGE' THEN
        EXECUTE IMMEDIATE 'DROP PACKAGE ' || r.object_name;
      ELSIF r.object_type = 'VIEW' THEN
        EXECUTE IMMEDIATE 'DROP VIEW ' || r.object_name;
      ELSIF r.object_type = 'TRIGGER' THEN
        EXECUTE IMMEDIATE 'DROP TRIGGER ' || r.object_name;
      ELSIF r.object_type = 'TABLE' THEN
        EXECUTE IMMEDIATE 'DROP TABLE ' || r.object_name || ' CASCADE CONSTRAINTS PURGE';
      ELSIF r.object_type = 'SEQUENCE' THEN
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || r.object_name;
      END IF;
      DBMS_OUTPUT.PUT_LINE('Dropped ' || r.object_type || ' ' || r.object_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Skip ' || r.object_name || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT Drop complete. Re-run install scripts to recreate schema.
