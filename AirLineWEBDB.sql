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
-- One phone number can belong to only one account (empty phones are ignored).
CREATE UNIQUE INDEX UX_Passengers_Phone ON Passengers (Phone) WHERE Phone IS NOT NULL;
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
    CONSTRAINT CK_Bookings_Status CHECK (Status IN ('Confirmed', 'Cancelled', 'Rebooked'))
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

/* ---- Round 2 tables: baggage, lost-baggage claims, feedback ---- */
IF OBJECT_ID('Baggage', 'U') IS NULL
BEGIN
    CREATE TABLE Baggage (
        BagID     INT IDENTITY(1,1) NOT NULL,
        BookingID INT NOT NULL,
        TagNumber VARCHAR(20) NOT NULL,
        WeightKg  DECIMAL(5,1) NOT NULL CONSTRAINT DF_Baggage_Weight DEFAULT 0,
        Fee       DECIMAL(10,2) NOT NULL CONSTRAINT DF_Baggage_Fee DEFAULT 0,
        Status    VARCHAR(20) NOT NULL CONSTRAINT DF_Baggage_Status DEFAULT 'Checked In',
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Baggage_Created DEFAULT SYSDATETIME(),
        CONSTRAINT PK_Baggage PRIMARY KEY (BagID),
        CONSTRAINT UQ_Baggage_Tag UNIQUE (TagNumber),
        CONSTRAINT FK_Baggage_Booking FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID),
        CONSTRAINT CK_Baggage_Status CHECK (Status IN ('Checked In', 'Lost', 'Arrived', 'Delivered'))
    );
    CREATE INDEX IX_Baggage_Booking ON Baggage (BookingID);
END
GO
IF OBJECT_ID('BaggageClaims', 'U') IS NULL
BEGIN
    CREATE TABLE BaggageClaims (
        ClaimID            INT IDENTITY(1,1) NOT NULL,
        BagID              INT NOT NULL,
        PassengerID        INT NOT NULL,
        ClaimReference     VARCHAR(20) NOT NULL,
        ClaimType          VARCHAR(20) NOT NULL,
        Description        VARCHAR(500) NOT NULL,
        ContactPhone       VARCHAR(20) NOT NULL,
        Status             VARCHAR(30) NOT NULL CONSTRAINT DF_Claims_Status DEFAULT 'Reported',
        CompensationAmount DECIMAL(10,2) NULL,
        CreatedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Claims_Created DEFAULT SYSDATETIME(),
        CONSTRAINT PK_BaggageClaims PRIMARY KEY (ClaimID),
        CONSTRAINT UQ_Claims_Reference UNIQUE (ClaimReference),
        CONSTRAINT FK_Claims_Bag FOREIGN KEY (BagID) REFERENCES Baggage(BagID),
        CONSTRAINT FK_Claims_Passenger FOREIGN KEY (PassengerID) REFERENCES Passengers(PassengerID),
        CONSTRAINT CK_Claims_Type CHECK (ClaimType IN ('Lost', 'Delayed', 'Damaged')),
        CONSTRAINT CK_Claims_Status CHECK (Status IN ('Reported', 'Searching', 'Found', 'Delivered', 'Compensation Approved'))
    );
    CREATE TABLE ClaimUpdates (
        UpdateID  INT IDENTITY(1,1) NOT NULL,
        ClaimID   INT NOT NULL,
        Status    VARCHAR(30) NOT NULL,
        Note      VARCHAR(300) NOT NULL CONSTRAINT DF_ClaimUpdates_Note DEFAULT '',
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ClaimUpdates_Created DEFAULT SYSDATETIME(),
        CONSTRAINT PK_ClaimUpdates PRIMARY KEY (UpdateID),
        CONSTRAINT FK_ClaimUpdates_Claim FOREIGN KEY (ClaimID) REFERENCES BaggageClaims(ClaimID)
    );
END
GO
IF OBJECT_ID('Feedback', 'U') IS NULL
BEGIN
    CREATE TABLE Feedback (
        FeedbackID  INT IDENTITY(1,1) NOT NULL,
        PassengerID INT NOT NULL,
        BookingID   INT NULL,
        Rating      TINYINT NOT NULL,
        Category    VARCHAR(30) NOT NULL,
        Comment     VARCHAR(1000) NOT NULL,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_Feedback_Created DEFAULT SYSDATETIME(),
        CONSTRAINT PK_Feedback PRIMARY KEY (FeedbackID),
        CONSTRAINT FK_Feedback_Passenger FOREIGN KEY (PassengerID) REFERENCES Passengers(PassengerID),
        CONSTRAINT FK_Feedback_Booking FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID),
        CONSTRAINT CK_Feedback_Rating CHECK (Rating BETWEEN 1 AND 5),
        CONSTRAINT CK_Feedback_Category CHECK (Category IN ('Booking', 'Payment', 'Flight', 'Baggage', 'Website', 'Other'))
    );
END
GO
GO

