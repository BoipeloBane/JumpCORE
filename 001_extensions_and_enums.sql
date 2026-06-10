-- =============================================================
-- JUMPCORE OS — MIGRATION 001
-- Extensions & Enums
-- =============================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";        -- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";         -- Password hashing
CREATE EXTENSION IF NOT EXISTS "pg_trgm";          -- Fuzzy text search
CREATE EXTENSION IF NOT EXISTS "postgis";          -- GPS / geolocation (optional, graceful fallback)
CREATE EXTENSION IF NOT EXISTS "btree_gin";        -- Composite GIN indexes

-- =============================================================
-- ENUMS
-- =============================================================

-- User roles across the platform
CREATE TYPE user_role AS ENUM (
  'super_admin',
  'regional_manager',
  'operator',
  'customer'
);

-- User account status
CREATE TYPE account_status AS ENUM (
  'active',
  'inactive',
  'suspended',
  'pending_verification'
);

-- Booking lifecycle statuses
CREATE TYPE booking_status AS ENUM (
  'new_lead',
  'quote_sent',
  'awaiting_payment',
  'confirmed',
  'scheduled',
  'in_delivery',
  'setup_complete',
  'collection_pending',
  'completed',
  'cancelled'
);

-- Payment statuses
CREATE TYPE payment_status AS ENUM (
  'unpaid',
  'deposit_paid',
  'partially_paid',
  'fully_paid',
  'refunded',
  'failed'
);

-- Payment methods
CREATE TYPE payment_method AS ENUM (
  'eft',
  'cash',
  'card',
  'yoco',
  'payfast',
  'snapscan',
  'zapper'
);

-- Equipment statuses
CREATE TYPE equipment_status AS ENUM (
  'available',
  'reserved',
  'in_use',
  'in_maintenance',
  'damaged',
  'retired'
);

-- Equipment condition ratings
CREATE TYPE equipment_condition AS ENUM (
  'excellent',
  'good',
  'fair',
  'poor',
  'write_off'
);

-- Equipment category types
CREATE TYPE equipment_type AS ENUM (
  'jumping_castle',
  'water_slide',
  'obstacle_course',
  'soft_play',
  'party_chair',
  'party_table',
  'generator',
  'blower',
  'combo_unit',
  'other'
);

-- Operator job statuses
CREATE TYPE operator_status AS ENUM (
  'available',
  'en_route',
  'on_site',
  'returning',
  'offline',
  'on_leave'
);

-- Maintenance types
CREATE TYPE maintenance_type AS ENUM (
  'cleaning',
  'repair',
  'inspection',
  'servicing',
  'patch_work',
  'replacement'
);

-- Maintenance ticket statuses
CREATE TYPE maintenance_status AS ENUM (
  'open',
  'in_progress',
  'awaiting_parts',
  'completed',
  'cancelled'
);

-- Vehicle types
CREATE TYPE vehicle_type AS ENUM (
  'van',
  'truck',
  'trailer',
  'bakkie'
);

-- Vehicle statuses
CREATE TYPE vehicle_status AS ENUM (
  'available',
  'in_use',
  'in_service',
  'damaged',
  'retired'
);

-- Notification channels
CREATE TYPE notification_channel AS ENUM (
  'email',
  'sms',
  'whatsapp',
  'push',
  'in_app'
);

-- Document types
CREATE TYPE document_type AS ENUM (
  'contract',
  'invoice',
  'quotation',
  'delivery_note',
  'inspection_report',
  'payment_proof',
  'id_document',
  'insurance_certificate',
  'photo'
);

-- Transaction types
CREATE TYPE transaction_type AS ENUM (
  'booking_deposit',
  'booking_payment',
  'booking_balance',
  'refund',
  'expense_fuel',
  'expense_maintenance',
  'expense_staff',
  'expense_other'
);

-- South African regions
CREATE TYPE sa_region AS ENUM (
  'johannesburg',
  'pretoria',
  'cape_town',
  'durban',
  'bloemfontein',
  'polokwane',
  'rustenburg',
  'nelspruit',
  'east_london',
  'kimberley',
  'port_elizabeth',
  'other'
);

-- Loyalty tiers
CREATE TYPE loyalty_tier AS ENUM (
  'bronze',
  'silver',
  'gold',
  'platinum'
);

-- Inventory movement types
CREATE TYPE inventory_movement AS ENUM (
  'stock_in',
  'stock_out',
  'adjustment',
  'write_off'
);
