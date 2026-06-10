-- =============================================================
-- JUMPCORE OS — MASTER MIGRATION RUNNER
-- Run this file to build the entire database from scratch.
-- Compatible with: PostgreSQL 14+
-- =============================================================
-- Usage:
--   psql -U postgres -d jumpcore_os -f run_all_migrations.sql
-- =============================================================

\echo '============================================='
\echo ' JUMPCORE OS — Database Migration Runner'
\echo ' JumpZone South Africa'
\echo '============================================='

-- Create database (run this separately as superuser if needed)
-- CREATE DATABASE jumpcore_os;
-- \c jumpcore_os

\echo '[1/8] Extensions & Enums...'
\i migrations/001_extensions_and_enums.sql
\echo '     ✓ Done'

\echo '[2/8] Users, Auth & Regions...'
\i migrations/002_users_auth_regions.sql
\echo '     ✓ Done'

\echo '[3/8] Equipment & Vehicles...'
\i migrations/003_equipment_vehicles.sql
\echo '     ✓ Done'

\echo '[4/8] Bookings & Payments...'
\i migrations/004_bookings_payments.sql
\echo '     ✓ Done'

\echo '[5/8] Inventory, Dispatch & Notifications...'
\i migrations/005_inventory_dispatch_notifications.sql
\echo '     ✓ Done'

\echo '[6/8] Indexes...'
\i migrations/006_indexes.sql
\echo '     ✓ Done'

\echo '[7/8] Functions, Triggers & Views...'
\i migrations/007_functions_triggers_views.sql
\echo '     ✓ Done'

\echo '[8/8] Seed Data...'
\i migrations/008_seed_data.sql
\echo '     ✓ Done'

\echo ''
\echo '============================================='
\echo ' JUMPCORE OS Database Ready!'
\echo ' Tables:    32'
\echo ' Indexes:   60+'
\echo ' Triggers:  8'
\echo ' Functions: 4'
\echo ' Views:     6'
\echo '============================================='
\echo ' Default admin login:'
\echo '   Email:    admin@jumpzone.co.za'
\echo '   Password: ChangeMe@2024!'
\echo ' CHANGE THE PASSWORD IMMEDIATELY!'
\echo '============================================='
