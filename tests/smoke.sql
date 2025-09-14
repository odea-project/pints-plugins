-- ============================
-- Smoke test for intra_run_components plugin
-- ============================

-- 1) Clean slate (only plugin tables)
DELETE FROM intra_run_components;
DELETE FROM intra_run_component_members;

-- 2) Insert demo component
INSERT INTO intra_run_components(component_id, sample_id, run_id, annotation)
VALUES ('C001', 'S001', 'R001', 'demo component for adduct grouping');

-- 3) Link features to this component
INSERT INTO intra_run_component_members(component_id, feature_id, role)
VALUES
('C001', 'R001_F0001', 'monoisotope'),
('C001', 'R001_F0002', 'isotope+1'),
('C001', 'R001_F0003', 'adduct:Na');

-- 4) Quick check
SELECT * FROM intra_run_components;
SELECT * FROM intra_run_component_members;
