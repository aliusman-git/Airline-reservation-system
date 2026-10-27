package com.airline;
import jakarta.servlet.http.HttpSession;
import java.math.BigDecimal;
import java.sql.Timestamp;
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
public class ServiceController {
    private final JdbcTemplate jdbc;
    public ServiceController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }
    @PostMapping("/baggage")
    public Map<String, Object> addBaggage(@RequestBody Map<String, String> body, HttpSession session) {
        return jdbc.queryForMap("EXEC usp_AddBaggage ?, ?, ?", Integer.parseInt(body.get("bookingId")),
            passengerId(session), Integer.parseInt(body.get("bagCount")));
    }
    @GetMapping("/baggage/mine")
    public List<Map<String, Object>> myBaggage(HttpSession session) {
        return readable(jdbc.queryForList("EXEC usp_GetBaggage ?", passengerId(session)));
    }
    @PostMapping("/baggage/{bagId}/report")
    public Map<String, Object> reportBaggage(@PathVariable int bagId, @RequestBody Map<String, String> body, HttpSession session) {
        return jdbc.queryForMap("EXEC usp_ReportBaggageIssue ?, ?, ?, ?, ?", bagId, passengerId(session),
            body.getOrDefault("claimType", ""), body.getOrDefault("description", ""), body.getOrDefault("contactPhone", ""));
    }
    @GetMapping("/claims/mine")
    public List<Map<String, Object>> myClaims(HttpSession session) {
        return readable(jdbc.queryForList("EXEC usp_GetClaims ?", passengerId(session)));
    }
    @PostMapping("/feedback")
    public Map<String, Object> addFeedback(@RequestBody Map<String, String> body, HttpSession session) {
        return jdbc.queryForMap("EXEC usp_AddFeedback ?, ?, ?, ?, ?", passengerId(session),
            Integer.parseInt(body.getOrDefault("bookingId", "0")), Integer.parseInt(body.get("rating")),
            body.getOrDefault("category", ""), body.getOrDefault("comment", ""));
    }
    @GetMapping("/feedback/mine")
    public List<Map<String, Object>> myFeedback(HttpSession session) {
        return readable(jdbc.queryForList("EXEC usp_GetFeedback ?", passengerId(session)));
    }
    @GetMapping("/admin/claims")
    public List<Map<String, Object>> allClaims(HttpSession session) {
        requireAdmin(session);
        return readable(jdbc.queryForList("EXEC usp_GetClaims 0"));
    }
    @PostMapping("/admin/claims/{claimId}/status")
    public Map<String, Object> updateClaim(@PathVariable int claimId, @RequestBody Map<String, String> body, HttpSession session) {
        requireAdmin(session);
        return jdbc.queryForMap("EXEC usp_AdminUpdateClaim ?, ?, ?, ?", claimId, body.getOrDefault("status", ""),
            body.getOrDefault("note", ""), new BigDecimal(body.getOrDefault("amount", "0")));
    }
    @GetMapping("/admin/feedback")
    public List<Map<String, Object>> allFeedback(HttpSession session) {
        requireAdmin(session);
        return readable(jdbc.queryForList("EXEC usp_GetFeedback 0"));
    }
    @SuppressWarnings("unchecked")
    private Map<String, Object> currentUser(HttpSession session) {
        Map<String, Object> user = (Map<String, Object>) session.getAttribute("user");
        if (user == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please log in first.");
        }
        return user;
    }
    private Object passengerId(HttpSession session) {
        Object passengerId = currentUser(session).get("PassengerID");
        if (passengerId == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Administrator accounts do not have bookings.");
        }
        return passengerId;
    }
    private void requireAdmin(HttpSession session) {
        if (!"Admin".equals(currentUser(session).get("Role"))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Administrators only.");
        }
    }
    private List<Map<String, Object>> readable(List<Map<String, Object>> rows) {
        rows.forEach(row -> row.replaceAll((column, value) ->
            value instanceof Timestamp timestamp ? timestamp.toLocalDateTime().toString() : value));
        return rows;
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
