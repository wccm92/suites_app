package co.com.bancolombia.acceptance.logs.infrastructure.utils;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.File;
import java.util.Scanner;

public class ReadFiles {


    private static final Logger LOGGER = LogManager.getLogger(ReadFiles.class);

    private ReadFiles() {
        throw new IllegalStateException("Utility class");
    }

    public static String returnFiles(String routeFile){
        StringBuilder line = new StringBuilder();
        try (Scanner input = new Scanner(new File(routeFile))){
            while (input.hasNext()){
                line.append(input.nextLine());
            }
            return String.valueOf(line);
        }catch (Exception e){
            LOGGER.error(e);
            return null;
        }
    }
}
