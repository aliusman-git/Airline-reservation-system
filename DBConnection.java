import java.sql.Connection;
import java.sql.DriverManager;

public class DBConnection {
    private static final String DB_URL = "jdbc:sqlserver://localhost\\SQLEXPRESS01;databaseName=AirlineWEBDB;integratedSecurity=true;encrypt=false;trustServerCertificate=true;";

    public static Connection connect() {
        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
            return DriverManager.getConnection(DB_URL);
        } catch (Exception e) {
            System.out.println("Connection failed!");
            e.printStackTrace();
            return null;
        }
    }

    // Add this main method to test the connection in VS Code
    public static void main(String[] args) {
        Connection conn = connect();
        if (conn != null) {
            System.out.println("Database Connected Successfully!");
        }
    }
}