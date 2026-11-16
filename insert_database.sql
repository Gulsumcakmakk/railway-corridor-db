USE railway_corridor;

-- Mantıksal bağımlılık sırasına göre eklemeler yapılıyor.
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE CustomsClearance;
TRUNCATE TABLE MaintenanceRecord;
TRUNCATE TABLE FreightShipment;
TRUNCATE TABLE WaitingList;
TRUNCATE TABLE Payment;
TRUNCATE TABLE Luggage;
TRUNCATE TABLE Reservation;
TRUNCATE TABLE Dependent;
TRUNCATE TABLE Passenger;
TRUNCATE TABLE StaffAssignment;
TRUNCATE TABLE Staff;
TRUNCATE TABLE RouteStop;
TRUNCATE TABLE Schedule;
TRUNCATE TABLE Train;
TRUNCATE TABLE TrackSegment;
TRUNCATE TABLE Station;
TRUNCATE TABLE Country;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. Country 
INSERT INTO Country (country_id, country_name, country_code) VALUES
(1, 'Saudi Arabia', 'SAU'),
(2, 'Jordan', 'JOR'),
(3, 'Syria', 'SYR'),
(4, 'Turkey', 'TUR');

-- 2. Station
INSERT INTO Station (station_id, station_name, city, country_id, station_type, is_border, is_active) VALUES
(1, 'Jeddah Port', 'Jeddah', 1, 'port', 0, 1),
(2, 'Tabuk Border', 'Tabuk', 1, 'border', 1, 1),
(3, 'Aqaba Hub', 'Aqaba', 2, 'freight', 0, 1),
(4, 'Amman Station', 'Amman', 2, 'passenger', 0, 1),
(5, 'Damascus Station', 'Damascus', 3, 'passenger', 0, 1),
(6, 'Istanbul Station', 'Istanbul', 4, 'historical', 0, 1);

-- 3. TrackSegment 
INSERT INTO TrackSegment (track_id, station_from, station_to, distance_km, electrified, max_speed_passenger, max_speed_freight, track_status) VALUES
(1, 1, 2, 600.00, 1, 250, 120, 'active'),
(2, 2, 3, 350.00, 0, 140, 90, 'active'),
(3, 3, 4, 330.00, 0, 140, 90, 'active'),
(4, 4, 5, 200.00, 0, 120, 80, 'active');

-- 4. Train
INSERT INTO Train (train_id, train_name, train_type, total_seats, status) VALUES
(1, 'Desert Express', 'passenger', 100, 'active'),
(2, 'Silk Road Freight', 'freight', NULL, 'active'),
(3, 'Corridor Mixed', 'mixed', 50, 'active');

-- 5. RouteStop 
INSERT INTO RouteStop (train_id, station_id, stop_sequence, arrival_offset_min, departure_offset_min) VALUES
(1, 1, 1, NULL, 0),
(1, 2, 2, 180, 200),
(1, 4, 3, 400, NULL),
(2, 1, 1, NULL, 0),
(2, 3, 2, 300, 360),
(2, 5, 3, 700, NULL);

-- 6. Schedule 
INSERT INTO Schedule (schedule_id, train_id, travel_date, departure_time, status) VALUES
(1, 1, '2026-08-01', '08:00:00', 'scheduled'),
(2, 2, '2026-08-02', '06:00:00', 'scheduled'),
(3, 1, '2026-08-15', '08:00:00', 'scheduled');

-- 7. Passenger
INSERT INTO Passenger (passenger_id, first_name, last_name, email, phone, passport_no, nationality, password_hash, total_miles, loyalty_class, account_created) VALUES
(1, 'Ahmed', 'Al-Rashid', 'ahmed@mail.com', '+966501', 'SA1001', 'Saudi', 'hash1', 12000, 'green', '2025-01-01'),
(2, 'Fatima', 'Al-Zahra', 'fatima@mail.com', '+966502', 'SA1002', 'Saudi', 'hash2', 55000, 'silver', '2025-02-01'),
(3, 'Omar', 'Khalil', 'omar@mail.com', '+962791', 'JO1003', 'Jordanian', 'hash3', 2000, 'none', '2025-03-01'),
(4, 'Mehmet', 'Yilmaz', 'mehmet@mail.com', '+905301', 'TR1005', 'Turkish', 'hash4', 105000, 'gold', '2025-04-01');

-- 8. Dependent 
INSERT INTO Dependent (dependent_id, passenger_id, full_name, birth_date, relation) VALUES
(1, 1, 'Ali Al-Rashid', '2015-05-20', 'son'),
(2, 4, 'Zeynep Yilmaz', '2018-11-01', 'daughter');

