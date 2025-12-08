package co.com.bancolombia.acceptance.logs.infrastructure.utils;

import org.joda.time.DateTime;

import java.text.SimpleDateFormat;

public class DateAndTime {

        private DateAndTime() {
            throw new IllegalStateException("Utility class");
        }

    public static String getDate() {
        DateTime date = new DateTime();
        SimpleDateFormat format = new SimpleDateFormat("MM/dd/yyyy");
        return format.format(date.toDate());
    }

    public static String getTime() {
        DateTime time = new DateTime();
        SimpleDateFormat format = new SimpleDateFormat("HH:mm:ss");
        return format.format(time.toDate());
    }
}
