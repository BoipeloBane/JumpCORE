-- =============================================================
-- JUMPCORE OS — MIGRATION 008
-- Seed Data — Regions, Categories & Default Config
-- =============================================================

-- =============================================================
-- REGIONS — South Africa
-- =============================================================

INSERT INTO regions (name, slug, province, city, latitude, longitude) VALUES
  ('Johannesburg',  'johannesburg',  'Gauteng',       'Johannesburg',  -26.2041, 28.0473),
  ('Pretoria',      'pretoria',      'Gauteng',       'Pretoria',      -25.7479, 28.2293),
  ('Cape Town',     'cape_town',     'Western Cape',  'Cape Town',     -33.9249, 18.4241),
  ('Durban',        'durban',        'KwaZulu-Natal', 'Durban',        -29.8587, 31.0218),
  ('Bloemfontein',  'bloemfontein',  'Free State',    'Bloemfontein',  -29.0852, 26.1596),
  ('Polokwane',     'polokwane',     'Limpopo',       'Polokwane',     -23.9045, 29.4689),
  ('Rustenburg',    'rustenburg',    'North West',    'Rustenburg',    -25.6671, 27.2423),
  ('Nelspruit',     'nelspruit',     'Mpumalanga',    'Nelspruit',     -25.4745, 30.9703),
  ('East London',   'east_london',   'Eastern Cape',  'East London',   -32.9982, 27.8980),
  ('Kimberley',     'kimberley',     'Northern Cape', 'Kimberley',     -28.7282, 24.7499),
  ('Port Elizabeth','port_elizabeth','Eastern Cape',  'Port Elizabeth',-33.9608, 25.6022),
  ('Other',         'other',         NULL,            NULL,             NULL,     NULL);

-- =============================================================
-- EQUIPMENT CATEGORIES
-- =============================================================

INSERT INTO equipment_categories (name, slug, type, description) VALUES
  ('Jumping Castles',     'jumping-castles',    'jumping_castle',  'Inflatable bouncy castles in various sizes and themes'),
  ('Water Slides',        'water-slides',       'water_slide',     'Inflatable water slides for hot weather events'),
  ('Obstacle Courses',    'obstacle-courses',   'obstacle_course', 'Multi-section inflatable obstacle courses'),
  ('Soft Play Sets',      'soft-play',          'soft_play',       'Foam soft play for toddlers and young children'),
  ('Combo Units',         'combo-units',        'combo_unit',      'Combined castle + slide units'),
  ('Party Chairs',        'party-chairs',       'party_chair',     'Stackable event chairs'),
  ('Party Tables',        'party-tables',       'party_table',     'Folding trestle and round event tables'),
  ('Generators',          'generators',         'generator',       'Petrol and diesel generators for power supply'),
  ('Blowers',             'blowers',            'blower',          'Electric air blowers for inflatables'),
  ('Other Equipment',     'other',              'other',           'Miscellaneous rental equipment');

-- =============================================================
-- INVENTORY CATEGORIES
-- =============================================================

INSERT INTO inventory_categories (name, description) VALUES
  ('Cleaning Chemicals',  'Disinfectants, degreasers and cleaning solutions'),
  ('Repair Materials',    'PVC patches, glue, thread and repair kits'),
  ('Blower Parts',        'Spare blower motors, capacitors and cables'),
  ('Fuel',                'Petrol and diesel for generators and vehicles'),
  ('Packaging',           'Bags, straps, tie-downs and protective covers'),
  ('Safety Equipment',    'Stakes, sandbags, safety mats and anchors'),
  ('Consumables',         'Disposable items used in operations');

-- =============================================================
-- SUPER ADMIN USER (Change password immediately after setup)
-- =============================================================

INSERT INTO users (
  role, status, first_name, last_name,
  email, phone,
  password_hash,
  email_verified
) VALUES (
  'super_admin',
  'active',
  'System',
  'Administrator',
  'admin@jumpzone.co.za',
  '+27000000000',
  crypt('ChangeMe@2024!', gen_salt('bf', 12)),
  TRUE
);

-- =============================================================
-- SAMPLE EQUIPMENT (Demo data)
-- =============================================================

WITH jnb AS (SELECT id FROM regions WHERE slug = 'johannesburg' LIMIT 1),
     cpt AS (SELECT id FROM regions WHERE slug = 'cape_town' LIMIT 1),
     castle_cat AS (SELECT id FROM equipment_categories WHERE slug = 'jumping-castles' LIMIT 1),
     slide_cat  AS (SELECT id FROM equipment_categories WHERE slug = 'water-slides' LIMIT 1),
     combo_cat  AS (SELECT id FROM equipment_categories WHERE slug = 'combo-units' LIMIT 1),
     obs_cat    AS (SELECT id FROM equipment_categories WHERE slug = 'obstacle-courses' LIMIT 1),
     soft_cat   AS (SELECT id FROM equipment_categories WHERE slug = 'soft-play' LIMIT 1)

