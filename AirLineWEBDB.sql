/* =====================================================================
   AirlineWEBDB - Airline Reservation System (SQL Server / T-SQL)

   RUN THIS WHOLE FILE ONCE in SQL Server Management Studio (press F5).

   WARNING: it DROPS and RECREATES the AirlineWEBDB database, so every
   run starts clean. Remove PART 0 once you keep real data.

   Parts: 0 Reset | 1 Tables | 2 Procedures | 3 Sample data | 4 App login | 5 Tests
   ===================================================================== */

/* ---------------- PART 0 - Reset database ---------------- */
USE master;
GO
IF DB_ID('AirlineWEBDB') IS NOT NULL
BEGIN
    ALTER DATABASE AirlineWEBDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE AirlineWEBDB;
END
GO
CREATE DATABASE AirlineWEBDB;
GO
USE AirlineWEBDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

/* ---------------- PART 1 - Tables ---------------- */
CREATE TABLE Airports (
    AirportCode CHAR(3)      NOT NULL,
    City        VARCHAR(100) NOT NULL,
    Country     VARCHAR(100) NOT NULL,
    CONSTRAINT PK_Airports PRIMARY KEY (AirportCode)
);
GO
CREATE TABLE Users (
    UserID           INT IDENTITY(1,1) NOT NULL,
    Email            VARCHAR(100)      NOT NULL,
    PasswordHash     VARBINARY(32)     NOT NULL,
    PasswordSalt     VARBINARY(16)     NOT NULL,
    Role             VARCHAR(20)       NOT NULL CONSTRAINT DF_Users_Role DEFAULT 'Customer',
    IsActive         BIT               NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
    FailedLoginCount INT               NOT NULL CONSTRAINT DF_Users_FailedLogins DEFAULT 0,
    LockedUntil      DATETIME2(0)      NULL,
    LastLoginAt      DATETIME2(0)      NULL,
    CreatedAt        DATETIME2(0)      NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Users PRIMARY KEY (UserID),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role CHECK (Role IN ('Customer', 'Admin')),
    CONSTRAINT CK_Users_Email CHECK (Email LIKE '%_@_%._%')
);
GO
CREATE TABLE Passengers (
    PassengerID INT IDENTITY(1,1) NOT NULL,
    UserID      INT               NULL,
    FullName    VARCHAR(150)      NOT NULL,
    Email       VARCHAR(100)      NOT NULL,
    Phone       VARCHAR(20)       NULL,
    CONSTRAINT PK_Passengers PRIMARY KEY (PassengerID),
    CONSTRAINT UQ_Passengers_Email UNIQUE (Email),
    CONSTRAINT FK_Passengers_User FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT CK_Passengers_Email CHECK (Email LIKE '%_@_%._%')
);
GO
CREATE UNIQUE INDEX UX_Passengers_User ON Passengers (UserID) WHERE UserID IS NOT NULL;
GO
CREATE TABLE Flights (
    FlightID        INT IDENTITY(1,1) NOT NULL,
    FlightNumber    VARCHAR(20)       NOT NULL,
    OriginCode      CHAR(3)           NOT NULL,
    DestinationCode CHAR(3)           NOT NULL,
    DepartureTime   DATETIME2(0)      NOT NULL,
    ArrivalTime     DATETIME2(0)      NOT NULL,
    Capacity        INT               NOT NULL,
    BasePrice       DECIMAL(10,2)     NOT NULL,
    Status          VARCHAR(20)       NOT NULL CONSTRAINT DF_Flights_Status DEFAULT 'Scheduled',
    CONSTRAINT PK_Flights PRIMARY KEY (FlightID),
    CONSTRAINT UQ_Flights_Number UNIQUE (FlightNumber),
    CONSTRAINT FK_Flights_Origin FOREIGN KEY (OriginCode) REFERENCES Airports(AirportCode),
    CONSTRAINT FK_Flights_Destination FOREIGN KEY (DestinationCode) REFERENCES Airports(AirportCode),
    CONSTRAINT CK_Flights_Route CHECK (OriginCode <> DestinationCode),
    CONSTRAINT CK_Flights_Times CHECK (ArrivalTime > DepartureTime),
    CONSTRAINT CK_Flights_Capacity CHECK (Capacity > 0),
    CONSTRAINT CK_Flights_BasePrice CHECK (BasePrice >= 0),
    CONSTRAINT CK_Flights_Status CHECK (Status IN ('Scheduled', 'Cancelled', 'Departed'))
);
GO
CREATE INDEX IX_Flights_Search ON Flights (OriginCode, DestinationCode, DepartureTime);
GO
CREATE TABLE Seats (
    FlightID        INT          NOT NULL,
    SeatNumber      VARCHAR(10)  NOT NULL,
    SeatClass       VARCHAR(20)  NOT NULL,
    PriceMultiplier DECIMAL(4,2) NOT NULL CONSTRAINT DF_Seats_Multiplier DEFAULT 1.00,
    CONSTRAINT PK_Seats PRIMARY KEY (FlightID, SeatNumber),
    CONSTRAINT FK_Seats_Flight FOREIGN KEY (FlightID) REFERENCES Flights(FlightID),
    CONSTRAINT CK_Seats_Class CHECK (SeatClass IN ('Economy', 'Business')),
    CONSTRAINT CK_Seats_Multiplier CHECK (PriceMultiplier > 0)
);
GO
CREATE TABLE Bookings (
    BookingID   INT IDENTITY(1,1) NOT NULL,
    PassengerID INT               NOT NULL,
    FlightID    INT               NOT NULL,
    BookingDate DATETIME2(0)      NOT NULL CONSTRAINT DF_Bookings_Date DEFAULT SYSDATETIME(),
    Status      VARCHAR(20)       NOT NULL CONSTRAINT DF_Bookings_Status DEFAULT 'Confirmed',
    CancelledAt DATETIME2(0)      NULL,
    CONSTRAINT PK_Bookings PRIMARY KEY (BookingID),
    CONSTRAINT UQ_Bookings_Booking_Flight UNIQUE (BookingID, FlightID),
    CONSTRAINT FK_Bookings_Passenger FOREIGN KEY (PassengerID) REFERENCES Passengers(PassengerID),
    CONSTRAINT FK_Bookings_Flight FOREIGN KEY (FlightID) REFERENCES Flights(FlightID),
    CONSTRAINT CK_Bookings_Status CHECK (Status IN ('Confirmed', 'Cancelled'))
);
GO
CREATE UNIQUE INDEX UX_Bookings_Passenger_Flight_Active ON Bookings (PassengerID, FlightID) WHERE Status = 'Confirmed';
CREATE INDEX IX_Bookings_Flight    ON Bookings (FlightID, Status);
CREATE INDEX IX_Bookings_Passenger ON Bookings (PassengerID);
GO
CREATE TABLE Tickets (
    TicketID     INT IDENTITY(1,1) NOT NULL,
    BookingID    INT               NOT NULL,
    FlightID     INT               NOT NULL,
    SeatNumber   VARCHAR(10)       NOT NULL,
    Price        DECIMAL(10,2)     NOT NULL,
    Status       VARCHAR(20)       NOT NULL CONSTRAINT DF_Tickets_Status DEFAULT 'Active',
    IssueDate    DATETIME2(0)      NOT NULL CONSTRAINT DF_Tickets_Issue DEFAULT SYSDATETIME(),
    RefundAmount DECIMAL(10,2)     NULL,
    CONSTRAINT PK_Tickets PRIMARY KEY (TicketID),
    CONSTRAINT FK_Tickets_Booking FOREIGN KEY (BookingID, FlightID) REFERENCES Bookings(BookingID, FlightID),
    CONSTRAINT FK_Tickets_Seat FOREIGN KEY (FlightID, SeatNumber) REFERENCES Seats(FlightID, SeatNumber),
    CONSTRAINT CK_Tickets_Price CHECK (Price >= 0),
    CONSTRAINT CK_Tickets_Status CHECK (Status IN ('Active', 'Cancelled'))
);
GO
CREATE UNIQUE INDEX UX_Tickets_ActiveSeat ON Tickets (FlightID, SeatNumber) WHERE Status = 'Active';
CREATE INDEX IX_Tickets_Booking ON Tickets (BookingID);
GO
-- Simulated payments: one 'Paid' row per booking, plus a 'Refunded' row on a refundable cancellation.
-- No card numbers are ever stored.
CREATE TABLE Payments (
    PaymentID INT IDENTITY(1,1) NOT NULL,
    BookingID INT               NOT NULL,
    Amount    DECIMAL(10,2)     NOT NULL,
    Method    VARCHAR(20)       NOT NULL,
    Status    VARCHAR(20)       NOT NULL,
    Reference VARCHAR(30)       NOT NULL,
    PayerName VARCHAR(100)      NULL,
    AccountMask VARCHAR(8)      NULL,
    CreatedAt DATETIME2(0)      NOT NULL CONSTRAINT DF_Payments_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Payments PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payments_Booking FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID),
    CONSTRAINT CK_Payments_Amount CHECK (Amount >= 0),
    CONSTRAINT CK_Payments_Method CHECK (Method IN ('Card', 'JazzCash', 'Easypaisa', 'Bank Transfer')),
    CONSTRAINT CK_Payments_Status CHECK (Status IN ('Paid', 'Refunded'))
);
GO
CREATE INDEX IX_Payments_Booking ON Payments (BookingID);
GO