-- 9. Reservation 
INSERT INTO Reservation (reservation_id, passenger_id, schedule_id, from_station, to_station, seat_number, coach_type, ticket_price, payment_status, ticket_status, booking_date, expiry_date, dependent_id) VALUES
(1, 1, 1, 1, 4, 'A01', 'first', 300.00, 'completed', 'confirmed', '2026-07-20 10:00:00', '2026-07-22 10:00:00', NULL),
(2, 1, 1, 1, 4, 'A02', 'first', 225.00, 'completed', 'confirmed', '2026-07-20 10:00:00', '2026-07-22 10:00:00', 1), -- Bağımlı yolcu (İndirimli fiyat)
(3, 2, 1, 1, 4, 'B01', 'business', 200.00, 'pending', 'temporary', '2026-07-21 09:00:00', '2026-07-23 09:00:00', NULL),
(4, 3, 3, 1, 4, 'C01', 'economy', 100.00, 'failed', 'canceled', '2026-07-22 11:00:00', '2026-07-24 11:00:00', NULL);

-- 10. Luggage 
INSERT INTO Luggage (luggage_id, reservation_id, weight_kg, description) VALUES
(1, 1, 20.50, 'Large Suitcase'),
(2, 2, 10.00, 'Small Backpack');

-- 11. Payment 
INSERT INTO Payment (payment_id, reservation_id, amount, payment_method, payment_date, status) VALUES
(1, 1, 300.00, 'credit_card', '2026-07-20 10:15:00', 'completed'),
(2, 2, 225.00, 'credit_card', '2026-07-20 10:15:00', 'completed'),
(3, 3, 200.00, 'debit_card', NULL, 'pending');

-- 12. WaitingList 
INSERT INTO WaitingList (waiting_id, passenger_id, schedule_id, from_station, to_station, coach_type, request_date, position, status) VALUES
(1, 4, 1, 1, 4, 'first', '2026-07-25 14:00:00', 1, 'waiting'),
(2, 3, 1, 1, 4, 'first', '2026-07-25 15:00:00', 2, 'waiting');

-- 13. Staff 
INSERT INTO Staff (staff_id, first_name, last_name, email, phone, role, country_id, hire_date, password_hash) VALUES
(1, 'Saud', 'Al-Ghamdi', 'saud@rw.sa', '+96611', 'driver', 1, '2020-01-01', 'staffhash1'),
(2, 'Tariq', 'Farouq', 'tariq@rw.jo', '+96222', 'engineer', 2, '2021-05-10', 'staffhash2'),
(3, 'Emre', 'Sahin', 'emre@rw.tr', '+90555', 'admin', 4, '2019-03-15', 'staffhash3');

-- 14. StaffAssignment
INSERT INTO StaffAssignment (assignment_id, staff_id, train_id, travel_date, role_on_trip) VALUES
(1, 1, 1, '2026-08-01', 'Lead Driver'),
(2, 2, 1, '2026-08-01', 'On-Board Engineer');

-- 15. FreightShipment 
INSERT INTO FreightShipment (shipment_id, shipper_name, origin_station, destination_station, cargo_type, weight_kg, container_count, status, train_id, schedule_id) VALUES
(1, 'Red Sea Logistics', 1, 5, 'Electronics', 15000.00, 2, 'in_transit', 2, 2),
(2, 'Gulf Trade Co.', 3, 5, 'Machinery', 30000.00, 4, 'pending', 2, 2);

-- 16. CustomsClearance 
INSERT INTO CustomsClearance (clearance_id, shipment_id, checkpoint_station, inspection_date, clearance_status, document_ref, fee, remarks) VALUES
(1, 1, 2, '2026-08-02', 'cleared', 'DOC-991', 500.00, 'Passed inspection'),
(2, 2, 2, '2026-08-02', 'pending', 'DOC-992', 0.00, 'Awaiting papers');

-- 17. MaintenanceRecord 
INSERT INTO MaintenanceRecord (record_id, train_id, station_id, track_id, maintenance_type, start_date, end_date, technician_id, status, sensor_type, sensor_value, notes) VALUES
(1, 1, NULL, NULL, 'Brake Inspection', '2026-07-15', '2026-07-15', 2, 'completed', 'brake', '4.2 bar', 'All good'),
(2, NULL, 1, NULL, 'Platform Repair', '2026-07-20', '2026-07-22', 2, 'completed', NULL, NULL, 'Repainted lines'),
(3, NULL, NULL, 1, 'Track Alignment', '2026-07-25', NULL, 2, 'scheduled', 'track_condition', '8.0', 'Routine check');