/* ---- Round 3 table: flight re-allocation log ---- */
CREATE TABLE Reallocations (
    ReallocationID INT IDENTITY(1,1) NOT NULL,
    OldBookingID   INT NOT NULL,
    NewBookingID   INT NOT NULL,
    OldFlightID    INT NOT NULL,
    NewFlightID    INT NOT NULL,
    OldSeats       VARCHAR(200) NOT NULL,
    NewSeats       VARCHAR(200) NOT NULL,
    Reason         VARCHAR(200) NOT NULL,
    MovedBy        VARCHAR(100) NOT NULL,
    MovedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_Realloc_MovedAt DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Reallocations PRIMARY KEY (ReallocationID),
    CONSTRAINT UQ_Realloc_OldBooking UNIQUE (OldBookingID),
    CONSTRAINT FK_Realloc_OldBooking FOREIGN KEY (OldBookingID) REFERENCES Bookings(BookingID),
    CONSTRAINT FK_Realloc_NewBooking FOREIGN KEY (NewBookingID) REFERENCES Bookings(BookingID),
    CONSTRAINT FK_Realloc_OldFlight FOREIGN KEY (OldFlightID) REFERENCES Flights(FlightID),
    CONSTRAINT FK_Realloc_NewFlight FOREIGN KEY (NewFlightID) REFERENCES Flights(FlightID)
);
CREATE INDEX IX_Realloc_NewBooking ON Reallocations (NewBookingID);
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
    -- Keep digits only, and treat +92300... and 0300... as the same number.
    DECLARE @Digits VARCHAR(20) = '';
    DECLARE @i INT = 1;
    WHILE @i <= LEN(ISNULL(@Phone, ''))
    BEGIN
        IF SUBSTRING(@Phone, @i, 1) LIKE '[0-9]' SET @Digits += SUBSTRING(@Phone, @i, 1);
        SET @i += 1;
    END;
    IF LEFT(@Digits, 2) = '92' AND LEN(@Digits) = 12 SET @Digits = '0' + SUBSTRING(@Digits, 3, 20);
    IF LEN(@Digits) < 10 OR LEN(@Digits) > 15
        THROW 50023, 'Please enter a valid phone number (10 to 15 digits).', 1;
    SET @Phone = @Digits;
    IF LEN(@Password) < 8
        THROW 50020, 'Password must be at least 8 characters.', 1;
    IF @Password NOT LIKE '%[A-Z]%' COLLATE Latin1_General_BIN
       OR @Password NOT LIKE '%[a-z]%' COLLATE Latin1_General_BIN
       OR @Password NOT LIKE '%[0-9]%'
       OR @Password NOT LIKE '%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN
        THROW 50022, 'Password needs an uppercase letter, a lowercase letter, a number and a special character.', 1;
    IF EXISTS (SELECT 1 FROM Users WHERE Email = @Email) OR EXISTS (SELECT 1 FROM Passengers WHERE Email = @Email)
        THROW 50021, 'This email is already registered.', 1;
    IF EXISTS (SELECT 1 FROM Passengers WHERE Phone = @Phone)
        THROW 50024, 'This phone number is already registered to another account.', 1;
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
    @PayerName VARCHAR(100) = NULL, @AccountMask VARCHAR(8) = NULL, @BaggageKg INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @DepartureTime DATETIME2(0), @FlightStatus VARCHAR(20), @BasePrice DECIMAL(10,2);
    DECLARE @BagFee DECIMAL(10,2) = 0, @Paid DECIMAL(10,2), @Multiplier DECIMAL(4,2), @Price DECIMAL(10,2), @NewBookingID INT, @NewTicketID INT, @Reference VARCHAR(30);
    SET @SeatNumber = UPPER(LTRIM(RTRIM(@SeatNumber)));
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @PaymentMethod NOT IN ('Card', 'JazzCash', 'Easypaisa', 'Bank Transfer')
            THROW 50046, 'Please choose a valid payment method.', 1;
        IF LEN(LTRIM(RTRIM(ISNULL(@PayerName, '')))) < 2
            THROW 50049, 'Please enter the payer name.', 1;
        IF @AccountMask IS NULL OR @AccountMask NOT LIKE '****[0-9][0-9][0-9][0-9]'
            THROW 50049, 'Please enter a valid card, account or mobile number.', 1;
        IF @BaggageKg < 0 OR @BaggageKg > 40
            THROW 50065, 'Baggage can be 0 to 40 kg per passenger.', 1;
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
        SET @BagFee = CASE WHEN @BaggageKg > 20 THEN (@BaggageKg - 20) * 500 ELSE 0 END;
        SET @Paid = @Price + @BagFee;
        INSERT INTO Bookings (PassengerID, FlightID, Status) VALUES (@PassengerID, @FlightID, 'Confirmed');
        SET @NewBookingID = SCOPE_IDENTITY();
        INSERT INTO Tickets (BookingID, FlightID, SeatNumber, Price) VALUES (@NewBookingID, @FlightID, @SeatNumber, @Price);
        SET @NewTicketID = SCOPE_IDENTITY();
        IF @BaggageKg > 0
        BEGIN
            ;WITH n AS (SELECT TOP (CAST(CEILING(@BaggageKg / 23.0) AS INT)) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS i FROM sys.all_objects)
            INSERT INTO Baggage (BookingID, TagNumber, WeightKg, Fee)
            SELECT @NewBookingID, 'BG' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 100000000 AS VARCHAR(8)), 8),
                   c.CumEnd - c.CumStart,
                   (CASE WHEN c.CumEnd > 1 * 20 THEN c.CumEnd - 1 * 20 ELSE 0 END
                    - CASE WHEN c.CumStart > 1 * 20 THEN c.CumStart - 1 * 20 ELSE 0 END) * 500
            FROM n
            CROSS APPLY (SELECT 23 * (i - 1) AS CumStart, CASE WHEN 23 * i < @BaggageKg THEN 23 * i ELSE @BaggageKg END AS CumEnd) c;
        END;
        SET @Reference = 'PAY-' + RIGHT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 10);
        INSERT INTO Payments (BookingID, Amount, Method, Status, Reference, PayerName, AccountMask)
        VALUES (@NewBookingID, @Paid, @PaymentMethod, 'Paid', @Reference, LTRIM(RTRIM(@PayerName)), @AccountMask);
        COMMIT TRANSACTION;
        SELECT @NewBookingID AS BookingID, @NewTicketID AS TicketID, @SeatNumber AS SeatNumber,
               @Paid AS Price, @Price AS TicketPrice, @BagFee AS BaggageFee, @BaggageKg AS BaggageKg, CAST(CEILING(@BaggageKg / 23.0) AS INT) AS BagCount, @PaymentMethod AS PaymentMethod, @Reference AS PaymentReference, @AccountMask AS AccountMask;
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
    DECLARE @OwnerID INT, @BookingStatus VARCHAR(20), @FlightID INT, @DepartureTime DATETIME2(0), @FlightStatus VARCHAR(20);
    DECLARE @Price DECIMAL(10,2), @Refund DECIMAL(10,2), @RefundMethod VARCHAR(20);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @OwnerID = PassengerID, @BookingStatus = Status, @FlightID = FlightID
        FROM Bookings WITH (UPDLOCK) WHERE BookingID = @BookingID;
        IF @OwnerID IS NULL OR @OwnerID <> @PassengerID
            THROW 50050, 'Booking not found.', 1;
        IF @BookingStatus = 'Cancelled'
            THROW 50051, 'This booking is already cancelled.', 1;
        IF @BookingStatus = 'Rebooked'
            THROW 50053, 'This booking was moved to another flight. Cancel the new booking instead.', 1;
        SELECT @DepartureTime = DepartureTime, @FlightStatus = Status FROM Flights WHERE FlightID = @FlightID;
        IF @DepartureTime <= SYSDATETIME() AND @FlightStatus <> 'Cancelled'
            THROW 50052, 'A flight that has already departed cannot be cancelled.', 1;
        SELECT @Price = SUM(Price) FROM Tickets WHERE BookingID = @BookingID AND Status = 'Active';
        SET @Refund = CAST(
            CASE WHEN @FlightStatus = 'Cancelled' THEN @Price
                 WHEN @DepartureTime > DATEADD(HOUR, 48, SYSDATETIME()) THEN @Price
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
               CASE WHEN f.Status = 'Cancelled' THEN tk.TotalPrice
                    WHEN f.DepartureTime > DATEADD(HOUR, 48, SYSDATETIME()) THEN tk.TotalPrice
                    WHEN f.DepartureTime > DATEADD(HOUR, 24, SYSDATETIME()) THEN tk.TotalPrice * 0.50
                    ELSE 0 END AS DECIMAL(10,2)) END AS ExpectedRefund,
           f.Status AS FlightStatus,
           mv.MovedFromFlight, mv.MovedFromSeats, mv.MoveReason, mv.MovedAt,
           mt.MovedToBooking
    FROM Bookings b
    JOIN Flights f ON f.FlightID = b.FlightID
    CROSS APPLY (SELECT STRING_AGG(t.SeatNumber, ', ') WITHIN GROUP (ORDER BY t.SeatNumber) AS SeatNumbers,
                        SUM(t.Price) AS TotalPrice, SUM(t.RefundAmount) AS TotalRefund
                 FROM Tickets t WHERE t.BookingID = b.BookingID) tk
    OUTER APPLY (SELECT TOP 1 Method, Reference FROM Payments
                 WHERE BookingID = b.BookingID AND Status = 'Paid' ORDER BY PaymentID) pay
    OUTER APPLY (SELECT TOP 1 fo.FlightNumber AS MovedFromFlight, r.OldSeats AS MovedFromSeats,
                        r.Reason AS MoveReason, r.MovedAt
                 FROM Reallocations r JOIN Flights fo ON fo.FlightID = r.OldFlightID
                 WHERE r.NewBookingID = b.BookingID ORDER BY r.ReallocationID DESC) mv
    OUTER APPLY (SELECT TOP 1 r2.NewBookingID AS MovedToBooking
                 FROM Reallocations r2 WHERE r2.OldBookingID = b.BookingID) mt
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
    @AccountMask VARCHAR(8) = NULL,
    @BaggageKg INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @DepartureTime DATETIME2(0), @FlightStatus VARCHAR(20), @BasePrice DECIMAL(10,2);
    DECLARE @BagFee DECIMAL(10,2) = 0, @Paid DECIMAL(10,2), @SeatCount INT, @FoundCount INT, @Total DECIMAL(10,2), @NewBookingID INT, @Reference VARCHAR(30);
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
        IF @BaggageKg < 0 OR @BaggageKg > @SeatCount * 40
            THROW 50065, 'Baggage can be 0 to 40 kg per passenger.', 1;
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
        SET @BagFee = CASE WHEN @BaggageKg > @SeatCount * 20 THEN (@BaggageKg - @SeatCount * 20) * 500 ELSE 0 END;
        SET @Paid = @Total + @BagFee;
        IF @BaggageKg > 0
        BEGIN
            ;WITH n AS (SELECT TOP (CAST(CEILING(@BaggageKg / 23.0) AS INT)) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS i FROM sys.all_objects)
            INSERT INTO Baggage (BookingID, TagNumber, WeightKg, Fee)
            SELECT @NewBookingID, 'BG' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 100000000 AS VARCHAR(8)), 8),
                   c.CumEnd - c.CumStart,
                   (CASE WHEN c.CumEnd > @SeatCount * 20 THEN c.CumEnd - @SeatCount * 20 ELSE 0 END
                    - CASE WHEN c.CumStart > @SeatCount * 20 THEN c.CumStart - @SeatCount * 20 ELSE 0 END) * 500
            FROM n
            CROSS APPLY (SELECT 23 * (i - 1) AS CumStart, CASE WHEN 23 * i < @BaggageKg THEN 23 * i ELSE @BaggageKg END AS CumEnd) c;
        END;
        SET @Reference = 'PAY-' + RIGHT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 10);
        INSERT INTO Payments (BookingID, Amount, Method, Status, Reference, PayerName, AccountMask)
        VALUES (@NewBookingID, @Paid, @PaymentMethod, 'Paid', @Reference, LTRIM(RTRIM(@PayerName)), @AccountMask);
        COMMIT TRANSACTION;
        SELECT @NewBookingID AS BookingID,
               (SELECT STRING_AGG(SeatNumber, ', ') WITHIN GROUP (ORDER BY SeatNumber) FROM @Wanted) AS SeatNumber,
               @Paid AS Price, @Total AS TicketPrice, @BagFee AS BaggageFee, @BaggageKg AS BaggageKg, CAST(CEILING(@BaggageKg / 23.0) AS INT) AS BagCount, @PaymentMethod AS PaymentMethod, @Reference AS PaymentReference, @AccountMask AS AccountMask;
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