/* ---------------- PART 2 - Stored procedures ---------------- */

-- Seat map: 6 seats per row (A-F), rows 1-3 Business at 2x price.
CREATE OR ALTER PROCEDURE usp_GenerateSeats
    @FlightID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Capacity INT;
    SELECT @Capacity = Capacity FROM Flights WHERE FlightID = @FlightID;
    IF @Capacity IS NULL
        THROW 50010, 'Flight does not exist.', 1;
    IF EXISTS (SELECT 1 FROM Seats WHERE FlightID = @FlightID)
        RETURN;
    ;WITH Numbers AS (
        SELECT TOP (@Capacity) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS SeatIndex
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    INSERT INTO Seats (FlightID, SeatNumber, SeatClass, PriceMultiplier)
    SELECT @FlightID,
           CONCAT(((SeatIndex - 1) / 6) + 1, CHAR(65 + ((SeatIndex - 1) % 6))),
           CASE WHEN ((SeatIndex - 1) / 6) + 1 <= 3 THEN 'Business' ELSE 'Economy' END,
           CASE WHEN ((SeatIndex - 1) / 6) + 1 <= 3 THEN 2.00 ELSE 1.00 END
    FROM Numbers;
END;
GO
-- Admin: add a flight and its seats in one safe step.
CREATE OR ALTER PROCEDURE usp_AddFlight
    @FlightNumber VARCHAR(20), @OriginCode CHAR(3), @DestinationCode CHAR(3),
    @DepartureTime DATETIME2(0), @ArrivalTime DATETIME2(0), @Capacity INT, @BasePrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NewFlightID INT;
        INSERT INTO Flights (FlightNumber, OriginCode, DestinationCode, DepartureTime, ArrivalTime, Capacity, BasePrice)
        VALUES (@FlightNumber, @OriginCode, @DestinationCode, @DepartureTime, @ArrivalTime, @Capacity, @BasePrice);
        SET @NewFlightID = SCOPE_IDENTITY();
        EXEC usp_GenerateSeats @FlightID = @NewFlightID;
        COMMIT TRANSACTION;
        SELECT @NewFlightID AS FlightID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- Sign up: creates the login account and the passenger profile together.
CREATE OR ALTER PROCEDURE usp_RegisterUser
    @FullName VARCHAR(150), @Email VARCHAR(100), @Phone VARCHAR(20) = NULL, @Password NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Email = LOWER(LTRIM(RTRIM(@Email)));
    IF LEN(@Password) < 8
        THROW 50020, 'Password must be at least 8 characters.', 1;
    IF @Password NOT LIKE '%[A-Z]%' COLLATE Latin1_General_BIN
       OR @Password NOT LIKE '%[a-z]%' COLLATE Latin1_General_BIN
       OR @Password NOT LIKE '%[0-9]%'
       OR @Password NOT LIKE '%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN
        THROW 50022, 'Password needs an uppercase letter, a lowercase letter, a number and a special character.', 1;
    IF EXISTS (SELECT 1 FROM Users WHERE Email = @Email) OR EXISTS (SELECT 1 FROM Passengers WHERE Email = @Email)
        THROW 50021, 'This email is already registered.', 1;
    DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);
    DECLARE @Hash VARBINARY(32) = HASHBYTES('SHA2_256', @Salt + CONVERT(VARBINARY(200), @Password));
    DECLARE @NewUserID INT, @NewPassengerID INT;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO Users (Email, PasswordHash, PasswordSalt, Role) VALUES (@Email, @Hash, @Salt, 'Customer');
        SET @NewUserID = SCOPE_IDENTITY();
        INSERT INTO Passengers (UserID, FullName, Email, Phone) VALUES (@NewUserID, @FullName, @Email, @Phone);
        SET @NewPassengerID = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
        SELECT @NewUserID AS UserID, @NewPassengerID AS PassengerID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- Login: locks the account for 15 minutes after 5 wrong passwords in a row.
