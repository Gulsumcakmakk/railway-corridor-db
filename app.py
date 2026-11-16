import os
import streamlit as st
import pandas as pd
import mysql.connector

# ─── DB CONNECTION ───────────────────────────────────
def get_db():
    return mysql.connector.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        user=os.environ.get('DB_USER', 'root'),
        password=os.environ.get('DB_PASSWORD', ''),    
        database='railway_corridor'
    )

def query(sql, params=None):
    db = get_db()
    df = pd.read_sql(sql, db, params=params)
    db.close()
    return df

def execute(sql, params=None):
    db = get_db()
    cur = db.cursor()
    cur.execute(sql, params)
    db.commit()
    last_id = cur.lastrowid
    db.close()
    return last_id

# ─── SESSION ─────────────────────────────────────────
if 'role' not in st.session_state:
    st.session_state.role = None
if 'user_id' not in st.session_state:
    st.session_state.user_id = None

# ─── SIDEBAR ─────────────────────────────────────────
st.sidebar.title("Railway Corridor")

if st.session_state.role:
    st.sidebar.success(f"Logged in as: {st.session_state.role}")
    if st.sidebar.button("Logout"):
        st.session_state.role = None
        st.session_state.user_id = None
        st.rerun()

# ─── PAGE SELECT ─────────────────────────────────────
if st.session_state.role == 'passenger':
    page = st.sidebar.radio("Menu", ["My Reservations", "Search Trains", "Book a Seat"])
elif st.session_state.role == 'staff':
    page = st.sidebar.radio("Menu", ["Trains", "Schedules", "Maintenance", "Reports", "System Ops"])
else:
    page = st.sidebar.radio("Menu", ["Passenger Login", "Register", "Staff Login"])

st.title(page)

# PASSENGER LOGIN
if page == "Passenger Login":
    email = st.text_input("Email")
    password = st.text_input("Password", type="password")
    if st.button("Login"):
        df = query("SELECT * FROM Passenger WHERE email=%s AND password_hash=%s", (email, password))
        if not df.empty:
            st.session_state.role = 'passenger'
            st.session_state.user_id = int(df.iloc[0]['passenger_id'])
            st.success("Login successful!")
            st.rerun()
        else:
            st.error("Invalid credentials")

# REGISTER
elif page == "Register":
    st.subheader("Create Passenger Account")
    
    first = st.text_input("First Name")
    last  = st.text_input("Last Name")
    email = st.text_input("Email")
    phone = st.text_input("Phone")
    passport = st.text_input("Passport No")
    nationality = st.text_input("Nationality")
    password = st.text_input("Password", type="password")
    
    if st.button("Register"):
        # Boş alan bırakılmamasını garantiye alıyoruz
        if first and last and email and phone and password:
            try:
                # Sorguya veritabanında NOT NULL olabilecek diğer alanları da ekliyoruz (Örn: total_miles, loyalty_class)
                # Eğer tablonuzda bu sütunlar yoksa veya hata alırsanız sorgudan çıkarabilirsiniz.
                execute("""INSERT INTO Passenger 
                    (first_name, last_name, email, phone, passport_no, nationality, password_hash, account_created, total_miles, loyalty_class) 
                    VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), 0, 'none')""", 
                    (first, last, email, phone, passport, nationality, password))
                
                st.success("Registered successfully! Please switch to Login.")
                
            except Exception as e:
                # Eğer veritabanı seviyesinde bir hata çıkarsa ekranda kırmızı kutuda ne olduğunu göreceğiz
                st.error(f"Veritabanı Hatası: {e}")
        else:
            st.warning("Lütfen zorunlu alanları (İsim, Soyisim, Email, Telefon ve Şifre) doldurun!")

# STAFF LOGIN
elif page == "Staff Login":
    email = st.text_input("Email")
    password = st.text_input("Password", type="password")
    if st.button("Login"):
        df = query("SELECT * FROM Staff WHERE email=%s AND password_hash=%s", (email, password))
        if not df.empty:
            st.session_state.role = 'staff'
            st.session_state.user_id = int(df.iloc[0]['staff_id'])
            st.success("Login successful!")
            st.rerun()
        else:
            st.error("Invalid credentials")