INSERT INTO equipment (
  asset_id, category_id, region_id, name, description,
  status, condition,
  purchase_date, purchase_price, current_value,
  daily_rate, weekend_rate, deposit_amount,
  requires_blower, requires_water,
  capacity_persons, age_min, age_max,
  space_required_m2, weight_kg,
  last_service_date, next_service_date,
  colour, serial_number, qr_code
)
SELECT * FROM (VALUES
  ('EQ-001', (SELECT id FROM castle_cat), (SELECT id FROM jnb),
   'Rainbow Castle XL', 'Large themed jumping castle with rainbow colours',
   'in_use', 'excellent',
   '2023-01-15', 12500.00, 10000.00,
   800.00, 1200.00, 400.00,
   TRUE, FALSE, 15, 3, 12, 36.00, 85.00,
   CURRENT_DATE - 14, CURRENT_DATE + 16,
   'Multi-colour', 'SN-RC-001', 'QR-EQ-001'),

  ('EQ-002', (SELECT id FROM slide_cat), (SELECT id FROM jnb),
   'Water Slide Pro', 'Double lane water slide 8m height',
   'available', 'good',
   '2022-06-10', 18000.00, 14000.00,
   1200.00, 1800.00, 600.00,
   TRUE, TRUE, 1, 6, 16, 60.00, 140.00,
   CURRENT_DATE - 30, CURRENT_DATE,
   'Blue/Yellow', 'SN-WS-002', 'QR-EQ-002'),

  ('EQ-003', (SELECT id FROM obs_cat), (SELECT id FROM jnb),
   'Obstacle Course XL', '20m multi-section obstacle course',
   'in_use', 'excellent',
   '2023-03-20', 28000.00, 24000.00,
   1800.00, 2600.00, 900.00,
   TRUE, FALSE, 20, 5, 18, 120.00, 280.00,
   CURRENT_DATE - 21, CURRENT_DATE + 9,
   'Red/Blue', 'SN-OC-003', 'QR-EQ-003'),

  ('EQ-004', (SELECT id FROM soft_cat), (SELECT id FROM jnb),
   'Soft Play Bundle 1', 'Complete toddler soft play set',
   'in_maintenance', 'fair',
   '2021-08-05', 9500.00, 6000.00,
   600.00, 900.00, 300.00,
   FALSE, FALSE, 10, 1, 5, 25.00, 60.00,
   CURRENT_DATE, CURRENT_DATE + 30,
   'Primary colours', 'SN-SP-004', 'QR-EQ-004'),

  ('EQ-005', (SELECT id FROM combo_cat), (SELECT id FROM jnb),
   'Jungle Gym Combo', 'Castle + slide combo jungle theme',
   'reserved', 'good',
   '2022-11-12', 22000.00, 18000.00,
   1400.00, 2000.00, 700.00,
   TRUE, FALSE, 20, 3, 14, 80.00, 180.00,
   CURRENT_DATE - 14, CURRENT_DATE + 16,
   'Green/Brown', 'SN-CC-005', 'QR-EQ-005'),

  ('EQ-006', (SELECT id FROM castle_cat), (SELECT id FROM cpt),
   'Princess Castle', 'Pink princess themed castle',
   'available', 'excellent',
   '2023-09-01', 11000.00, 10000.00,
   750.00, 1100.00, 375.00,
   TRUE, FALSE, 12, 3, 10, 30.00, 80.00,
   CURRENT_DATE - 7, CURRENT_DATE + 23,
   'Pink/Purple', 'SN-PC-006', 'QR-EQ-006'),

  ('EQ-007', (SELECT id FROM slide_cat), (SELECT id FROM jnb),
   'Speed Slide Combo', 'Triple lane speed water slide',
   'damaged', 'poor',
   '2021-03-15', 22000.00, 8000.00,
   1400.00, 2000.00, 700.00,
   TRUE, TRUE, 3, 7, 18, 75.00, 200.00,
   CURRENT_DATE, NULL,
   'Orange/Blue', 'SN-SS-007', 'QR-EQ-007')
) AS v (
  asset_id, category_id, region_id, name, description,
  status, condition,
  purchase_date, purchase_price, current_value,
  daily_rate, weekend_rate, deposit_amount,
  requires_blower, requires_water, capacity_persons, age_min, age_max,
  space_required_m2, weight_kg,
  last_service_date, next_service_date,
  colour, serial_number, qr_code
);
