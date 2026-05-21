-- =============================================================================
-- Inventory & Supply Chain Management - Warehouse Management (Oracle)
-- 01_create_tables.sql - Core tables and primary keys
-- =============================================================================

-- Organization
CREATE TABLE department (
  department_id   NUMBER(10)      NOT NULL,
  department_code VARCHAR2(10)    NOT NULL,
  department_name VARCHAR2(100)   NOT NULL,
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_department PRIMARY KEY (department_id),
  CONSTRAINT uq_department_code UNIQUE (department_code)
);

CREATE TABLE employee (
  employee_id     NUMBER(10)      NOT NULL,
  department_id   NUMBER(10)      NOT NULL,
  employee_code   VARCHAR2(20)    NOT NULL,
  first_name      VARCHAR2(50)    NOT NULL,
  last_name       VARCHAR2(50)    NOT NULL,
  email           VARCHAR2(120),
  phone           VARCHAR2(30),
  job_title       VARCHAR2(80),
  hire_date       DATE            NOT NULL,
  is_active       CHAR(1)         DEFAULT 'Y' NOT NULL,
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_employee PRIMARY KEY (employee_id),
  CONSTRAINT uq_employee_code UNIQUE (employee_code)
);

-- Master data
CREATE TABLE product_category (
  category_id     NUMBER(10)      NOT NULL,
  category_code   VARCHAR2(20)    NOT NULL,
  category_name   VARCHAR2(100)   NOT NULL,
  description     VARCHAR2(500),
  CONSTRAINT pk_product_category PRIMARY KEY (category_id),
  CONSTRAINT uq_category_code UNIQUE (category_code)
);

CREATE TABLE product (
  product_id      NUMBER(10)      NOT NULL,
  category_id     NUMBER(10)      NOT NULL,
  sku             VARCHAR2(30)    NOT NULL,
  product_name    VARCHAR2(200)   NOT NULL,
  description     VARCHAR2(1000),
  unit_of_measure VARCHAR2(10)    DEFAULT 'EA' NOT NULL,
  unit_cost       NUMBER(12,2)    DEFAULT 0 NOT NULL,
  unit_price      NUMBER(12,2)    DEFAULT 0 NOT NULL,
  reorder_level   NUMBER(10,3)    DEFAULT 0 NOT NULL,
  is_active       CHAR(1)         DEFAULT 'Y' NOT NULL,
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_product PRIMARY KEY (product_id),
  CONSTRAINT uq_product_sku UNIQUE (sku)
);

CREATE TABLE supplier (
  supplier_id     NUMBER(10)      NOT NULL,
  supplier_code   VARCHAR2(20)    NOT NULL,
  supplier_name   VARCHAR2(150)   NOT NULL,
  contact_name    VARCHAR2(100),
  email           VARCHAR2(120),
  phone           VARCHAR2(30),
  address_line1   VARCHAR2(200),
  city            VARCHAR2(80),
  state_province  VARCHAR2(80),
  postal_code     VARCHAR2(20),
  country         VARCHAR2(60)    DEFAULT 'USA',
  is_active       CHAR(1)         DEFAULT 'Y' NOT NULL,
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_supplier PRIMARY KEY (supplier_id),
  CONSTRAINT uq_supplier_code UNIQUE (supplier_code)
);

CREATE TABLE customer (
  customer_id     NUMBER(10)      NOT NULL,
  customer_code   VARCHAR2(20)    NOT NULL,
  customer_name   VARCHAR2(150)   NOT NULL,
  contact_name    VARCHAR2(100),
  email           VARCHAR2(120),
  phone           VARCHAR2(30),
  address_line1   VARCHAR2(200),
  city            VARCHAR2(80),
  state_province  VARCHAR2(80),
  postal_code     VARCHAR2(20),
  country         VARCHAR2(60)    DEFAULT 'USA',
  is_active       CHAR(1)         DEFAULT 'Y' NOT NULL,
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_customer PRIMARY KEY (customer_id),
  CONSTRAINT uq_customer_code UNIQUE (customer_code)
);

-- Warehouses
CREATE TABLE warehouse (
  warehouse_id    NUMBER(10)      NOT NULL,
  warehouse_code  VARCHAR2(20)    NOT NULL,
  warehouse_name  VARCHAR2(150)   NOT NULL,
  address_line1   VARCHAR2(200),
  city            VARCHAR2(80),
  state_province  VARCHAR2(80),
  postal_code     VARCHAR2(20),
  country         VARCHAR2(60)    DEFAULT 'USA',
  manager_id      NUMBER(10),
  capacity_units  NUMBER(12,2),
  is_active       CHAR(1)         DEFAULT 'Y' NOT NULL,
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_warehouse PRIMARY KEY (warehouse_id),
  CONSTRAINT uq_warehouse_code UNIQUE (warehouse_code)
);