# MY RESERVATIONS
elif page == "My Reservations":
    df = query("""
        SELECT r.reservation_id, t.train_name, s.travel_date,
               sf.station_name as `From`, st2.station_name as `To`,
               r.seat_number, r.coach_type, r.ticket_price, r.ticket_status
        FROM Reservation r
        JOIN Schedule s   ON r.schedule_id  = s.schedule_id
        JOIN Train t      ON s.train_id     = t.train_id
        JOIN Station sf   ON r.from_station = sf.station_id
        JOIN Station st2  ON r.to_station   = st2.station_id
        WHERE r.passenger_id = %s
    """, (st.session_state.user_id,))
    st.dataframe(df, use_container_width=True)

# SEARCH TRAINS
elif page == "Search Trains":
    st.subheader("Available Schedules")
    st.dataframe(query("""
        SELECT t.train_name, s.travel_date, s.departure_time,
               s1.station_name as departs_from, s2.station_name as arrives_at
        FROM Schedule s
        JOIN Train t ON s.train_id = t.train_id
        JOIN RouteStop rs1 ON rs1.train_id = t.train_id AND rs1.stop_sequence = 1
        JOIN RouteStop rs2 ON rs2.train_id = t.train_id
        JOIN Station s1 ON rs1.station_id = s1.station_id
        JOIN Station s2 ON rs2.station_id = s2.station_id
        WHERE rs2.departure_offset_min IS NULL
        ORDER BY s.travel_date
    """), use_container_width=True)
    st.subheader("Search")
    stations = query("SELECT station_id, station_name FROM Station ORDER BY station_name")
    
    names = stations['station_name'].tolist()
    ids   = stations['station_id'].tolist()

    col1, col2, col3 = st.columns(3)
    with col1:
        from_name = st.selectbox("From", names)
    with col2:
        to_name   = st.selectbox("To", names)
    with col3:
        date = st.date_input("Date")

    from_id = ids[names.index(from_name)]
    to_id   = ids[names.index(to_name)]

    if st.button("Search"):
        df = query("""
            SELECT s.schedule_id, t.train_name, s.travel_date, s.departure_time,
                   %s as `From`, %s as `To`
            FROM Schedule s
            JOIN Train t ON s.train_id = t.train_id
            JOIN RouteStop r1 ON r1.train_id = t.train_id AND r1.station_id = %s
            JOIN RouteStop r2 ON r2.train_id = t.train_id AND r2.station_id = %s
            WHERE s.travel_date = %s AND r1.stop_sequence < r2.stop_sequence
        """, (from_name, to_name, from_id, to_id, str(date)))
        if df.empty:
            st.warning("No trains found.")
        else:
            st.dataframe(df, use_container_width=True)
            st.session_state['search_result'] = df.to_dict('records')
            st.session_state['from_id'] = from_id
            st.session_state['to_id']   = to_id

