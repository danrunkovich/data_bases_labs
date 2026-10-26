DROP TABLE IF EXISTS return_item CASCADE;
DROP TABLE IF EXISTS issuance CASCADE;
DROP TABLE IF EXISTS storage_extension CASCADE;
DROP TABLE IF EXISTS cargo_place CASCADE;
DROP TABLE IF EXISTS departure CASCADE;
DROP TABLE IF EXISTS notification CASCADE;
DROP TABLE IF EXISTS partner_payout CASCADE;
DROP TABLE IF EXISTS collision_act CASCADE;
DROP TABLE IF EXISTS placement CASCADE;
DROP TABLE IF EXISTS receiving_operation CASCADE;
DROP TABLE IF EXISTS courier_trip CASCADE;
DROP TABLE IF EXISTS storage_place CASCADE;
DROP TABLE IF EXISTS partner_contract CASCADE;
DROP TABLE IF EXISTS client CASCADE;
DROP TABLE IF EXISTS transfer_registry CASCADE;
DROP TABLE IF EXISTS pickup_point CASCADE;
DROP TABLE IF EXISTS partner CASCADE;


-- E1. Партнер
CREATE TABLE partner (
    partner_id INT GENERATED ALWAYS AS IDENTITY,
    org_name VARCHAR(100) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL,

    CONSTRAINT pk_partner PRIMARY KEY (partner_id),
    CONSTRAINT chk_patner_phone CHECK (phone ~ '^((\+7)|(8))\d{10}$'),
    CONSTRAINT chk_partner_status CHECK (status IN ('заблокирован', 'активен', 'неактивен'))
);

-- E3. Пункт выдачи
CREATE TABLE pickup_point (
    point_id INT GENERATED ALWAYS AS IDENTITY,
    address TEXT NOT NULL UNIQUE,
    status VARCHAR(30) NOT NULL,

    CONSTRAINT pk_pickup_point PRIMARY KEY (point_id),
    CONSTRAINT chk_pickup_point_status CHECK (status IN ('работает', 'не работает', 'на техническом осмотре'))
);

-- E7. Реестр передачи
CREATE TABLE transfer_registry (
    registry_id INT GENERATED ALWAYS AS IDENTITY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_transfer_registry PRIMARY KEY (registry_id)
);

-- E17. Клиент
CREATE TABLE client (
    client_id INT GENERATED ALWAYS AS IDENTITY,
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    age SMALLINT NOT NULL,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT pk_client PRIMARY KEY (client_id),
    CONSTRAINT chk_client_age CHECK (age >= 14),
    CONSTRAINT chk_client_status CHECK (status IN ('заблокирован', 'активен')),
    CONSTRAINT chk_client_phone CHECK (phone ~ '^((\+7)|(8))\d{10}$')
);

