# Airline Reservation System

A web-based airline reservation system. Customers can register, search flights, choose a seat on a seat map, pay (simulated), and cancel bookings with an automatic refund calculation.

**Stack:** Java 17+ and Spring Boot (backend), SQL Server (database, with stored procedures), HTML, CSS and JavaScript (frontend).

## Features

- Register and log in (salted password hashes, account lock for 15 minutes after 5 wrong passwords)
- Search flights by route and date, and browse all upcoming flights with free seats
- Seat map with Economy and Business seats (Business costs 2x)
- No double booking: protected by a unique database index and row locking
- Separate payment step: Card, JazzCash, Easypaisa or Bank transfer (demo only, no real money)
- Cancellation with refund rules: 100% more than 48 hours before departure, 50% from 24 to 48 hours, none after that
- My bookings page with payment method and refund amount
- Four colour themes

## How it works

```
Browser (index.html)  ->  Spring Boot (AirlineController.java)  ->  SQL Server (stored procedures)
```

The page talks to the REST API under `/api`. The controller only calls stored procedures, and all business rules (pricing, seat checks, refunds) live in the database.

## Project structure

```
pom.xml                                     Maven dependencies
AirLineWEBDB.sql                            Full database script (tables, procedures, sample data)
src/main/java/com/airline/
    AirlineApplication.java                 Starts the app
    AirlineController.java                  REST API
src/main/resources/
    application.properties.example          Connection settings template
    static/index.html                       The whole frontend
```

## Setup

### 1. Requirements

- JDK 17 or newer
- Maven 3.9+
- SQL Server (Express is fine) and SQL Server Management Studio (SSMS)

### 2. Create the database

1. In SSMS, connect to your server (for example `localhost\SQLEXPRESS01`).
2. In SQL Server **Properties > Security**, choose **SQL Server and Windows Authentication mode**, then restart the server.
3. Open `AirLineWEBDB.sql`. In **Part 4A**, remove the comment markers around the `CREATE LOGIN` block and put your own password in it.
4. Stop the Java app if it is running, then press **F5** once with nothing selected.

> Warning: the script **drops and recreates** the `AirlineWEBDB` database every time it runs.

Sample flights are created relative to the day you run the script (in the week after next week), so they are always in the future.

### 3. Configure the app

Copy `src/main/resources/application.properties.example` to `src/main/resources/application.properties` and set your values:

```properties
server.port=8080
spring.datasource.url=jdbc:sqlserver://localhost\\SQLEXPRESS01;databaseName=AirlineWEBDB;encrypt=false;trustServerCertificate=true;
spring.datasource.username=airline_app
spring.datasource.password=YOUR_PASSWORD_HERE
```

The password must match the one you used in Part 4A. Never commit `application.properties` (it is in `.gitignore`).

### 4. Run

```
mvn spring-boot:run
```

Wait for `Started AirlineApplication`, then open <http://localhost:8080>.

## Demo accounts

| Role | Email | Password |
|---|---|---|
| Customer | demo@example.com | Demo@12345 |
| Admin | admin@airline.com | Admin@12345 |

Change the admin password before any real use. Admin accounts cannot book flights.

## Quick test

1. Log in as the demo customer.
2. Search a route from the **Upcoming flights** list, and click **Choose seat**.
3. Pick a seat, click **Continue to payment**, fill in the form and pay.
4. Check **My bookings**, then cancel the booking and see the refund.

## Troubleshooting

| Problem | Fix |
|---|---|
| `Login failed for user 'airline_app'` | Mixed mode is not enabled or the server was not restarted. Check the password in `application.properties`. |
| Login or register hangs for 30 seconds | Enable TCP/IP and start SQL Server Browser in SQL Server Configuration Manager, then restart SQL Server. |
| `Unable to load authentication DLL` | Remove `integratedSecurity=true` from the URL and use the SQL login. |
| SQL script hangs on the drop | Stop the Java app first, or restart the SQL Server service. |
| "No flights found" | The sample flights are in a specific week. Pick a date from the Upcoming flights list. |
| Page does not update after a code change | Restart the app (Ctrl+C, then `mvn spring-boot:run`) and press Ctrl+F5. |

## Notes and limitations

- Payments are simulated. Card numbers, CVV and PINs are checked in the browser and never sent or stored. Only a masked value such as `**** 4242` is saved.
- Passwords use salted SHA-256, which is fine for a course project. Production systems should use bcrypt or Argon2 and HTTPS.
- There is no admin screen yet. The `usp_AddFlight` procedure exists for adding flights from SSMS.

## Team

Add your team members' names here.