# BOOK A SEAT
elif page == "Book a Seat":
    PRICES = {"economy": 100, "business": 200, "first": 350}

    results = st.session_state.get('search_result', [])
    if not results:
        st.info("Please search for a train first.")
    else:
        options = {f"{r['train_name']} — {r['travel_date']}": r['schedule_id'] for r in results}
        choice = st.selectbox("Select Train", list(options.keys()))
        schedule_id = options[choice]

        coach = st.selectbox("Coach Type", ["economy", "business", "first"])
        price = PRICES[coach]
        st.info(f"Ticket Price: ${price}")

        # Empty seats
        booked = query("""
            SELECT seat_number FROM Reservation
            WHERE schedule_id=%s AND ticket_status != 'cancelled'
        """, (schedule_id,))
        booked_seats = booked['seat_number'].tolist() if not booked.empty else []

        # Seat list
        all_seats = [f"{row}{col:02d}" for row in "ABCDE" for col in range(1, 11)]
        available = [s for s in all_seats if s not in booked_seats]

        if not available:
            st.warning("No seats available. You will be added to the waiting list.")
            if st.button("Join Waiting List"):
                execute("""INSERT INTO WaitingList
                    (passenger_id, schedule_id, from_station, to_station, coach_type, request_date, position, status)
                    VALUES (%s,%s,%s,%s,%s,NOW(),
                        (SELECT COALESCE(MAX(position),0)+1 FROM WaitingList w2
                         WHERE w2.schedule_id=%s AND w2.coach_type=%s),
                        'waiting')""",
                    (st.session_state.user_id, schedule_id,
                     st.session_state['from_id'], st.session_state['to_id'],
                     coach, schedule_id, coach))
                st.success("Added to waiting list.")
        else:
            seat = st.selectbox("Select Seat", available)
            lug_w = st.number_input("Luggage Weight (kg)", min_value=0.0)

            if st.button("Book & Pay"):
                res_id = execute("""
                    INSERT INTO Reservation
                    (passenger_id, schedule_id, from_station, to_station, seat_number,
                     coach_type, ticket_price, payment_status, ticket_status, booking_date, expiry_date)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,'completed','confirmed',NOW(),DATE_ADD(NOW(),INTERVAL 2 DAY))
                """, (st.session_state.user_id, schedule_id,
                      st.session_state['from_id'], st.session_state['to_id'],
                      seat, coach, price))
                execute("INSERT INTO Payment (reservation_id, amount, payment_method, payment_date, status) VALUES (%s,%s,'credit_card',NOW(),'completed')",
                        (res_id, price))
                if lug_w > 0:
                    execute("INSERT INTO Luggage (reservation_id, weight_kg) VALUES (%s,%s)",
                            (res_id, lug_w))
                st.success(f"Booking confirmed! Seat {seat} — ${price}")

# STAFF: TRAINS
elif page == "Trains":
    st.subheader("Add Train")
    name  = st.text_input("Train Name")
    ttype = st.selectbox("Type", ["passenger", "freight", "mixed"])
    seats = st.number_input("Total Seats (0 = freight)", min_value=0)
    if st.button("Add Train"):
        execute("INSERT INTO Train (train_name, train_type, total_seats, status) VALUES (%s,%s,%s,'active')",
                (name, ttype, seats if seats > 0 else None))
        st.success("Train added.")
    st.subheader("All Trains")
    st.dataframe(query("SELECT * FROM Train"), use_container_width=True)

# STAFF: SCHEDULES
elif page == "Schedules":
    trains = query("SELECT train_id, train_name FROM Train")
    t_names = trains['train_name'].tolist()
    t_ids   = trains['train_id'].tolist()

    st.subheader("Add Schedule")
    t_choice = st.selectbox("Train", t_names)
    t_id = t_ids[t_names.index(t_choice)]
    date = st.date_input("Travel Date")
    dep  = st.time_input("Departure Time")
    if st.button("Add Schedule"):
        execute("INSERT INTO Schedule (train_id, travel_date, departure_time, status) VALUES (%s,%s,%s,'scheduled')",
                (t_id, str(date), str(dep)))
        st.success("Schedule added.")
    st.subheader("All Schedules")
    st.dataframe(query("""
        SELECT s.schedule_id, t.train_name, s.travel_date,
            CAST(s.departure_time AS CHAR) as departure_time, s.status
        FROM Schedule s JOIN Train t ON s.train_id=t.train_id
        ORDER BY travel_date DESC LIMIT 20
    """),
                 use_container_width=True)