CREATE OR ALTER PROCEDURE usp_LoginUser
    @Email VARCHAR(100), @Password NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Email = LOWER(LTRIM(RTRIM(@Email)));
    DECLARE @UserID INT, @StoredHash VARBINARY(32), @Salt VARBINARY(16), @IsActive BIT, @LockedUntil DATETIME2(0);
    SELECT @UserID = UserID, @StoredHash = PasswordHash, @Salt = PasswordSalt, @IsActive = IsActive, @LockedUntil = LockedUntil
    FROM Users WHERE Email = @Email;
    IF @UserID IS NULL
        THROW 50030, 'Invalid email or password.', 1;
    IF @IsActive = 0
        THROW 50031, 'This account is disabled.', 1;
    IF @LockedUntil IS NOT NULL AND @LockedUntil > SYSDATETIME()
        THROW 50032, 'Account temporarily locked. Please try again later.', 1;
    IF @LockedUntil IS NOT NULL AND @LockedUntil <= SYSDATETIME()
        UPDATE Users SET FailedLoginCount = 0, LockedUntil = NULL WHERE UserID = @UserID;
    IF HASHBYTES('SHA2_256', @Salt + CONVERT(VARBINARY(200), @Password)) <> @StoredHash
    BEGIN
        UPDATE Users
        SET FailedLoginCount = FailedLoginCount + 1,
            LockedUntil = CASE WHEN FailedLoginCount + 1 >= 5 THEN DATEADD(MINUTE, 15, SYSDATETIME()) ELSE LockedUntil END
        WHERE UserID = @UserID;
        THROW 50030, 'Invalid email or password.', 1;
    END;
    UPDATE Users SET FailedLoginCount = 0, LockedUntil = NULL, LastLoginAt = SYSDATETIME() WHERE UserID = @UserID;
    SELECT u.UserID, p.PassengerID, u.Role, p.FullName, u.Email
    FROM Users u LEFT JOIN Passengers p ON p.UserID = u.UserID
    WHERE u.UserID = @UserID;
