BEGIN;

CREATE OR REPLACE PROCEDURE sp_set_current_user(p_actor_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_actor_id AND is_active) THEN
        RAISE EXCEPTION 'Користувача % не знайдено або він неактивний', p_actor_id;
    END IF;
    PERFORM set_config('vet.user_id', p_actor_id::text, true);
END;
$$;

CREATE OR REPLACE FUNCTION fn_register_payment(
    p_invoice_id integer, p_amount numeric, p_method text, p_actor_id integer)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE new_id integer;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Сума оплати має бути більшою за нуль';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM invoices WHERE id = p_invoice_id) THEN
        RAISE EXCEPTION 'Рахунок % не знайдено', p_invoice_id;
    END IF;
    INSERT INTO payments (invoice_id, amount, method, created_by)
    VALUES (p_invoice_id, p_amount, p_method::payment_method, p_actor_id)
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$$;

CREATE OR REPLACE VIEW v_invoices_overview AS
SELECT i.id AS invoice_id,
       i.appointment_id,
       p.name AS pet_name,
       o.first_name || ' ' || o.last_name AS owner_name,
       i.total,
       COALESCE(SUM(pay.amount), 0)::numeric(12,2) AS paid,
       (i.total - COALESCE(SUM(pay.amount), 0))::numeric(12,2) AS balance,
       i.status
FROM invoices i
JOIN appointments a ON a.id = i.appointment_id
JOIN pets p         ON p.id = a.pet_id
JOIN owners o       ON o.id = p.owner_id
LEFT JOIN payments pay ON pay.invoice_id = i.id
GROUP BY i.id, i.appointment_id, p.name, o.first_name, o.last_name, i.total, i.status;

CREATE OR REPLACE PROCEDURE sp_cancel_appointment(p_appointment_id integer, p_actor_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('vet.user_id', p_actor_id::text, true);
    UPDATE appointments
    SET status = 'cancelled'
    WHERE id = p_appointment_id AND status = 'scheduled';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Прийом не знайдено або його вже не можна скасувати';
    END IF;
END;
$$;

COMMIT;
