-- =============================================================
-- JUMPCORE OS — MIGRATION 002
-- Users, Authentication & Regions
-- =============================================================

-- =============================================================
-- REGIONS
-- =============================================================

CREATE TABLE regions (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name             VARCHAR(100) NOT NULL,
  slug             sa_region NOT NULL UNIQUE,
  province         VARCHAR(100),
  city             VARCHAR(100),
  latitude         DECIMAL(10, 7),
  longitude        DECIMAL(10, 7),
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE regions IS 'South African operational regions for JumpZone';

-- =============================================================
-- USERS (All roles share this table)
-- =============================================================

CREATE TABLE users (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role                   user_role NOT NULL,
  status                 account_status NOT NULL DEFAULT 'pending_verification',

  -- Personal details
  first_name             VARCHAR(100) NOT NULL,
  last_name              VARCHAR(100) NOT NULL,
  email                  VARCHAR(255) NOT NULL UNIQUE,
  phone                  VARCHAR(20),
  whatsapp_number        VARCHAR(20),
  id_number              VARCHAR(20),                        -- SA ID number
  profile_photo_url      TEXT,

  -- Auth
  password_hash          TEXT NOT NULL,
  mfa_enabled            BOOLEAN NOT NULL DEFAULT FALSE,
  mfa_secret             TEXT,                              -- TOTP secret (encrypted)
  email_verified         BOOLEAN NOT NULL DEFAULT FALSE,
  email_verify_token     TEXT,
  password_reset_token   TEXT,
  password_reset_expires TIMESTAMPTZ,
  last_login_at          TIMESTAMPTZ,
  last_login_ip          INET,
  failed_login_attempts  SMALLINT NOT NULL DEFAULT 0,
  locked_until           TIMESTAMPTZ,

  -- Region (nullable for super_admin)
  region_id              UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Preferences
  timezone               VARCHAR(50) NOT NULL DEFAULT 'Africa/Johannesburg',
  language               VARCHAR(10) NOT NULL DEFAULT 'en',
  notification_prefs     JSONB NOT NULL DEFAULT '{}',

  -- Soft delete
  deleted_at             TIMESTAMPTZ,

  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE users IS 'All platform users — admins, managers, operators and customers';
COMMENT ON COLUMN users.notification_prefs IS 'JSON: { email: bool, sms: bool, whatsapp: bool, push: bool }';

-- =============================================================
-- REFRESH TOKENS (JWT refresh token store)
-- =============================================================

CREATE TABLE refresh_tokens (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash   TEXT NOT NULL UNIQUE,
  device_info  TEXT,
  ip_address   INET,
  expires_at   TIMESTAMPTZ NOT NULL,
  revoked_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE refresh_tokens IS 'Stores hashed JWT refresh tokens per user session';

-- =============================================================
-- AUDIT LOG (Every important action recorded)
-- =============================================================

CREATE TABLE audit_logs (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
  action       VARCHAR(100) NOT NULL,      -- e.g. 'booking.created', 'user.login'
  entity_type  VARCHAR(100),               -- e.g. 'booking', 'equipment'
  entity_id    UUID,
  old_values   JSONB,
  new_values   JSONB,
  ip_address   INET,
  user_agent   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'Immutable audit trail for all significant system events';

-- =============================================================
-- CUSTOMER PROFILES (Extended data for role = customer)
-- =============================================================

CREATE TABLE customer_profiles (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id            UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

  -- Address
  address_line1      VARCHAR(255),
  address_line2      VARCHAR(255),
  suburb             VARCHAR(100),
  city               VARCHAR(100),
  province           VARCHAR(100),
  postal_code        VARCHAR(10),
  country            VARCHAR(100) NOT NULL DEFAULT 'South Africa',
  latitude           DECIMAL(10, 7),
  longitude          DECIMAL(10, 7),
  delivery_notes     TEXT,

  -- CRM
  source             VARCHAR(100),           -- 'google', 'facebook', 'referral', etc.
  referral_code      VARCHAR(50),
  loyalty_tier       loyalty_tier NOT NULL DEFAULT 'bronze',
  loyalty_points     INTEGER NOT NULL DEFAULT 0,
  total_bookings     INTEGER NOT NULL DEFAULT 0,
  total_spent        DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  average_spend      DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  last_booking_at    TIMESTAMPTZ,

  -- Marketing
  marketing_consent  BOOLEAN NOT NULL DEFAULT FALSE,
  sms_consent        BOOLEAN NOT NULL DEFAULT FALSE,
  whatsapp_consent   BOOLEAN NOT NULL DEFAULT FALSE,
  notes              TEXT,
  tags               TEXT[],                -- ['vip', 'school', 'corporate', etc.]

  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE customer_profiles IS 'Extended CRM profile for customers';

-- =============================================================
-- OPERATOR PROFILES (Extended data for role = operator)
-- =============================================================

CREATE TABLE operator_profiles (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  employee_number       VARCHAR(50) UNIQUE,
  region_id             UUID REFERENCES regions(id) ON DELETE SET NULL,

  -- Current status
  current_status        operator_status NOT NULL DEFAULT 'offline',
  current_latitude      DECIMAL(10, 7),
  current_longitude     DECIMAL(10, 7),
  last_location_update  TIMESTAMPTZ,
  current_vehicle_id    UUID,                               -- FK added after vehicles table

  -- Employment
  employment_type       VARCHAR(50) NOT NULL DEFAULT 'full_time',  -- full_time, part_time, contractor
  date_hired            DATE,
  license_number        VARCHAR(50),
  license_expiry        DATE,
  pdp_number            VARCHAR(50),                        -- Professional Driver Permit (SA)
  pdp_expiry            DATE,

  -- Performance
  total_deliveries      INTEGER NOT NULL DEFAULT 0,
  average_rating        DECIMAL(3, 2),
  on_time_percentage    DECIMAL(5, 2),

  -- Emergency contact
  emergency_name        VARCHAR(100),
  emergency_phone       VARCHAR(20),
  emergency_relation    VARCHAR(50),

  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE operator_profiles IS 'Extended profile for delivery operators';

-- =============================================================
-- OPERATOR LOCATION HISTORY (GPS breadcrumbs)
-- =============================================================

CREATE TABLE operator_location_history (
  id           BIGSERIAL PRIMARY KEY,
  operator_id  UUID NOT NULL REFERENCES operator_profiles(id) ON DELETE CASCADE,
  latitude     DECIMAL(10, 7) NOT NULL,
  longitude    DECIMAL(10, 7) NOT NULL,
  speed_kmh    DECIMAL(5, 1),
  heading      DECIMAL(5, 1),
  accuracy_m   DECIMAL(6, 1),
  recorded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE operator_location_history IS 'GPS breadcrumb trail — partitioned by month in production';
