DROP DATABASE IF EXISTS railway_corridor;
CREATE DATABASE railway_corridor CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE railway_corridor;

-- 1. Country
CREATE TABLE Country (
    country_id   INT          PRIMARY KEY AUTO_INCREMENT,
    country_name VARCHAR(100) NOT NULL,
    country_code CHAR(3)      NOT NULL UNIQUE
);

-- 2. Station
-- station_type: passenger | freight | port | customs | historical | border
CREATE TABLE Station (
    station_id   INT          PRIMARY KEY AUTO_INCREMENT,
    station_name VARCHAR(100) NOT NULL,
    city         VARCHAR(100) NOT NULL,
    country_id   INT          NOT NULL,
    station_type VARCHAR(20)  NOT NULL DEFAULT 'passenger',
    is_border    TINYINT(1)   NOT NULL DEFAULT 0,
    is_active    TINYINT(1)   NOT NULL DEFAULT 1,
    CONSTRAINT fk_station_country FOREIGN KEY (country_id) REFERENCES Country(country_id),
    CONSTRAINT chk_station_type   CHECK (station_type IN ('passenger','freight','port','customs','historical','border'))
);

-- 3. TrackSegment
-- One direct track between any two connected stations.
CREATE TABLE TrackSegment (
    track_id              INT           PRIMARY KEY AUTO_INCREMENT,
    station_from          INT           NOT NULL,
    station_to            INT           NOT NULL,
    distance_km           DECIMAL(8,2)  NOT NULL,
    electrified           TINYINT(1)    NOT NULL DEFAULT 0,
    max_speed_passenger   INT,          -- km/h
    max_speed_freight     INT,          -- km/h
    track_status          VARCHAR(20)   NOT NULL DEFAULT 'active',
    CONSTRAINT fk_track_from   FOREIGN KEY (station_from) REFERENCES Station(station_id),
    CONSTRAINT fk_track_to     FOREIGN KEY (station_to)   REFERENCES Station(station_id),
    CONSTRAINT chk_diff_stations CHECK (station_from <> station_to),
    CONSTRAINT chk_distance      CHECK (distance_km > 0),
    CONSTRAINT chk_track_status  CHECK (track_status IN ('active','maintenance','closed'))
);

-- 4. Train
-- train_type: passenger | freight | mixed
CREATE TABLE Train (
    train_id    INT          PRIMARY KEY AUTO_INCREMENT,
    train_name  VARCHAR(100) NOT NULL UNIQUE,
    train_type  VARCHAR(20)  NOT NULL,
    total_seats INT,
    status      VARCHAR(20)  NOT NULL DEFAULT 'active',
    CONSTRAINT chk_train_type   CHECK (train_type IN ('passenger','freight','mixed')),
    CONSTRAINT chk_train_status CHECK (status IN ('active','maintenance','retired')),
    CONSTRAINT chk_seats        CHECK (total_seats IS NULL OR total_seats > 0)
);

-- 5. RouteStop  (ordered stations for each train)
-- stop_sequence defines travel order.
CREATE TABLE RouteStop (
    stop_id              INT PRIMARY KEY AUTO_INCREMENT,
    train_id             INT NOT NULL,
    station_id           INT NOT NULL,
    stop_sequence        INT NOT NULL,
    arrival_offset_min   INT,   -- minutes from departure of train
    departure_offset_min INT,
    CONSTRAINT fk_routestop_train   FOREIGN KEY (train_id)   REFERENCES Train(train_id),
    CONSTRAINT fk_routestop_station FOREIGN KEY (station_id) REFERENCES Station(station_id),
    CONSTRAINT uq_train_sequence    UNIQUE (train_id, stop_sequence),
    CONSTRAINT uq_train_station     UNIQUE (train_id, station_id)
);

-- 6. Schedule  (one trip = one train on one date)
CREATE TABLE Schedule (
    schedule_id    INT         PRIMARY KEY AUTO_INCREMENT,
    train_id       INT         NOT NULL,
    travel_date    DATE        NOT NULL,
    departure_time TIME        NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    CONSTRAINT fk_schedule_train FOREIGN KEY (train_id) REFERENCES Train(train_id),
    CONSTRAINT chk_sched_status  CHECK (status IN ('scheduled','running','completed','cancelled'))
);

-- 7. Passenger  (includes loyalty account — merged for simplicity)
-- loyalty_class: none | green (10k mi) | silver (50k mi) | gold (100k mi)
CREATE TABLE Passenger (
    passenger_id    INT          PRIMARY KEY AUTO_INCREMENT,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    phone           VARCHAR(20),
    passport_no     VARCHAR(30)  NOT NULL UNIQUE,
    nationality     VARCHAR(50),
    password_hash   VARCHAR(255) NOT NULL,
    total_miles     INT          NOT NULL DEFAULT 0,
    loyalty_class   VARCHAR(10)  NOT NULL DEFAULT 'none',
    account_created DATE         NOT NULL,
    CONSTRAINT chk_loyalty  CHECK (loyalty_class IN ('none','green','silver','gold')),
    CONSTRAINT chk_miles    CHECK (total_miles >= 0)
);

