-- Run all scripts in order (SQL*Plus / SQLcl)
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET ECHO ON
SET DEFINE OFF

@01_create_tables.sql
@02_constraints.sql
@03_sequences_triggers.sql
@04_indexes.sql
@05_views.sql
@06_sample_data.sql
@07_packages.sql

COMMIT;
PROMPT Warehouse Management schema installed successfully.
