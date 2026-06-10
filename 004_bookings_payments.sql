-- =============================================================
-- JUMPCORE OS — MIGRATION 004
-- Bookings, Line Items & Payments
-- =============================================================

-- =============================================================
-- BOOKING SEQUENCES (Human-readable IDs)
-- =============================================================

CREATE SEQUENCE booking_seq START 1000 INCREMENT 1;

-- =============================================================
-- BOOKINGS
-- =============================================================

CREATE TABLE bookings (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_number       VARCHAR(20) NOT NULL UNIQUE DEFAULT ('JZ-' || nextval('booking_seq')),
  region_id            UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Customer
  customer_id          UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

  -- Status
  status               booking_status NOT NULL DEFAULT 'new_lead',
  payment_status       payment_status NOT NULL DEFAULT 'unpaid',

  -- Event details
  event_date           DATE NOT NULL,
  event_start_time     TIME NOT NULL,
  event_end_time       TIME,
  setup_time           TIME,
  collection_time      TIME,
  event_duration_hours DECIMAL(4, 1),
  event_type           VARCHAR(100),              -- 'birthday', 'school_event', 'corporate'

  -- Delivery address
  delivery_address     TEXT NOT NULL,
  delivery_suburb      VARCHAR(100),
  delivery_city        VARCHAR(100),
  delivery_province    VARCHAR(100),
  delivery_postal_code VARCHAR(10),
  delivery_latitude    DECIMAL(10, 7),
  delivery_longitude   DECIMAL(10, 7),
  delivery_notes       TEXT,
  gate_code            VARCHAR(50),
  contact_on_site      VARCHAR(100),
  contact_phone        VARCHAR(20),

  -- Financials
  subtotal             DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  discount_amount      DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  discount_reason      VARCHAR(255),
  delivery_fee         DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  vat_amount           DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  vat_rate             DECIMAL(4, 2) NOT NULL DEFAULT 15.00,   -- 15% SA VAT
  total_amount         DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  deposit_required     DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  deposit_paid         DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  balance_due          DECIMAL(12, 2) GENERATED ALWAYS AS (total_amount - deposit_paid) STORED,

  -- Assignment
  assigned_operator_id UUID REFERENCES operator_profiles(id) ON DELETE SET NULL,
  assigned_vehicle_id  UUID REFERENCES vehicles(id) ON DELETE SET NULL,

  -- Scheduling
  scheduled_delivery   TIMESTAMPTZ,
  scheduled_collection TIMESTAMPTZ,
  actual_delivery      TIMESTAMPTZ,
  actual_setup         TIMESTAMPTZ,
  actual_collection    TIMESTAMPTZ,
  actual_completed     TIMESTAMPTZ,

  -- Customer interaction
  customer_signature   TEXT,                      -- Base64 SVG or URL
  customer_rated_at    TIMESTAMPTZ,
  customer_rating      SMALLINT CHECK (customer_rating BETWEEN 1 AND 5),
  customer_review      TEXT,

  -- Internal
  internal_notes       TEXT,
  cancellation_reason  TEXT,
  cancelled_at         TIMESTAMPTZ,
  cancelled_by         UUID REFERENCES users(id) ON DELETE SET NULL,

  -- Source tracking
  source               VARCHAR(100),              -- 'website', 'whatsapp', 'phone', 'walk_in'
  referral_code        VARCHAR(50),

  -- Soft delete
  deleted_at           TIMESTAMPTZ,

  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE bookings IS 'Core booking records — one row per event booking';

-- =============================================================
-- BOOKING LINE ITEMS (Equipment per booking)
-- =============================================================

CREATE TABLE booking_line_items (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id        UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  equipment_id      UUID NOT NULL REFERENCES equipment(id) ON DELETE RESTRICT,

  -- Pricing snapshot (locked at time of booking)
  quantity          SMALLINT NOT NULL DEFAULT 1,
  unit_price        DECIMAL(10, 2) NOT NULL,
  discount_pct      DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
  line_total        DECIMAL(12, 2) NOT NULL,

  -- Notes
  special_requests  TEXT,
  setup_notes       TEXT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (booking_id, equipment_id)
);

COMMENT ON TABLE booking_line_items IS 'Individual equipment items within a booking';

-- =============================================================
-- PAYMENTS
-- =============================================================

CREATE TABLE payments (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id         UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
  customer_id        UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

  -- Payment details
  payment_type       transaction_type NOT NULL,
  method             payment_method NOT NULL,
  amount             DECIMAL(12, 2) NOT NULL,
  currency           CHAR(3) NOT NULL DEFAULT 'ZAR',

  -- Reference
  reference_number   VARCHAR(100) UNIQUE,          -- Bank ref / gateway ref
  gateway_id         VARCHAR(200),                 -- PayFast / Yoco transaction ID
  gateway_response   JSONB,

  -- Status
  is_confirmed       BOOLEAN NOT NULL DEFAULT FALSE,
  confirmed_at       TIMESTAMPTZ,
  confirmed_by       UUID REFERENCES users(id) ON DELETE SET NULL,

  -- Proof
  proof_of_payment_url TEXT,
  notes              TEXT,

  paid_at            TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE payments IS 'All payment transactions linked to bookings';

-- =============================================================
-- INVOICES
-- =============================================================

CREATE TABLE invoices (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_number   VARCHAR(30) NOT NULL UNIQUE,    -- INV-2024-0001
  booking_id       UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
  customer_id      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

  -- Financials (snapshot at generation)
  subtotal         DECIMAL(12, 2) NOT NULL,
  vat_amount       DECIMAL(12, 2) NOT NULL,
  total_amount     DECIMAL(12, 2) NOT NULL,

  -- Status
  is_paid          BOOLEAN NOT NULL DEFAULT FALSE,
  due_date         DATE,
  paid_at          TIMESTAMPTZ,

  -- Document
  pdf_url          TEXT,
  sent_at          TIMESTAMPTZ,
  sent_via         notification_channel,

  -- Notes
  notes            TEXT,
  terms            TEXT,

  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE invoices IS 'Tax invoices generated per booking';

-- =============================================================
-- QUOTATIONS
-- =============================================================

CREATE TABLE quotations (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quote_number     VARCHAR(30) NOT NULL UNIQUE,    -- QT-2024-0001
  booking_id       UUID REFERENCES bookings(id) ON DELETE SET NULL,
  customer_id      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_by       UUID REFERENCES users(id) ON DELETE SET NULL,

  -- Financials
  subtotal         DECIMAL(12, 2) NOT NULL,
  vat_amount       DECIMAL(12, 2) NOT NULL,
  total_amount     DECIMAL(12, 2) NOT NULL,

  -- Validity
  valid_until      DATE NOT NULL,
  is_accepted      BOOLEAN,
  accepted_at      TIMESTAMPTZ,
  expired_at       TIMESTAMPTZ,

  -- Document
  pdf_url          TEXT,
  sent_at          TIMESTAMPTZ,
  sent_via         notification_channel,
  notes            TEXT,

  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE quotations IS 'Price quotations sent to customers before booking confirmation';

-- =============================================================
-- BOOKING STATUS HISTORY (Full audit trail)
-- =============================================================

CREATE TABLE booking_status_history (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id   UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  from_status  booking_status,
  to_status    booking_status NOT NULL,
  changed_by   UUID REFERENCES users(id) ON DELETE SET NULL,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE booking_status_history IS 'Immutable log of every booking status transition';

-- =============================================================
-- BOOKING PHOTOS (Delivery / setup / collection evidence)
-- =============================================================

CREATE TABLE booking_photos (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id   UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  uploaded_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  photo_type   VARCHAR(50) NOT NULL,    -- 'delivery', 'setup', 'collection', 'damage'
  url          TEXT NOT NULL,
  caption      TEXT,
  taken_at     TIMESTAMPTZ,
  latitude     DECIMAL(10, 7),
  longitude    DECIMAL(10, 7),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE booking_photos IS 'Photo evidence uploaded by operators at each booking stage';
