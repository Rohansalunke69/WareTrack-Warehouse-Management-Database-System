PROMPT
PROMPT Enter the WMS schema username (default: WMS_USER):
ACCEPT wms_user CHAR DEFAULT 'WMS_USER' PROMPT 'Username: '

PROMPT
PROMPT Enter the WMS schema password (input is hidden):
ACCEPT wms_pwd  CHAR PROMPT 'Password: ' HIDE

-- -------------------------------------------------------------------------
-- Create the application schema user
-- -------------------------------------------------------------------------
CREATE USER &&wms_user
  IDENTIFIED BY "&&wms_pwd"
  DEFAULT TABLESPACE   users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON   users;

-- -------------------------------------------------------------------------
-- Minimum privileges required to install and run the WMS schema
-- -------------------------------------------------------------------------
GRANT CREATE SESSION   TO &&wms_user;
GRANT CREATE TABLE     TO &&wms_user;
GRANT CREATE VIEW      TO &&wms_user;
GRANT CREATE SEQUENCE  TO &&wms_user;
GRANT CREATE TRIGGER   TO &&wms_user;
GRANT CREATE PROCEDURE TO &&wms_user;

-- -------------------------------------------------------------------------
-- Clear substitution variables from memory immediately after use
-- so the password does not linger in the SQL*Plus session buffer
-- -------------------------------------------------------------------------
UNDEFINE wms_pwd

PROMPT
PROMPT User &&wms_user created successfully.
PROMPT Connect as &&wms_user and run:  @run_all.sql
PROMPT