END;
GO
CREATE OR ALTER PROCEDURE usp_SearchFlights
    @Origin CHAR(3), @Destination CHAR(3), @TravelDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FlightID, f.FlightNumber, f.OriginCode, f.DestinationCode, f.DepartureTime, f.ArrivalTime, f.BasePrice,
           f.Capacity - taken.SeatsTaken AS AvailableSeats
    FROM Flights f
    CROSS APPLY (SELECT COUNT(*) AS SeatsTaken FROM Tickets t WHERE t.FlightID = f.FlightID AND t.Status = 'Active') taken
    WHERE f.OriginCode = @Origin AND f.DestinationCode = @Destination
      AND f.DepartureTime >= @TravelDate AND f.DepartureTime < DATEADD(DAY, 1, @TravelDate)
      AND f.DepartureTime > SYSDATETIME() AND f.Status = 'Scheduled'
    ORDER BY f.DepartureTime;
END;
GO
-- Departures board: every upcoming scheduled flight with its free seats.
CREATE OR ALTER PROCEDURE usp_GetUpcomingFlights
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FlightID, f.FlightNumber, f.OriginCode, f.DestinationCode, f.DepartureTime, f.ArrivalTime, f.BasePrice,
           f.Capacity - taken.SeatsTaken AS AvailableSeats
    FROM Flights f
    CROSS APPLY (SELECT COUNT(*) AS SeatsTaken FROM Tickets t WHERE t.FlightID = f.FlightID AND t.Status = 'Active') taken
    WHERE f.Status = 'Scheduled' AND f.DepartureTime > SYSDATETIME()
    ORDER BY f.DepartureTime;
END;
GO
CREATE OR ALTER PROCEDURE usp_GetAvailableSeats
    @FlightID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT s.SeatNumber, s.SeatClass, CAST(f.BasePrice * s.PriceMultiplier AS DECIMAL(10,2)) AS Price
    FROM Seats s
    JOIN Flights f ON f.FlightID = s.FlightID
    WHERE s.FlightID = @FlightID
      AND NOT EXISTS (SELECT 1 FROM Tickets t WHERE t.FlightID = s.FlightID AND t.SeatNumber = s.SeatNumber AND t.Status = 'Active')
    ORDER BY CAST(LEFT(s.SeatNumber, LEN(s.SeatNumber) - 1) AS INT), RIGHT(s.SeatNumber, 1);
END;
GO
-- Book a seat and record the (simulated) payment in the same transaction.
CREATE OR ALTER PROCEDURE usp_BookFlight
    @PassengerID INT, @FlightID INT, @SeatNumber VARCHAR(10), @PaymentMethod VARCHAR(20) = 'Card',
    @PayerName VARCHAR(100) = NULL, @AccountMask VARCHAR(8) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @DepartureTime DATETIME2(0), @FlightStatus VARCHAR(20), @BasePrice DECIMAL(10,2);
    DECLARE @Multiplier DECIMAL(4,2), @Price DECIMAL(10,2), @NewBookingID INT, @NewTicketID INT, @Reference VARCHAR(30);
    SET @SeatNumber = UPPER(LTRIM(RTRIM(@SeatNumber)));
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @PaymentMethod NOT IN ('Card', 'JazzCash', 'Easypaisa', 'Bank Transfer')
            THROW 50046, 'Please choose a valid payment method.', 1;
        IF LEN(LTRIM(RTRIM(ISNULL(@PayerName, '')))) < 2
            THROW 50049, 'Please enter the payer name.', 1;
        IF @AccountMask IS NULL OR @AccountMask NOT LIKE '****[0-9][0-9][0-9][0-9]'
            THROW 50049, 'Please enter a valid card, account or mobile number.', 1;
        SELECT @DepartureTime = DepartureTime, @FlightStatus = Status, @BasePrice = BasePrice
        FROM Flights WHERE FlightID = @FlightID;
        IF @FlightStatus IS NULL
            THROW 50040, 'Flight does not exist.', 1;
        IF @FlightStatus <> 'Scheduled' OR @DepartureTime <= SYSDATETIME()
            THROW 50041, 'This flight is not open for booking.', 1;
        IF NOT EXISTS (SELECT 1 FROM Passengers WHERE PassengerID = @PassengerID)
            THROW 50042, 'Passenger does not exist.', 1;
        SELECT @Multiplier = PriceMultiplier
        FROM Seats WITH (UPDLOCK, HOLDLOCK)
        WHERE FlightID = @FlightID AND SeatNumber = @SeatNumber;
        IF @Multiplier IS NULL
            THROW 50043, 'This seat does not exist on the selected flight.', 1;
        IF EXISTS (SELECT 1 FROM Tickets WHERE FlightID = @FlightID AND SeatNumber = @SeatNumber AND Status = 'Active')
            THROW 50044, 'This seat is already taken.', 1;
        IF EXISTS (SELECT 1 FROM Bookings WHERE PassengerID = @PassengerID AND FlightID = @FlightID AND Status = 'Confirmed')
            THROW 50045, 'You already have a confirmed booking on this flight.', 1;
        SET @Price = CAST(@BasePrice * @Multiplier AS DECIMAL(10,2));
        INSERT INTO Bookings (PassengerID, FlightID, Status) VALUES (@PassengerID, @FlightID, 'Confirmed');
        SET @NewBookingID = SCOPE_IDENTITY();
        INSERT INTO Tickets (BookingID, FlightID, SeatNumber, Price) VALUES (@NewBookingID, @FlightID, @SeatNumber, @Price);
        SET @NewTicketID = SCOPE_IDENTITY();
        SET @Reference = 'PAY-' + RIGHT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 10);
        INSERT INTO Payments (BookingID, Amount, Method, Status, Reference, PayerName, AccountMask)
        VALUES (@NewBookingID, @Price, @PaymentMethod, 'Paid', @Reference, LTRIM(RTRIM(@PayerName)), @AccountMask);
        COMMIT TRANSACTION;
        SELECT @NewBookingID AS BookingID, @NewTicketID AS TicketID, @SeatNumber AS SeatNumber,
               @Price AS Price, @PaymentMethod AS PaymentMethod, @Reference AS PaymentReference, @AccountMask AS AccountMask;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- Cancel: frees the seat and records the refund. Refund rules (change if needed):
