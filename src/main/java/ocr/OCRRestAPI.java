package ocr;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.*;

/*
 *
 * Sample class for OCRWebService.com (REST API)
 *
 */

public class OCRRestAPI {

    public static void main(String[] args) {
        OCRRestAPI ocrRestAPI = new OCRRestAPI();
        File imageDir= new File("/Users/happy/Downloads/book-ci-cd-images");
        try {
            //ocrRestAPI.convert();
           //简体中文chinesesimplified 繁体中文chinesetraditional
            ocrRestAPI.batch_convert(imageDir,"chinesesimplified");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /*

      You should specify OCR settings. See full description http://www.ocrwebservice.com/service/restguide

      Input parameters:

      [language]      - Specifies the recognition language.
                           This parameter can contain several language names separated with commas.
                        For example "language=english,german,spanish".
                        Optional parameter. By default:english

      [pagerange]     - Enter page numbers and/or page ranges separated by commas.
                        For example "pagerange=1,3,5-12" or "pagerange=allpages".
                        Optional parameter. By default:allpages

      [tobw]	  	   - Convert image to black and white (recommend for color image and photo).
                        For example "tobw=false"
                        Optional parameter. By default:false

      [zone]          - Specifies the region on the image for zonal OCR.
                        The coordinates in pixels relative to the left top corner in the following format: top:left:height:width.
                        This parameter can contain several zones separated with commas.
                        For example "zone=0:0:100:100,50:50:50:50"
                        Optional parameter.

      [outputformat]  - Specifies the output file format.
                        Can be specified up to two output formats, separated with commas.
                        For example "outputformat=pdf,txt"
                        Optional parameter. By default:doc

      [gettext]	   - Specifies that extracted text will be returned.
                        For example "tobw=true"
                        Optional parameter. By default:false

       [description]  - Specifies your task description. Will be returned in response.
                        Optional parameter.


      !!!!  For getting result you must specify "gettext" or "outputformat" !!!!

   */
    public void batch_convert(File imageDir, String language) throws Exception {
        // Provide your user name and license code
        String license_code = "F4CE6AF3-5FEC-4449-8572-7A014D139F16";// <your license code>;
        //2019.04.04 到期.
        String user_name = "happyfreeangel";
        // Build your OCR:
        // Extraction text with English language
        //简体中文chinesesimplified 繁体中文chinesetraditional
        // http://www.ocrwebservice.com/api/keyfeatures
        //

        String languageStr="chinesesimplified";
        if(language!=null){
            languageStr = language;
        }
        else {
            System.out.println("图片识别的语言没有设置,使用缺省默认语言:简体中文"+languageStr);
        }
        String ocrURL = "http://www.ocrwebservice.com/restservices/processDocument?gettext=true&language="+languageStr+"&outputformat=txt";

        // Extraction text with English and German language using zonal OCR
        // ocrURL = "http://www.ocrwebservice.com/restservices/processDocument?language=english,german&zone=0:0:600:400,500:1000:150:400";

        // Convert first 5 pages of multipage document into doc and txt
        // ocrURL = "http://www.ocrwebservice.com/restservices/processDocument?language=english&pagerange=1-5&outputformat=doc,txt";

        // Full path to uploaded document

        List<String> imageFilePathList = getFileListFromDirectory(imageDir);

        for (int i = 0; i < imageFilePathList.size(); i++) {
            String imagePath = imageFilePathList.get(i);
            String textOfImage=processImage(imagePath, ocrURL, user_name, license_code);
            System.out.println(imagePath+"<--->"+textOfImage);
        }
    }

    public String processImage(String imagePath, String ocrURL, String username, String license_code) throws Exception {
        byte[] fileContent = Files.readAllBytes(Paths.get(imagePath));

        URL url = new URL(ocrURL);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setDoOutput(true);
        connection.setDoInput(true);
        connection.setRequestMethod("POST");

        connection.setRequestProperty("Authorization", "Basic " + Base64.getEncoder().encodeToString((username + ":" + license_code).getBytes()));

        // Specify Response format to JSON or XML (application/json or application/xml)
        connection.setRequestProperty("Content-Type", "application/json");

        connection.setRequestProperty("Content-Length", Integer.toString(fileContent.length));

        OutputStream stream = connection.getOutputStream();

        // Send POST request
        stream.write(fileContent);
        stream.close();

        int httpCode = connection.getResponseCode();

        System.out.println("HTTP Response code: " + httpCode);

        String ocrResult =null;

        // Success request
        if (httpCode == HttpURLConnection.HTTP_OK) {
            // Get response stream
            String jsonResponse = GetResponseToString(connection.getInputStream());

            // Parse and print response from OCR server
            ocrResult=PrintOCRResponse(jsonResponse);
        } else if (httpCode == HttpURLConnection.HTTP_UNAUTHORIZED) {
            System.out.println("OCR Error Message: Unauthorizied request");
        } else {
            // Error occurred
            String jsonResponse = GetResponseToString(connection.getErrorStream());

            JSONParser parser = new JSONParser();
            JSONObject jsonObj = (JSONObject) parser.parse(jsonResponse);

            // Error message
            System.out.println("Error Message: " + jsonObj.get("ErrorMessage"));
        }

        connection.disconnect();
        return ocrResult;
    }

    private static String GetResponseToString(InputStream inputStream) throws IOException {
        InputStreamReader responseStream = new InputStreamReader(inputStream);

        BufferedReader br = new BufferedReader(responseStream);
        StringBuffer strBuff = new StringBuffer();
        String s;
        while ((s = br.readLine()) != null) {
            strBuff.append(s);
        }

        return strBuff.toString();
    }

    public void convert() throws Exception {

    }

    private String PrintOCRResponse(String jsonResponse) throws ParseException, IOException {
        // Parse JSON data
        JSONParser parser = new JSONParser();
        JSONObject jsonObj = (JSONObject) parser.parse(jsonResponse);

        // Get available pages
        System.out.println("Available pages: " + jsonObj.get("AvailablePages"));

        // get an array from the JSON object
        JSONArray text = (JSONArray) jsonObj.get("OCRText");

        // For zonal OCR: OCRText[z][p]    z - zone, p - pages
        for (int i = 0; i < text.size(); i++) {
            System.out.println(" " + text.get(i));
        }

        // Output file URL
        String outputFileUrl = (String) jsonObj.get("OutputFileUrl");

        String resultContent=null;
        // If output file URL is specified
        if (outputFileUrl != null && !outputFileUrl.equals("")) {
            // Download output file
            String textFilePath = DownloadConvertedFile(outputFileUrl);
            byte[] data = Files.readAllBytes(Paths.get(textFilePath));
            resultContent = new String(data,"utf-8"); //??? todo
        }
        return resultContent;
    }

    // Download converted output file from OCRWebService, 返回文件名称.
    private String DownloadConvertedFile(String outputFileUrl) throws IOException {
        URL downloadUrl = new URL(outputFileUrl);
        HttpURLConnection downloadConnection = (HttpURLConnection) downloadUrl.openConnection();
        // opens an output stream to save into file
        String tempFile = "/tmp/converted_file" + System.currentTimeMillis() + "_" + System.nanoTime() + ".txt";

        if (downloadConnection.getResponseCode() == HttpURLConnection.HTTP_OK) {

            InputStream inputStream = downloadConnection.getInputStream();

            // opens an output stream to save into file
            FileOutputStream outputStream = new FileOutputStream(tempFile);

            int bytesRead = -1;
            byte[] buffer = new byte[4096];
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }

            outputStream.close();
            inputStream.close();
        } else {
            tempFile = null;
        }

        downloadConnection.disconnect();
        return tempFile;
    }

    public List<String> getFileListFromDirectory(File dir) {
        List<String> filePathList = null;

        FilenameFilter filter = new FilenameFilter() {
            @Override
            public boolean accept(File dir, String name) {
                String lowcaseName = name.toLowerCase();
                if (lowcaseName.endsWith(".jpg")
                        || lowcaseName.endsWith(".jpeg") || lowcaseName.endsWith(".png")
                        || lowcaseName.endsWith("bmp") || lowcaseName.endsWith(".svg")) {
                    return true;
                }
                return false;
            }
        };

        List<File> fileList = Arrays.asList(dir.listFiles(filter));

        if (fileList != null) {
            filePathList = new LinkedList<String>();

            for (int i = 0; i < fileList.size(); i++) {
                filePathList.add(fileList.get(i).getAbsolutePath());
            }
        }
        Collections.sort(filePathList, new Comparator<String>() {
            @Override
            public int compare(String o1, String o2) {
                return extractDigit(o1) - extractDigit(o2);
            }
        });

        return filePathList;
    }


    protected int extractDigit(String str) {
        int result = -1;
        String digitStr = "";

        if (str != null) {
            for (int i = 0; i < str.length(); i++) {
                char c = str.charAt(i);
                if (c >= '0' && c <= '9') {
                    digitStr += c;
                }
            }
        }

        if (digitStr != null && digitStr.length() > 0) {
            result = Integer.parseInt(digitStr);
        }
        return result;
    }

}

