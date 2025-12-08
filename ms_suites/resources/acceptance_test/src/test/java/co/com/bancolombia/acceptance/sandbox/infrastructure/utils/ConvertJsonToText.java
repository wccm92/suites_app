package co.com.bancolombia.acceptance.logs.infrastructure.utils;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;

public class ConvertJsonToText {
    public static String jsonToText(String jsonContent) throws IOException {
        ObjectMapper objectMapper = new ObjectMapper();
        Object json = objectMapper.readValue(jsonContent, Object.class);
        return objectMapper.writeValueAsString(json);
    }
}