--   more than 48 hours before departure -> 100%,  24 to 48 hours -> 50%,  under 24 hours -> 0
CREATE OR ALTER PROCEDURE usp_CancelBooking
    @BookingID INT, @PassengerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OwnerID INT, @BookingStatus VARCHAR(20), @FlightID INT, @DepartureTime DATETIME2(0);
    DECLARE @Price DECIMAL(10,2), @Refund DECIMAL(10,2), @RefundMethod VARCHAR(20);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @OwnerID = PassengerID, @BookingStatus = Status, @FlightID = FlightID
        FROM Bookings WITH (UPDLOCK) WHERE BookingID = @BookingID;
        IF @OwnerID IS NULL OR @OwnerID <> @PassengerID
            THROW 50050, 'Booking not found.', 1;
        IF @BookingStatus = 'Cancelled'
            THROW 50051, 'This booking is already cancelled.', 1;
        SELECT @DepartureTime = DepartureTime FROM Flights WHERE FlightID = @FlightID;
        IF @DepartureTime <= SYSDATETIME()
            THROW 50052, 'A flight that has already departed cannot be cancelled.', 1;
        SELECT @Price = SUM(Price) FROM Tickets WHERE BookingID = @BookingID AND Status = 'Active';
        SET @Refund = CAST(
            CASE WHEN @DepartureTime > DATEADD(HOUR, 48, SYSDATETIME()) THEN @Price
                 WHEN @DepartureTime > DATEADD(HOUR, 24, SYSDATETIME()) THEN @Price * 0.50
                 ELSE 0 END AS DECIMAL(10,2));
        UPDATE Bookings SET Status = 'Cancelled', CancelledAt = SYSDATETIME() WHERE BookingID = @BookingID;
        UPDATE Tickets
        SET Status = 'Cancelled',
            RefundAmount = CAST(CASE WHEN @Price = 0 THEN 0 ELSE Price * @Refund / @Price END AS DECIMAL(10,2))
        WHERE BookingID = @BookingID AND Status = 'Active';
        IF @Refund > 0
        BEGIN
            SELECT TOP 1 @RefundMethod = Method FROM Payments
            WHERE BookingID = @BookingID AND Status = 'Paid' ORDER BY PaymentID;
            IF @RefundMethod IS NOT NULL
                INSERT INTO Payments (BookingID, Amount, Method, Status, Reference)
                VALUES (@BookingID, @Refund, @RefundMethod, 'Refunded',
                        'REF-' + RIGHT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 10));
        END;
        COMMIT TRANSACTION;
        SELECT @BookingID AS BookingID, 'Cancelled' AS Status, @Refund AS RefundAmount, @RefundMethod AS RefundMethod;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE usp_GetPassengerBookings
    @PassengerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.BookingID, b.Status AS BookingStatus, b.BookingDate, f.FlightNumber, f.OriginCode, f.DestinationCode,
           f.DepartureTime, f.ArrivalTime, tk.SeatNumbers AS SeatNumber, tk.TotalPrice AS Price, tk.TotalRefund AS RefundAmount,
           pay.Method AS PaymentMethod, pay.Reference AS PaymentReference,
           CASE WHEN b.Status = 'Confirmed' THEN CAST(
               CASE WHEN f.DepartureTime > DATEADD(HOUR, 48, SYSDATETIME()) THEN tk.TotalPrice
                    WHEN f.DepartureTime > DATEADD(HOUR, 24, SYSDATETIME()) THEN tk.TotalPrice * 0.50
                    ELSE 0 END AS DECIMAL(10,2)) END AS ExpectedRefund
    FROM Bookings b
    JOIN Flights f ON f.FlightID = b.FlightID
    CROSS APPLY (SELECT STRING_AGG(t.SeatNumber, ', ') WITHIN GROUP (ORDER BY t.SeatNumber) AS SeatNumbers,
                        SUM(t.Price) AS TotalPrice, SUM(t.RefundAmount) AS TotalRefund
                 FROM Tickets t WHERE t.BookingID = b.BookingID) tk
    OUTER APPLY (SELECT TOP 1 Method, Reference FROM Payments
                 WHERE BookingID = b.BookingID AND Status = 'Paid' ORDER BY PaymentID) pay
    WHERE b.PassengerID = @PassengerID
    ORDER BY f.DepartureTime DESC;