# STAFF: MAINTENANCE
elif page == "Maintenance":
    trains = query("SELECT train_id, train_name FROM Train")
    t_names = trains['train_name'].tolist()
    t_ids   = trains['train_id'].tolist()

    st.subheader("Add Maintenance Record")
    t_choice = st.selectbox("Train", t_names)
    t_id = t_ids[t_names.index(t_choice)]
    mtype = st.selectbox("Maintenance Type", ["Brake Inspection", "Engine Overhaul", "Wheel Inspection", "Signal Inspection", "Track Alignment"])
    start = st.date_input("Start Date")
    if st.button("Add Record"):
        execute("""INSERT INTO MaintenanceRecord
            (train_id, maintenance_type, start_date, technician_id, status)
            VALUES (%s,%s,%s,%s,'scheduled')""",
            (t_id, mtype, str(start), st.session_state.user_id))
    st.success("Record added.")
    st.subheader("Maintenance History")
    st.dataframe(query("""
        SELECT mr.record_id, t.train_name, mr.maintenance_type,
               mr.start_date, mr.status, mr.notes
        FROM MaintenanceRecord mr
        LEFT JOIN Train t ON mr.train_id=t.train_id
        ORDER BY mr.start_date DESC LIMIT 20
    """), use_container_width=True)