/* ---- Round 2 procedures: baggage, claims, feedback ---- */
-- Baggage: 1 free bag per passenger, extra bags PKR 3,000 each, maximum 3 bags per passenger.
CREATE OR ALTER PROCEDURE usp_AddBaggage
    @BookingID INT, @PassengerID INT, @WeightKg INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Owner INT, @BookingStatus VARCHAR(20), @DepartureTime DATETIME2(0), @Seats INT, @Existing INT, @Fee DECIMAL(10,2);
    SELECT @Owner = b.PassengerID, @BookingStatus = b.Status, @DepartureTime = f.DepartureTime
    FROM Bookings b JOIN Flights f ON f.FlightID = b.FlightID WHERE b.BookingID = @BookingID;
    IF @Owner IS NULL OR @Owner <> @PassengerID THROW 50060, 'Booking not found.', 1;
    IF @BookingStatus <> 'Confirmed' THROW 50061, 'Baggage can only be added to a confirmed booking.', 1;
    IF @DepartureTime <= SYSDATETIME() THROW 50062, 'This flight has already departed.', 1;
    IF @WeightKg < 1 THROW 50063, 'Enter the baggage weight in kg.', 1;
    SELECT @Seats = COUNT(*) FROM Tickets WHERE BookingID = @BookingID AND Status = 'Active';
    SELECT @Existing = CAST(ISNULL(SUM(WeightKg), 0) AS INT) FROM Baggage WHERE BookingID = @BookingID;
    IF @Existing + @WeightKg > @Seats * 40 THROW 50064, 'Maximum 40 kg of baggage per passenger.', 1;
    SET @Fee = (CASE WHEN @Existing + @WeightKg > @Seats * 20 THEN @Existing + @WeightKg - @Seats * 20 ELSE 0 END
              - CASE WHEN @Existing > @Seats * 20 THEN @Existing - @Seats * 20 ELSE 0 END) * 500;
    ;WITH n AS (SELECT TOP (CAST(CEILING(@WeightKg / 23.0) AS INT)) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS i FROM sys.all_objects)
    INSERT INTO Baggage (BookingID, TagNumber, WeightKg, Fee)
    SELECT @BookingID, 'BG' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 100000000 AS VARCHAR(8)), 8),
           c.CumEnd - c.CumStart,
           (CASE WHEN @Existing + c.CumEnd > @Seats * 20 THEN @Existing + c.CumEnd - @Seats * 20 ELSE 0 END
            - CASE WHEN @Existing + c.CumStart > @Seats * 20 THEN @Existing + c.CumStart - @Seats * 20 ELSE 0 END) * 500
    FROM n
    CROSS APPLY (SELECT 23 * (i - 1) AS CumStart, CASE WHEN 23 * i < @WeightKg THEN 23 * i ELSE @WeightKg END AS CumEnd) c;
    SELECT CAST(CEILING(@WeightKg / 23.0) AS INT) AS BagsAdded, @WeightKg AS WeightKg, @Fee AS TotalFee;
