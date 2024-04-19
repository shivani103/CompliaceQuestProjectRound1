/**
 * @description: This class is used to get the data using callout and upsert the part records
 */
public class PartSyncService {

    public static final String SERVICE_RECORD_NAME = 'Service_Information';
    public static final String HIGH_VOLUME_ACCOUNT = 'High Volume';
    public static final String LOW_VOLUME_ACCOUNT = 'Low Volume';
    public static final String NO_CONFIGURATION_MESSAGE = 'No Configuration Found, Please set up the configuration';
    public static final String RESPONSE_PART_NUMBER = 'Part Number';
    public static final String RESPONSE_PART_NAME = 'Part Name';
    public static final String RESPONSE_TOTAL_QUANTITY_SHIPPED = 'Total Quantity Shipped';

    /**
	 * @description: This method will get response from external system and sync with the parts.
	 */
    @AuraEnabled
    public static CallOutResponseWrapper synchronizeParts() {
        
        CallOutResponseWrapper responseData = new CallOutResponseWrapper(); 
        try {
            List<REST_Service_Information__mdt> partServiceParameter = [SELECT x_api_key__c,
                                                    Content_Type__c,
                                                    Endpoint__c
                                                    FROM REST_Service_Information__mdt
                                                    WHERE DeveloperName =:SERVICE_RECORD_NAME];
            
            if (!partServiceParameter.isEmpty() && (partServiceParameter[0].Content_Type__c != null && partServiceParameter[0].x_api_key__c != null && partServiceParameter[0].Endpoint__c != null)) {
                HttpRequest request = new HttpRequest();
                request.setMethod('GET');
                request.setHeader('Content-type', partServiceParameter[0].Content_Type__c);
                request.setHeader('x-api-key', partServiceParameter[0].x_api_key__c);
                request.setEndpoint(partServiceParameter[0].Endpoint__c);
                
                // Send HTTP request
                HTTP http = new HTTP();
                HTTPResponse response = http.send(request);
                if (response.getStatusCode() == 200) {
                    // Process response data
                    String partsResponse = response.getBody();
                    List<Object> responseWrapperList = (List<Object>) JSON.deserializeUntyped(partsResponse);
                    
                    Set<String> partIdsListFromResponse = new Set<String>();
                    
                    if (!responseWrapperList.isEmpty()) {
                        for (Object obj : responseWrapperList) {
                            Map<String, Object> partData = (Map<String, Object>) obj;
                            partIdsListFromResponse.add((String) partData.get(RESPONSE_PART_NUMBER));
                        }
                    }
                    List<SQX_Part__c> partsList = new List<SQX_Part__c>();
                    
                    //Query the accounts
                    List<Account> volumeAccountsList = [SELECT Id, Name FROM Account WHERE Name =: HIGH_VOLUME_ACCOUNT OR Name =: LOW_VOLUME_ACCOUNT];
                    
                    Map<String, Id> volumeNameAndIdMap = new Map<String, Id>();
                    
                    // Create map of account names to IDs
                    if (!volumeAccountsList.isEmpty()) {
                        for (Account accRec : volumeAccountsList) {
                            volumeNameAndIdMap.put(accRec.Name, accRec.Id);
                        }
                    }
                    
                    // Query existing parts based on IDs from response
                    if (!partIdsListFromResponse.isEmpty()) {
                        partsList = [SELECT Id, Name, Active__c, Part_Number__c FROM SQX_Part__c WHERE Part_Number__c IN: partIdsListFromResponse];
                    }
                    Map<String, String> partNumberAndIdMap = new Map<String, String>();
                    if (!partsList.isEmpty()) {
                        for (SQX_Part__c partRec : partsList) {
                            partNumberAndIdMap.put(partRec.Part_Number__c, partRec.Id);
                        }
                    }
                    
                    List<SQX_Part__c> newPartsList = new List<SQX_Part__c>();
                    
                    // Create new parts based on response data
                    if (!responseWrapperList.isEmpty()) {
                        for (Object obj : responseWrapperList) {
                            Map<String, Object> wrapper = (Map<String, Object>) obj;
                            SQX_Part__c part = new SQX_Part__c();
                            if (partNumberAndIdMap.get((String) wrapper.get(RESPONSE_PART_NUMBER)) != null) {
                                part.Id = partNumberAndIdMap.get((String) wrapper.get(RESPONSE_PART_NUMBER));
                            }
                            part.Name = (String) wrapper.get(RESPONSE_PART_NAME);
                            part.Part_Number__c = (String) wrapper.get(RESPONSE_PART_NUMBER);
                            part.Active__c = true;
                            Integer totalQuantityShipped = (Integer) wrapper.get(RESPONSE_TOTAL_QUANTITY_SHIPPED);
                            // Determine account based on quantity shipped
                            if (totalQuantityShipped < 99) {
                                if (volumeNameAndIdMap.get(HIGH_VOLUME_ACCOUNT) != null) {
                                    part.Related_Account__c = volumeNameAndIdMap.get(HIGH_VOLUME_ACCOUNT);
                                }
                            } else if (totalQuantityShipped >= 99) {
                                if (volumeNameAndIdMap.get(LOW_VOLUME_ACCOUNT) != null) {
                                    part.Related_Account__c = volumeNameAndIdMap.get(LOW_VOLUME_ACCOUNT);
                                }
                            }
                            newPartsList.add(part);
                        }
                    }
                    
                    if (!newPartsList.isEmpty()) {
                        upsert newPartsList;
                    }
                    responseData.statusCode = response.getStatusCode(); 
                    responseData.responseMessage = 'Success';
                    
                } else {
                    responseData.statusCode = response.getStatusCode(); 
                    responseData.responseMessage = response.getStatus(); 
                }
                
            } else {
                responseData.statusCode = null; 
                responseData.responseMessage = NO_CONFIGURATION_MESSAGE; 
            }
            
        }
        // Handle exceptions
        catch (Exception ex) {
            responseData.statusCode = null; 
            responseData.responseMessage = ex.getMessage(); 
        }
        system.debug('responseData-->'+responseData);
        return responseData;     
    }
    
    // This wrapper class used to store data from the response.
    public class CallOutResponseWrapper {
        @AuraEnabled 
        public Integer statusCode {get; set;} 
        @AuraEnabled 
        public String responseMessage {get; set;} 
    }
}