-- E2. Договор партнера
CREATE TABLE partner_contract (
    contract_id INT GENERATED ALWAYS AS IDENTITY,
    partner_id INT NOT NULL,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE NOT NULL,
    status VARCHAR(30) NOT NULL,

    CONSTRAINT pk_partner_contract PRIMARY KEY (contract_id),
    CONSTRAINT fk_contract_partner FOREIGN KEY (partner_id)
        REFERENCES partner (partner_id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT chk_contract_dates CHECK (end_date > start_date),
    CONSTRAINT chk_partner_contract_status CHECK (status IN ('расторжен', 'действует', 'истек срок действия'))
);

-- E4. Место хранения
CREATE TABLE storage_place (
    point_id INT NOT NULL,
    place_id INT NOT NULL,
    length_m NUMERIC(4, 3) NOT NULL,
    width_m NUMERIC(4, 3) NOT NULL,
    height_m NUMERIC(4, 3) NOT NULL,
    status VARCHAR(30) NOT NULL,

    CONSTRAINT pk_storage_cell PRIMARY KEY (point_id, place_id),
    CONSTRAINT fk_place_point FOREIGN KEY (point_id)
        REFERENCES pickup_point (point_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_place_parametrs CHECK (length_m > 0 AND width_m > 0 AND height_m > 0 AND length_m < 2 AND width_m < 2 AND height_m < 2),
    CONSTRAINT chk_storage_place_status CHECK (status IN ('свободно', 'занято', 'на техническом осмотре'))
);

-- E8. Курьерский рейс
CREATE TABLE courier_trip (
    trip_id INT GENERATED ALWAYS AS IDENTITY,
    registry_id INT NOT NULL,
    sender_point_id INT NOT NULL,
    receiver_point_id INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    departure_time TIMESTAMPTZ NOT NULL,
    arrival_time TIMESTAMPTZ,

    CONSTRAINT pk_courier_trip PRIMARY KEY (trip_id),
    CONSTRAINT fk_trip_registry FOREIGN KEY (registry_id)
        REFERENCES transfer_registry (registry_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_trip_sender FOREIGN KEY (sender_point_id)
        REFERENCES pickup_point (point_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_trip_receiver FOREIGN KEY (receiver_point_id)
        REFERENCES pickup_point (point_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_trip_dates CHECK (arrival_time IS NULL OR arrival_time >= departure_time),
    CONSTRAINT chk_receiver_isnt_sender CHECK (receiver_point_id <> sender_point_id),
    CONSTRAINT chk_courier_trip_status CHECK (status IN ('запланирован', 'в процессе отправки', 'завершен', 'отменен'))
);

-- E9. Операция приема
CREATE TABLE receiving_operation (
    receiving_op_id INT GENERATED ALWAYS AS IDENTITY,
    registry_id INT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMPTZ,
    status VARCHAR(30) NOT NULL,

    CONSTRAINT pk_receiving_operation PRIMARY KEY (receiving_op_id),
    CONSTRAINT fk_op_registry FOREIGN KEY (registry_id)
        REFERENCES transfer_registry (registry_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_operation_times CHECK (end_time IS NULL OR end_time >= start_time),
    CONSTRAINT chk_receiving_operation_status CHECK (status IN ('в процессе выполнения', 'запланирована', 'отменена', 'проведена'))
);

-- E16. Начисление партнеру
CREATE TABLE partner_payout (
    payout_id INT GENERATED ALWAYS AS IDENTITY,
    contract_id INT NOT NULL,
    registry_id INT NOT NULL,
    amount_rub REAL NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT pk_partner_payout PRIMARY KEY (payout_id),
    CONSTRAINT fk_payout_contract FOREIGN KEY (contract_id)
        REFERENCES partner_contract (contract_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_payout_registry FOREIGN KEY (registry_id)
        REFERENCES transfer_registry (registry_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_accrual_amount CHECK (amount_rub >= 0),
    CONSTRAINT chk_patrner_payout_status CHECK(status IN ('начислено', 'запланировано', 'отменено'))
);

-- E5. Отправление
CREATE TABLE departure (
    partner_id INT NOT NULL,
    departure_id INT NOT NULL,
    registry_id INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    storage_end_date DATE NOT NULL,

    CONSTRAINT pk_departure PRIMARY KEY (partner_id, departure_id),
    CONSTRAINT fk_departure_partner FOREIGN KEY (partner_id)
        REFERENCES partner (partner_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_departure_registry FOREIGN KEY (registry_id)
        REFERENCES transfer_registry (registry_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_departure_status CHECK (status IN ('полностью доставлено', 'частично доставлено', 'не доставлено'))
);

-- E10. Размещение
CREATE TABLE placement (
    placement_id INT GENERATED ALWAYS AS IDENTITY,
    point_id INT NOT NULL,
    place_id INT NOT NULL,
    receiving_op_id INT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT pk_placement PRIMARY KEY (placement_id),
    CONSTRAINT fk_placement_place FOREIGN KEY (point_id, place_id)
        REFERENCES storage_place (point_id, place_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_placement_operation FOREIGN KEY (receiving_op_id)
        REFERENCES receiving_operation (receiving_op_id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT chk_placement_dates CHECK (end_time IS NULL OR end_time >= start_time),
    CONSTRAINT chk_placement_status CHECK (status IN ('проведено', 'не проведено', 'в процессе', 'отменено'))
);

-- E15. Акт расхождения
CREATE TABLE collision_act (
    act_id INT GENERATED ALWAYS AS IDENTITY,
    receiving_op_id INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL,

    CONSTRAINT pk_discrepancy_act PRIMARY KEY (act_id),
    CONSTRAINT fk_act_operation FOREIGN KEY (receiving_op_id)
        REFERENCES receiving_operation (receiving_op_id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT chk_act_status CHECK (status IN ('в силе', 'расторжен'))
);

-- E11. Уведомление
CREATE TABLE notification (
    notification_id INT GENERATED ALWAYS AS IDENTITY,
    client_id INT NOT NULL,
    receiving_op_id INT NOT NULL,
    message_text TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_notification PRIMARY KEY (notification_id),
    CONSTRAINT fk_notification_client FOREIGN KEY (client_id)
        REFERENCES client (client_id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT fk_notification_operation FOREIGN KEY (receiving_op_id)
        REFERENCES receiving_operation (receiving_op_id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

-- E6. Грузовое место
CREATE TABLE cargo_place (
    cargo_place_id INT GENERATED ALWAYS AS IDENTITY,
    partner_id INT NOT NULL,
    departure_id INT NOT NULL,
    min_age SMALLINT NOT NULL DEFAULT 14,
    weight_kg NUMERIC(5, 3) NOT NULL,
    length_m NUMERIC(4, 3) NOT NULL,
    width_m NUMERIC(4, 3) NOT NULL,
    height_m NUMERIC(4, 3) NOT NULL,
    description TEXT,

    CONSTRAINT pk_cargo_place PRIMARY KEY (cargo_place_id),
    CONSTRAINT fk_cargo_departure FOREIGN KEY (partner_id, departure_id)
        REFERENCES departure (partner_id, departure_id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT chk_place_weight CHECK (weight_kg > 0),
    CONSTRAINT chk_place_dimensions CHECK (length_m > 0 AND width_m > 0 AND height_m > 0 AND length_m < 2 AND width_m < 2 AND height_m < 2)
);

-- E13. Продление хранения отправления
CREATE TABLE storage_extension (
    extension_id INT GENERATED ALWAYS AS IDENTITY,
    partner_id INT NOT NULL,
    departure_id INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_end_date DATE NOT NULL,
    new_end_date DATE NOT NULL,
    reason TEXT,

    CONSTRAINT pk_storage_extension PRIMARY KEY (extension_id),
    CONSTRAINT fk_extension_departure FOREIGN KEY (partner_id, departure_id)
        REFERENCES departure (partner_id, departure_id)
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT chk_extension_dates CHECK (new_end_date > old_end_date)
);


-- E12. Выдача
CREATE TABLE issuance (
    cargo_place_id INT NOT NULL,
    client_id INT NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT pk_issuance PRIMARY KEY (cargo_place_id),
    CONSTRAINT fk_issuance_place FOREIGN KEY (cargo_place_id)
        REFERENCES cargo_place (cargo_place_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_issuance_client FOREIGN KEY (client_id)
        REFERENCES client (client_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_issuance_status CHECK (status IN ('проведена', 'не проведена'))
);

-- E14. Возврат
CREATE TABLE return_item (
    cargo_place_id INT NOT NULL,
    return_id INT NOT NULL,
    client_id INT NOT NULL,
    returned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT pk_return_item PRIMARY KEY (cargo_place_id, return_id),
    CONSTRAINT fk_return_place FOREIGN KEY (cargo_place_id)
        REFERENCES cargo_place (cargo_place_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_return_client FOREIGN KEY (client_id)
        REFERENCES client (client_id)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT chk_return_status CHECK (status IN ('проведен', 'не проведен'))
);