END;
GO
CREATE OR ALTER PROCEDURE usp_GetBaggage
    @PassengerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT g.BagID, g.TagNumber, g.WeightKg, g.Fee, g.Status AS BagStatus, b.BookingID, f.FlightNumber, f.OriginCode, f.DestinationCode,
           f.DepartureTime, c.ClaimReference, c.Status AS ClaimStatus
    FROM Baggage g
    JOIN Bookings b ON b.BookingID = g.BookingID
    JOIN Flights f ON f.FlightID = b.FlightID
    OUTER APPLY (SELECT TOP 1 ClaimReference, Status FROM BaggageClaims WHERE BagID = g.BagID ORDER BY ClaimID DESC) c
    WHERE b.PassengerID = @PassengerID AND b.Status = 'Confirmed'
    ORDER BY g.BagID DESC;
END;
GO
-- Report a lost, delayed or damaged bag. (Demo: reporting is allowed at any time so you can test it.)
CREATE OR ALTER PROCEDURE usp_ReportBaggageIssue
    @BagID INT, @PassengerID INT, @ClaimType VARCHAR(20), @Description VARCHAR(500), @ContactPhone VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Owner INT, @Reference VARCHAR(20), @ClaimID INT;
    SELECT @Owner = b.PassengerID FROM Baggage g JOIN Bookings b ON b.BookingID = g.BookingID WHERE g.BagID = @BagID;
    IF @Owner IS NULL OR @Owner <> @PassengerID THROW 50070, 'Bag not found.', 1;
    IF @ClaimType NOT IN ('Lost', 'Delayed', 'Damaged') THROW 50071, 'Choose Lost, Delayed or Damaged.', 1;
    IF LEN(LTRIM(RTRIM(ISNULL(@Description, '')))) < 10 THROW 50072, 'Please describe the problem (at least 10 characters).', 1;
    IF LEN(LTRIM(RTRIM(ISNULL(@ContactPhone, '')))) < 7 THROW 50073, 'Please enter a contact phone number.', 1;
    IF EXISTS (SELECT 1 FROM BaggageClaims WHERE BagID = @BagID AND Status NOT IN ('Delivered', 'Compensation Approved'))
        THROW 50074, 'This bag already has an open claim.', 1;
    SET @Reference = 'LC-' + RIGHT('000000' + CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS VARCHAR(6)), 6);
    BEGIN TRANSACTION;
    INSERT INTO BaggageClaims (BagID, PassengerID, ClaimReference, ClaimType, Description, ContactPhone)
    VALUES (@BagID, @PassengerID, @Reference, @ClaimType, LTRIM(RTRIM(@Description)), LTRIM(RTRIM(@ContactPhone)));
    SET @ClaimID = SCOPE_IDENTITY();
    INSERT INTO ClaimUpdates (ClaimID, Status, Note) VALUES (@ClaimID, 'Reported', 'Claim received. We will start searching for your bag.');
    IF @ClaimType = 'Lost' UPDATE Baggage SET Status = 'Lost' WHERE BagID = @BagID;
    COMMIT TRANSACTION;
    SELECT @Reference AS ClaimReference;