CREATE TABLE warehouse_location (
  location_id     NUMBER(10)      NOT NULL,
  warehouse_id    NUMBER(10)      NOT NULL,
  location_code   VARCHAR2(30)    NOT NULL,
  aisle           VARCHAR2(10),
  rack            VARCHAR2(10),
  bin             VARCHAR2(10),
  zone_type       VARCHAR2(20)    DEFAULT 'STORAGE' NOT NULL,
  max_capacity    NUMBER(12,2),
  is_active       CHAR(1)         DEFAULT 'Y' NOT NULL,
  CONSTRAINT pk_warehouse_location PRIMARY KEY (location_id),
  CONSTRAINT uq_location_per_wh UNIQUE (warehouse_id, location_code)
);

-- Inventory on hand
CREATE TABLE inventory (
  inventory_id    NUMBER(10)      NOT NULL,
  product_id      NUMBER(10)      NOT NULL,
  warehouse_id    NUMBER(10)      NOT NULL,
  location_id     NUMBER(10)      NOT NULL,
  qty_on_hand     NUMBER(12,3)    DEFAULT 0 NOT NULL,
  qty_reserved    NUMBER(12,3)    DEFAULT 0 NOT NULL,
  last_count_date DATE,
  updated_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_inventory PRIMARY KEY (inventory_id),
  CONSTRAINT uq_inventory_slot UNIQUE (product_id, warehouse_id, location_id)
);

-- Procurement
CREATE TABLE purchase_order (
  po_id           NUMBER(10)      NOT NULL,
  po_number       VARCHAR2(30)    NOT NULL,
  supplier_id     NUMBER(10)      NOT NULL,
  warehouse_id    NUMBER(10)      NOT NULL,
  order_date      DATE            DEFAULT TRUNC(SYSDATE) NOT NULL,
  expected_date   DATE,
  status          VARCHAR2(20)    DEFAULT 'DRAFT' NOT NULL,
  total_amount    NUMBER(14,2)    DEFAULT 0 NOT NULL,
  created_by      NUMBER(10),
  notes           VARCHAR2(1000),
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_purchase_order PRIMARY KEY (po_id),
  CONSTRAINT uq_po_number UNIQUE (po_number)
);

CREATE TABLE po_line (
  po_line_id      NUMBER(10)      NOT NULL,
  po_id           NUMBER(10)      NOT NULL,
  line_number     NUMBER(5)       NOT NULL,
  product_id      NUMBER(10)      NOT NULL,
  qty_ordered     NUMBER(12,3)    NOT NULL,
  qty_received    NUMBER(12,3)    DEFAULT 0 NOT NULL,
  unit_cost       NUMBER(12,2)    NOT NULL,
  line_total      NUMBER(14,2)    NOT NULL,
  CONSTRAINT pk_po_line PRIMARY KEY (po_line_id),
  CONSTRAINT uq_po_line UNIQUE (po_id, line_number)
);

CREATE TABLE goods_receipt (
  receipt_id      NUMBER(10)      NOT NULL,
  receipt_number  VARCHAR2(30)    NOT NULL,
  po_id           NUMBER(10)      NOT NULL,
  receipt_date    DATE            DEFAULT TRUNC(SYSDATE) NOT NULL,
  received_by     NUMBER(10),
  notes           VARCHAR2(500),
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_goods_receipt PRIMARY KEY (receipt_id),
  CONSTRAINT uq_receipt_number UNIQUE (receipt_number)
);

CREATE TABLE goods_receipt_line (
  receipt_line_id NUMBER(10)      NOT NULL,
  receipt_id      NUMBER(10)      NOT NULL,
  po_line_id      NUMBER(10)      NOT NULL,
  product_id      NUMBER(10)      NOT NULL,
  location_id     NUMBER(10)      NOT NULL,
  qty_received    NUMBER(12,3)    NOT NULL,
  CONSTRAINT pk_goods_receipt_line PRIMARY KEY (receipt_line_id)
);

