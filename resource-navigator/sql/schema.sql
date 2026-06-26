-- ============================================================
-- Community Resource Navigator — Database Schema
-- ============================================================
-- Database: SQLite (local dev) / PostgreSQL (production)
-- Run: sqlite3 resources.db < schema.sql
-- ============================================================


-- ── 1. ORGANIZATIONS ────────────────────────────────────────
-- One row per nonprofit / agency / program provider.
-- An organization can offer multiple services (see services table).

CREATE TABLE IF NOT EXISTS organizations (
    org_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT    NOT NULL,
    address         TEXT,
    phone           TEXT,
    website         TEXT,
    lat             REAL,
    lng             REAL,
    languages       TEXT,               -- comma-separated: "English,Spanish,Arabic"
    last_verified   DATE,               -- when a staff member last confirmed info
    is_active       INTEGER DEFAULT 1,  -- 0 = soft-deleted / inactive
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- ── 2. SERVICES ─────────────────────────────────────────────
-- Each organization can have 1+ services (shelter, food, legal aid…).
-- Keeping services separate lets us tag, filter, and search precisely.

CREATE TABLE IF NOT EXISTS services (
    service_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    org_id          INTEGER NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    category        TEXT    NOT NULL,   -- 'housing', 'food', 'health', 'environment', 'humanitarian'
    service_name    TEXT    NOT NULL,
    description     TEXT,
    hours           TEXT,               -- freetext: "Mon-Fri 9am-5pm"
    capacity        TEXT,               -- freetext: "14 beds", "250 families/week", "Open"
    is_active       INTEGER DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- ── 3. ELIGIBILITY ──────────────────────────────────────────
-- Structured eligibility rules for a service.
-- Storing as rows (not a single text blob) enables filtered matching.

CREATE TABLE IF NOT EXISTS eligibility (
    eligibility_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    service_id      INTEGER NOT NULL REFERENCES services(service_id) ON DELETE CASCADE,
    rule_type       TEXT    NOT NULL,   -- 'age_min', 'age_max', 'gender', 'residency',
                                        --   'income', 'status', 'other'
    rule_value      TEXT    NOT NULL,   -- e.g. '18', 'women_and_families', 'county_resident'
    notes           TEXT                -- human-readable explanation
);


-- ── 4. LOCATIONS ────────────────────────────────────────────
-- Separate from organizations because some orgs (e.g. mobile clinics)
-- have multiple or rotating service locations.

CREATE TABLE IF NOT EXISTS locations (
    location_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    org_id          INTEGER NOT NULL REFERENCES organizations(org_id) ON DELETE CASCADE,
    label           TEXT,               -- 'Main office', 'North branch', 'Mobile stop #2'
    address         TEXT,
    lat             REAL,
    lng             REAL,
    notes           TEXT                -- "Call ahead — rotating schedule"
);


-- ── 5. SEARCH_LOGS ──────────────────────────────────────────
-- Every search the tool runs gets logged here.
-- Powers the gap analysis: unmatched searches reveal missing resources.

CREATE TABLE IF NOT EXISTS search_logs (
    log_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    searched_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    query           TEXT    NOT NULL,
    category_filter TEXT,               -- NULL = no filter applied
    results_count   INTEGER DEFAULT 0,
    matched         INTEGER DEFAULT 0,  -- 1 = at least one result returned
    session_id      TEXT                -- anonymous browser session
);


-- ── INDEXES ─────────────────────────────────────────────────
-- Speed up the most common query patterns.

CREATE INDEX IF NOT EXISTS idx_services_category   ON services(category);
CREATE INDEX IF NOT EXISTS idx_services_org        ON services(org_id);
CREATE INDEX IF NOT EXISTS idx_eligibility_service ON eligibility(service_id);
CREATE INDEX IF NOT EXISTS idx_search_logs_date    ON search_logs(searched_at);
CREATE INDEX IF NOT EXISTS idx_search_logs_matched ON search_logs(matched);
CREATE INDEX IF NOT EXISTS idx_orgs_active         ON organizations(is_active);


-- ── SEED DATA ───────────────────────────────────────────────

INSERT INTO organizations (name, address, phone, lat, lng, languages, last_verified) VALUES
    ('GreenRoots Alliance',    '440 Elm Street',       '555-0141', 40.7128, -74.0060, 'English,Spanish',               '2024-11-01'),
    ('Bridge House Shelter',   '82 Pine Avenue',       '555-0188', 40.7138, -74.0070, 'English',                       '2024-10-15'),
    ('Harvest Table',          '10 Church Lane',       '555-0109', 40.7118, -74.0050, 'English,Spanish,French',        '2024-12-01'),
    ('Community Health Van',   'Rotating — call',      '555-0167', NULL,    NULL,     'English,Spanish',               '2024-11-20'),
    ('Refugee Welcome Center', '300 Harbor Blvd',      '555-0122', 40.7148, -74.0080, 'English,Spanish,Arabic,Somali', '2024-12-01'),
    ('Clean Air Coalition',    '55 Greenway Dr',       '555-0133', 40.7158, -74.0090, 'English',                       '2024-09-01'),
    ('Second Chance Housing',  '200 Oak Street',       '555-0155', 40.7168, -74.0100, 'English',                       '2024-11-10'),
    ('Sunrise Food Pantry',    '12 Sunrise Ave',       '555-0177', 40.7178, -74.0110, 'English,Spanish',               '2024-12-01'),
    ('Hope Housing Coalition', '525 Main Street',      '555-0222', 40.7208, -74.0140, 'English',                       '2024-11-01'),
    ('Urban Tree Canopy',      'City Hall Annex',      '555-0211', 40.7198, -74.0130, 'English,Spanish',               '2024-11-15'),
    ('River Cleanup Project',  'River Park Entrance',  '555-0199', 40.7188, -74.0120, 'English',                       '2024-10-01');

INSERT INTO services (org_id, category, service_name, description, hours, capacity) VALUES
    (1, 'environment', 'Urban Farming Training',      'Hands-on urban farming and composting education',          'Mon-Fri 9am-5pm',               'Open enrollment'),
    (1, 'environment', 'Green Job Placement',         'Job training and placement in environmental sector',       'Mon-Fri 9am-5pm',               'Open enrollment'),
    (2, 'housing',     'Emergency Shelter',           'Overnight shelter for women and families',                 '24/7',                          '14 beds'),
    (2, 'housing',     'Transitional Housing',        'Medium-term housing with case management support',         '24/7',                          '6 units'),
    (3, 'food',        'Hot Meals Program',           'Free hot meals served Monday through Friday',              'Mon-Fri 11am-1pm',              'Unlimited'),
    (3, 'food',        'Food Pantry',                 'Grocery-style pantry distribution every Thursday',         'Thu 4-7pm',                     'Unlimited'),
    (4, 'health',      'Mobile Medical Clinic',       'Primary care for uninsured residents',                     'Tue & Thu 8am-4pm',             '30/day'),
    (4, 'health',      'Dental & Vision',             'Free dental and vision screening',                         'Tue & Thu 8am-4pm',             '20/day'),
    (5, 'humanitarian','Refugee Resettlement',        'Full resettlement coordination and case management',       'Mon-Sat 8am-6pm',               'Open'),
    (5, 'humanitarian','ESL Classes',                 'English language classes for refugees and immigrants',     'Mon/Wed/Fri 10am-12pm',         'Open'),
    (5, 'humanitarian','Legal Aid',                   'Immigration legal assistance',                             'By appointment',                'Limited'),
    (6, 'environment', 'Air Quality Monitoring',      'Community air sensor network and data reporting',          'Mon-Fri 10am-4pm',              'Open'),
    (7, 'housing',     'Re-entry Housing',            'Supportive housing for people leaving incarceration',      'Mon-Fri 9am-5pm',               '8 units'),
    (8, 'food',        'Saturday Food Pantry',        'Drive-through produce and dry goods distribution',         'Sat 8am-noon',                  '250 families'),
    (9, 'housing',     'Rapid Rehousing',             'Emergency rental assistance and deposit help',             'Mon-Fri 8am-4pm',               '20 cases/month'),
    (10,'environment', 'Urban Tree Planting',         'Free trees and greening education for low-income areas',   'Mon-Wed 9am-3pm',               'Open'),
    (11,'environment', 'River Cleanup',               'Monthly cleanups and water quality testing',               'Sat monthly 9am-1pm',           '50 volunteers');

INSERT INTO eligibility (service_id, rule_type, rule_value, notes) VALUES
    (1, 'age_min',   '18',                    'Must be 18 or older'),
    (1, 'residency', 'county_resident',        'Must reside in the county'),
    (3, 'gender',    'women_and_families',     'Women and families only — men not accepted'),
    (4, 'gender',    'women_and_families',     'Women and families only'),
    (5, 'other',     'no_restrictions',        'Open to all community members'),
    (6, 'other',     'no_restrictions',        'Open to all community members'),
    (7, 'income',    'uninsured_low_income',   'Must be uninsured or meet income threshold'),
    (8, 'income',    'uninsured_low_income',   'Must be uninsured or meet income threshold'),
    (9, 'status',    'refugee_asylee',         'Must have refugee or asylee status'),
    (10,'status',    'refugee_asylee',         'Open to all immigrants and refugees'),
    (11,'status',    'refugee_asylee',         'Immigration status required for legal services'),
    (13,'status',    'post_incarceration',     'Must have been recently released from incarceration'),
    (14,'residency', 'county_resident',        'County residents only'),
    (15,'other',     'adults_facing_eviction', 'Must be facing eviction or housing instability'),
    (16,'income',    'low_income_area',        'Targeting low-income neighborhoods'),
    (17,'age_min',   '16',                     'Volunteers must be 16 or older');


-- ── USEFUL QUERIES ──────────────────────────────────────────

-- Q1: All active services by category with org info
-- SELECT o.name, s.category, s.service_name, s.hours, s.capacity
-- FROM services s
-- JOIN organizations o ON s.org_id = o.org_id
-- WHERE o.is_active = 1 AND s.is_active = 1
-- ORDER BY s.category, o.name;

-- Q2: Find services that allow 'no_restrictions' eligibility
-- SELECT o.name, s.service_name, s.category
-- FROM services s
-- JOIN organizations o ON s.org_id = o.org_id
-- JOIN eligibility e ON s.service_id = e.service_id
-- WHERE e.rule_value = 'no_restrictions' AND o.is_active = 1;

-- Q3: Gap analysis — top unmatched search terms (last 30 days)
-- SELECT query, COUNT(*) AS search_count
-- FROM search_logs
-- WHERE matched = 0
--   AND searched_at >= DATE('now', '-30 days')
-- GROUP BY query
-- ORDER BY search_count DESC
-- LIMIT 20;

-- Q4: Category coverage — % of searches that found a match
-- SELECT
--     category_filter,
--     COUNT(*) AS total_searches,
--     SUM(matched) AS matched_searches,
--     ROUND(100.0 * SUM(matched) / COUNT(*), 1) AS match_rate_pct
-- FROM search_logs
-- WHERE category_filter IS NOT NULL
-- GROUP BY category_filter
-- ORDER BY match_rate_pct ASC;

-- Q5: Organizations with stale data (not verified in 90+ days)
-- SELECT name, phone, last_verified,
--        CAST(julianday('now') - julianday(last_verified) AS INTEGER) AS days_since_verified
-- FROM organizations
-- WHERE is_active = 1
--   AND (last_verified IS NULL OR julianday('now') - julianday(last_verified) > 90)
-- ORDER BY days_since_verified DESC;

-- Q6: Services with missing eligibility records (data quality check)
-- SELECT s.service_id, s.service_name, o.name AS org_name
-- FROM services s
-- JOIN organizations o ON s.org_id = o.org_id
-- LEFT JOIN eligibility e ON s.service_id = e.service_id
-- WHERE e.eligibility_id IS NULL AND s.is_active = 1;
