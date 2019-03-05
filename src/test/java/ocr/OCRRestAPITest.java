package ocr;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.util.List;

import static org.junit.Assert.*;

public class OCRRestAPITest {

    OCRRestAPI ocrRestAPI = new OCRRestAPI();
    @Before
    public void setUp() throws Exception {
    }

    @After
    public void tearDown() throws Exception {
    }

    @Test
    public void getFileListFromDirectory() {
        File dir=new File("/Users/happy/Downloads/book-ci-cd-images");
        List<String> filePathList = ocrRestAPI.getFileListFromDirectory(dir);
        for(int i=0;i<filePathList.size();i++){
            System.out.println(filePathList.get(i));
        }
        assertEquals(376,filePathList.size());
    }

    @Test
    public void extractDigit() {
        assertEquals(456,ocrRestAPI.extractDigit("abc456.png"));
    }

    @Test
    public void batch_convert() throws Exception {
        ocrRestAPI.batch_convert(new File(""),"");
    }
}