END;
GO
-- Group seat finder: suggests up to 3 blocks of neighbouring free seats in one row.
-- Blocks that do not cross the aisle (between seats C and D) come first, then the front rows.
CREATE OR ALTER PROCEDURE usp_FindAdjacentSeats
    @FlightID INT,
    @GroupSize INT,
    @SeatClass VARCHAR(20) = 'Any'
AS
BEGIN
    SET NOCOUNT ON;
    IF @GroupSize < 2 OR @GroupSize > 6
        THROW 50047, 'A group needs 2 to 6 seats.', 1;
    DECLARE @BasePrice DECIMAL(10,2) = (SELECT BasePrice FROM Flights WHERE FlightID = @FlightID);
    IF @BasePrice IS NULL
        THROW 50040, 'Flight does not exist.', 1;
    -- Work out the free seats ONCE, then search blocks inside that small list.
    CREATE TABLE #Free (
        RowNo INT NOT NULL, Col INT NOT NULL, SeatNumber VARCHAR(10) NOT NULL, Price DECIMAL(10,2) NOT NULL,
        PRIMARY KEY (RowNo, Col));
    INSERT INTO #Free (RowNo, Col, SeatNumber, Price)
    SELECT CAST(LEFT(s.SeatNumber, LEN(s.SeatNumber) - 1) AS INT), ASCII(RIGHT(s.SeatNumber, 1)) - 64,
           s.SeatNumber, CAST(@BasePrice * s.PriceMultiplier AS DECIMAL(10,2))
    FROM Seats s
    LEFT JOIN Tickets t ON t.FlightID = s.FlightID AND t.SeatNumber = s.SeatNumber AND t.Status = 'Active'
    WHERE s.FlightID = @FlightID AND t.TicketID IS NULL
      AND (@SeatClass = 'Any' OR s.SeatClass = @SeatClass);
    SELECT TOP (3) a.RowNo,
           CASE WHEN a.Col <= 3 AND a.Col + @GroupSize - 1 >= 4 THEN 1 ELSE 0 END AS CrossesAisle,
           STRING_AGG(b.SeatNumber, ',') WITHIN GROUP (ORDER BY b.Col) AS Seats,
           CAST(SUM(b.Price) AS DECIMAL(10,2)) AS TotalPrice
    FROM #Free a
    JOIN #Free b ON b.RowNo = a.RowNo AND b.Col BETWEEN a.Col AND a.Col + @GroupSize - 1
    GROUP BY a.RowNo, a.Col
    HAVING COUNT(*) = @GroupSize
    ORDER BY CASE WHEN a.Col <= 3 AND a.Col + @GroupSize - 1 >= 4 THEN 1 ELSE 0 END, a.RowNo, a.Col;
