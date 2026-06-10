-- =============================================================
-- JUMPCORE OS — MIGRATION 005
-- Inventory, Dispatch, Notifications & Documents
-- =============================================================

-- =============================================================
-- INVENTORY CATEGORIES
-- =============================================================

CREATE TABLE inventory_categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE inventory_categories IS 'Categories for consumable inventory items';

-- =============================================================
-- INVENTORY ITEMS (Consumables, Chemicals, Spare Parts)
-- =============================================================

CREATE TABLE inventory_items (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id       UUID REFERENCES inventory_categories(id) ON DELETE SET NULL,
  region_id         UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Identity
  sku               VARCHAR(50) NOT NULL UNIQUE,
  name              VARCHAR(200) NOT NULL,
  description       TEXT,
  unit_of_measure   VARCHAR(30) NOT NULL DEFAULT 'unit',   -- 'litre', 'kg', 'roll', 'unit'

  -- Stock levels
  quantity_in_stock DECIMAL(12, 2) NOT NULL DEFAULT 0,
  reorder_level     DECIMAL(12, 2) NOT NULL DEFAULT 5,
  reorder_quantity  DECIMAL(12, 2) NOT NULL DEFAULT 20,
  max_stock_level   DECIMAL(12, 2),

  -- Pricing
  unit_cost         DECIMAL(10, 2),
  supplier_name     VARCHAR(200),
  supplier_contact  VARCHAR(100),
  supplier_sku      VARCHAR(100),

  -- Status
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  notes             TEXT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE inventory_items IS 'Consumable inventory: chemicals, parts, fuel, packaging etc.';

-- =============================================================
-- INVENTORY MOVEMENTS (Stock in / out / adjustments)
-- =============================================================

CREATE TABLE inventory_movements (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id         UUID NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  region_id       UUID REFERENCES regions(id) ON DELETE SET NULL,
  movement_type   inventory_movement NOT NULL,
  quantity        DECIMAL(12, 2) NOT NULL,
  unit_cost       DECIMAL(10, 2),
  total_cost      DECIMAL(12, 2),
  reference_type  VARCHAR(50),          -- 'booking', 'maintenance', 'purchase', 'adjustment'
  reference_id    UUID,                 -- Links to booking or maintenance ticket
  notes           TEXT,
  performed_by    UUID REFERENCES users(id) ON DELETE SET NULL,
  supplier_ref    VARCHAR(100),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE inventory_movements IS 'Every stock movement — receipts, consumption and adjustments';

-- =============================================================
-- DISPATCH SCHEDULES
-- =============================================================

CREATE TABLE dispatch_schedules (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id           UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  operator_id          UUID NOT NULL REFERENCES operator_profiles(id) ON DELETE RESTRICT,
  vehicle_id           UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  region_id            UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Schedule
  scheduled_departure  TIMESTAMPTZ NOT NULL,
  scheduled_arrival    TIMESTAMPTZ,
  actual_departure     TIMESTAMPTZ,
  actual_arrival       TIMESTAMPTZ,

  -- Route
  origin_address       TEXT,
  origin_latitude      DECIMAL(10, 7),
  origin_longitude     DECIMAL(10, 7),
  destination_address  TEXT,
  dest_latitude        DECIMAL(10, 7),
  dest_longitude       DECIMAL(10, 7),
  route_distance_km    DECIMAL(8, 2),
  estimated_duration   INTERVAL,

  -- Job type
  job_type             VARCHAR(30) NOT NULL DEFAULT 'delivery',  -- 'delivery', 'collection', 'both'

  -- Status
  is_completed         BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at         TIMESTAMPTZ,
  notes                TEXT,

  -- Assigned by
  dispatched_by        UUID REFERENCES users(id) ON DELETE SET NULL,
  dispatched_at        TIMESTAMPTZ,

  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE dispatch_schedules IS 'Operator job assignments and delivery scheduling';

-- =============================================================
-- OPERATOR CHECKLISTS (Pre/post delivery)
-- =============================================================

CREATE TABLE operator_checklists (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id    UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  operator_id   UUID NOT NULL REFERENCES operator_profiles(id) ON DELETE RESTRICT,
  checklist_type VARCHAR(30) NOT NULL,     -- 'pre_delivery', 'post_setup', 'pre_collection', 'post_collection'

  -- Checklist items stored as JSONB array
  -- [{ item: "Castle inflated", checked: true, notes: "" }, ...]
  items         JSONB NOT NULL DEFAULT '[]',
  is_complete   BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at  TIMESTAMPTZ,

  -- Signature
  signature_url TEXT,
  signed_by     VARCHAR(100),            -- Customer name who signed

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE operator_checklists IS 'Pre/post delivery checklists completed by operators on mobile';

-- =============================================================
-- NOTIFICATIONS
-- =============================================================

CREATE TABLE notifications (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel          notification_channel NOT NULL,

  -- Content
  title            VARCHAR(255) NOT NULL,
  body             TEXT NOT NULL,
  data             JSONB,                   -- Extra payload (booking_id etc.)
  template_key     VARCHAR(100),            -- 'booking_confirmed', 'operator_assigned'

  -- Status
  is_read          BOOLEAN NOT NULL DEFAULT FALSE,
  read_at          TIMESTAMPTZ,
  is_sent          BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at          TIMESTAMPTZ,
  failed_at        TIMESTAMPTZ,
  failure_reason   TEXT,
  retry_count      SMALLINT NOT NULL DEFAULT 0,

  -- Reference
  entity_type      VARCHAR(100),
  entity_id        UUID,

  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE notifications IS 'All outbound notifications — email, SMS, WhatsApp, push';

-- =============================================================
-- DOCUMENTS
-- =============================================================

CREATE TABLE documents (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_type    document_type NOT NULL,
  name             VARCHAR(255) NOT NULL,
  description      TEXT,

  -- Ownership
  entity_type      VARCHAR(100),           -- 'booking', 'customer', 'equipment', 'vehicle'
  entity_id        UUID,

  -- File
  file_url         TEXT NOT NULL,          -- S3 URL
  file_key         TEXT NOT NULL,          -- S3 key
  file_size_bytes  BIGINT,
  mime_type        VARCHAR(100),
  version          SMALLINT NOT NULL DEFAULT 1,

  -- Access
  is_public        BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at       TIMESTAMPTZ,

  uploaded_by      UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE documents IS 'All documents: invoices, contracts, delivery notes, inspection reports';

-- =============================================================
-- FINANCIAL TRANSACTIONS (General ledger)
-- =============================================================

CREATE TABLE financial_transactions (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  region_id        UUID REFERENCES regions(id) ON DELETE SET NULL,
  transaction_type transaction_type NOT NULL,

  -- Reference
  reference_id     UUID,                   -- booking_id, payment_id, etc.
  reference_type   VARCHAR(50),

  -- Amounts
  amount           DECIMAL(12, 2) NOT NULL,
  vat_amount       DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  net_amount       DECIMAL(12, 2) NOT NULL,
  currency         CHAR(3) NOT NULL DEFAULT 'ZAR',

  -- Classification
  is_income        BOOLEAN NOT NULL,
  category         VARCHAR(100),
  description      TEXT NOT NULL,

  -- Accounting
  recorded_by      UUID REFERENCES users(id) ON DELETE SET NULL,
  transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,

  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE financial_transactions IS 'General ledger — every financial movement across the business';

-- =============================================================
-- REVIEWS
-- =============================================================

CREATE TABLE reviews (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id   UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
  customer_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  operator_id  UUID REFERENCES operator_profiles(id) ON DELETE SET NULL,

  overall_rating    SMALLINT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
  equipment_rating  SMALLINT CHECK (equipment_rating BETWEEN 1 AND 5),
  service_rating    SMALLINT CHECK (service_rating BETWEEN 1 AND 5),
  punctuality_rating SMALLINT CHECK (punctuality_rating BETWEEN 1 AND 5),

  title        VARCHAR(255),
  body         TEXT,
  is_public    BOOLEAN NOT NULL DEFAULT TRUE,
  is_verified  BOOLEAN NOT NULL DEFAULT TRUE,

  responded_at TIMESTAMPTZ,
  response     TEXT,
  responded_by UUID REFERENCES users(id) ON DELETE SET NULL,

  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE reviews IS 'Customer reviews linked to completed bookings';
