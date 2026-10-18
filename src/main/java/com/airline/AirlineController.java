package com.airline;
import jakarta.servlet.http.HttpSession;
import java.sql.Timestamp;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
@RestController
@RequestMapping("/api")
public class AirlineController {
    private final JdbcTemplate jdbc;
    public AirlineController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }
    @PostMapping("/register")
    public Map<String, Object> register(@RequestBody Map<String, String> body) {
        return jdbc.queryForMap("EXEC usp_RegisterUser ?, ?, ?, ?",
            body.get("fullName"), body.get("email"), body.getOrDefault("phone", ""), body.get("password"));
    }
    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody Map<String, String> body, HttpSession session) {
        Map<String, Object> loggedInUser = new HashMap<>(
            jdbc.queryForMap("EXEC usp_LoginUser ?, ?", body.get("email"), body.get("password")));
        session.setAttribute("user", loggedInUser);
        return loggedInUser;
    }
    @PostMapping("/logout")
    public Map<String, Object> logout(HttpSession session) {
        session.invalidate();
        return Map.of("ok", true);
    }
    @GetMapping("/me")
    public Map<String, Object> me(HttpSession session) {
        return requireUser(session);
    }
    @SuppressWarnings("unchecked")
    private Map<String, Object> requireUser(HttpSession session) {
        Map<String, Object> user = (Map<String, Object>) session.getAttribute("user");
        if (user == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please log in first.");
        }
        return user;
    }
    @GetMapping("/airports")
    public List<Map<String, Object>> airports() {
        return jdbc.queryForList("SELECT AirportCode, City FROM Airports ORDER BY City");
    }
    @GetMapping("/flights")
    public List<Map<String, Object>> searchFlights(@RequestParam String origin,
            @RequestParam String destination, @RequestParam String date) {
        return readable(jdbc.queryForList("EXEC usp_SearchFlights ?, ?, ?", origin, destination, date));
    }
    @GetMapping("/flights/{flightId}/seats")
    public List<Map<String, Object>> availableSeats(@PathVariable int flightId) {
        return jdbc.queryForList("EXEC usp_GetAvailableSeats ?", flightId);
    }
    @GetMapping("/flights/upcoming")
    public List<Map<String, Object>> upcomingFlights() {
        return readable(jdbc.queryForList("EXEC usp_GetUpcomingFlights"));
    }
    private List<Map<String, Object>> readable(List<Map<String, Object>> rows) {
        rows.forEach(row -> row.replaceAll((column, value) ->
            value instanceof Timestamp timestamp ? timestamp.toLocalDateTime().toString() : value));
        return rows;
    }
    @PostMapping("/bookings")
    public Map<String, Object> book(@RequestBody Map<String, String> body, HttpSession session) {
        return jdbc.queryForMap("EXEC usp_BookFlight ?, ?, ?, ?, ?, ?",
            requirePassengerId(session), Integer.parseInt(body.get("flightId")), body.get("seatNumber"),
            body.getOrDefault("paymentMethod", "Card"), body.get("payerName"), body.get("accountMask"));
    }
    @GetMapping("/bookings/mine")
    public List<Map<String, Object>> myBookings(HttpSession session) {
        return readable(jdbc.queryForList("EXEC usp_GetPassengerBookings ?", requirePassengerId(session)));
    }
    @PostMapping("/bookings/{bookingId}/cancel")
    public Map<String, Object> cancelBooking(@PathVariable int bookingId, HttpSession session) {
        return jdbc.queryForMap("EXEC usp_CancelBooking ?, ?", bookingId, requirePassengerId(session));
    }
    private Object requirePassengerId(HttpSession session) {
        Object passengerId = requireUser(session).get("PassengerID");
        if (passengerId == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin accounts cannot book flights.");
        }
        return passengerId;
    }
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> handleDatabaseError(DataAccessException exception) {
        return ResponseEntity.badRequest()
            .body(Map.of("error", String.valueOf(NestedExceptionUtils.getMostSpecificCause(exception).getMessage())));
    }
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, String>> handleStatusError(ResponseStatusException exception) {
        return ResponseEntity.status(exception.getStatusCode()).body(Map.of("error", String.valueOf(exception.getReason())));
    }
}