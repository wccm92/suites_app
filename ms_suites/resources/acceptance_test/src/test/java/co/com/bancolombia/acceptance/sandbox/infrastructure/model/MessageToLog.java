package co.com.bancolombia.acceptance.sandbox.infrastructure.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder(toBuilder = true)
public class MessageToLog {
    private List<DataType> data;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder(toBuilder = true)
    public static class DataType {
        private Type type;
        private Time time;
        private Registry registry;
        private Details details;
        private String additionalInfo;

        @Data
        @NoArgsConstructor
        @AllArgsConstructor
        @Builder(toBuilder = true)
        public static class Type {
            private String classification;
            private String action;
            private String app;
            private String process;
        }

        @Data
        @NoArgsConstructor
        @AllArgsConstructor
        @Builder(toBuilder = true)
        public static class Time {
            private String date;
            private String time;
        }

        @Data
        @NoArgsConstructor
        @AllArgsConstructor
        @Builder(toBuilder = true)
        public static class Registry {
            private String sourceId;
            private String actor;
            private String transactionalId;
            private String document;
            private String documentType;
        }

        @Data
        @NoArgsConstructor
        @AllArgsConstructor
        @Builder(toBuilder = true)
        public static class Details {
            private String description;
            private String afterValue;
            private String beforeValue;
            private String transactionResultCode;
            private String transactionResultDescription;
        }
    }
}