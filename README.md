# Airline Reservation System

A full-stack web application for booking airline tickets, built with **Spring Boot**, **Microsoft SQL Server** and plain **JavaScript**.
Passengers can search flights, pick exact seats on a cabin map, pay (simulated), manage baggage and lost-baggage claims, and leave feedback.
Administrators get a dashboard, can cancel or reschedule flights, and can **re-allocate passengers** from a cancelled flight to another flight on the same route.

> Payments are **simulated**. No real money moves, and no full card number, CVV or PIN is ever stored.

---

## Features

### Passengers
- Register and log in (strong password rule, salted SHA-256 hashing, account lock after 5 wrong attempts)
- Search flights by route and date, or browse the upcoming flights board
- Plane-style seat map with Window / Aisle / Middle filters and Business / Economy classes
- Book one seat, or 2 to 6 seats in a single booking (manual selection or the **family seat finder** that suggests neighbouring seats)
- Realistic payment page (Card, JazzCash, Easypaisa, Bank transfer) in its own tab
- Cancel a booking with an automatic refund (100% / 50% / 0% by time before departure, 100% if the airline cancels)
- Baggage with tag numbers and extra-weight fees
- Report lost, delayed or damaged baggage and follow the claim timeline
- Feedback with star rating, category and comment
- Notices when a flight is cancelled or when the airline moved you to another flight

### Administrators
- Dashboard with active flights, passengers, bookings that need moving, open claims and average rating
- Cancel or reschedule flights
- Move selected or all bookings of a flight to another flight on the same route (same class, same price, baggage and payment move too, full history kept)
- Update baggage claims (searching, found, delivered, compensation approved)
- Read all feedback

---

## Technology

| Layer | Technology |
|---|---|
| Front end | HTML, CSS, JavaScript (single page, Fetch API) |
| Back end | Java 17+, Spring Boot 3 (REST controllers, HttpSession, JdbcTemplate) |
| Database | Microsoft SQL Server (T-SQL stored procedures, transactions, constraints, indexes) |
| Build / tools | Maven, Git, GitHub, SQL Server Management Studio |

---

## Project structure

```
airline-reservation-system/
├── AirLineWEBDB.sql                      # Whole database: tables, procedures, sample data
├── pom.xml
└── src/main
    ├── java/com/airline
    │   ├── AirlineApplication.java       # Starts the application
    │   ├── AirlineController.java        # Accounts, flights, seats, bookings
    │   └── ServiceController.java        # Baggage, claims, feedback, admin
    └── resources
        ├── application.properties.example
        └── static/index.html             # The whole front end
```

`application.properties` (with your database password) is **not** in the repository. It is listed in `.gitignore`.

---

## Getting started

### 1. Requirements
- JDK 17 or newer
- Maven 3.9+
- SQL Server (Express is fine) and SQL Server Management Studio
- SQL Server set to **SQL Server and Windows Authentication mode**, with **TCP/IP** enabled

### 2. Create the database
1. Open `AirLineWEBDB.sql` in SSMS.
2. Click in the editor, press `Ctrl+A`, then `F5`.

This **drops and recreates** the `AirlineWEBDB` database, so run it on a fresh setup only.
It creates 13 tables, 27 stored procedures, 6 airports, 16 sample flights with seats, and two demo accounts.

### 3. Create the application login (first time only)
In Part 4 of the script, remove the comment markers from the `CREATE LOGIN` block, choose your own password, and run it once.
Then run the whole script again so the login receives access to the new database.

### 4. Configure the application
Copy `src/main/resources/application.properties.example` to `src/main/resources/application.properties` and fill in your values:

```properties
server.port=8080
spring.datasource.url=jdbc:sqlserver://localhost\\SQLEXPRESS01;databaseName=AirlineWEBDB;encrypt=false;trustServerCertificate=true;
spring.datasource.username=airline_app
spring.datasource.password=YOUR_PASSWORD_HERE
```

