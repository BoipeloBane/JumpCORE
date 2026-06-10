# JumpCore OS — PostgreSQL Database

Complete database architecture for the JumpCore OS platform powering JumpZone South Africa.

---

## Requirements

- PostgreSQL **14+**
- Extensions: `uuid-ossp`, `pgcrypto`, `pg_trgm`, `postgis` (optional), `btree_gin`
- PostGIS is optional — remove from migration 001 if not available

---

## Quick Start

```bash
# 1. Create the database
psql -U postgres -c "CREATE DATABASE jumpcore_os;"

# 2. Run all migrations
psql -U postgres -d jumpcore_os -f run_all_migrations.sql
```

---

## Database Structure

```
jumpcore-db/
├── run_all_migrations.sql        ← Run this to build everything
└── migrations/
    ├── 001_extensions_and_enums.sql    ← PG extensions + all ENUM types
    ├── 002_users_auth_regions.sql      ← Users, auth, audit log, GPS tracking
    ├── 003_equipment_vehicles.sql      ← Equipment assets, vehicles, fleet
    ├── 004_bookings_payments.sql       ← Bookings, line items, payments, invoices
    ├── 005_inventory_dispatch.sql      ← Inventory, dispatch, notifications, docs
    ├── 006_indexes.sql                 ← All performance indexes
    ├── 007_functions_triggers_views.sql ← Business logic + reporting views
    └── 008_seed_data.sql               ← Regions, categories, demo data
```

---

## Tables (32 total)

### Authentication & Users
| Table | Purpose |
|-------|---------|
| `users` | All platform users (all roles) |
| `refresh_tokens` | JWT session management |
| `audit_logs` | Immutable security audit trail |
| `customer_profiles` | CRM data for customers |
| `operator_profiles` | Employment & performance data |
| `operator_location_history` | GPS breadcrumb trail |
| `regions` | SA operational regions |

### Equipment & Fleet
| Table | Purpose |
|-------|---------|
| `equipment` | Individual physical assets |
| `equipment_categories` | Asset type classification |
| `maintenance_tickets` | Repair & service tickets |
| `vehicles` | Company fleet registry |
| `vehicle_fuel_log` | Fuel consumption tracking |
| `vehicle_service_log` | Service history |

### Bookings & Finance
| Table | Purpose |
|-------|---------|
| `bookings` | Core booking records |
| `booking_line_items` | Equipment per booking |
| `booking_status_history` | Status change audit trail |
| `booking_photos` | Delivery evidence photos |
| `payments` | Payment transactions |
| `invoices` | Tax invoices |
| `quotations` | Price quotations |

### Operations
| Table | Purpose |
|-------|---------|
| `inventory_items` | Consumable stock |
| `inventory_categories` | Stock classification |
| `inventory_movements` | Stock in/out ledger |
| `dispatch_schedules` | Operator job assignments |
| `operator_checklists` | Mobile app checklists |

### Communication & Documents
| Table | Purpose |
|-------|---------|
| `notifications` | All outbound notifications |
| `documents` | S3-linked document store |
| `reviews` | Customer reviews |
| `financial_transactions` | General ledger |

---

## Views (6)

| View | Purpose |
|------|---------|
| `v_today_bookings` | Dashboard — today's deliveries |
| `v_revenue_by_region_month` | Revenue analytics |
| `v_equipment_utilization` | Equipment performance |
| `v_operator_performance` | Operator KPIs |
| `v_low_stock_alerts` | Inventory reorder alerts |
| `v_maintenance_due` | Upcoming/overdue maintenance |

---

## Key Design Decisions

**UUIDs everywhere** — All primary keys are UUIDs for distributed safety and API exposure without enumeration risk.

**Soft deletes** — bookings, equipment, users and vehicles use `deleted_at` instead of hard deletes to preserve audit history.

**JSONB for flexible data** — Checklist items, notification preferences and gateway responses stored as JSONB for schema flexibility.

**Generated columns** — `balance_due` on bookings and `total_cost` on maintenance tickets are computed automatically.

**Booking totals auto-calculated** — A trigger recalculates subtotal, VAT and total whenever line items change.

**Equipment status auto-synced** — Triggers update equipment status (available → reserved → in_use → available) as bookings progress.

**Customer loyalty auto-upgraded** — Tier (Bronze/Silver/Gold/Platinum) updates automatically when a booking completes.

**60+ indexes** — Every foreign key is indexed. Common dashboard queries have composite indexes. Text search uses `pg_trgm` for fuzzy matching.

---

## Default Login

```
Email:    admin@jumpzone.co.za
Password: ChangeMe@2024!
```

> ⚠️ Change this password immediately after first login.

---

## Production Notes

- **Partition** `operator_location_history` by month (can reach billions of rows)
- Enable **PgBouncer** connection pooling
- Set up **pg_cron** for nightly loyalty tier recalculation
- Use **read replicas** for reporting queries (the `v_` views)
- Enable **WAL archiving** for point-in-time recovery
- Run `VACUUM ANALYZE` weekly on high-traffic tables

---

## Next Step: Backend API

The NestJS API will map directly to these tables:

- `AuthModule` → `users`, `refresh_tokens`
- `BookingsModule` → `bookings`, `booking_line_items`, `booking_status_history`
- `EquipmentModule` → `equipment`, `equipment_categories`, `maintenance_tickets`
- `OperatorsModule` → `operator_profiles`, `operator_location_history`, `dispatch_schedules`
- `FinanceModule` → `payments`, `invoices`, `financial_transactions`
- `InventoryModule` → `inventory_items`, `inventory_movements`
- `ReportsModule` → all `v_` views