-- Sales & fulfillment
CREATE TABLE sales_order (
  so_id           NUMBER(10)      NOT NULL,
  so_number       VARCHAR2(30)    NOT NULL,
  customer_id     NUMBER(10)      NOT NULL,
  warehouse_id    NUMBER(10)      NOT NULL,
  order_date      DATE            DEFAULT TRUNC(SYSDATE) NOT NULL,
  required_date   DATE,
  status          VARCHAR2(20)    DEFAULT 'DRAFT' NOT NULL,
  total_amount    NUMBER(14,2)    DEFAULT 0 NOT NULL,
  created_by      NUMBER(10),
  notes           VARCHAR2(1000),
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sales_order PRIMARY KEY (so_id),
  CONSTRAINT uq_so_number UNIQUE (so_number)
);

CREATE TABLE so_line (
  so_line_id      NUMBER(10)      NOT NULL,
  so_id           NUMBER(10)      NOT NULL,
  line_number     NUMBER(5)       NOT NULL,
  product_id      NUMBER(10)      NOT NULL,
  qty_ordered     NUMBER(12,3)    NOT NULL,
  qty_shipped     NUMBER(12,3)    DEFAULT 0 NOT NULL,
  unit_price      NUMBER(12,2)    NOT NULL,
  line_total      NUMBER(14,2)    NOT NULL,
  CONSTRAINT pk_so_line PRIMARY KEY (so_line_id),
  CONSTRAINT uq_so_line UNIQUE (so_id, line_number)
);

CREATE TABLE shipment (
  shipment_id     NUMBER(10)      NOT NULL,
  shipment_number VARCHAR2(30)    NOT NULL,
  so_id           NUMBER(10)      NOT NULL,
  ship_date       DATE            DEFAULT TRUNC(SYSDATE) NOT NULL,
  carrier         VARCHAR2(80),
  tracking_number VARCHAR2(80),
  status          VARCHAR2(20)    DEFAULT 'PENDING' NOT NULL,
  shipped_by      NUMBER(10),
  created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_shipment PRIMARY KEY (shipment_id),
  CONSTRAINT uq_shipment_number UNIQUE (shipment_number)
);

CREATE TABLE shipment_line (
  shipment_line_id NUMBER(10)     NOT NULL,
  shipment_id     NUMBER(10)      NOT NULL,
  so_line_id      NUMBER(10)      NOT NULL,
  product_id      NUMBER(10)      NOT NULL,
  location_id     NUMBER(10)      NOT NULL,
  qty_shipped     NUMBER(12,3)    NOT NULL,
  CONSTRAINT pk_shipment_line PRIMARY KEY (shipment_line_id)
);

-- Inter-warehouse transfers
CREATE TABLE stock_transfer (
  transfer_id     NUMBER(10)      NOT NULL,
  transfer_number VARCHAR2(30)    NOT NULL,
  from_warehouse_id NUMBER(10)    NOT NULL,
  to_warehouse_id NUMBER(10)      NOT NULL,
  request_date    DATE            DEFAULT TRUNC(SYSDATE) NOT NULL,
  ship_date       DATE,
  receive_date    DATE,
  status          VARCHAR2(20)    DEFAULT 'REQUESTED' NOT NULL,
  requested_by    NUMBER(10),
  notes           VARCHAR2(500),
  CONSTRAINT pk_stock_transfer PRIMARY KEY (transfer_id),
  CONSTRAINT uq_transfer_number UNIQUE (transfer_number)
);

CREATE TABLE stock_transfer_line (
  transfer_line_id NUMBER(10)     NOT NULL,
  transfer_id     NUMBER(10)      NOT NULL,
  product_id      NUMBER(10)      NOT NULL,
  from_location_id NUMBER(10)   NOT NULL,
  to_location_id  NUMBER(10)      NOT NULL,
  qty_requested   NUMBER(12,3)    NOT NULL,
  qty_shipped     NUMBER(12,3)    DEFAULT 0 NOT NULL,
  qty_received    NUMBER(12,3)    DEFAULT 0 NOT NULL,
  CONSTRAINT pk_stock_transfer_line PRIMARY KEY (transfer_line_id)
);

-- Audit trail for all stock movements
CREATE TABLE stock_transaction (
  transaction_id  NUMBER(10)      NOT NULL,
  product_id      NUMBER(10)      NOT NULL,
  warehouse_id    NUMBER(10)      NOT NULL,
  location_id     NUMBER(10),
  transaction_type VARCHAR2(20)   NOT NULL,
  qty_change      NUMBER(12,3)    NOT NULL,
  qty_before      NUMBER(12,3),
  qty_after       NUMBER(12,3),
  reference_type  VARCHAR2(30),
  reference_id    NUMBER(10),
  employee_id     NUMBER(10),
  transaction_date TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  notes           VARCHAR2(500),
  CONSTRAINT pk_stock_transaction PRIMARY KEY (transaction_id)
);

PROMPT Tables created.
