# Inventory & Supply Chain Management (Warehouse Management)

Oracle database scripts for a warehouse management system covering suppliers, products, multi-warehouse inventory, purchase orders, goods receipt, sales orders, shipments, stock transfers, and transaction audit trails.

## Prerequisites

- Oracle Database 12c or later (19c/21c recommended)
- SQL*Plus, SQL Developer, or Oracle SQLcl
- A schema user with `CREATE TABLE`, `CREATE SEQUENCE`, `CREATE TRIGGER`, and `CREATE VIEW` privileges

## Project structure

| File | Purpose |
|------|---------|
| `00_drop_schema.sql` | Drops all objects (run only to reset) |
| `01_create_tables.sql` | Tables and primary keys |
| `02_constraints.sql` | Foreign keys and check constraints |
| `03_sequences_triggers.sql` | Sequences and `BEFORE INSERT` triggers for surrogate keys |
| `04_indexes.sql` | Performance indexes |
| `05_views.sql` | Reporting views |
| `06_sample_data.sql` | Seed data for testing |
| `07_packages.sql` | Stock movement procedures |

## Installation

Connect as your application user (replace credentials and connect string):

```bash
sqlplus wms_user/wms_password@localhost:1521/XEPDB1
```

Run scripts in order:

```sql
@01_create_tables.sql
@02_constraints.sql
@03_sequences_triggers.sql
@04_indexes.sql
@05_views.sql
@06_sample_data.sql
@07_packages.sql
```

From PowerShell (SQL*Plus in PATH):

```powershell
cd d:\Workspace\SoftwareEngMiniProject\sql\oracle\warehouse-management
sqlplus wms_user/wms_password@localhost:1521/XEPDB1 @run_all.sql
```

## Entity overview

```
SUPPLIER ──< PURCHASE_ORDER >── WAREHOUSE
                │
                └──< PO_LINE >── PRODUCT
                         │
GOODS_RECEIPT ───────────┘
      └──< GOODS_RECEIPT_LINE

CUSTOMER ──< SALES_ORDER >── WAREHOUSE
                │
                └──< SO_LINE >── PRODUCT
                         │
SHIPMENT ────────────────┘
      └──< SHIPMENT_LINE

WAREHOUSE ──< WAREHOUSE_LOCATION
      └──< INVENTORY >── PRODUCT

STOCK_TRANSFER (from/to warehouses)
STOCK_TRANSACTION (audit log)
```

## Useful queries

```sql
-- Low stock (below reorder level)
SELECT * FROM v_low_stock;

-- Inventory by warehouse
SELECT * FROM v_inventory_by_warehouse ORDER BY warehouse_code, sku;

-- Open purchase orders
SELECT * FROM v_open_purchase_orders;

-- Stock movement history for a product
SELECT * FROM stock_transaction
 WHERE product_id = 1
 ORDER BY transaction_date DESC;
```

## Reset database

```sql
@00_drop_schema.sql
```

Then re-run the install scripts above.