END;
GO
-- Group booking: 2 to 6 seats chosen by the passenger (the finder suggests neighbouring ones),
-- one booking, one payment. All seats or none.
CREATE OR ALTER PROCEDURE usp_BookGroup
    @PassengerID INT,
    @FlightID INT,
    @SeatNumbers VARCHAR(200),
    @PaymentMethod VARCHAR(20) = 'Card',
    @PayerName VARCHAR(100) = NULL,
    @AccountMask VARCHAR(8) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @DepartureTime DATETIME2(0), @FlightStatus VARCHAR(20), @BasePrice DECIMAL(10,2);
    DECLARE @SeatCount INT, @FoundCount INT, @Total DECIMAL(10,2), @NewBookingID INT, @Reference VARCHAR(30);
    DECLARE @Wanted TABLE (SeatNumber VARCHAR(10) PRIMARY KEY);
    INSERT INTO @Wanted
    SELECT DISTINCT UPPER(LTRIM(RTRIM(value))) FROM STRING_SPLIT(@SeatNumbers, ',') WHERE LTRIM(RTRIM(value)) <> '';
    SELECT @SeatCount = COUNT(*) FROM @Wanted;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @PaymentMethod NOT IN ('Card', 'JazzCash', 'Easypaisa', 'Bank Transfer')
            THROW 50046, 'Please choose a valid payment method.', 1;
        IF LEN(LTRIM(RTRIM(ISNULL(@PayerName, '')))) < 2
            THROW 50049, 'Please enter the payer name.', 1;
        IF @AccountMask IS NULL OR @AccountMask NOT LIKE '****[0-9][0-9][0-9][0-9]'
            THROW 50049, 'Please enter a valid card, account or mobile number.', 1;
        IF @SeatCount < 2 OR @SeatCount > 6
            THROW 50047, 'A group booking needs 2 to 6 seats.', 1;
        SELECT @DepartureTime = DepartureTime, @FlightStatus = Status, @BasePrice = BasePrice
        FROM Flights WHERE FlightID = @FlightID;
        IF @FlightStatus IS NULL
            THROW 50040, 'Flight does not exist.', 1;
        IF @FlightStatus <> 'Scheduled' OR @DepartureTime <= SYSDATETIME()
            THROW 50041, 'This flight is not open for booking.', 1;
        IF NOT EXISTS (SELECT 1 FROM Passengers WHERE PassengerID = @PassengerID)
            THROW 50042, 'Passenger does not exist.', 1;
        SELECT @FoundCount = COUNT(*) FROM Seats WITH (UPDLOCK, HOLDLOCK)
        WHERE FlightID = @FlightID AND SeatNumber IN (SELECT SeatNumber FROM @Wanted);
        IF @FoundCount <> @SeatCount
            THROW 50043, 'One of the seats does not exist on this flight.', 1;
        IF EXISTS (SELECT 1 FROM Tickets WHERE FlightID = @FlightID AND Status = 'Active'
                   AND SeatNumber IN (SELECT SeatNumber FROM @Wanted))
            THROW 50044, 'One of these seats is already taken.', 1;
        IF EXISTS (SELECT 1 FROM Bookings WHERE PassengerID = @PassengerID AND FlightID = @FlightID AND Status = 'Confirmed')
            THROW 50045, 'You already have a confirmed booking on this flight.', 1;
        INSERT INTO Bookings (PassengerID, FlightID, Status) VALUES (@PassengerID, @FlightID, 'Confirmed');
        SET @NewBookingID = SCOPE_IDENTITY();
        INSERT INTO Tickets (BookingID, FlightID, SeatNumber, Price)
        SELECT @NewBookingID, @FlightID, s.SeatNumber, CAST(@BasePrice * s.PriceMultiplier AS DECIMAL(10,2))
        FROM Seats s JOIN @Wanted w ON w.SeatNumber = s.SeatNumber
        WHERE s.FlightID = @FlightID;
        SELECT @Total = SUM(Price) FROM Tickets WHERE BookingID = @NewBookingID;
        SET @Reference = 'PAY-' + RIGHT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 10);
        INSERT INTO Payments (BookingID, Amount, Method, Status, Reference, PayerName, AccountMask)
        VALUES (@NewBookingID, @Total, @PaymentMethod, 'Paid', @Reference, LTRIM(RTRIM(@PayerName)), @AccountMask);
        COMMIT TRANSACTION;
        SELECT @NewBookingID AS BookingID,
               (SELECT STRING_AGG(SeatNumber, ', ') WITHIN GROUP (ORDER BY SeatNumber) FROM @Wanted) AS SeatNumber,
               @Total AS Price, @PaymentMethod AS PaymentMethod, @Reference AS PaymentReference, @AccountMask AS AccountMask;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Full seat map of a flight (free and taken seats) for the plane-style seat picker.
CREATE OR ALTER PROCEDURE usp_GetSeatMap
    @FlightID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT s.SeatNumber, s.SeatClass, CAST(f.BasePrice * s.PriceMultiplier AS DECIMAL(10,2)) AS Price,
           CASE WHEN EXISTS (SELECT 1 FROM Tickets t WHERE t.FlightID = s.FlightID AND t.SeatNumber = s.SeatNumber AND t.Status = 'Active')
                THEN 1 ELSE 0 END AS IsTaken
    FROM Seats s
    JOIN Flights f ON f.FlightID = s.FlightID
    WHERE s.FlightID = @FlightID;
END;
GO

/* ---------------- PART 3 - Sample data ---------------- */
INSERT INTO Airports (AirportCode, City, Country) VALUES
    ('KHI', 'Karachi', 'Pakistan'), ('LHE', 'Lahore', 'Pakistan'), ('ISB', 'Islamabad', 'Pakistan'),
    ('MUX', 'Multan', 'Pakistan'), ('PEW', 'Peshawar', 'Pakistan'), ('SKT', 'Sialkot', 'Pakistan');
