INSERT INTO roles (name, description) VALUES
 ('admin',        'Адміністратор клініки'),
 ('veterinarian', 'Ветеринарний лікар'),
 ('assistant',    'Асистент');

INSERT INTO users (role_id, username, email, password_hash) VALUES
 (1, 'admin',      'admin@vetclinic.ua',      'hash_admin'),
 (2, 'ivanenko',   'ivanenko@vetclinic.ua',   'hash_vet1'),
 (2, 'kovalenko',  'kovalenko@vetclinic.ua',  'hash_vet2'),
 (3, 'assistant1', 'assistant1@vetclinic.ua', 'hash_asst');

INSERT INTO species (name) VALUES ('Собака'), ('Кіт'), ('Кролик');

INSERT INTO breeds (species_id, name) VALUES
 (1, 'Лабрадор'),
 (1, 'Німецька вівчарка'),
 (1, 'Той-тер''єр'),
 (2, 'Британська короткошерста'),
 (2, 'Мейн-кун'),
 (3, 'Декоративний');

INSERT INTO specializations (name) VALUES ('Терапія'), ('Хірургія'), ('Дерматологія');

INSERT INTO veterinarians (user_id, first_name, last_name, phone, license_no, hired_at) VALUES
 (2, 'Олексій', 'Іваненко',  '+380501112233', 'VL-1001', '2022-03-01'),
 (3, 'Марія',   'Коваленко', '+380672223344', 'VL-1002', '2023-06-15');

INSERT INTO veterinarian_specializations (veterinarian_id, specialization_id) VALUES
 (1, 1), (1, 2), (2, 1), (2, 3);

INSERT INTO owners (first_name, last_name, phone, email, address, created_by) VALUES
 ('Андрій',  'Шевченко', '+380931234567', 'a.shevchenko@mail.com', 'Одеса, вул. Дерибасівська 5',  1),
 ('Олена',   'Мельник',  '+380502345678', 'o.melnyk@mail.com',     'Одеса, вул. Рішельєвська 12',  1),
 ('Ігор',    'Бондар',   '+380633456789', NULL,                    'Одеса, вул. Преображенська 3',        1),
 ('Наталія', 'Ткачук',   '+380674567890', 'n.tkachuk@mail.com',    'Чорноморськ, вул. Паркова 7',  1);

INSERT INTO pets (owner_id, breed_id, name, birth_date, sex, weight_kg, microchip_no, created_by) VALUES
 (1, 1, 'Рекс',   '2020-04-12', 'male',   32.50, '980000000000001', 1),
 (1, 4, 'Мурка',  '2021-08-03', 'female',  4.20, '980000000000002', 1),
 (2, 3, 'Бусинка','2022-01-20', 'female',  2.10, '980000000000003', 1),
 (3, 2, 'Грім',   '2019-11-05', 'male',   38.00, '980000000000004', 1),
 (4, 6, 'Пухнастик','2023-05-30','unknown',1.60, NULL,              1);

INSERT INTO medications (name, form, unit, stock_qty, unit_price) VALUES
 ('Амоксицилін 250 мг', 'таблетки', 'шт', 200.00,  6.50),
 ('Мелоксикам',         'суспензія','мл', 150.00,  4.80),
 ('Дротаверин',         'ін''єкція','мл',  60.00, 12.00),
 ('Фронтлайн Комбо',    'краплі',   'шт',  40.00, 220.00),
 ('Регідрон',           'порошок',  'шт',  80.00,  18.00);

INSERT INTO services (name, price) VALUES
 ('Первинний огляд',           400.00),
 ('УЗД',                       700.00),
 ('Загальний аналіз крові',    550.00),
 ('Вакцинація (послуга)',      300.00),
 ('Обробка від паразитів',     250.00);


INSERT INTO appointments (pet_id, vet_id, start_time, end_time, status, reason, created_by) VALUES
 (1, 1, '2026-10-05 10:00+03', '2026-10-05 10:30+03', 'completed', 'Кульгавість задньої лапи',   4),
 (3, 2, '2026-10-06 11:00+03', '2026-10-06 11:45+03', 'completed', 'Свербіж, випадіння шерсті',  4),
 (2, 1, '2026-10-14 15:00+03', '2026-10-14 15:30+03', 'scheduled', 'Плановий огляд',             4),
 (4, 1, '2026-10-16 09:00+03', '2026-10-16 09:45+03', 'scheduled', 'Вакцинація',                 4),
 (5, 2, '2026-10-16 09:30+03', '2026-10-16 10:00+03', 'scheduled', 'Відмова від їжі',            4);

INSERT INTO medical_records (appointment_id, complaints, diagnosis, notes, created_by) VALUES
 (1, 'Кульгає на праву задню лапу 3 дні', 'Розтягнення зв''язок', 'Обмежити навантаження 2 тижні', 2),
 (2, 'Свербіж, місцеве облисіння',        'Алергічний дерматит',  'Повторний огляд через 10 днів', 3);

INSERT INTO prescriptions (medical_record_id, medication_id, dosage, duration_days, quantity, instructions) VALUES
 (1, 2, '0.1 мл/кг раз на добу', 5, 16.00, 'Давати з їжею'),
 (2, 1, '1 таблетка двічі на день', 7, 14.00, NULL),
 (2, 2, '0.05 мл/кг раз на добу', 5,  2.00, 'Давати з їжею');


INSERT INTO vaccinations (pet_id, vet_id, appointment_id, vaccine_name, batch_no, vaccinated_on, next_due_date) VALUES
 (1, 1, NULL, 'Nobivac DHPPi+L', 'B1001', '2025-09-10', '2026-09-10'),
 (2, 1, NULL, 'Nobivac Tricat',  'B2002', '2026-05-01', '2027-05-01'),
 (3, 2, NULL, 'Eurican DAPPi',   'B3003', '2025-08-01', '2026-08-01');

INSERT INTO appointment_services (appointment_id, service_id, quantity, unit_price) VALUES
 (1, 1, 1, 400.00),
 (1, 2, 1, 700.00),
 (2, 1, 1, 400.00),
 (2, 3, 1, 550.00);

INSERT INTO invoices (appointment_id, subtotal, discount_percent, total, status, created_by) VALUES
 (1, 1100.00, 10.00,  990.00, 'paid',           4),
 (2,  950.00,  0.00,  950.00, 'partially_paid', 4);

INSERT INTO payments (invoice_id, amount, method, created_by) VALUES
 (1, 990.00, 'card', 4),
 (2, 500.00, 'cash', 4);
