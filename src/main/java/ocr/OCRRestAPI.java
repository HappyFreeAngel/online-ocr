package ocr;

import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Base64;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

/*
 *
 * Sample class for OCRWebService.com (REST API)
 *
 */

public class OCRRestAPI {

    public static void main(String[] args) throws Exception
    {
		/*

        	Sample project for OCRWebService.com (REST API).
        	Extract text from scanned images and convert into editable formats.
        	Please create new account with ocrwebservice.com via http://www.ocrwebservice.com/account/signup and get license code

		 */

        // Provide your user name and license code
        String license_code ="F4CE6AF3-5FEC-4449-8572-7A014D139F16";// <your license code>;
        //2019.04.04 到期.
        String user_name ="happyfreeangel";

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

        // Build your OCR:

        // Extraction text with English language
        //简体中文chinesesimplified 繁体中文chinesetraditional
        // http://www.ocrwebservice.com/api/keyfeatures
        //
        String ocrURL = "http://www.ocrwebservice.com/restservices/processDocument?gettext=true&language=chinesesimplified&outputformat=txt";

        // Extraction text with English and German language using zonal OCR
        // ocrURL = "http://www.ocrwebservice.com/restservices/processDocument?language=english,german&zone=0:0:600:400,500:1000:150:400";

        // Convert first 5 pages of multipage document into doc and txt
        // ocrURL = "http://www.ocrwebservice.com/restservices/processDocument?language=english&pagerange=1-5&outputformat=doc,txt";

        // Full path to uploaded document
        String filePath = "/tmp/sample_image.png";

        byte[] fileContent = Files.readAllBytes(Paths.get(filePath));

        URL url = new URL(ocrURL);

        HttpURLConnection connection = (HttpURLConnection)url.openConnection();
        connection.setDoOutput(true);
        connection.setDoInput(true);
        connection.setRequestMethod("POST");

        connection.setRequestProperty("Authorization", "Basic " + Base64.getEncoder().encodeToString((user_name + ":" + license_code).getBytes()));

        // Specify Response format to JSON or XML (application/json or application/xml)
        connection.setRequestProperty("Content-Type", "application/json");

        connection.setRequestProperty("Content-Length", Integer.toString(fileContent.length));

        OutputStream stream = connection.getOutputStream();

        // Send POST request
        stream.write(fileContent);
        stream.close();

        int httpCode = connection.getResponseCode();

        System.out.println("HTTP Response code: " + httpCode);

        // Success request
        if (httpCode == HttpURLConnection.HTTP_OK)
        {
            // Get response stream
            String jsonResponse = GetResponseToString(connection.getInputStream());

            // Parse and print response from OCR server
            PrintOCRResponse(jsonResponse);
        }
        else if (httpCode == HttpURLConnection.HTTP_UNAUTHORIZED)
        {
            System.out.println("OCR Error Message: Unauthorizied request");
        }
        else
        {
            // Error occurred
            String jsonResponse = GetResponseToString(connection.getErrorStream());

            JSONParser parser = new JSONParser();
            JSONObject jsonObj = (JSONObject)parser.parse(jsonResponse);

            // Error message
            System.out.println("Error Message: " + jsonObj.get("ErrorMessage"));
        }

        connection.disconnect();

    }

    private static void PrintOCRResponse(String jsonResponse) throws ParseException, IOException
    {
        // Parse JSON data
        JSONParser parser = new JSONParser();
        JSONObject jsonObj = (JSONObject)parser.parse(jsonResponse);

        // Get available pages
        System.out.println("Available pages: " + jsonObj.get("AvailablePages"));

        // get an array from the JSON object
        JSONArray text= (JSONArray)jsonObj.get("OCRText");

        // For zonal OCR: OCRText[z][p]    z - zone, p - pages
        for(int i=0; i<text.size(); i++){
            System.out.println(" "+ text.get(i));
        }

        // Output file URL
        String outputFileUrl = (String)jsonObj.get("OutputFileUrl");

        // If output file URL is specified
        if (outputFileUrl != null && !outputFileUrl.equals(""))
        {
            // Download output file
            DownloadConvertedFile (outputFileUrl);
        }
    }

    // Download converted output file from OCRWebService
    private static void DownloadConvertedFile(String outputFileUrl) throws IOException
    {
        URL downloadUrl = new URL(outputFileUrl);
        HttpURLConnection downloadConnection = (HttpURLConnection)downloadUrl.openConnection();

        if (downloadConnection.getResponseCode() == HttpURLConnection.HTTP_OK) {

            InputStream inputStream = downloadConnection.getInputStream();

            // opens an output stream to save into file
            FileOutputStream outputStream = new FileOutputStream("/tmp/converted_file.txt");

            int bytesRead = -1;
            byte[] buffer = new byte[4096];
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }

            outputStream.close();
            inputStream.close();
        }

        downloadConnection.disconnect();
    }

    private static String GetResponseToString(InputStream inputStream) throws IOException
    {
        InputStreamReader responseStream  = new InputStreamReader(inputStream);

        BufferedReader br = new BufferedReader(responseStream);
        StringBuffer strBuff = new StringBuffer();
        String s;
        while ( ( s = br.readLine() ) != null ) {
            strBuff.append(s);
        }

        return strBuff.toString();
    }

}

