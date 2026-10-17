CREATE OR REPLACE VIEW v_active_owners AS
SELECT id, first_name, last_name, phone, email
FROM owners
WHERE is_deleted = FALSE;

SELECT * FROM v_active_owners ORDER BY id LIMIT 10;
