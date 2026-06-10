-- =============================================================
-- JUMPCORE OS — MIGRATION 007
-- Functions, Triggers & Views
-- =============================================================

-- =============================================================
-- UTILITY: Auto-update updated_at timestamp
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'users', 'regions', 'customer_profiles', 'operator_profiles',
    'equipment', 'maintenance_tickets', 'vehicles',
    'bookings', 'booking_line_items', 'payments', 'invoices',
    'quotations', 'inventory_items', 'dispatch_schedules',
    'operator_checklists', 'reviews'
  ])
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%s_updated_at
       BEFORE UPDATE ON %s
       FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at()',
      t, t
    );
  END LOOP;
END;
$$;

-- =============================================================
-- TRIGGER: Log booking status changes automatically
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_log_booking_status()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO booking_status_history (booking_id, from_status, to_status)
    VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_booking_status_history
  AFTER UPDATE OF status ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION trigger_log_booking_status();

-- =============================================================
-- TRIGGER: Recalculate booking totals on line item change
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_recalculate_booking_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_subtotal     DECIMAL(12, 2);
  v_vat_rate     DECIMAL(4, 2);
  v_vat_amount   DECIMAL(12, 2);
  v_total        DECIMAL(12, 2);
BEGIN
  -- Sum all line items for this booking
  SELECT COALESCE(SUM(line_total), 0)
  INTO v_subtotal
  FROM booking_line_items
  WHERE booking_id = COALESCE(NEW.booking_id, OLD.booking_id);

  -- Get VAT rate from booking
  SELECT vat_rate INTO v_vat_rate
  FROM bookings
  WHERE id = COALESCE(NEW.booking_id, OLD.booking_id);

  v_vat_amount := ROUND(v_subtotal * (v_vat_rate / 100), 2);
  v_total := v_subtotal + v_vat_amount;

  UPDATE bookings
  SET
    subtotal   = v_subtotal,
    vat_amount = v_vat_amount,
    total_amount = v_total
  WHERE id = COALESCE(NEW.booking_id, OLD.booking_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_booking_line_item_totals
  AFTER INSERT OR UPDATE OR DELETE ON booking_line_items
  FOR EACH ROW
  EXECUTE FUNCTION trigger_recalculate_booking_totals();

-- =============================================================
-- TRIGGER: Update customer profile stats after booking
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_update_customer_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    UPDATE customer_profiles
    SET
      total_bookings   = total_bookings + 1,
      total_spent      = total_spent + NEW.total_amount,
      average_spend    = (total_spent + NEW.total_amount) / (total_bookings + 1),
      last_booking_at  = NOW(),
      loyalty_tier     = CASE
        WHEN (total_spent + NEW.total_amount) >= 50000  THEN 'platinum'
        WHEN (total_spent + NEW.total_amount) >= 20000  THEN 'gold'
        WHEN (total_spent + NEW.total_amount) >= 5000   THEN 'silver'
        ELSE 'bronze'
      END
    WHERE user_id = NEW.customer_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customer_stats
  AFTER UPDATE OF status ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_customer_stats();

-- =============================================================
-- TRIGGER: Update equipment status when booking changes
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_sync_equipment_status()
RETURNS TRIGGER AS $$
BEGIN
  -- When booking goes IN DELIVERY → mark equipment as 'in_use'
  IF NEW.status = 'in_delivery' AND OLD.status != 'in_delivery' THEN
    UPDATE equipment e
    SET status = 'in_use'
    FROM booking_line_items bli
    WHERE bli.booking_id = NEW.id AND bli.equipment_id = e.id;

  -- When booking COMPLETED or CANCELLED → return to available
  ELSIF NEW.status IN ('completed', 'cancelled')
    AND OLD.status NOT IN ('completed', 'cancelled') THEN
    UPDATE equipment e
    SET status = 'available'
    FROM booking_line_items bli
    WHERE bli.booking_id = NEW.id
      AND bli.equipment_id = e.id
      AND e.status = 'in_use';

  -- When booking CONFIRMED → mark as reserved
  ELSIF NEW.status = 'confirmed' AND OLD.status != 'confirmed' THEN
    UPDATE equipment e
    SET status = 'reserved'
    FROM booking_line_items bli
    WHERE bli.booking_id = NEW.id
      AND bli.equipment_id = e.id
      AND e.status = 'available';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_equipment_status_sync
  AFTER UPDATE OF status ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION trigger_sync_equipment_status();

-- =============================================================
-- TRIGGER: Update inventory stock on movement
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_apply_inventory_movement()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.movement_type = 'stock_in' THEN
    UPDATE inventory_items
    SET quantity_in_stock = quantity_in_stock + NEW.quantity
    WHERE id = NEW.item_id;

  ELSIF NEW.movement_type IN ('stock_out', 'write_off') THEN
    UPDATE inventory_items
    SET quantity_in_stock = GREATEST(0, quantity_in_stock - NEW.quantity)
    WHERE id = NEW.item_id;

  ELSIF NEW.movement_type = 'adjustment' THEN
    -- quantity can be positive or negative for adjustments
    UPDATE inventory_items
    SET quantity_in_stock = GREATEST(0, quantity_in_stock + NEW.quantity)
    WHERE id = NEW.item_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_movement
  AFTER INSERT ON inventory_movements
  FOR EACH ROW
  EXECUTE FUNCTION trigger_apply_inventory_movement();

-- =============================================================
-- TRIGGER: Update operator performance stats after review
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_update_operator_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE operator_profiles
  SET average_rating = (
    SELECT ROUND(AVG(overall_rating)::NUMERIC, 2)
    FROM reviews
    WHERE operator_id = NEW.operator_id
  )
  WHERE id = NEW.operator_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_operator_rating
  AFTER INSERT OR UPDATE ON reviews
  FOR EACH ROW
  WHEN (NEW.operator_id IS NOT NULL)
  EXECUTE FUNCTION trigger_update_operator_rating();

-- =============================================================
-- FUNCTION: Check equipment availability for a date range
-- =============================================================

CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id   UUID,
  p_event_date     DATE,
  p_exclude_booking UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  conflict_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO conflict_count
  FROM booking_line_items bli
  JOIN bookings b ON b.id = bli.booking_id
  WHERE
    bli.equipment_id = p_equipment_id
    AND b.event_date = p_event_date
    AND b.status NOT IN ('cancelled')
    AND (p_exclude_booking IS NULL OR b.id != p_exclude_booking)
    AND b.deleted_at IS NULL;

  RETURN conflict_count = 0;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION check_equipment_availability IS
  'Returns TRUE if equipment has no conflicting bookings on the given date';

-- =============================================================
-- FUNCTION: Get available equipment for a given date and region
-- =============================================================

CREATE OR REPLACE FUNCTION get_available_equipment(
  p_event_date  DATE,
  p_region_id   UUID DEFAULT NULL,
  p_type        equipment_type DEFAULT NULL
)
RETURNS TABLE (
  id            UUID,
  asset_id      VARCHAR,
  name          VARCHAR,
  type          equipment_type,
  daily_rate    DECIMAL,
  condition     equipment_condition,
  region_id     UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id, e.asset_id, e.name,
    ec.type, e.daily_rate, e.condition, e.region_id
  FROM equipment e
  JOIN equipment_categories ec ON ec.id = e.category_id
  WHERE
    e.status = 'available'
    AND e.deleted_at IS NULL
    AND (p_region_id IS NULL OR e.region_id = p_region_id)
    AND (p_type IS NULL OR ec.type = p_type)
    AND check_equipment_availability(e.id, p_event_date)
  ORDER BY e.name;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================
-- VIEW: Dashboard — Today's bookings summary
-- =============================================================

CREATE OR REPLACE VIEW v_today_bookings AS
SELECT
  b.id,
  b.booking_number,
  b.status,
  b.event_date,
  b.event_start_time,
  b.total_amount,
  b.payment_status,
  b.delivery_city,
  u.first_name || ' ' || u.last_name AS customer_name,
  u.phone AS customer_phone,
  op_user.first_name || ' ' || op_user.last_name AS operator_name,
  op.current_status AS operator_status,
  r.name AS region_name
FROM bookings b
JOIN users u ON u.id = b.customer_id
LEFT JOIN operator_profiles op ON op.id = b.assigned_operator_id
LEFT JOIN users op_user ON op_user.id = op.user_id
LEFT JOIN regions r ON r.id = b.region_id
WHERE
  b.event_date = CURRENT_DATE
  AND b.deleted_at IS NULL
  AND b.status NOT IN ('cancelled')
ORDER BY b.event_start_time;

COMMENT ON VIEW v_today_bookings IS 'All active bookings for today — used on dashboard';

-- =============================================================
-- VIEW: Revenue summary by region and month
-- =============================================================

CREATE OR REPLACE VIEW v_revenue_by_region_month AS
SELECT
  r.name AS region_name,
  DATE_TRUNC('month', b.event_date) AS month,
  COUNT(b.id) AS booking_count,
  SUM(b.total_amount) AS gross_revenue,
  SUM(b.vat_amount) AS vat_collected,
  SUM(b.total_amount - b.vat_amount) AS net_revenue,
  AVG(b.total_amount) AS avg_booking_value
FROM bookings b
LEFT JOIN regions r ON r.id = b.region_id
WHERE
  b.status = 'completed'
  AND b.deleted_at IS NULL
GROUP BY r.name, DATE_TRUNC('month', b.event_date)
ORDER BY month DESC, gross_revenue DESC;

-- =============================================================
-- VIEW: Equipment utilization report
-- =============================================================

CREATE OR REPLACE VIEW v_equipment_utilization AS
SELECT
  e.asset_id,
  e.name,
  ec.type,
  e.status,
  e.condition,
  r.name AS region_name,
  COUNT(bli.id) AS total_bookings,
  SUM(CASE WHEN b.status = 'completed' THEN 1 ELSE 0 END) AS completed_bookings,
  SUM(CASE WHEN b.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
  COALESCE(SUM(bli.line_total), 0) AS total_revenue_generated,
  e.last_service_date,
  e.next_service_date,
  e.total_hire_days
FROM equipment e
JOIN equipment_categories ec ON ec.id = e.category_id
LEFT JOIN regions r ON r.id = e.region_id
LEFT JOIN booking_line_items bli ON bli.equipment_id = e.id
LEFT JOIN bookings b ON b.id = bli.booking_id AND b.deleted_at IS NULL
WHERE e.deleted_at IS NULL
GROUP BY e.id, ec.type, r.name
ORDER BY total_revenue_generated DESC;

-- =============================================================
-- VIEW: Operator performance dashboard
-- =============================================================

CREATE OR REPLACE VIEW v_operator_performance AS
SELECT
  op.id AS operator_id,
  u.first_name || ' ' || u.last_name AS operator_name,
  r.name AS region_name,
  op.current_status,
  op.average_rating,
  op.total_deliveries,
  op.on_time_percentage,
  COUNT(DISTINCT b.id) FILTER (WHERE b.event_date = CURRENT_DATE) AS jobs_today,
  COUNT(DISTINCT b.id) FILTER (
    WHERE b.event_date >= DATE_TRUNC('month', CURRENT_DATE)
  ) AS jobs_this_month,
  COALESCE(SUM(b.total_amount) FILTER (
    WHERE b.status = 'completed'
    AND b.event_date >= DATE_TRUNC('month', CURRENT_DATE)
  ), 0) AS revenue_this_month
FROM operator_profiles op
JOIN users u ON u.id = op.user_id
LEFT JOIN regions r ON r.id = op.region_id
LEFT JOIN bookings b ON b.assigned_operator_id = op.id AND b.deleted_at IS NULL
GROUP BY op.id, u.first_name, u.last_name, r.name;

-- =============================================================
-- VIEW: Low stock inventory alert
-- =============================================================

CREATE OR REPLACE VIEW v_low_stock_alerts AS
SELECT
  i.id,
  i.sku,
  i.name,
  ic.name AS category,
  r.name AS region_name,
  i.quantity_in_stock,
  i.reorder_level,
  i.reorder_quantity,
  i.unit_of_measure,
  i.supplier_name,
  (i.reorder_level - i.quantity_in_stock) AS units_below_reorder
FROM inventory_items i
LEFT JOIN inventory_categories ic ON ic.id = i.category_id
LEFT JOIN regions r ON r.id = i.region_id
WHERE
  i.is_active = TRUE
  AND i.quantity_in_stock <= i.reorder_level
ORDER BY units_below_reorder DESC;

-- =============================================================
-- VIEW: Upcoming maintenance due
-- =============================================================

CREATE OR REPLACE VIEW v_maintenance_due AS
SELECT
  e.asset_id,
  e.name AS equipment_name,
  ec.type AS equipment_type,
  e.condition,
  r.name AS region_name,
  e.last_service_date,
  e.next_service_date,
  (e.next_service_date - CURRENT_DATE) AS days_until_service,
  CASE
    WHEN e.next_service_date < CURRENT_DATE THEN 'overdue'
    WHEN e.next_service_date <= CURRENT_DATE + 7 THEN 'due_this_week'
    WHEN e.next_service_date <= CURRENT_DATE + 30 THEN 'due_this_month'
    ELSE 'upcoming'
  END AS urgency
FROM equipment e
JOIN equipment_categories ec ON ec.id = e.category_id
LEFT JOIN regions r ON r.id = e.region_id
WHERE
  e.deleted_at IS NULL
  AND e.status != 'retired'
  AND e.next_service_date IS NOT NULL
ORDER BY e.next_service_date ASC;