END;
GO
-- @PassengerID = 0 returns every claim (used by the admin page only).
CREATE OR ALTER PROCEDURE usp_GetClaims
    @PassengerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.ClaimID, c.ClaimReference, c.ClaimType, c.Status, c.Description, c.ContactPhone, c.CompensationAmount, c.CreatedAt,
           g.TagNumber, f.FlightNumber, p.FullName,
           (SELECT STRING_AGG(CONCAT(CONVERT(VARCHAR(16), u.CreatedAt, 120), ' - ', u.Status,
                   CASE WHEN u.Note <> '' THEN ': ' + u.Note ELSE '' END), '|') WITHIN GROUP (ORDER BY u.UpdateID)
            FROM ClaimUpdates u WHERE u.ClaimID = c.ClaimID) AS Timeline
    FROM BaggageClaims c
    JOIN Baggage g ON g.BagID = c.BagID
    JOIN Bookings b ON b.BookingID = g.BookingID
    JOIN Flights f ON f.FlightID = b.FlightID
    JOIN Passengers p ON p.PassengerID = c.PassengerID
    WHERE @PassengerID = 0 OR c.PassengerID = @PassengerID
    ORDER BY c.ClaimID DESC;
END;
GO
CREATE OR ALTER PROCEDURE usp_AdminUpdateClaim
    @ClaimID INT, @Status VARCHAR(30), @Note VARCHAR(300) = '', @Amount DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM BaggageClaims WHERE ClaimID = @ClaimID) THROW 50075, 'Claim not found.', 1;
    IF @Status NOT IN ('Reported', 'Searching', 'Found', 'Delivered', 'Compensation Approved') THROW 50076, 'Invalid claim status.', 1;
    IF @Status = 'Compensation Approved' AND @Amount <= 0 THROW 50077, 'Enter the compensation amount.', 1;
    BEGIN TRANSACTION;
    UPDATE BaggageClaims
    SET Status = @Status,
        CompensationAmount = CASE WHEN @Status = 'Compensation Approved' THEN @Amount ELSE CompensationAmount END
    WHERE ClaimID = @ClaimID;
    INSERT INTO ClaimUpdates (ClaimID, Status, Note) VALUES (@ClaimID, @Status, LEFT(LTRIM(RTRIM(ISNULL(@Note, ''))), 300));
    UPDATE Baggage
    SET Status = CASE WHEN @Status = 'Found' THEN 'Arrived' WHEN @Status = 'Delivered' THEN 'Delivered' ELSE Status END
    WHERE BagID = (SELECT BagID FROM BaggageClaims WHERE ClaimID = @ClaimID);
    COMMIT TRANSACTION;
    SELECT @ClaimID AS ClaimID, @Status AS Status;
END;
GO
CREATE OR ALTER PROCEDURE usp_AddFeedback
    @PassengerID INT, @BookingID INT, @Rating INT, @Category VARCHAR(30), @Comment VARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Rating < 1 OR @Rating > 5 THROW 50080, 'Please choose a rating from 1 to 5 stars.', 1;
    IF @Category NOT IN ('Booking', 'Payment', 'Flight', 'Baggage', 'Website', 'Other') THROW 50081, 'Please choose a category.', 1;
    IF LEN(LTRIM(RTRIM(ISNULL(@Comment, '')))) < 5 THROW 50082, 'Please write a short comment (at least 5 characters).', 1;
    IF @BookingID > 0 AND NOT EXISTS (SELECT 1 FROM Bookings WHERE BookingID = @BookingID AND PassengerID = @PassengerID)
        THROW 50083, 'Booking not found.', 1;
    INSERT INTO Feedback (PassengerID, BookingID, Rating, Category, Comment)
    VALUES (@PassengerID, NULLIF(@BookingID, 0), @Rating, @Category, LTRIM(RTRIM(@Comment)));
    SELECT SCOPE_IDENTITY() AS FeedbackID;
END;
GO
-- @PassengerID = 0 returns all feedback (admin page only).
CREATE OR ALTER PROCEDURE usp_GetFeedback
    @PassengerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FeedbackID, p.FullName, f.BookingID, f.Rating, f.Category, f.Comment, f.CreatedAt
    FROM Feedback f JOIN Passengers p ON p.PassengerID = f.PassengerID
    WHERE @PassengerID = 0 OR f.PassengerID = @PassengerID
    ORDER BY f.FeedbackID DESC;
END;
GO

/* ---- Round 3 procedures: flight management and passenger re-allocation (admin) ---- */
-- Admin: every flight with how many passengers hold confirmed seats on it.
CREATE OR ALTER PROCEDURE usp_AdminGetFlights
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FlightID, f.FlightNumber, f.OriginCode, f.DestinationCode, f.DepartureTime, f.ArrivalTime, f.Status, f.Capacity,
           ISNULL(x.Passengers, 0) AS Passengers, ISNULL(x.ConfirmedBookings, 0) AS ConfirmedBookings
    FROM Flights f
    OUTER APPLY (SELECT COUNT(*) AS Passengers, COUNT(DISTINCT t.BookingID) AS ConfirmedBookings
                 FROM Tickets t JOIN Bookings b ON b.BookingID = t.BookingID
                 WHERE t.FlightID = f.FlightID AND t.Status = 'Active' AND b.Status = 'Confirmed') x
    ORDER BY f.DepartureTime;
