BEGIN;
CREATE OR REPLACE VIEW v_species_catalog AS
SELECT id, name FROM species;
CREATE OR REPLACE VIEW v_breeds_catalog AS
SELECT b.id, b.species_id, b.name, s.name AS species_name
FROM breeds b JOIN species s ON s.id = b.species_id;
CREATE OR REPLACE VIEW v_active_veterinarians AS
SELECT v.id, v.first_name, v.last_name,
       COALESCE(string_agg(s.name, ', ' ORDER BY s.name), '') AS specializations
FROM veterinarians v
JOIN users u ON u.id = v.user_id
LEFT JOIN veterinarian_specializations vs ON vs.veterinarian_id = v.id
LEFT JOIN specializations s ON s.id = vs.specialization_id
WHERE NOT v.is_deleted AND u.is_active AND v.fired_at IS NULL
GROUP BY v.id, v.first_name, v.last_name;
CREATE OR REPLACE FUNCTION fn_create_species(p_name text)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE new_id integer;
BEGIN
    IF length(btrim(coalesce(p_name, ''))) = 0 THEN
        RAISE EXCEPTION 'Назва виду не може бути порожньою';
    END IF;
    IF EXISTS (SELECT 1 FROM species WHERE lower(name) = lower(btrim(p_name))) THEN
        RAISE EXCEPTION 'Такий вид уже існує';
    END IF;
    INSERT INTO species(name) VALUES (btrim(p_name)) RETURNING id INTO new_id;
    RETURN new_id;
END; $$;
CREATE OR REPLACE FUNCTION fn_create_breed(p_species_id integer, p_name text)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE new_id integer;
BEGIN
    IF length(btrim(coalesce(p_name, ''))) = 0 THEN
        RAISE EXCEPTION 'Назва породи не може бути порожньою';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM species WHERE id = p_species_id) THEN
        RAISE EXCEPTION 'Вид не знайдено';
    END IF;
    IF EXISTS (SELECT 1 FROM breeds WHERE species_id = p_species_id AND lower(name) = lower(btrim(p_name))) THEN
        RAISE EXCEPTION 'Така порода цього виду вже існує';
    END IF;
    INSERT INTO breeds(species_id, name) VALUES(p_species_id, btrim(p_name)) RETURNING id INTO new_id;
    RETURN new_id;
END; $$;
COMMIT;
