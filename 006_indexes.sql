-- =============================================================
-- JUMPCORE OS — MIGRATION 006
-- Indexes — Performance Optimization
-- =============================================================
-- Designed to handle millions of records efficiently.
-- All foreign keys are indexed. Critical query paths get
-- composite indexes. GIN indexes for JSONB and array columns.
-- Text search uses pg_trgm for fuzzy matching.
-- =============================================================

-- =============================================================
-- USERS
-- =============================================================
CREATE INDEX idx_users_email           ON users (email);
CREATE INDEX idx_users_role            ON users (role);
CREATE INDEX idx_users_status          ON users (status);
CREATE INDEX idx_users_region          ON users (region_id);
CREATE INDEX idx_users_deleted         ON users (deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_last_login      ON users (last_login_at DESC NULLS LAST);

-- Fuzzy search on name
CREATE INDEX idx_users_first_name_trgm ON users USING GIN (first_name gin_trgm_ops);
CREATE INDEX idx_users_last_name_trgm  ON users USING GIN (last_name gin_trgm_ops);

-- =============================================================
-- REFRESH TOKENS
-- =============================================================
CREATE INDEX idx_refresh_tokens_user      ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_hash      ON refresh_tokens (token_hash);
CREATE INDEX idx_refresh_tokens_expires   ON refresh_tokens (expires_at);

-- =============================================================
-- AUDIT LOGS
-- =============================================================
CREATE INDEX idx_audit_user          ON audit_logs (user_id);
CREATE INDEX idx_audit_entity        ON audit_logs (entity_type, entity_id);
CREATE INDEX idx_audit_action        ON audit_logs (action);
CREATE INDEX idx_audit_created       ON audit_logs (created_at DESC);

-- =============================================================
-- CUSTOMER PROFILES
-- =============================================================
CREATE INDEX idx_customer_user        ON customer_profiles (user_id);
CREATE INDEX idx_customer_tier        ON customer_profiles (loyalty_tier);
CREATE INDEX idx_customer_tags        ON customer_profiles USING GIN (tags);
CREATE INDEX idx_customer_last_booking ON customer_profiles (last_booking_at DESC NULLS LAST);
CREATE INDEX idx_customer_total_spent ON customer_profiles (total_spent DESC);

-- =============================================================
-- OPERATOR PROFILES
-- =============================================================
CREATE INDEX idx_operator_user        ON operator_profiles (user_id);
CREATE INDEX idx_operator_region      ON operator_profiles (region_id);
CREATE INDEX idx_operator_status      ON operator_profiles (current_status);
CREATE INDEX idx_operator_vehicle     ON operator_profiles (current_vehicle_id);

-- =============================================================
-- OPERATOR LOCATION HISTORY
-- Partitioning recommended in production (by month)
-- =============================================================
CREATE INDEX idx_location_operator    ON operator_location_history (operator_id);
CREATE INDEX idx_location_recorded    ON operator_location_history (recorded_at DESC);
CREATE INDEX idx_location_operator_time ON operator_location_history (operator_id, recorded_at DESC);

-- =============================================================
-- EQUIPMENT
-- =============================================================
CREATE INDEX idx_equipment_asset_id   ON equipment (asset_id);
CREATE INDEX idx_equipment_category   ON equipment (category_id);
CREATE INDEX idx_equipment_region     ON equipment (region_id);
CREATE INDEX idx_equipment_status     ON equipment (status);
CREATE INDEX idx_equipment_condition  ON equipment (condition);
CREATE INDEX idx_equipment_deleted    ON equipment (deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_equipment_service    ON equipment (next_service_date) WHERE next_service_date IS NOT NULL;
CREATE INDEX idx_equipment_tags       ON equipment USING GIN (tags);

-- Fuzzy name search
CREATE INDEX idx_equipment_name_trgm  ON equipment USING GIN (name gin_trgm_ops);

-- Composite: available equipment by region (most common query)
CREATE INDEX idx_equipment_region_status ON equipment (region_id, status)
  WHERE deleted_at IS NULL;

-- =============================================================
-- MAINTENANCE TICKETS
-- =============================================================
CREATE INDEX idx_maintenance_equipment   ON maintenance_tickets (equipment_id);
CREATE INDEX idx_maintenance_status      ON maintenance_tickets (status);
CREATE INDEX idx_maintenance_type        ON maintenance_tickets (maintenance_type);
CREATE INDEX idx_maintenance_assigned    ON maintenance_tickets (assigned_to);
CREATE INDEX idx_maintenance_scheduled   ON maintenance_tickets (scheduled_date);
CREATE INDEX idx_maintenance_priority    ON maintenance_tickets (priority, status);

-- =============================================================
-- VEHICLES
-- =============================================================
CREATE INDEX idx_vehicles_region      ON vehicles (region_id);
CREATE INDEX idx_vehicles_status      ON vehicles (status);
CREATE INDEX idx_vehicles_type        ON vehicles (vehicle_type);
CREATE INDEX idx_vehicles_deleted     ON vehicles (deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_vehicles_reg_trgm    ON vehicles USING GIN (registration_number gin_trgm_ops);

-- =============================================================
-- BOOKINGS — Most critical table, most indexes
-- =============================================================
CREATE INDEX idx_bookings_number      ON bookings (booking_number);
CREATE INDEX idx_bookings_customer    ON bookings (customer_id);
CREATE INDEX idx_bookings_region      ON bookings (region_id);
CREATE INDEX idx_bookings_status      ON bookings (status);
CREATE INDEX idx_bookings_payment     ON bookings (payment_status);
CREATE INDEX idx_bookings_operator    ON bookings (assigned_operator_id);
CREATE INDEX idx_bookings_vehicle     ON bookings (assigned_vehicle_id);
CREATE INDEX idx_bookings_event_date  ON bookings (event_date);
CREATE INDEX idx_bookings_deleted     ON bookings (deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_bookings_created     ON bookings (created_at DESC);
CREATE INDEX idx_bookings_source      ON bookings (source);

-- Composite: Today's bookings by region (dashboard query)
CREATE INDEX idx_bookings_date_region ON bookings (event_date, region_id, status)
  WHERE deleted_at IS NULL;

-- Composite: Active bookings per operator
CREATE INDEX idx_bookings_operator_active ON bookings (assigned_operator_id, status, event_date)
  WHERE deleted_at IS NULL AND status NOT IN ('completed', 'cancelled');

-- Fuzzy search on address
CREATE INDEX idx_bookings_address_trgm ON bookings USING GIN (delivery_address gin_trgm_ops);

-- =============================================================
-- BOOKING LINE ITEMS
-- =============================================================
CREATE INDEX idx_line_items_booking   ON booking_line_items (booking_id);
CREATE INDEX idx_line_items_equipment ON booking_line_items (equipment_id);

-- =============================================================
-- PAYMENTS
-- =============================================================
CREATE INDEX idx_payments_booking     ON payments (booking_id);
CREATE INDEX idx_payments_customer    ON payments (customer_id);
CREATE INDEX idx_payments_type        ON payments (payment_type);
CREATE INDEX idx_payments_confirmed   ON payments (is_confirmed, paid_at);
CREATE INDEX idx_payments_ref         ON payments (reference_number) WHERE reference_number IS NOT NULL;

-- =============================================================
-- INVOICES
-- =============================================================
CREATE INDEX idx_invoices_booking     ON invoices (booking_id);
CREATE INDEX idx_invoices_customer    ON invoices (customer_id);
CREATE INDEX idx_invoices_paid        ON invoices (is_paid, due_date);

-- =============================================================
-- QUOTATIONS
-- =============================================================
CREATE INDEX idx_quotations_booking   ON quotations (booking_id);
CREATE INDEX idx_quotations_customer  ON quotations (customer_id);
CREATE INDEX idx_quotations_valid     ON quotations (valid_until) WHERE is_accepted IS NULL;

-- =============================================================
-- BOOKING STATUS HISTORY
-- =============================================================
CREATE INDEX idx_status_history_booking  ON booking_status_history (booking_id);
CREATE INDEX idx_status_history_created  ON booking_status_history (created_at DESC);

-- =============================================================
-- BOOKING PHOTOS
-- =============================================================
CREATE INDEX idx_photos_booking       ON booking_photos (booking_id);
CREATE INDEX idx_photos_type          ON booking_photos (photo_type);

-- =============================================================
-- INVENTORY
-- =============================================================
CREATE INDEX idx_inventory_category   ON inventory_items (category_id);
CREATE INDEX idx_inventory_region     ON inventory_items (region_id);
CREATE INDEX idx_inventory_sku        ON inventory_items (sku);
CREATE INDEX idx_inventory_low_stock  ON inventory_items (quantity_in_stock, reorder_level)
  WHERE is_active = TRUE;
CREATE INDEX idx_inventory_name_trgm  ON inventory_items USING GIN (name gin_trgm_ops);

-- =============================================================
-- INVENTORY MOVEMENTS
-- =============================================================
CREATE INDEX idx_inv_movements_item   ON inventory_movements (item_id);
CREATE INDEX idx_inv_movements_type   ON inventory_movements (movement_type);
CREATE INDEX idx_inv_movements_ref    ON inventory_movements (reference_type, reference_id);
CREATE INDEX idx_inv_movements_date   ON inventory_movements (created_at DESC);

-- =============================================================
-- DISPATCH SCHEDULES
-- =============================================================
CREATE INDEX idx_dispatch_booking     ON dispatch_schedules (booking_id);
CREATE INDEX idx_dispatch_operator    ON dispatch_schedules (operator_id);
CREATE INDEX idx_dispatch_vehicle     ON dispatch_schedules (vehicle_id);
CREATE INDEX idx_dispatch_scheduled   ON dispatch_schedules (scheduled_departure);
CREATE INDEX idx_dispatch_incomplete  ON dispatch_schedules (is_completed, scheduled_departure)
  WHERE is_completed = FALSE;

-- =============================================================
-- NOTIFICATIONS
-- =============================================================
CREATE INDEX idx_notifications_user   ON notifications (user_id);
CREATE INDEX idx_notifications_unread ON notifications (user_id, is_read, created_at DESC)
  WHERE is_read = FALSE;
CREATE INDEX idx_notifications_unsent ON notifications (is_sent, created_at)
  WHERE is_sent = FALSE AND failed_at IS NULL;
CREATE INDEX idx_notifications_entity ON notifications (entity_type, entity_id);

-- =============================================================
-- DOCUMENTS
-- =============================================================
CREATE INDEX idx_documents_entity     ON documents (entity_type, entity_id);
CREATE INDEX idx_documents_type       ON documents (document_type);
CREATE INDEX idx_documents_uploader   ON documents (uploaded_by);

-- =============================================================
-- FINANCIAL TRANSACTIONS
-- =============================================================
CREATE INDEX idx_finance_region       ON financial_transactions (region_id);
CREATE INDEX idx_finance_type         ON financial_transactions (transaction_type);
CREATE INDEX idx_finance_date         ON financial_transactions (transaction_date DESC);
CREATE INDEX idx_finance_income       ON financial_transactions (is_income, transaction_date);
CREATE INDEX idx_finance_ref          ON financial_transactions (reference_type, reference_id);

-- =============================================================
-- REVIEWS
-- =============================================================
CREATE INDEX idx_reviews_booking      ON reviews (booking_id);
CREATE INDEX idx_reviews_customer     ON reviews (customer_id);
CREATE INDEX idx_reviews_operator     ON reviews (operator_id);
CREATE INDEX idx_reviews_rating       ON reviews (overall_rating);
CREATE INDEX idx_reviews_public       ON reviews (is_public, created_at DESC)
  WHERE is_public = TRUE;
