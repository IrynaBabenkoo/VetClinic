BEGIN;

-- Тригер аудиту (updated_at, updated_by)..
CREATE OR REPLACE FUNCTION fn_set_audit_fields()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    actor_id integer;
BEGIN
    actor_id := NULLIF(current_setting('vet.user_id', true), '')::integer;
    NEW.updated_at := clock_timestamp();
    NEW.updated_by := actor_id;
    RETURN NEW;
END;
$$;

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['users','owners','pets','veterinarians','appointments','medical_records','invoices']
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_update ON %I', t);
        EXECUTE format('CREATE TRIGGER trg_audit_update BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_set_audit_fields()', t);
    END LOOP;
END;
$$;

-- Видалення власника лише за відсутності активних тварин.
CREATE OR REPLACE PROCEDURE sp_soft_delete_owner(p_owner_id integer, p_actor_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM pets WHERE owner_id=p_owner_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'У власника % є активні тварини', p_owner_id;
    END IF;
    PERFORM set_config('vet.user_id', p_actor_id::text, true);
    UPDATE owners SET is_deleted=true, deleted_at=clock_timestamp(), deleted_by=p_actor_id
    WHERE id=p_owner_id AND NOT is_deleted;
    IF NOT FOUND THEN RAISE EXCEPTION 'Активного власника % не знайдено', p_owner_id; END IF;
END;
$$;

-- Видалення тварини. Зберігає історичні прийоми.
CREATE OR REPLACE PROCEDURE sp_soft_delete_pet(p_pet_id integer, p_actor_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM appointments WHERE pet_id=p_pet_id AND status IN ('scheduled','in_progress')) THEN
        RAISE EXCEPTION 'Спочатку скасуйте активні/заплановані прийоми тварини %', p_pet_id;
    END IF;
    PERFORM set_config('vet.user_id', p_actor_id::text, true);
    UPDATE pets SET is_deleted=true, deleted_at=clock_timestamp(), deleted_by=p_actor_id
    WHERE id=p_pet_id AND NOT is_deleted;
    IF NOT FOUND THEN RAISE EXCEPTION 'Активної тварини % не знайдено', p_pet_id; END IF;
END;
$$;

-- Видалення ветеринара.
CREATE OR REPLACE PROCEDURE sp_soft_delete_veterinarian(p_vet_id integer, p_actor_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM appointments WHERE vet_id=p_vet_id AND status IN ('scheduled','in_progress')) THEN
        RAISE EXCEPTION 'У лікаря % залишилися активні/заплановані прийоми', p_vet_id;
    END IF;
    PERFORM set_config('vet.user_id', p_actor_id::text, true);
    UPDATE veterinarians SET is_deleted=true, deleted_at=clock_timestamp(), deleted_by=p_actor_id,
        fired_at=COALESCE(fired_at, current_date)
    WHERE id=p_vet_id AND NOT is_deleted;
    IF NOT FOUND THEN RAISE EXCEPTION 'Активного лікаря % не знайдено', p_vet_id; END IF;
END;
$$;

-- Перевірка накладення прийомів у конкурентних транзакціях:
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS ex_appointments_vet_no_overlap;
ALTER TABLE appointments ADD CONSTRAINT ex_appointments_vet_no_overlap
EXCLUDE USING gist (
    vet_id WITH =,
    tstzrange(start_time, end_time, '[)') WITH &&
) WHERE (status IN ('scheduled','in_progress'));

-- 6. Тригер: заборона прийомів для логічно видалених тварин/лікарів.
CREATE OR REPLACE FUNCTION fn_check_appointment_participants()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM pets WHERE id=NEW.pet_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Тварина % неактивна або відсутня', NEW.pet_id;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM veterinarians v JOIN users u ON u.id=v.user_id
                  WHERE v.id=NEW.vet_id AND NOT v.is_deleted AND u.is_active AND v.fired_at IS NULL) THEN
        RAISE EXCEPTION 'Лікар % неактивний або відсутній', NEW.vet_id;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_check_appointment_participants ON appointments;
CREATE TRIGGER trg_check_appointment_participants
BEFORE INSERT OR UPDATE OF pet_id,vet_id ON appointments
FOR EACH ROW EXECUTE FUNCTION fn_check_appointment_participants();

CREATE OR REPLACE FUNCTION fn_create_owner(p_first_name text, p_last_name text, p_phone text,
                                            p_actor_id integer, p_email text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE new_id integer;
BEGIN
    INSERT INTO owners(first_name,last_name,phone,email,created_by)
    VALUES (p_first_name,p_last_name,p_phone,p_email,p_actor_id)
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$$;


CREATE OR REPLACE FUNCTION fn_register_pet(p_owner_id integer, p_breed_id integer,
                                            p_name text, p_actor_id integer)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM owners WHERE id=p_owner_id AND NOT is_deleted) THEN
       RAISE EXCEPTION 'Активного власника % не знайдено', p_owner_id;
    END IF;
    INSERT INTO pets(owner_id,breed_id,name,created_by)
    VALUES(p_owner_id,p_breed_id,p_name,p_actor_id) RETURNING id INTO new_id;
    RETURN new_id;
END;
$$;

-- Запис на прийом.
CREATE OR REPLACE FUNCTION fn_schedule_appointment(p_pet_id integer,p_vet_id integer,
    p_start timestamptz,p_end timestamptz,p_reason text,p_actor_id integer)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE new_id integer;
BEGIN
    INSERT INTO appointments(pet_id,vet_id,start_time,end_time,reason,created_by)
    VALUES(p_pet_id,p_vet_id,p_start,p_end,p_reason,p_actor_id)
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$$;