GO
-- Flight dates are calculated from the day you run this script (DayOffset = days from today,
-- DepartMinutes = minutes after midnight), so the sample flights are always in the near future.
-- WeekShift moves every flight 7 days later, so all flights fall in the week after next week.
-- Change the 7 below to 0 for next week, or 14 for the week after that.
DECLARE @Today DATETIME2(0) = CAST(CAST(SYSDATETIME() AS DATE) AS DATETIME2(0));
INSERT INTO Flights (FlightNumber, OriginCode, DestinationCode, DepartureTime, ArrivalTime, Capacity, BasePrice)
SELECT CONCAT(v.FlightNumber, w.Suffix), v.OriginCode, v.DestinationCode,
       DATEADD(MINUTE, v.DepartMinutes, DATEADD(DAY, v.DayOffset + w.WeekShift, @Today)),
       DATEADD(MINUTE, v.DepartMinutes + v.DurationMinutes, DATEADD(DAY, v.DayOffset + w.WeekShift, @Today)),
       v.Capacity, v.BasePrice
FROM (VALUES
    ('PK-300', 'KHI', 'ISB', 1,  480, 120, 150, 22000.00),
    ('PK-302', 'KHI', 'LHE', 2,  840, 105, 180, 20000.00),
    ('PK-301', 'ISB', 'KHI', 3, 1080, 120, 150, 22000.00),
    ('PK-901', 'ISB', 'SKT', 3,  900,  55, 150, 11000.00),
    ('PK-211', 'MUX', 'KHI', 4,  360,  75, 120, 15000.00),
    ('PK-741', 'PEW', 'ISB', 5,  840,  50, 250,  9000.00),
    ('PK-799', 'SKT', 'PEW', 6,  600,  65, 230, 14000.00),
    ('PK-739', 'SKT', 'MUX', 6, 1200,  80, 230, 12000.00)
) AS v (FlightNumber, OriginCode, DestinationCode, DayOffset, DepartMinutes, DurationMinutes, Capacity, BasePrice)
CROSS JOIN (VALUES (7, '')) AS w (WeekShift, Suffix);
GO
DECLARE @CurrentFlightID INT = (SELECT MIN(FlightID) FROM Flights);
WHILE @CurrentFlightID IS NOT NULL
BEGIN
    EXEC usp_GenerateSeats @FlightID = @CurrentFlightID;
    SELECT @CurrentFlightID = MIN(FlightID) FROM Flights WHERE FlightID > @CurrentFlightID;
END;
GO
-- Demo admin account (CHANGE THIS PASSWORD before real use)
DECLARE @AdminSalt VARBINARY(16) = CRYPT_GEN_RANDOM(16);
DECLARE @AdminPassword NVARCHAR(100) = N'Admin@12345';
INSERT INTO Users (Email, PasswordHash, PasswordSalt, Role)
VALUES ('admin@airline.com', HASHBYTES('SHA2_256', @AdminSalt + CONVERT(VARBINARY(200), @AdminPassword)), @AdminSalt, 'Admin');
GO
-- Demo customer account for testing
EXEC usp_RegisterUser @FullName = 'Demo Passenger', @Email = 'demo@example.com', @Phone = '0300-0000000', @Password = N'Demo@12345';
GO

/* ---------------- PART 4 - Application login ----------------
   The Java app connects with a SQL login. The password is NOT stored in this file.
   A) FIRST TIME ONLY: remove the comment markers, choose your own password, run it once
      (SQL Server must allow "SQL Server and Windows Authentication mode"):

   USE master;
   CREATE LOGIN airline_app WITH PASSWORD = 'CHOOSE_YOUR_PASSWORD', CHECK_POLICY = OFF;
   GO
   USE AirlineWEBDB;
   GO

   B) Every run: if the login already exists, give it access to this fresh database. */
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'airline_app')
BEGIN
    CREATE USER airline_app FOR LOGIN airline_app;
    GRANT EXECUTE TO airline_app;
    GRANT SELECT ON Airports TO airline_app;
END
GO

/* ---------------- PART 5 - Test examples (select a line and press F5) ----------------

EXEC usp_LoginUser @Email = 'demo@example.com', @Password = N'Demo@12345';
EXEC usp_GetUpcomingFlights;
EXEC usp_FindAdjacentSeats @FlightID = 1, @GroupSize = 3, @SeatClass = 'Economy';
EXEC usp_BookGroup @PassengerID = 1, @FlightID = 1, @SeatNumbers = '12A,12B,12C', @PaymentMethod = 'Easypaisa', @PayerName = 'Demo Passenger', @AccountMask = '****4567';
EXEC usp_GetAvailableSeats @FlightID = 1;
EXEC usp_GetSeatMap @FlightID = 1;
EXEC usp_BookFlight @PassengerID = 1, @FlightID = 1, @SeatNumber = '5C', @PaymentMethod = 'Easypaisa', @PayerName = 'Demo Passenger', @AccountMask = '****4567';
EXEC usp_GetPassengerBookings @PassengerID = 1;
EXEC usp_CancelBooking @BookingID = 1, @PassengerID = 1;
SELECT * FROM Payments;

   --------------------------------------------------------------------- */