-- =============================================================
-- JUMPCORE OS — MIGRATION 003
-- Equipment, Vehicles & Asset Management
-- =============================================================

-- =============================================================
-- EQUIPMENT CATEGORIES
-- =============================================================

CREATE TABLE equipment_categories (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         VARCHAR(100) NOT NULL,
  slug         VARCHAR(100) NOT NULL UNIQUE,
  type         equipment_type NOT NULL,
  description  TEXT,
  icon_url     TEXT,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE equipment_categories IS 'Categories of rental equipment (e.g. Jumping Castles, Water Slides)';

-- =============================================================
-- EQUIPMENT (Individual Assets)
-- =============================================================

CREATE TABLE equipment (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id          VARCHAR(30) NOT NULL UNIQUE,     -- Human readable: EQ-001
  category_id       UUID NOT NULL REFERENCES equipment_categories(id) ON DELETE RESTRICT,
  region_id         UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Identity
  name              VARCHAR(200) NOT NULL,
  description       TEXT,
  serial_number     VARCHAR(100) UNIQUE,
  qr_code           VARCHAR(100) UNIQUE,              -- QR payload string
  barcode           VARCHAR(100) UNIQUE,

  -- Status & Condition
  status            equipment_status NOT NULL DEFAULT 'available',
  condition         equipment_condition NOT NULL DEFAULT 'good',
  condition_notes   TEXT,

  -- Financials
  purchase_date     DATE,
  purchase_price    DECIMAL(12, 2),
  current_value     DECIMAL(12, 2),
  replacement_cost  DECIMAL(12, 2),
  depreciation_pct  DECIMAL(5, 2) NOT NULL DEFAULT 20.00,  -- annual %

  -- Physical details
  dimensions_cm     JSONB,                            -- { length, width, height }
  weight_kg         DECIMAL(8, 2),
  colour            VARCHAR(100),
  capacity_persons  SMALLINT,
  age_min           SMALLINT,
  age_max           SMALLINT,
  requires_blower   BOOLEAN NOT NULL DEFAULT TRUE,
  requires_water    BOOLEAN NOT NULL DEFAULT FALSE,
  requires_power    BOOLEAN NOT NULL DEFAULT FALSE,
  space_required_m2 DECIMAL(8, 2),

  -- Location tracking
  current_location  VARCHAR(255),
  current_latitude  DECIMAL(10, 7),
  current_longitude DECIMAL(10, 7),

  -- Maintenance scheduling
  last_service_date DATE,
  next_service_date DATE,
  service_interval_days SMALLINT NOT NULL DEFAULT 30,
  total_hire_days   INTEGER NOT NULL DEFAULT 0,

  -- Media
  primary_photo_url TEXT,
  photo_urls        TEXT[],
  manual_url        TEXT,

  -- Pricing (base rates, can be overridden per booking)
  daily_rate        DECIMAL(10, 2),
  weekend_rate      DECIMAL(10, 2),
  deposit_amount    DECIMAL(10, 2),

  -- Notes
  internal_notes    TEXT,
  tags              TEXT[],

  -- Soft delete
  deleted_at        TIMESTAMPTZ,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE equipment IS 'Individual equipment assets — each row is a physical item with a unique asset ID';

-- =============================================================
-- EQUIPMENT MAINTENANCE LOG
-- =============================================================

CREATE TABLE maintenance_tickets (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_number     VARCHAR(30) NOT NULL UNIQUE,       -- MT-0001
  equipment_id      UUID NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  region_id         UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Details
  maintenance_type  maintenance_type NOT NULL,
  status            maintenance_status NOT NULL DEFAULT 'open',
  priority          SMALLINT NOT NULL DEFAULT 2,       -- 1=critical, 2=normal, 3=low
  title             VARCHAR(255) NOT NULL,
  description       TEXT,
  root_cause        TEXT,
  resolution_notes  TEXT,

  -- Assignment
  assigned_to       UUID REFERENCES users(id) ON DELETE SET NULL,
  reported_by       UUID REFERENCES users(id) ON DELETE SET NULL,

  -- Scheduling
  scheduled_date    DATE,
  started_at        TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  estimated_hours   DECIMAL(5, 2),
  actual_hours      DECIMAL(5, 2),

  -- Cost tracking
  labour_cost       DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  parts_cost        DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  total_cost        DECIMAL(10, 2) GENERATED ALWAYS AS (labour_cost + parts_cost) STORED,

  -- Media
  before_photos     TEXT[],
  after_photos      TEXT[],

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE maintenance_tickets IS 'Maintenance, repair and cleaning tickets for equipment';

-- =============================================================
-- VEHICLES
-- =============================================================

CREATE TABLE vehicles (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  region_id            UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Identity
  registration_number  VARCHAR(20) NOT NULL UNIQUE,    -- e.g. GP 123-456
  make                 VARCHAR(100) NOT NULL,
  model                VARCHAR(100) NOT NULL,
  year                 SMALLINT,
  colour               VARCHAR(50),
  vehicle_type         vehicle_type NOT NULL,
  status               vehicle_status NOT NULL DEFAULT 'available',

  -- Capacity
  payload_kg           DECIMAL(8, 2),
  volume_m3            DECIMAL(8, 2),
  tow_capacity_kg      DECIMAL(8, 2),

  -- Documentation
  license_disc_expiry  DATE,
  roadworthy_expiry    DATE,
  insurance_provider   VARCHAR(100),
  insurance_policy     VARCHAR(100),
  insurance_expiry     DATE,

  -- Fuel & Mileage
  fuel_type            VARCHAR(20) NOT NULL DEFAULT 'diesel',
  current_mileage_km   INTEGER NOT NULL DEFAULT 0,
  last_service_km      INTEGER,
  next_service_km      INTEGER,
  last_service_date    DATE,
  next_service_date    DATE,

  -- GPS
  current_latitude     DECIMAL(10, 7),
  current_longitude    DECIMAL(10, 7),
  last_location_update TIMESTAMPTZ,

  -- Media & Notes
  photo_url            TEXT,
  notes                TEXT,

  -- Soft delete
  deleted_at           TIMESTAMPTZ,

  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE vehicles IS 'Company fleet — vans, trucks and trailers';

-- =============================================================
-- VEHICLE FUEL LOG
-- =============================================================

CREATE TABLE vehicle_fuel_log (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id    UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  operator_id   UUID REFERENCES operator_profiles(id) ON DELETE SET NULL,
  litres        DECIMAL(8, 2) NOT NULL,
  cost_per_litre DECIMAL(6, 2),
  total_cost    DECIMAL(10, 2),
  mileage_at_fill INTEGER,
  station_name  VARCHAR(100),
  receipt_url   TEXT,
  filled_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- VEHICLE SERVICE LOG
-- =============================================================

CREATE TABLE vehicle_service_log (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id      UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  service_type    VARCHAR(100) NOT NULL,         -- 'oil_change', 'tyres', 'full_service'
  mileage_at_service INTEGER,
  service_provider VARCHAR(200),
  cost            DECIMAL(10, 2),
  notes           TEXT,
  invoice_url     TEXT,
  serviced_at     DATE NOT NULL,
  next_service_km INTEGER,
  next_service_date DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- Add FK from operator_profiles to vehicles (circular — deferred)
-- =============================================================

ALTER TABLE operator_profiles
  ADD CONSTRAINT fk_operator_current_vehicle
  FOREIGN KEY (current_vehicle_id)
  REFERENCES vehicles(id)
  ON DELETE SET NULL;