# STAFF: REPORTS
elif page == "Reports":
    report = st.selectbox("Select Report", [
        "1. Active Trains",
        "2. Train Route Order",
        "3. Passenger Reservations",
        "4. Waiting List",
        "5. Load Factor",
        "6. Dependents Traveling",
        "7. Freight Shipments",
        "8. Customs Clearance",
        "9. Maintenance History",
        "10. Staff Assignments"
    ])

    if report.startswith("1"):
        date = st.date_input("Date")
        st.dataframe(query("""
            SELECT t.train_name, t.train_type, s.departure_time, s.status
            FROM Schedule s JOIN Train t ON s.train_id=t.train_id
            WHERE s.travel_date=%s AND s.status != 'cancelled'
        """, (str(date),)), use_container_width=True)

    elif report.startswith("2"):
        trains = query("SELECT train_id, train_name FROM Train")
        choice = st.selectbox("Train", trains['train_name'].tolist())
        t_id = int(trains[trains['train_name']==choice]['train_id'].iloc[0])
        st.dataframe(query("""
            SELECT rs.stop_sequence, st.station_name, c.country_name
            FROM RouteStop rs
            JOIN Station st ON rs.station_id=st.station_id
            JOIN Country c  ON st.country_id=c.country_id
            WHERE rs.train_id=%s ORDER BY rs.stop_sequence
        """, (t_id,)), use_container_width=True)

    elif report.startswith("3"):
        pid = st.number_input("Passenger ID", min_value=1, step=1)
        st.dataframe(query("""
            SELECT r.reservation_id, t.train_name, s.travel_date,
                   sf.station_name as `From`, st2.station_name as `To`,
                   r.seat_number, r.ticket_price, r.ticket_status
            FROM Reservation r
            JOIN Schedule s   ON r.schedule_id=s.schedule_id
            JOIN Train t      ON s.train_id=t.train_id
            JOIN Station sf   ON r.from_station=sf.station_id
            JOIN Station st2  ON r.to_station=st2.station_id
            WHERE r.passenger_id=%s
        """, (int(pid),)), use_container_width=True)

    elif report.startswith("4"):
        st.dataframe(query("""
            SELECT wl.position, p.first_name, p.last_name, p.loyalty_class,
                   t.train_name, s.travel_date, wl.coach_type, wl.status
            FROM WaitingList wl
            JOIN Passenger p ON wl.passenger_id=p.passenger_id
            JOIN Schedule s  ON wl.schedule_id=s.schedule_id
            JOIN Train t     ON s.train_id=t.train_id
            ORDER BY s.travel_date, wl.position
        """), use_container_width=True)

    elif report.startswith("5"):
        date = st.date_input("Date")
        st.dataframe(query("""
            SELECT t.train_name, t.total_seats,
                   COUNT(r.reservation_id) as booked,
                   ROUND(COUNT(r.reservation_id)*100.0/t.total_seats,1) as load_pct
            FROM Schedule s
            JOIN Train t ON s.train_id=t.train_id
            LEFT JOIN Reservation r ON r.schedule_id=s.schedule_id AND r.ticket_status='confirmed'
            WHERE s.travel_date=%s AND t.total_seats IS NOT NULL
            GROUP BY t.train_id, t.train_name, t.total_seats
        """, (str(date),)), use_container_width=True)

    elif report.startswith("6"):
        date = st.date_input("Date")
        st.dataframe(query("""
            SELECT s.travel_date, t.train_name,
                   p.first_name as main_passenger,
                   d.full_name as dependent, d.relation
            FROM Reservation r
            JOIN Passenger p ON r.passenger_id=p.passenger_id
            JOIN Dependent d ON r.dependent_id=d.dependent_id
            JOIN Schedule s  ON r.schedule_id=s.schedule_id
            JOIN Train t     ON s.train_id=t.train_id
            WHERE s.travel_date=%s
        """, (str(date),)), use_container_width=True)

    elif report.startswith("7"):
        st.dataframe(query("""
            SELECT fs.shipment_id, fs.shipper_name, fs.cargo_type,
                   fs.weight_kg, fs.status,
                   so.station_name as origin, sd.station_name as destination
            FROM FreightShipment fs
            JOIN Station so ON fs.origin_station=so.station_id
            JOIN Station sd ON fs.destination_station=sd.station_id
            WHERE so.country_id != sd.country_id
        """), use_container_width=True)

    elif report.startswith("8"):
        sid = st.number_input("Shipment ID", min_value=1, step=1)
        st.dataframe(query("""
            SELECT cc.clearance_id, st.station_name as checkpoint,
                   cc.inspection_date, cc.clearance_status, cc.document_ref, cc.fee
            FROM CustomsClearance cc
            JOIN Station st ON cc.checkpoint_station=st.station_id
            WHERE cc.shipment_id=%s
        """, (int(sid),)), use_container_width=True)

    elif report.startswith("9"):
        trains = query("SELECT train_id, train_name FROM Train")
        choice = st.selectbox("Train", trains['train_name'].tolist())
        t_id = int(trains[trains['train_name']==choice]['train_id'].iloc[0])
        st.dataframe(query("""
            SELECT maintenance_type, start_date, end_date, status, sensor_type, sensor_value, notes
            FROM MaintenanceRecord WHERE train_id=%s ORDER BY start_date DESC
        """, (t_id,)), use_container_width=True)

    elif report.startswith("10"):
        date = st.date_input("Date")
        st.dataframe(query("""
            SELECT t.train_name, sf.first_name, sf.last_name, sf.role, sa.role_on_trip
            FROM StaffAssignment sa
            JOIN Staff sf ON sa.staff_id=sf.staff_id
            JOIN Train t  ON sa.train_id=t.train_id
            WHERE sa.travel_date=%s
        """, (str(date),)), use_container_width=True)

# SYSTEM OPS
elif page == "System Ops":
    if st.button("Cancel Expired Reservations"):
        execute("""
            UPDATE Reservation SET ticket_status='cancelled', payment_status='failed'
            WHERE ticket_status='temporary' AND expiry_date < NOW()
        """)
        st.success("Expired reservations cancelled.")

    if st.button("Update Loyalty Classes"):
        execute("""
            UPDATE Passenger SET loyalty_class = CASE
                WHEN total_miles >= 100000 THEN 'gold'
                WHEN total_miles >= 50000  THEN 'silver'
                WHEN total_miles >= 10000  THEN 'green'
                ELSE 'none' END
        """)
        st.success("Loyalty classes updated.")

    if st.button("Show Waiting List"):
        st.dataframe(query("""
            SELECT wl.waiting_id, p.first_name, p.last_name, t.train_name, s.travel_date
            FROM WaitingList wl
            JOIN Passenger p ON wl.passenger_id=p.passenger_id
            JOIN Schedule s  ON wl.schedule_id=s.schedule_id
            JOIN Train t     ON s.train_id=t.train_id
            WHERE wl.status='waiting' ORDER BY wl.position
        """), use_container_width=True)
