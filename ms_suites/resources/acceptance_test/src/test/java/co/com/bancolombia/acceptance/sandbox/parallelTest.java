package co.com.bancolombia.acceptance.sandbox;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import net.masterthought.cucumber.Configuration;
import net.masterthought.cucumber.ReportBuilder;
import org.apache.commons.io.FileUtils;
import org.junit.jupiter.api.Test;

import java.io.File;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import static co.com.bancolombia.acceptance.logs.infrastructure.utils.Constants.*;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class parallelTest {
    @Test
    void testAll() {
        Results results = Runner.path(CLASSPATHKARATE)
                .outputCucumberJson(true)
                .parallel(ONE);
        generateReport(results.getReportDir());
        assertEquals(results.getFailCount(),ZERO, results.getErrorMessages());
    }

    public static void generateReport(String karateOutputPath) {
        Collection<File> jsonFiles = FileUtils.listFiles(new File(karateOutputPath), new String[] {JSON}, true);
        List<String> jsonPaths = new ArrayList<>(jsonFiles.size());
        jsonFiles.forEach(file -> jsonPaths.add(file.getAbsolutePath()));
        Configuration config = new Configuration(new File(BUILD), PROJECTNAME);
        ReportBuilder reportBuilder = new ReportBuilder(jsonPaths, config);
        reportBuilder.generateReports();
    }
}