END;
GO
-- Admin: cancel a flight. Its passengers keep their bookings until the admin moves them (or they cancel for a full refund).
CREATE OR ALTER PROCEDURE usp_AdminCancelFlight
    @FlightID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FlightStatus VARCHAR(20), @AffectedBookings INT;
    SELECT @FlightStatus = Status FROM Flights WHERE FlightID = @FlightID;
    IF @FlightStatus IS NULL
        THROW 50100, 'Flight does not exist.', 1;
    IF @FlightStatus <> 'Scheduled'
        THROW 50109, 'Only a scheduled flight can be cancelled.', 1;
    UPDATE Flights SET Status = 'Cancelled' WHERE FlightID = @FlightID;
    SELECT @AffectedBookings = COUNT(*) FROM Bookings WHERE FlightID = @FlightID AND Status = 'Confirmed';
    SELECT @FlightID AS FlightID, 'Cancelled' AS Status, @AffectedBookings AS AffectedBookings;
END;
GO
-- Admin: change the departure and arrival time of a scheduled flight (a delay or an earlier departure).
CREATE OR ALTER PROCEDURE usp_AdminRescheduleFlight
    @FlightID INT, @NewDeparture DATETIME2(0), @NewArrival DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FlightStatus VARCHAR(20);
    SELECT @FlightStatus = Status FROM Flights WHERE FlightID = @FlightID;
    IF @FlightStatus IS NULL
        THROW 50100, 'Flight does not exist.', 1;
    IF @FlightStatus <> 'Scheduled'
        THROW 50110, 'Only a scheduled flight can be rescheduled.', 1;
    IF @NewDeparture <= SYSDATETIME()
        THROW 50111, 'The new departure time must be in the future.', 1;
    IF @NewArrival <= @NewDeparture
        THROW 50112, 'The arrival time must be after the departure time.', 1;
    UPDATE Flights SET DepartureTime = @NewDeparture, ArrivalTime = @NewArrival WHERE FlightID = @FlightID;
    SELECT @FlightID AS FlightID, @NewDeparture AS DepartureTime, @NewArrival AS ArrivalTime;
END;
GO
-- Admin: confirmed bookings on one flight (the passengers who may need to be moved).
CREATE OR ALTER PROCEDURE usp_AdminGetFlightBookings
    @FlightID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.BookingID, p.FullName, p.Email, tk.Seats, tk.TicketCount, ISNULL(bg.TotalKg, 0) AS BaggageKg
    FROM Bookings b
    JOIN Passengers p ON p.PassengerID = b.PassengerID
    CROSS APPLY (SELECT STRING_AGG(t.SeatNumber, ', ') WITHIN GROUP (ORDER BY t.SeatNumber) AS Seats, COUNT(*) AS TicketCount
                 FROM Tickets t WHERE t.BookingID = b.BookingID AND t.Status = 'Active') tk
    OUTER APPLY (SELECT SUM(WeightKg) AS TotalKg FROM Baggage WHERE BookingID = b.BookingID) bg
    WHERE b.FlightID = @FlightID AND b.Status = 'Confirmed'
    ORDER BY b.BookingID;
END;
GO
-- Admin: flights a passenger group can be moved to (same route, scheduled, in the future) with free seats per class.
CREATE OR ALTER PROCEDURE usp_AdminGetTargetFlights
    @FromFlightID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FlightID, f.FlightNumber, f.OriginCode, f.DestinationCode, f.DepartureTime, f.ArrivalTime,
           ISNULL(fr.FreeEconomy, 0) AS FreeEconomy, ISNULL(fr.FreeBusiness, 0) AS FreeBusiness
    FROM Flights f
    JOIN Flights o ON o.FlightID = @FromFlightID AND o.OriginCode = f.OriginCode AND o.DestinationCode = f.DestinationCode
    CROSS APPLY (SELECT SUM(CASE WHEN s.SeatClass = 'Economy' THEN 1 ELSE 0 END) AS FreeEconomy,
                        SUM(CASE WHEN s.SeatClass = 'Business' THEN 1 ELSE 0 END) AS FreeBusiness
                 FROM Seats s
                 WHERE s.FlightID = f.FlightID
                   AND NOT EXISTS (SELECT 1 FROM Tickets t WHERE t.FlightID = s.FlightID AND t.SeatNumber = s.SeatNumber AND t.Status = 'Active')) fr
    WHERE f.FlightID <> @FromFlightID AND f.Status = 'Scheduled' AND f.DepartureTime > SYSDATETIME()
    ORDER BY f.DepartureTime;