-- 8. Dependent  (family member traveling with main passenger)
-- Gets 25% discount when traveling with the main passenger.
CREATE TABLE Dependent (
    dependent_id INT          PRIMARY KEY AUTO_INCREMENT,
    passenger_id INT          NOT NULL,
    full_name    VARCHAR(100) NOT NULL,
    birth_date   DATE,
    relation     VARCHAR(30),
    CONSTRAINT fk_dep_passenger FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id)
);

-- 9. Reservation  (ticket info embedded — merged for simplicity)
-- Seat uniqueness per schedule enforced via UNIQUE constraint.
CREATE TABLE Reservation (
    reservation_id INT           PRIMARY KEY AUTO_INCREMENT,
    passenger_id   INT           NOT NULL,
    schedule_id    INT           NOT NULL,
    from_station   INT           NOT NULL,
    to_station     INT           NOT NULL,
    seat_number    VARCHAR(10)   NOT NULL,
    coach_type     VARCHAR(20)   NOT NULL DEFAULT 'economy',
    ticket_price   DECIMAL(10,2) NOT NULL,
    payment_status VARCHAR(20)   NOT NULL DEFAULT 'pending',
    ticket_status  VARCHAR(20)   NOT NULL DEFAULT 'temporary',
    booking_date   DATETIME      NOT NULL,
    expiry_date    DATETIME      NOT NULL,
    dependent_id   INT,          -- NULL if no dependent on this booking
    CONSTRAINT fk_res_passenger  FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id),
    CONSTRAINT fk_res_schedule   FOREIGN KEY (schedule_id)  REFERENCES Schedule(schedule_id),
    CONSTRAINT fk_res_from       FOREIGN KEY (from_station) REFERENCES Station(station_id),
    CONSTRAINT fk_res_to         FOREIGN KEY (to_station)   REFERENCES Station(station_id),
    CONSTRAINT fk_res_dependent  FOREIGN KEY (dependent_id) REFERENCES Dependent(dependent_id),
    -- Business Rule 6: seat cannot be assigned twice for same train + date
    CONSTRAINT uq_seat           UNIQUE (schedule_id, seat_number),
    CONSTRAINT chk_coach_type    CHECK (coach_type    IN ('economy','business','first','sleeper')),
    CONSTRAINT chk_pay_status    CHECK (payment_status IN ('pending','completed','failed','refunded')),
    CONSTRAINT chk_ticket_status CHECK (ticket_status  IN ('temporary','confirmed','canceled','used')),
    CONSTRAINT chk_price         CHECK (ticket_price > 0)
);

-- 10. Luggage
CREATE TABLE Luggage (
    luggage_id     INT          PRIMARY KEY AUTO_INCREMENT,
    reservation_id INT          NOT NULL,
    weight_kg      DECIMAL(5,2) NOT NULL,
    description    VARCHAR(200),
    CONSTRAINT fk_luggage_res    FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id),
    CONSTRAINT chk_luggage_wt    CHECK (weight_kg > 0)
);

-- 11. Payment
-- One payment record per reservation (1-to-1).
CREATE TABLE Payment (
    payment_id     INT           PRIMARY KEY AUTO_INCREMENT,
    reservation_id INT           NOT NULL UNIQUE,
    amount         DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(30)   NOT NULL,
    payment_date   DATETIME,
    status         VARCHAR(20)   NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_payment_res  FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id),
    CONSTRAINT chk_pay_method  CHECK (payment_method IN ('credit_card','debit_card','bank_transfer','cash')),
    CONSTRAINT chk_pay_st      CHECK (status IN ('pending','completed','failed','refunded')),
    CONSTRAINT chk_pay_amount  CHECK (amount > 0)
);

-- 12. WaitingList
-- Created when no seat is available (Business Rule 8).
CREATE TABLE WaitingList (
    waiting_id   INT         PRIMARY KEY AUTO_INCREMENT,
    passenger_id INT         NOT NULL,
    schedule_id  INT         NOT NULL,
    from_station INT         NOT NULL,
    to_station   INT         NOT NULL,
    coach_type   VARCHAR(20) NOT NULL DEFAULT 'economy',
    request_date DATETIME    NOT NULL,
    position     INT         NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'waiting',
    CONSTRAINT fk_wl_passenger FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id),
    CONSTRAINT fk_wl_schedule  FOREIGN KEY (schedule_id)  REFERENCES Schedule(schedule_id),
    CONSTRAINT fk_wl_from      FOREIGN KEY (from_station) REFERENCES Station(station_id),
    CONSTRAINT fk_wl_to        FOREIGN KEY (to_station)   REFERENCES Station(station_id),
    CONSTRAINT chk_wl_status   CHECK (status IN ('waiting','promoted','cancelled')),
    CONSTRAINT chk_position    CHECK (position > 0)
);