-- Завершення прийому.
CREATE OR REPLACE PROCEDURE sp_complete_appointment(p_appointment_id integer,p_actor_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('vet.user_id', p_actor_id::text, true);
    UPDATE appointments SET status='completed'
    WHERE id=p_appointment_id AND status='in_progress';
    IF NOT FOUND THEN RAISE EXCEPTION 'Прийом % не знайдено або він не в статусі in_progress', p_appointment_id; END IF;
END;
$$;

-- 11. Підрахунок вартості наданих послуг одного прийому.
CREATE OR REPLACE FUNCTION fn_appointment_subtotal(p_appointment_id integer)
RETURNS numeric LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(quantity*unit_price),0)::numeric(12,2)
    FROM appointment_services WHERE appointment_id=p_appointment_id;
$$;

-- Виставлення рахунку: зберігає історичну суму та знижку.
CREATE OR REPLACE FUNCTION fn_issue_invoice(p_appointment_id integer,p_discount numeric,p_actor_id integer)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE subtotal_amount numeric(12,2); new_id integer;
BEGIN
    IF p_discount IS NULL OR p_discount < 0 OR p_discount > 100 THEN
        RAISE EXCEPTION 'Знижка має бути від 0 до 100';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM appointments WHERE id=p_appointment_id AND status='completed') THEN
        RAISE EXCEPTION 'Рахунок можна створити лише для завершеного прийому';
    END IF;
    subtotal_amount := fn_appointment_subtotal(p_appointment_id);
    INSERT INTO invoices(appointment_id,issued_at,subtotal,discount_percent,total,status,created_by)
    VALUES(p_appointment_id,clock_timestamp(),subtotal_amount,p_discount,
           ROUND(subtotal_amount*(100-p_discount)/100,2),'issued',p_actor_id)
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$$;

-- Автоматичний статус оплати й заборона переплати.
CREATE OR REPLACE FUNCTION fn_recalculate_invoice_payment()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target_invoice_id integer; invoice_total numeric; paid_total numeric; current_status invoice_status;
BEGIN
    target_invoice_id := CASE WHEN TG_OP='DELETE' THEN OLD.invoice_id ELSE NEW.invoice_id END;
    SELECT total,status INTO invoice_total,current_status FROM invoices WHERE id=target_invoice_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Рахунок % відсутній',target_invoice_id; END IF;
    IF current_status IN ('cancelled','draft') THEN
        RAISE EXCEPTION 'Оплата рахунку зі статусом % заборонена',current_status;
    END IF;
    SELECT COALESCE(SUM(amount),0) INTO paid_total FROM payments WHERE invoice_id=target_invoice_id;
    IF paid_total > invoice_total THEN RAISE EXCEPTION 'Переплата: % > %', paid_total, invoice_total; END IF;
    UPDATE invoices SET status=(CASE
      WHEN paid_total=0 THEN 'issued'::invoice_status
      WHEN paid_total>=invoice_total THEN 'paid'::invoice_status
      ELSE 'partially_paid'::invoice_status END)
    WHERE id=target_invoice_id;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_recalculate_invoice_payment ON payments;
CREATE TRIGGER trg_recalculate_invoice_payment
AFTER INSERT OR DELETE ON payments
FOR EACH ROW EXECUTE FUNCTION fn_recalculate_invoice_payment();

-- Активні власники і тварини.
CREATE OR REPLACE VIEW v_active_pets AS
SELECT p.id,p.name,p.owner_id,o.first_name AS owner_first_name,o.last_name AS owner_last_name,
       p.breed_id,b.name AS breed_name,s.name AS species_name,p.birth_date,p.sex,p.weight_kg
FROM pets p JOIN owners o ON o.id=p.owner_id
LEFT JOIN breeds b ON b.id=p.breed_id
LEFT JOIN species s ON s.id=b.species_id
WHERE NOT p.is_deleted AND NOT o.is_deleted;

CREATE OR REPLACE VIEW v_doctor_schedule AS
SELECT a.id AS appointment_id,a.vet_id,v.first_name AS vet_first_name,v.last_name AS vet_last_name,
       a.pet_id,p.name AS pet_name,a.start_time,a.end_time,a.status,a.reason
FROM appointments a
JOIN veterinarians v ON v.id=a.vet_id JOIN pets p ON p.id=a.pet_id
WHERE NOT v.is_deleted AND NOT p.is_deleted;

CREATE OR REPLACE VIEW v_pet_history AS
SELECT a.pet_id,a.id AS appointment_id,a.start_time,a.status,m.id AS medical_record_id,
       m.complaints,m.diagnosis,m.notes,m.updated_at,m.updated_by
FROM appointments a JOIN medical_records m ON m.appointment_id=a.id;

-- Заборгованість за рахунками.
CREATE OR REPLACE VIEW v_invoice_balance AS
SELECT i.id AS invoice_id,i.appointment_id,i.total,i.status,
       COALESCE(SUM(p.amount),0)::numeric(12,2) AS paid,
       (i.total-COALESCE(SUM(p.amount),0))::numeric(12,2) AS balance
FROM invoices i LEFT JOIN payments p ON p.invoice_id=i.id
GROUP BY i.id,i.appointment_id,i.total,i.status;

-- Прострочені вакцинації.
CREATE OR REPLACE VIEW v_overdue_vaccinations AS
SELECT va.id, va.pet_id,p.name AS pet_name, va.vaccine_name,va.next_due_date
FROM vaccinations va JOIN pets p ON p.id=va.pet_id
WHERE va.next_due_date < CURRENT_DATE AND NOT p.is_deleted;

COMMIT;
