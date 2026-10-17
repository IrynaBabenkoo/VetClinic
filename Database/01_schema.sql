CREATE EXTENSION IF NOT EXISTS pg_trgm;  

DROP TABLE IF EXISTS payments, invoices, appointment_services, services,
    vaccinations, prescriptions, medications, medical_records, appointments,
    veterinarian_specializations, veterinarians, specializations,
    pets, breeds, species, owners, users, roles CASCADE;

DROP TYPE IF EXISTS pet_sex, appointment_status, invoice_status, payment_method CASCADE;

CREATE TYPE pet_sex            AS ENUM ('male', 'female', 'unknown');
CREATE TYPE appointment_status AS ENUM ('scheduled', 'in_progress', 'completed', 'cancelled', 'no_show');
CREATE TYPE invoice_status     AS ENUM ('draft', 'issued', 'partially_paid', 'paid', 'cancelled');
CREATE TYPE payment_method     AS ENUM ('cash', 'card', 'transfer');


CREATE TABLE roles (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255)
);

CREATE TABLE users (
    id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id       INT          NOT NULL REFERENCES roles(id),
    username      VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ,
    updated_by    INT REFERENCES users(id)
);

CREATE TABLE owners (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(80)  NOT NULL,
    last_name   VARCHAR(80)  NOT NULL,
    phone       VARCHAR(20)  NOT NULL,
    email       VARCHAR(150),
    address     VARCHAR(255),
    -- soft delete
    is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted_at  TIMESTAMPTZ,
    deleted_by  INT REFERENCES users(id),

    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by  INT REFERENCES users(id),
    updated_at  TIMESTAMPTZ,
    updated_by  INT REFERENCES users(id),
    CONSTRAINT ck_owners_soft_delete
        CHECK ((is_deleted = FALSE AND deleted_at IS NULL)
            OR (is_deleted = TRUE  AND deleted_at IS NOT NULL))
);

