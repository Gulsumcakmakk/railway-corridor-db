USE railway_corridor;

-- 1. Seçilen tarihte aktif trenler
SELECT t.train_id, t.train_name, t.train_type, s.departure_time, s.status
FROM Schedule s JOIN Train t ON s.train_id = t.train_id
WHERE s.travel_date = '2026-08-01' AND s.status != 'cancelled';

-- 2. Seçilen trenin güzergah sırası
SELECT rs.stop_sequence, st.station_name, st.city, c.country_name,
       rs.arrival_offset_min, rs.departure_offset_min
FROM RouteStop rs
JOIN Station st ON rs.station_id = st.station_id
JOIN Country c  ON st.country_id = c.country_id
WHERE rs.train_id = 1
ORDER BY rs.stop_sequence;

-- 3. Seçilen yolcunun rezervasyon detayları
SELECT r.reservation_id, t.train_name, s.travel_date,
       sf.station_name AS from_stn, st2.station_name AS to_stn,
       r.seat_number, r.coach_type, r.ticket_price, r.payment_status, r.ticket_status
FROM Reservation r
JOIN Schedule s   ON r.schedule_id  = s.schedule_id
JOIN Train t      ON s.train_id     = t.train_id
JOIN Station sf   ON r.from_station = sf.station_id
JOIN Station st2  ON r.to_station   = st2.station_id
WHERE r.passenger_id = 1;

-- 4. Bekleme listesi (tren, tarih, loyalty sınıfına göre)
SELECT wl.waiting_id, wl.position, p.first_name, p.last_name,
       p.loyalty_class, t.train_name, s.travel_date, wl.coach_type, wl.status
FROM WaitingList wl
JOIN Passenger p ON wl.passenger_id = p.passenger_id
JOIN Schedule s  ON wl.schedule_id  = s.schedule_id
JOIN Train t     ON s.train_id      = t.train_id
ORDER BY s.travel_date, wl.position;

-- 5. Ortalama doluluk oranı (seçilen tarih)
SELECT t.train_name, t.total_seats,
       COUNT(r.reservation_id) AS booked,
       ROUND(COUNT(r.reservation_id) * 100.0 / t.total_seats, 1) AS load_pct
FROM Schedule s
JOIN Train t ON s.train_id = t.train_id
LEFT JOIN Reservation r ON r.schedule_id = s.schedule_id AND r.ticket_status = 'confirmed'
WHERE s.travel_date = '2026-08-01' AND t.total_seats IS NOT NULL
GROUP BY t.train_id, t.train_name, t.total_seats;

-- 6. Seçilen tarihte bağımlı yolcular
SELECT s.travel_date, t.train_name,
       p.first_name AS main_passenger, d.full_name AS dependent, d.relation,
       r.seat_number, r.ticket_price
FROM Reservation r
JOIN Passenger p ON r.passenger_id = p.passenger_id
JOIN Dependent d ON r.dependent_id = d.dependent_id
JOIN Schedule s  ON r.schedule_id  = s.schedule_id
JOIN Train t     ON s.train_id     = t.train_id
WHERE s.travel_date = '2026-08-15';

-- 7. Seçilen ülke sınırını geçen kargo gönderimleri
SELECT fs.shipment_id, fs.shipper_name, fs.cargo_type, fs.weight_kg,
       fs.container_count, fs.status,
       so.station_name AS origin, sd.station_name AS destination
FROM FreightShipment fs
JOIN Station so ON fs.origin_station      = so.station_id
JOIN Station sd ON fs.destination_station = sd.station_id
WHERE so.country_id != sd.country_id
  AND (so.country_id = 1 OR sd.country_id = 1);  -- Suudi sınırı örneği

-- 8. Seçilen gönderi için gümrük durumu
SELECT cc.clearance_id, st.station_name AS checkpoint,
       cc.inspection_date, cc.clearance_status, cc.document_ref, cc.fee
FROM CustomsClearance cc
JOIN Station st ON cc.checkpoint_station = st.station_id
WHERE cc.shipment_id = 1;

-- 9. Seçilen tren/hat için bakım geçmişi
SELECT mr.record_id, mr.maintenance_type, mr.start_date, mr.end_date,
       mr.status, mr.sensor_type, mr.sensor_value, mr.notes
FROM MaintenanceRecord mr
WHERE mr.train_id = 1
ORDER BY mr.start_date DESC;

-- 10. Seçilen tarihte trenlere atanan personel
SELECT t.train_name, s2.travel_date,
       sf.first_name, sf.last_name, sf.role, sa.role_on_trip
FROM StaffAssignment sa
JOIN Staff sf   ON sa.staff_id  = sf.staff_id
JOIN Train t    ON sa.train_id  = t.train_id
JOIN Schedule s2 ON s2.train_id = sa.train_id AND s2.travel_date = sa.travel_date
WHERE sa.travel_date = '2026-08-01'
ORDER BY t.train_name;