END;
GO
-- Admin: move confirmed bookings from one flight to another flight on the same route, all or nothing.
-- @BookingIDs = comma separated booking numbers, or empty to move every confirmed booking on the old flight.
-- Each passenger keeps the same seat class and the price already paid. Neighbouring seats are kept together when possible.
-- The old booking becomes 'Rebooked', a new booking is created, and the payment and baggage move with it.
CREATE OR ALTER PROCEDURE usp_AdminReallocate
    @FromFlightID INT, @ToFlightID INT, @BookingIDs VARCHAR(MAX) = '', @Reason VARCHAR(200) = '', @AdminEmail VARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @FromOrigin CHAR(3), @FromDestination CHAR(3), @FromStatus VARCHAR(20);
    DECLARE @ToOrigin CHAR(3), @ToDestination CHAR(3), @ToStatus VARCHAR(20), @ToDeparture DATETIME2(0), @ToNumber VARCHAR(20);
    DECLARE @CurrentBookingID INT, @PassengerID INT, @NewBookingID INT, @MovedBookings INT = 0, @MovedSeats INT = 0;
    DECLARE @SeatClass VARCHAR(20), @NeedCount INT, @StartRow INT, @StartLetter INT, @OldSeatText VARCHAR(200), @NewSeatText VARCHAR(200);
    DECLARE @ShortClass VARCHAR(20), @ShortNeed INT, @ShortFree INT, @ShortMessage NVARCHAR(200);
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @Reason = LEFT(LTRIM(RTRIM(ISNULL(@Reason, ''))), 200);
        IF @Reason = '' SET @Reason = 'Flight change by the airline';
        SET @AdminEmail = LEFT(LTRIM(RTRIM(ISNULL(@AdminEmail, ''))), 100);
        IF @AdminEmail = '' SET @AdminEmail = 'admin';
        SELECT @FromOrigin = OriginCode, @FromDestination = DestinationCode, @FromStatus = Status
        FROM Flights WITH (UPDLOCK) WHERE FlightID = @FromFlightID;
        SELECT @ToOrigin = OriginCode, @ToDestination = DestinationCode, @ToStatus = Status, @ToDeparture = DepartureTime, @ToNumber = FlightNumber
        FROM Flights WITH (UPDLOCK) WHERE FlightID = @ToFlightID;
        IF @FromStatus IS NULL
            THROW 50100, 'The old flight does not exist.', 1;
        IF @ToStatus IS NULL
            THROW 50101, 'The new flight does not exist.', 1;
        IF @FromFlightID = @ToFlightID
            THROW 50102, 'Choose a different flight to move the passengers to.', 1;
        IF @FromOrigin <> @ToOrigin OR @FromDestination <> @ToDestination
            THROW 50103, 'The new flight must fly the same route as the old flight.', 1;
        IF @ToStatus <> 'Scheduled' OR @ToDeparture <= SYSDATETIME()
            THROW 50104, 'The new flight must be scheduled and in the future.', 1;
        IF @FromStatus = 'Departed'
            THROW 50105, 'Passengers cannot be moved from a flight that already departed.', 1;
        CREATE TABLE #Moving (BookingID INT NOT NULL PRIMARY KEY, PassengerID INT NOT NULL);
        INSERT INTO #Moving (BookingID, PassengerID)
        SELECT b.BookingID, b.PassengerID
        FROM Bookings b
        WHERE b.FlightID = @FromFlightID AND b.Status = 'Confirmed'
          AND (LTRIM(RTRIM(ISNULL(@BookingIDs, ''))) = ''
               OR b.BookingID IN (SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@BookingIDs, ',')));
        IF NOT EXISTS (SELECT 1 FROM #Moving)
            THROW 50106, 'There are no confirmed bookings to move.', 1;
        IF EXISTS (SELECT 1 FROM #Moving m
                   JOIN Bookings nb ON nb.PassengerID = m.PassengerID AND nb.FlightID = @ToFlightID AND nb.Status = 'Confirmed')
            THROW 50107, 'Some of these passengers already have a confirmed booking on the new flight.', 1;
        CREATE TABLE #Free (SeatNumber VARCHAR(10) NOT NULL PRIMARY KEY, SeatClass VARCHAR(20) NOT NULL, RowNo INT NOT NULL, Letter INT NOT NULL);
        INSERT INTO #Free (SeatNumber, SeatClass, RowNo, Letter)
        SELECT s.SeatNumber, s.SeatClass, CAST(LEFT(s.SeatNumber, LEN(s.SeatNumber) - 1) AS INT), ASCII(RIGHT(s.SeatNumber, 1))
        FROM Seats s
        WHERE s.FlightID = @ToFlightID
          AND NOT EXISTS (SELECT 1 FROM Tickets t WHERE t.FlightID = s.FlightID AND t.SeatNumber = s.SeatNumber AND t.Status = 'Active');
        CREATE TABLE #Need (SeatClass VARCHAR(20) NOT NULL PRIMARY KEY, Needed INT NOT NULL);
        INSERT INTO #Need (SeatClass, Needed)
        SELECT s.SeatClass, COUNT(*)
        FROM Tickets t
        JOIN Seats s ON s.FlightID = t.FlightID AND s.SeatNumber = t.SeatNumber
        WHERE t.FlightID = @FromFlightID AND t.Status = 'Active' AND t.BookingID IN (SELECT BookingID FROM #Moving)
        GROUP BY s.SeatClass;
        SELECT TOP 1 @ShortClass = n.SeatClass, @ShortNeed = n.Needed,
               @ShortFree = (SELECT COUNT(*) FROM #Free f WHERE f.SeatClass = n.SeatClass)
        FROM #Need n
        WHERE n.Needed > (SELECT COUNT(*) FROM #Free f WHERE f.SeatClass = n.SeatClass);
        IF @ShortClass IS NOT NULL
        BEGIN
            SET @ShortMessage = CONCAT('Not enough free ', @ShortClass, ' seats on ', @ToNumber, ' (need ', @ShortNeed, ', free ', @ShortFree, '). Nothing was moved.');
            THROW 50108, @ShortMessage, 1;
        END;
        CREATE TABLE #OldTickets (TicketID INT NOT NULL PRIMARY KEY, SeatNumber VARCHAR(10) NOT NULL, SeatClass VARCHAR(20) NOT NULL, Price DECIMAL(10,2) NOT NULL, Position INT NOT NULL);
        CREATE TABLE #Pick (SeatNumber VARCHAR(10) NOT NULL PRIMARY KEY, RowNo INT NOT NULL, Letter INT NOT NULL);
        SELECT @CurrentBookingID = MIN(BookingID) FROM #Moving;
        WHILE @CurrentBookingID IS NOT NULL
        BEGIN
            SELECT @PassengerID = PassengerID FROM #Moving WHERE BookingID = @CurrentBookingID;
            DELETE FROM #OldTickets;
            INSERT INTO #OldTickets (TicketID, SeatNumber, SeatClass, Price, Position)
            SELECT t.TicketID, t.SeatNumber, s.SeatClass, t.Price,
                   ROW_NUMBER() OVER (PARTITION BY s.SeatClass
                                      ORDER BY CAST(LEFT(t.SeatNumber, LEN(t.SeatNumber) - 1) AS INT), RIGHT(t.SeatNumber, 1))
            FROM Tickets t
            JOIN Seats s ON s.FlightID = t.FlightID AND s.SeatNumber = t.SeatNumber
            WHERE t.BookingID = @CurrentBookingID AND t.Status = 'Active';
            INSERT INTO Bookings (PassengerID, FlightID, Status) VALUES (@PassengerID, @ToFlightID, 'Confirmed');
            SET @NewBookingID = SCOPE_IDENTITY();
            SELECT @SeatClass = MIN(SeatClass) FROM #OldTickets;
            WHILE @SeatClass IS NOT NULL
            BEGIN
                SELECT @NeedCount = COUNT(*) FROM #OldTickets WHERE SeatClass = @SeatClass;
                DELETE FROM #Pick;
                SET @StartRow = NULL;
                SET @StartLetter = NULL;
                -- Prefer a block of neighbouring seats in one row that does not cross the aisle (between C and D).
                SELECT TOP 1 @StartRow = f.RowNo, @StartLetter = f.Letter
                FROM #Free f
                WHERE f.SeatClass = @SeatClass
                  AND (SELECT COUNT(*) FROM #Free g
                       WHERE g.SeatClass = @SeatClass AND g.RowNo = f.RowNo
                         AND g.Letter BETWEEN f.Letter AND f.Letter + @NeedCount - 1) = @NeedCount
                ORDER BY CASE WHEN f.Letter <= 67 AND f.Letter + @NeedCount - 1 > 67 THEN 1 ELSE 0 END, f.RowNo, f.Letter;
                IF @StartRow IS NOT NULL
                    INSERT INTO #Pick (SeatNumber, RowNo, Letter)
                    SELECT g.SeatNumber, g.RowNo, g.Letter FROM #Free g
                    WHERE g.SeatClass = @SeatClass AND g.RowNo = @StartRow AND g.Letter BETWEEN @StartLetter AND @StartLetter + @NeedCount - 1;
                ELSE
                    INSERT INTO #Pick (SeatNumber, RowNo, Letter)
                    SELECT TOP (@NeedCount) g.SeatNumber, g.RowNo, g.Letter FROM #Free g
                    WHERE g.SeatClass = @SeatClass ORDER BY g.RowNo, g.Letter;
                INSERT INTO Tickets (BookingID, FlightID, SeatNumber, Price)
                SELECT @NewBookingID, @ToFlightID, p.SeatNumber, o.Price
                FROM (SELECT SeatNumber, ROW_NUMBER() OVER (ORDER BY RowNo, Letter) AS Position FROM #Pick) p
                JOIN #OldTickets o ON o.SeatClass = @SeatClass AND o.Position = p.Position;
                DELETE f FROM #Free f JOIN #Pick p ON p.SeatNumber = f.SeatNumber;
                SELECT @SeatClass = MIN(SeatClass) FROM #OldTickets WHERE SeatClass > @SeatClass;
            END;
            SELECT @OldSeatText = LEFT(STRING_AGG(SeatNumber, ', ') WITHIN GROUP (ORDER BY SeatNumber), 200) FROM #OldTickets;
            SELECT @NewSeatText = LEFT(STRING_AGG(SeatNumber, ', ') WITHIN GROUP (ORDER BY SeatNumber), 200)
            FROM Tickets WHERE BookingID = @NewBookingID;
            UPDATE Tickets SET Status = 'Cancelled' WHERE TicketID IN (SELECT TicketID FROM #OldTickets);
            UPDATE Bookings SET Status = 'Rebooked' WHERE BookingID = @CurrentBookingID;
            UPDATE Payments SET BookingID = @NewBookingID WHERE BookingID = @CurrentBookingID;
            UPDATE Baggage SET BookingID = @NewBookingID WHERE BookingID = @CurrentBookingID;
            INSERT INTO Reallocations (OldBookingID, NewBookingID, OldFlightID, NewFlightID, OldSeats, NewSeats, Reason, MovedBy)
            VALUES (@CurrentBookingID, @NewBookingID, @FromFlightID, @ToFlightID, @OldSeatText, @NewSeatText, @Reason, @AdminEmail);
            SET @MovedBookings = @MovedBookings + 1;
            SELECT @MovedSeats = @MovedSeats + COUNT(*) FROM #OldTickets;
            SELECT @CurrentBookingID = MIN(BookingID) FROM #Moving WHERE BookingID > @CurrentBookingID;
        END;
        COMMIT TRANSACTION;
        SELECT @MovedBookings AS MovedBookings, @MovedSeats AS MovedSeats, @FromFlightID AS FromFlightID, @ToFlightID AS ToFlightID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- Admin: history of every move (newest first).
CREATE OR ALTER PROCEDURE usp_AdminGetReallocations
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 100 r.ReallocationID, r.MovedAt, p.FullName, p.Email, fo.FlightNumber AS OldFlight, fn.FlightNumber AS NewFlight,
           fn.DepartureTime AS NewDeparture, r.OldSeats, r.NewSeats, r.Reason, r.MovedBy
    FROM Reallocations r
    JOIN Bookings b ON b.BookingID = r.NewBookingID
    JOIN Passengers p ON p.PassengerID = b.PassengerID
    JOIN Flights fo ON fo.FlightID = r.OldFlightID
    JOIN Flights fn ON fn.FlightID = r.NewFlightID
    ORDER BY r.ReallocationID DESC;
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
CROSS JOIN (VALUES (7, ''), (8, 'B')) AS w (WeekShift, Suffix);
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
EXEC usp_AdminGetFlights;
EXEC usp_AdminCancelFlight @FlightID = 1;
EXEC usp_AdminGetTargetFlights @FromFlightID = 1;
EXEC usp_AdminReallocate @FromFlightID = 1, @ToFlightID = 2, @BookingIDs = '', @Reason = 'Flight cancelled', @AdminEmail = 'admin@airline.com';
EXEC usp_AdminGetReallocations;

   --------------------------------------------------------------------- */