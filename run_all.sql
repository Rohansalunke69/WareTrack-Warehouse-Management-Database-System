-- Exit immediately if any statement fails  [FIX-39]
WHENEVER SQLERROR EXIT SQL.SQLCODE

SET ECHO    ON    -- Print each statement before executing
SET DEFINE  OFF   -- Prevent & substitution in sample data strings
SET FEEDBACK ON   -- Show row counts after DML

-- [FIX-38] Capture the full install log
SPOOL wms_install.log

PROMPT =====================================================================
PROMPT  WMS Schema Install — started: &&_DATE
PROMPT =====================================================================

-- Installation order is dependency-driven:
--   01: Tables (no FKs yet, so any order within is fine)
--   02: Constraints (FKs require all tables to exist)
--   03: Sequences + Triggers (require tables)
--   04: Indexes (require tables)
--   05: Views (require tables + constraints)
--   06: Sample data (requires sequences, triggers, uom_lookup table)
--   07: Package (requires tables, sequences)

@01_create_tables.sql
@02_constraints.sql
@03_sequences_triggers.sql
@04_indexes.sql
@05_views.sql
@06_sample_data.sql
@07_packages.sql

COMMIT;

PROMPT =====================================================================
PROMPT  WMS Schema Install — COMPLETE
PROMPT =====================================================================

SPOOL OFF