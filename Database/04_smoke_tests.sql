SELECT 'roles' AS entity, count(*) FROM roles
UNION ALL SELECT 'pets',count(*) FROM pets
UNION ALL SELECT 'appointments',count(*) FROM appointments
UNION ALL SELECT 'invoices',count(*) FROM invoices;

SELECT * FROM v_active_pets ORDER BY id LIMIT 10;
SELECT * FROM v_doctor_schedule ORDER BY start_time LIMIT 10;
SELECT * FROM v_pet_history ORDER BY start_time LIMIT 10;
SELECT * FROM v_invoice_balance ORDER BY invoice_id;
SELECT * FROM v_overdue_vaccinations ORDER BY next_due_date;

BEGIN;
SELECT set_config('vet.user_id','1',true);
WITH new_owner AS (
 SELECT fn_create_owner('Тест','Демонстраційний','+380000000000',1) AS id
)
SELECT * FROM new_owner;
SELECT id,first_name,last_name FROM owners WHERE last_name='Демонстраційний';
ROLLBACK;
SELECT count(*) AS test_owners_after_rollback FROM owners WHERE last_name='Демонстраційний';