-- 13. Staff
-- role: driver | engineer | station_manager | customs_coordinator |
--       maintenance_technician | admin
CREATE TABLE Staff (
    staff_id      INT          PRIMARY KEY AUTO_INCREMENT,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    phone         VARCHAR(20),
    role          VARCHAR(30)  NOT NULL,
    country_id    INT          NOT NULL,
    hire_date     DATE         NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    CONSTRAINT fk_staff_country FOREIGN KEY (country_id) REFERENCES Country(country_id),
    CONSTRAINT chk_staff_role   CHECK (role IN (
        'driver','engineer','station_manager',
        'customs_coordinator','maintenance_technician','admin'
    ))
);

-- 14. StaffAssignment
-- Business Rule 13: staff cannot be on two trains same day.
-- Enforced by UNIQUE (staff_id, travel_date).
CREATE TABLE StaffAssignment (
    assignment_id INT         PRIMARY KEY AUTO_INCREMENT,
    staff_id      INT         NOT NULL,
    train_id      INT         NOT NULL,
    travel_date   DATE        NOT NULL,
    role_on_trip  VARCHAR(30),
    CONSTRAINT fk_sa_staff    FOREIGN KEY (staff_id)  REFERENCES Staff(staff_id),
    CONSTRAINT fk_sa_train    FOREIGN KEY (train_id)  REFERENCES Train(train_id),
    CONSTRAINT uq_staff_date  UNIQUE (staff_id, travel_date)
);

-- 15. FreightShipment
CREATE TABLE FreightShipment (
    shipment_id       INT           PRIMARY KEY AUTO_INCREMENT,
    shipper_name      VARCHAR(100)  NOT NULL,
    origin_station    INT           NOT NULL,
    destination_station INT         NOT NULL,
    cargo_type        VARCHAR(50)   NOT NULL,
    weight_kg         DECIMAL(10,2) NOT NULL,
    container_count   INT           NOT NULL DEFAULT 1,
    status            VARCHAR(20)   NOT NULL DEFAULT 'pending',
    train_id          INT,
    schedule_id       INT,
    CONSTRAINT fk_fs_origin  FOREIGN KEY (origin_station)      REFERENCES Station(station_id),
    CONSTRAINT fk_fs_dest    FOREIGN KEY (destination_station) REFERENCES Station(station_id),
    CONSTRAINT fk_fs_train   FOREIGN KEY (train_id)            REFERENCES Train(train_id),
    CONSTRAINT fk_fs_sched   FOREIGN KEY (schedule_id)         REFERENCES Schedule(schedule_id),
    CONSTRAINT chk_fs_status CHECK (status IN ('pending','in_transit','delivered','held','cancelled')),
    CONSTRAINT chk_fs_weight CHECK (weight_kg > 0),
    CONSTRAINT chk_fs_cont   CHECK (container_count > 0)
);

-- 16. CustomsClearance
-- Business Rule 11: cross-border shipment must have >= 1 record here.
CREATE TABLE CustomsClearance (
    clearance_id       INT          PRIMARY KEY AUTO_INCREMENT,
    shipment_id        INT          NOT NULL,
    checkpoint_station INT          NOT NULL,
    inspection_date    DATE         NOT NULL,
    clearance_status   VARCHAR(20)  NOT NULL DEFAULT 'pending',
    document_ref       VARCHAR(100),
    fee                DECIMAL(10,2) DEFAULT 0.00,
    remarks            TEXT,
    CONSTRAINT fk_cc_shipment    FOREIGN KEY (shipment_id)        REFERENCES FreightShipment(shipment_id),
    CONSTRAINT fk_cc_checkpoint  FOREIGN KEY (checkpoint_station) REFERENCES Station(station_id),
    CONSTRAINT chk_cc_status     CHECK (clearance_status IN ('pending','cleared','rejected','under_review')),
    CONSTRAINT chk_cc_fee        CHECK (fee >= 0)
);

-- 17. MaintenanceRecord
-- Covers trains, stations, AND tracks (sensor readings included).
-- At least one target (train/station/track) must be set.
CREATE TABLE MaintenanceRecord (
    record_id        INT         PRIMARY KEY AUTO_INCREMENT,
    train_id         INT,        -- target: train (nullable)
    station_id       INT,        -- target: station (nullable)
    track_id         INT,        -- target: track (nullable)
    maintenance_type VARCHAR(50) NOT NULL,
    start_date       DATE        NOT NULL,
    end_date         DATE,
    technician_id    INT,
    status           VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    sensor_type      VARCHAR(50),   -- e.g. 'vibration','brake','heat','signal'
    sensor_value     VARCHAR(100),  -- raw reading value
    notes            TEXT,
    CONSTRAINT fk_mr_train       FOREIGN KEY (train_id)      REFERENCES Train(train_id),
    CONSTRAINT fk_mr_station     FOREIGN KEY (station_id)    REFERENCES Station(station_id),
    CONSTRAINT fk_mr_track       FOREIGN KEY (track_id)      REFERENCES TrackSegment(track_id),
    CONSTRAINT fk_mr_technician  FOREIGN KEY (technician_id) REFERENCES Staff(staff_id),
    CONSTRAINT chk_mr_status     CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
    -- At least one target must be specified
    CONSTRAINT chk_mr_target     CHECK (
        train_id IS NOT NULL OR station_id IS NOT NULL OR track_id IS NOT NULL
    )
);
