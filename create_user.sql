-- =============================================================================
-- create_user.sql - Run as SYS or a DBA account (adjust password and tablespace)
-- Creates dedicated schema user for Warehouse Management System
-- =============================================================================
-- Example for Oracle XE / PDB:
--   sqlplus sys/password@localhost:1521/XEPDB1 AS SYSDBA
--   @create_user.sql

DEFINE wms_user = WMS_USER
DEFINE wms_pwd  = WMS_123

CREATE USER &&wms_user IDENTIFIED BY "&&wms_pwd"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT CREATE SESSION TO &&wms_user;
GRANT CREATE TABLE TO &&wms_user;
GRANT CREATE VIEW TO &&wms_user;
GRANT CREATE SEQUENCE TO &&wms_user;
GRANT CREATE TRIGGER TO &&wms_user;
GRANT CREATE PROCEDURE TO &&wms_user;

PROMPT User &&wms_user created. Connect as this user and run run_all.sql