Change `SQLEXPRESS01` to the name of your own SQL Server instance.

### 5. Run
```bash
mvn spring-boot:run
```
Open <http://localhost:8080>.

### Demo accounts

| Role | Email | Password |
|---|---|---|
| Passenger | `demo@example.com` | `Demo@12345` |
| Administrator | `admin@airline.com` | `Admin@12345` |

Change the admin password before any real use.

> Sample flight dates are calculated from the day you run the script (they fall in the next two weeks after the first week).
> If a search shows "No flights found", run the script again, or change the `7` in the `CROSS JOIN (VALUES (7, ''), (8, 'B'))` line of Part 3.

---

## Database overview

13 tables: `Airports`, `Users`, `Passengers`, `Flights`, `Seats`, `Bookings`, `Tickets`, `Payments`, `Baggage`, `BaggageClaims`, `ClaimUpdates`, `Feedback`, `Reallocations`.

Key design points:
- **No double booking.** Booking procedures lock the seat row (`UPDLOCK, HOLDLOCK`) inside a transaction, and a filtered unique index on active tickets enforces it again at table level.
- **All-or-nothing changes.** Every procedure that changes data runs in `BEGIN TRY` / `BEGIN TRANSACTION` / `COMMIT`, with `ROLLBACK` and `THROW` on error.
- **Prices come from the database**, never from the browser.
- **Payments store only the payer name and the last 4 digits** (`****1234`).
- **Business rules live in stored procedures**, so they hold no matter which program calls the database.

| Rule | Value |
|---|---|
| Seat layout | 6 seats per row (A to F), rows 1 to 3 are Business at 2x price |
| Group booking | 2 to 6 seats, one booking, one payment |
| Free baggage | 20 kg per passenger, PKR 500 per extra kg, maximum 40 kg per passenger |
| Refund | Airline-cancelled flight 100%; over 48 h 100%; 24 to 48 h 50%; under 24 h 0% |
| Login lock | 5 wrong passwords lock the account for 15 minutes |

---

## REST API (all paths start with `/api`)

**Passenger**

| Method and path | Purpose |
|---|---|
| `POST /register`, `/login`, `/logout`; `GET /me` | Account and session |
| `GET /airports`, `/flights`, `/flights/upcoming` | Search and departures board |
| `GET /flights/{id}/seats`, `/seat-map`, `/group-seats` | Free seats, cabin map, neighbouring seat suggestions |
| `POST /bookings`, `/bookings/group` | Book one seat or a group |
| `GET /bookings/mine`; `POST /bookings/{id}/cancel` | My bookings; cancel with refund |
| `POST /baggage`; `GET /baggage/mine` | Add and list bags |
| `POST /baggage/{id}/report`; `GET /claims/mine` | Report a problem; follow claims |
| `POST /feedback`; `GET /feedback/mine` | Send and list feedback |

**Administrator** (role `Admin` required)

| Method and path | Purpose |
|---|---|
| `GET /admin/flights` | All flights with passenger counts |
| `POST /admin/flights/{id}/cancel`, `/reschedule` | Cancel or reschedule a flight |
| `GET /admin/flights/{id}/bookings`, `/targets` | Bookings to move; valid target flights |
| `POST /admin/reallocate`; `GET /admin/reallocations` | Move passengers; history |
| `GET /admin/claims`; `POST /admin/claims/{id}/status` | Handle baggage claims |
| `GET /admin/feedback` | Read all feedback |

---

## Security notes
- Passwords: random 16-byte salt + SHA-256, never stored in plain text
- Parameterised queries and stored procedures (no SQL built from user text)
- The passenger ID comes from the server session, never from the browser
- Admin endpoints check the role on the server
- Real database password stays out of Git (`application.properties` is ignored)

Known limitations: payment is simulated, there are no e-mail or SMS notifications, only one-way trips are supported, and a slow hashing method (bcrypt or PBKDF2) would be stronger than SHA-256.

---