CREATE TABLE species (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE breeds (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    species_id INT         NOT NULL REFERENCES species(id),
    name       VARCHAR(80) NOT NULL,
    CONSTRAINT uq_breeds_species_name UNIQUE (species_id, name)
);

CREATE TABLE pets (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id     INT         NOT NULL REFERENCES owners(id),
    breed_id     INT         REFERENCES breeds(id),
    name         VARCHAR(80) NOT NULL,
    birth_date   DATE,
    sex          pet_sex     NOT NULL DEFAULT 'unknown',
    weight_kg    NUMERIC(6,2),
    microchip_no VARCHAR(30) UNIQUE,
    -- soft delete
    is_deleted   BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at   TIMESTAMPTZ,
    deleted_by   INT REFERENCES users(id),

    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by   INT REFERENCES users(id),
    updated_at   TIMESTAMPTZ,
    updated_by   INT REFERENCES users(id),
    CONSTRAINT ck_pets_weight      CHECK (weight_kg IS NULL OR weight_kg > 0),
    CONSTRAINT ck_pets_birth       CHECK (birth_date IS NULL OR birth_date <= CURRENT_DATE),
    CONSTRAINT ck_pets_soft_delete
        CHECK ((is_deleted = FALSE AND deleted_at IS NULL)
            OR (is_deleted = TRUE  AND deleted_at IS NOT NULL))
);


CREATE TABLE specializations (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE veterinarians (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    INT         NOT NULL UNIQUE REFERENCES users(id),
    first_name VARCHAR(80) NOT NULL,
    last_name  VARCHAR(80) NOT NULL,
    phone      VARCHAR(20),
    license_no VARCHAR(40) UNIQUE,
    hired_at   DATE        NOT NULL,
    fired_at   DATE,
    -- soft delete
    is_deleted BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by INT REFERENCES users(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    updated_by INT REFERENCES users(id),
    CONSTRAINT ck_vets_dates CHECK (fired_at IS NULL OR fired_at >= hired_at),
    CONSTRAINT ck_vets_soft_delete
        CHECK ((is_deleted = FALSE AND deleted_at IS NULL)
            OR (is_deleted = TRUE  AND deleted_at IS NOT NULL))
);

CREATE TABLE veterinarian_specializations (
    veterinarian_id   INT NOT NULL REFERENCES veterinarians(id),
    specialization_id INT NOT NULL REFERENCES specializations(id),
    PRIMARY KEY (veterinarian_id, specialization_id)
);

CREATE TABLE appointments (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pet_id     INT          NOT NULL REFERENCES pets(id),
    vet_id     INT          NOT NULL REFERENCES veterinarians(id),
    start_time TIMESTAMPTZ  NOT NULL,
    end_time   TIMESTAMPTZ  NOT NULL,
    status     appointment_status NOT NULL DEFAULT 'scheduled',
    reason     VARCHAR(255),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by INT REFERENCES users(id),
    updated_at TIMESTAMPTZ,
    updated_by INT REFERENCES users(id),
    CONSTRAINT ck_appointments_time CHECK (end_time > start_time)
);

CREATE TABLE medical_records (
    id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id INT  NOT NULL UNIQUE REFERENCES appointments(id),
    complaints     TEXT,
    diagnosis      TEXT,
    notes          TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by     INT REFERENCES users(id),
    updated_at     TIMESTAMPTZ,
    updated_by     INT REFERENCES users(id)
);

CREATE TABLE medications (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(120)  NOT NULL UNIQUE,
    form       VARCHAR(40),
    unit       VARCHAR(20)   NOT NULL,
    stock_qty  NUMERIC(10,2) NOT NULL DEFAULT 0,
    unit_price NUMERIC(10,2) NOT NULL,
    is_active  BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_medications_stock CHECK (stock_qty >= 0),
    CONSTRAINT ck_medications_price CHECK (unit_price >= 0)
);

CREATE TABLE prescriptions (
    id                INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medical_record_id INT           NOT NULL REFERENCES medical_records(id),
    medication_id     INT           NOT NULL REFERENCES medications(id),
    dosage            VARCHAR(100)  NOT NULL,
    duration_days     INT           NOT NULL,
    quantity          NUMERIC(10,2) NOT NULL,
    instructions      VARCHAR(255),
    CONSTRAINT ck_prescriptions_duration CHECK (duration_days > 0),
    CONSTRAINT ck_prescriptions_qty      CHECK (quantity > 0)
);

CREATE TABLE vaccinations (
    id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pet_id         INT          NOT NULL REFERENCES pets(id),
    vet_id         INT          NOT NULL REFERENCES veterinarians(id),
    appointment_id INT          REFERENCES appointments(id),
    vaccine_name   VARCHAR(120) NOT NULL,
    batch_no       VARCHAR(40),
    vaccinated_on  DATE         NOT NULL,
    next_due_date  DATE,
    CONSTRAINT ck_vaccinations_dates
        CHECK (next_due_date IS NULL OR next_due_date > vaccinated_on)
);


CREATE TABLE services (
    id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      VARCHAR(120)  NOT NULL UNIQUE,
    price     NUMERIC(10,2) NOT NULL,
    is_active BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_services_price CHECK (price >= 0)
);

CREATE TABLE appointment_services (
    appointment_id INT           NOT NULL REFERENCES appointments(id),
    service_id     INT           NOT NULL REFERENCES services(id),
    quantity       INT           NOT NULL DEFAULT 1,
    unit_price     NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (appointment_id, service_id),
    CONSTRAINT ck_appsvc_qty   CHECK (quantity > 0),
    CONSTRAINT ck_appsvc_price CHECK (unit_price >= 0)
);

CREATE TABLE invoices (
    id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id   INT            NOT NULL UNIQUE REFERENCES appointments(id),
    issued_at        TIMESTAMPTZ    NOT NULL DEFAULT now(),
    subtotal         NUMERIC(12,2)  NOT NULL DEFAULT 0,
    discount_percent NUMERIC(5,2)   NOT NULL DEFAULT 0,
    total            NUMERIC(12,2)  NOT NULL DEFAULT 0,
    status           invoice_status NOT NULL DEFAULT 'draft',
    created_by       INT REFERENCES users(id),
    updated_at       TIMESTAMPTZ,
    updated_by       INT REFERENCES users(id),
    CONSTRAINT ck_invoices_discount CHECK (discount_percent BETWEEN 0 AND 100),
    CONSTRAINT ck_invoices_amounts  CHECK (subtotal >= 0 AND total >= 0)
);

CREATE TABLE payments (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id INT            NOT NULL REFERENCES invoices(id),
    amount     NUMERIC(12,2)  NOT NULL,
    method     payment_method NOT NULL,
    paid_at    TIMESTAMPTZ    NOT NULL DEFAULT now(),
    created_by INT REFERENCES users(id),
    CONSTRAINT ck_payments_amount CHECK (amount > 0)
);

-- B-tree 
CREATE INDEX ix_appointments_vet_time ON appointments (vet_id, start_time);
CREATE INDEX ix_appointments_pet      ON appointments (pet_id);
CREATE INDEX ix_pets_owner            ON pets (owner_id);
CREATE INDEX ix_payments_invoice      ON payments (invoice_id);
CREATE INDEX ix_vaccinations_pet      ON vaccinations (pet_id);
CREATE INDEX ix_vaccinations_next_due ON vaccinations (next_due_date);

CREATE INDEX ix_owners_active_name ON owners (last_name, first_name) WHERE is_deleted = FALSE;
CREATE INDEX ix_owners_active_phone ON owners (phone)                WHERE is_deleted = FALSE;
CREATE INDEX ix_pets_active_owner   ON pets (owner_id, name)         WHERE is_deleted = FALSE;

CREATE INDEX ix_owners_fullname_trgm ON owners
    USING gin ((first_name || ' ' || last_name) gin_trgm_ops);
