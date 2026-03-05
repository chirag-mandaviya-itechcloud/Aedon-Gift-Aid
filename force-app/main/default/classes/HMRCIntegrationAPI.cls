/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-29-2022
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
global with sharing class HMRCIntegrationAPI {
    
       private static List<aednpc__Aedonco_Setting__mdt> privateKeys = [SELECT aednpc__General_Key__c FROM aednpc__Aedonco_Setting__mdt WITH SECURITY_ENFORCED LIMIT 1];

    private Static String Privatekey =privateKeys[0].aednpc__General_Key__c; 
    
    global Static String EncryptRecordData(String data){
        data=Userinfo.getUserId()+data;
        return EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES128', Blob.valueOf(Privatekey), Blob.valueOf(data)));
    }
    global Static String DecryptRecordData(String entryptData){
       String decrypData=Crypto.decryptWithManagedIV('AES128', Blob.valueOf(Privatekey), EncodingUtil.base64Decode(entryptData)).toString();
       return decrypData;
    } 
    
    global Static String DecryptStateInformation(String entryptState){
        String decrypData= Crypto.decryptWithManagedIV('AES256', Blob.valueOf(Privatekey+Privatekey), EncodingUtil.convertFromHex(entryptState)).toString();
        return decrypData;
    } 
    
    global Static String EncryptSessionToken(String data){
        data=Userinfo.getUserId()+data;
        return EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES128', Blob.valueOf(Privatekey), Blob.valueOf(data)));
    }
    global Static String DecryptSessionToken(String entryptData){
       String decrypData=Crypto.decryptWithManagedIV('AES128', Blob.valueOf(Privatekey), EncodingUtil.base64Decode(entryptData)).toString();
       if(decrypData.length()>18 && decrypData.substring(0,18)==userinfo.getUserId()){
            return decrypData.substring(18);
       }else{
           throw new AuraHandledException('{"code":"UNAUTHORIZED"}');  
       }
       //return  Crypto.decryptWithManagedIV('AES128', Blob.valueOf(Privatekey), EncodingUtil.base64Decode(entryptData)).toString();
    } 
    global static String authorizationAPI(){
        return authorizationAPI(null);
    }
    // Get Authorization URL
    global static String authorizationAPI(String companyId){
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
      //  system.debug('HMRCConfiguration:::::::::'+HMRCConfiguration);
       
        
        if(HMRCConfiguration!=null){
         //   system.debug('in if condition:::::::::');
            String AuthorizationUrl=HMRCConfiguration.HMRC_AUTHORIZATION_URL;
            AuthorizationUrl+='?client_id='+HMRCConfiguration.HMRC_CLIENT_ID;
            //AuthorizationUrl+='aednpc';
            AuthorizationUrl+='&grant_type=authorization_code';
            AuthorizationUrl+='&scope='+HMRCConfiguration.HMRC_SCOPE;
            AuthorizationUrl+='&response_type=code';
            String encodedState = EncodingUtil.convertToHex(Crypto.encryptWithManagedIV('AES256', Blob.valueOf(Privatekey+Privatekey), Blob.valueOf(companyId+'$$'+HMRCConfiguration.HMRC_APPLICATION_URL)));
            if(companyId!=null) AuthorizationUrl+='&state='+(encodedState);
            AuthorizationUrl+='&redirect_uri='+HMRCConfiguration.HMRC_RETURN_URL;
        //    system.debug('@@authorizationAPI : URL' + AuthorizationUrl);
            return AuthorizationUrl;
        }
        return '';
       
    }
    global static void getAccessTokenFromCode(String accessCode){
        getAccessTokenFromCode(accessCode,'');
    }
    // Get Token From the Access Code
    global static void getAccessTokenFromCode(String accessCode,String EncryptedCompanyId){
         String currentcompanyId=getLoggedInUserCompany();
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(currentcompanyId);
        if(HMRCConfiguration!=null){
            String AccessTokenUrl=HMRCConfiguration.HMRC_TOKEN_URL;
            String BodyParam='client_id='+HMRCConfiguration.HMRC_CLIENT_ID;
            BodyParam+='&client_secret='+HMRCConfiguration.HMRC_CLIENT_SECRET;
            BodyParam+='&grant_type=authorization_code';
            BodyParam+='&code='+accessCode;
            BodyParam+='&redirect_uri='+HMRCConfiguration.HMRC_RETURN_URL;
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(AccessTokenUrl);
            req.setHeader('content-type', 'application/x-www-form-urlencoded');
            req.setHeader('Content-length', String.valueOf(BodyParam.length()));
            req.setBody(BodyParam);
            req.setTimeout(60*1000);
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //    system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
        //    system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
            
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
        //    system.debug('Response Is: '+res);
            for(string s : headerkeys){
        //    system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            
            
            if(res.getStatusCode()==200){
                HMRCAuthResponse r = (HMRCAuthResponse) JSON.deserialize(res.getBody(), HMRCAuthResponse.class);
             //   system.debug('@@EncryptedCompanyId'+EncryptedCompanyId);
                if(EncryptedCompanyId!=null){
                    String companyId=EncryptedCompanyId;
                    List<Company__c> listCompany=[SELECT ID,HMRC_Access_Token__c,HMRC_Refresh_Token__c,HMRC_Token_Expired_In__c FROM Company__c Where ID=:companyId WITH SECURITY_ENFORCED];
                    if(listCompany.size()>0){
                        listCompany[0].HMRC_Access_Token__c=r.access_token;
                        listCompany[0].HMRC_Refresh_Token__c=r.refresh_token;
                        listCompany[0].HMRC_Token_Expired_In__c=DateTime.now().addSeconds(r.expires_in);
                        if(Schema.sObjectType.aednpc__Company__c.isAccessible() && Schema.sObjectType.aednpc__Company__c.isUpdateable()){
                            update listCompany[0];
                        }
                        
                    }
                }
                //aedonCacheManager.put(userinfo.getUserId(),'Bearer '+r.access_token,r.expires_in);
               //aedonPlatformEventHandler.publishHMRCAuthEvent(True,EncryptSessionToken(r.access_token),Userinfo.getUserId());
               aedonPlatformEventHandler.publishHMRCAuthEvent(True,'Token Get Successfully',Userinfo.getUserId());
            }else{
                aedonPlatformEventHandler.publishHMRCAuthEvent(False,res.getStatusCode()+' : '+res.getBody(),Userinfo.getUserId());
            }
        }
    }
    // get logging user company 
    public static string getLoggedInUserCompany(){
        User_Company__c userCompany = [SELECT Id, Current_Logged_In_Company__c 
                                       FROM User_Company__c WHERE User__c =: UserInfo.getUserId() WITH SECURITY_ENFORCED LIMIT 1];
        return userCompany.Current_Logged_In_Company__c;
    }
    
    // Get Token From the Access Code
    global static String getAccessToken(String companyId){
        List<Company__c> listCompany=[SELECT ID,HMRC_Access_Token__c,HMRC_Refresh_Token__c,HMRC_Token_Expired_In__c FROM Company__c Where ID=:companyId WITH SECURITY_ENFORCED];
        if(listCompany.size()>0){
            Company__c company=listCompany[0];
            if(company.HMRC_Token_Expired_In__c == null || company.HMRC_Token_Expired_In__c < system.now()){
                
               // VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
               aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId); 
            //   system.debug('HMRCConfiguration::::::'+HMRCConfiguration.HMRC_TOKEN_URL);
                if(HMRCConfiguration!=null){
                    String AccessTokenUrl=HMRCConfiguration.HMRC_TOKEN_URL;
                    String BodyParam='client_id='+HMRCConfiguration.HMRC_CLIENT_ID;
                    BodyParam+='&client_secret='+HMRCConfiguration.HMRC_CLIENT_SECRET;
                    BodyParam+='&grant_type=refresh_token';
                    BodyParam+='&refresh_token='+listCompany[0].HMRC_Refresh_Token__c;
                    
                    //Getting access token from 
                    HttpRequest req = new HttpRequest();
                    req.setMethod('POST');
                    req.setEndpoint(AccessTokenUrl);
                    req.setHeader('content-type', 'application/x-www-form-urlencoded');
                    req.setHeader('Content-length', String.valueOf(BodyParam.length()));
                    req.setBody(BodyParam);
                    req.setTimeout(60*1000);
                    
                    Http h = new Http();
                 //   system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
                 //   system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
         //   system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
         //   system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
         //   system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
                    
                    HttpResponse res = h.send(req);
                    string[] headerkeys = res.getHeaderKeys();
         //   system.debug('Response Is: '+res);
            for(string s : headerkeys){
         //      system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
         //   system.debug('Response Status Code: '+res.getStatusCode());
         //   system.debug('Response Body: '+res.getBody());
                    
                //    system.debug('res:::'+res);
                //    system.debug('res.getStatusCode():::'+res.getStatusCode());
                    if(res.getStatusCode()==200){
                        HMRCAuthResponse r = (HMRCAuthResponse) JSON.deserialize(res.getBody(), HMRCAuthResponse.class);
                        
                        company.HMRC_Access_Token__c=r.access_token;
                        if(r.refresh_token!=null) company.HMRC_Refresh_Token__c=r.refresh_token;
                        company.HMRC_Token_Expired_In__c=DateTime.now().addSeconds(r.expires_in);
                        //update company;
                        updateTokenDetail(JSON.serialize(company));
                        //aedonCacheManager.put(userinfo.getUserId(),'Bearer '+r.access_token,r.expires_in);
                        return company.HMRC_Access_Token__c;
                    }else{
                        return 'Refresh_Token_Expired';
                    }
                }
            }
            return company.HMRC_Access_Token__c;
        }
        return null;
    }
    @future
    public static void updateTokenDetail(String data){
     if(Schema.sObjectType.Company__c.isAccessible() && Schema.sObjectType.Company__c.isUpdateable() && Company__c.sObjectType.getDescribe().isUpdateable()){          
        update (Company__c)JSON.deserialize(data, Company__c.class);
     }
    }
    //Old method is added from managed pack due to deployment error
    // Get Token From the Access Code
    global static String getRetrieveVatConfig(String sessionID,String StartDate,String EndDate,String VRN){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
       // VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
       aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId); 
       if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/obligations';
            RetrieveVatURL+='?from='+StartDate;
            RetrieveVatURL+='&to='+EndDate;
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader((string)'Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
            req.setTimeout(60*1000);
            
            Http h = new Http();
        //   system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //    system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
         //   system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
           
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
         //   system.debug('Response Is: '+res);
            for(string s : headerkeys){
            //    system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            
            
            
            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        return null;
    }
	//Old Code added due to deployment error
	// Get Token From the Access Code
    global static String getRetrieveVatConfig1(String sessionID,String StartDate,String EndDate,String VRN,String userAgent){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        
       // VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
       aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId); 
      // aedonCustomMetadataAccess.AFUserConfig AFUserConfiguration = aedonCustomMetadataAccess.getUserConfigDetails(companyId,userAgent);
      /* if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/obligations';
            RetrieveVatURL+='?from='+StartDate;
            RetrieveVatURL+='&to='+EndDate;
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader('Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
          if(!String.isBlank(AFUserConfiguration.Gov_Client_Connection_Method)){
            req.setHeader('Gov-Client-Connection-Method',AFUserConfiguration.Gov_Client_Connection_Method);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Do_Not_Track)){
            req.setHeader('Gov-Client-Browser-Do-Not-Track',AFUserConfiguration.Gov_Client_Browser_Do_Not_Track);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_JS_User_Agent)){
           req.setHeader('Gov-Client-Browser-JS-User-Agent',AFUserConfiguration.Gov_Client_Browser_JS_User_Agent);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Plugins)) {
            req.setHeader('Gov-Client-Browser-Plugins',AFUserConfiguration.Gov_Client_Browser_Plugins);   
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Device_ID)) {
              req.setHeader('Gov-Client-Device-ID',AFUserConfiguration.Gov_Client_Device_ID);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs)) {
              req.setHeader('Gov-Client-Local-IPs',AFUserConfiguration.Gov_Client_Local_IPs);
            }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs_Timestamp)) {
              req.setHeader('Gov-Client-Local-IPs-Timestamp',AFUserConfiguration.Gov_Client_Local_IPs_Timestamp);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Multi_Factor)) {
           req.setHeader('Gov-Client-Multi-Factor',AFUserConfiguration.Gov_Client_Multi_Factor);
            }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP)) {
                req.setHeader('Gov-Client-Public-IP',AFUserConfiguration.Gov_Client_Public_IP);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP_Timestamp)) {
              req.setHeader('Gov-Client-Public-IP-Timestamp',AFUserConfiguration.Gov_Client_Public_IP_Timestamp);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_Port)) {
           req.setHeader('Gov-Client-Public-Port',AFUserConfiguration.Gov_Client_Public_Port);
           }
         if(!String.isBlank(AFUserConfiguration.Gov_Client_Screens)) {
              req.setHeader('Gov-Client-Screens',AFUserConfiguration.Gov_Client_Screens);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Timezone)) {
              req.setHeader('Gov-Client-Timezone',AFUserConfiguration.Gov_Client_Timezone);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_User_IDs)) {
               req.setHeader('Gov-Client-User-IDs',AFUserConfiguration.Gov_Client_User_IDs);
            }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Window_Size)) {
              req.setHeader('Gov-Client-Window-Size',AFUserConfiguration.Gov_Client_Window_Size);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Forwarded)) {
           req.setHeader('Gov-Vendor-Forwarded',AFUserConfiguration.Gov_Vendor_Forwarded);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_License_IDs)) {
              req.setHeader('Gov-Vendor-License-IDs',AFUserConfiguration.Gov_Vendor_License_IDs);
               }
            if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Product_Name)) {
              req.setHeader('Gov-Vendor-Product-Name',AFUserConfiguration.Gov_Vendor_Product_Name);  
           } 
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Public_IP)) {
           req.setHeader('Gov-Vendor-Public-IP',AFUserConfiguration.Gov_Vendor_Public_IP);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Version)) {
           req.setHeader('Gov-Vendor-Version',AFUserConfiguration.Gov_Vendor_Version);
           }  
            req.setTimeout(60*1000);
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
            // system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
         //   system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
         //   system.debug('Request Header - :Gov-Client-Connection-Method: '+req.getHeader('Gov-Client-Connection-Method'));
        //    system.debug('Request Header - :Gov-Client-Browser-Do-Not-Track: '+req.getHeader('Gov-Client-Browser-Do-Not-Track'));
        //   system.debug('Request Header - :Gov-Client-Browser-JS-User-Agent: '+req.getHeader('Gov-Client-Browser-JS-User-Agent'));
         //  system.debug('Request Header - :Gov-Client-Browser-Plugins: '+req.getHeader('Gov-Client-Browser-Plugins'));
         //  system.debug('Request Header - :Gov-Client-Device-ID: '+req.getHeader('Gov-Client-Device-ID'));
         //  system.debug('Request Header - :Gov-Client-Local-IPs: '+req.getHeader('Gov-Client-Local-IPs'));
        //   system.debug('Request Header - :Gov-Client-Local-IPs-Timestamp: '+req.getHeader('Gov-Client-Local-IPs-Timestamp'));
       //    system.debug('Request Header - :Gov-Client-Multi-Factor: '+req.getHeader('Gov-Client-Multi-Factor'));
        //   system.debug('Request Header - :Gov-Client-Public-Port: '+req.getHeader('Gov-Client-Public-Port'));
        //   system.debug('Request Header - :Gov-Client-Public-IP: '+req.getHeader('Gov-Client-Public-IP'));
        //   system.debug('Request Header - :Gov-Client-Public-IP-Timestamp: '+req.getHeader('Gov-Client-Public-IP-Timestamp'));
        //   system.debug('Request Header - :Gov-Client-Screens: '+req.getHeader('Gov-Client-Screens'));
        //   system.debug('Request Header - :Gov-Client-Timezone: '+req.getHeader('Gov-Client-Timezone'));
        //   system.debug('Request Header - :Gov-Client-User-IDs: '+req.getHeader('Gov-Client-User-IDs'));
        //   system.debug('Request Header - :Gov-Client-Window-Size: '+req.getHeader('Gov-Client-Window-Size'));
        //   system.debug('Request Header - :Gov-Vendor-Forwarded: '+req.getHeader('Gov-Vendor-Forwarded'));
        //   system.debug('Request Header - :Gov-Vendor-License-IDs: '+req.getHeader('Gov-Vendor-License-IDs'));
        //   system.debug('Request Header - :Gov-Vendor-Product-Name: '+req.getHeader('Gov-Vendor-Product-Name'));
        //   system.debug('Request Header - :Gov-Vendor-Public-IP: '+req.getHeader('Gov-Vendor-Public-IP'));
        //   system.debug('Request Header - :Gov-Vendor-Version: '+req.getHeader('Gov-Vendor-Version'));
        //    system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
           
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
         //   system.debug('Response Is: '+res);
            for(string s : headerkeys){
            //    system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            
            
            
            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
		}*/
        return null;
    }
    
    // Get Token From the Access Code
    public static String getRetrieveVatConfig2(String sessionID,String StartDate,String EndDate,String VRN,Map<String, String> userAgentUI){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
       // VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
       aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId); 
       aedonCustomMetadataAccess.AFUserConfig AFUserConfiguration = aedonCustomMetadataAccess.getUserConfigDetails(companyId,userAgentUI);
       if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/obligations';
            RetrieveVatURL+='?from='+StartDate;
            RetrieveVatURL+='&to='+EndDate;
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader((string)'Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
          if(!String.isBlank(AFUserConfiguration.Gov_Client_Connection_Method)){
            req.setHeader('Gov-Client-Connection-Method',AFUserConfiguration.Gov_Client_Connection_Method);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Do_Not_Track)){
            req.setHeader('Gov-Client-Browser-Do-Not-Track',AFUserConfiguration.Gov_Client_Browser_Do_Not_Track);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_JS_User_Agent)){
           req.setHeader('Gov-Client-Browser-JS-User-Agent',AFUserConfiguration.Gov_Client_Browser_JS_User_Agent);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Plugins)) {
            req.setHeader('Gov-Client-Browser-Plugins',AFUserConfiguration.Gov_Client_Browser_Plugins);   
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Device_ID)) {
              req.setHeader('Gov-Client-Device-ID',AFUserConfiguration.Gov_Client_Device_ID);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs)) {
              req.setHeader('Gov-Client-Local-IPs',AFUserConfiguration.Gov_Client_Local_IPs);
            }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs_Timestamp)) {
              req.setHeader('Gov-Client-Local-IPs-Timestamp',AFUserConfiguration.Gov_Client_Local_IPs_Timestamp);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Multi_Factor)) {
           req.setHeader('Gov-Client-Multi-Factor',AFUserConfiguration.Gov_Client_Multi_Factor);
            }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP)) {
                req.setHeader('Gov-Client-Public-IP',AFUserConfiguration.Gov_Client_Public_IP);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP_Timestamp)) {
              req.setHeader('Gov-Client-Public-IP-Timestamp',AFUserConfiguration.Gov_Client_Public_IP_Timestamp);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_Port)) {
           req.setHeader('Gov-Client-Public-Port',AFUserConfiguration.Gov_Client_Public_Port);
           }
         if(!String.isBlank(AFUserConfiguration.Gov_Client_Screens)) {
              req.setHeader('Gov-Client-Screens',AFUserConfiguration.Gov_Client_Screens);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Timezone)) {
              req.setHeader('Gov-Client-Timezone',AFUserConfiguration.Gov_Client_Timezone);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_User_IDs)) {
               req.setHeader('Gov-Client-User-IDs',AFUserConfiguration.Gov_Client_User_IDs);
            }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Window_Size)) {
              req.setHeader('Gov-Client-Window-Size',AFUserConfiguration.Gov_Client_Window_Size);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Forwarded)) {
           req.setHeader('Gov-Vendor-Forwarded',AFUserConfiguration.Gov_Vendor_Forwarded);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_License_IDs)) {
              req.setHeader('Gov-Vendor-License-IDs',AFUserConfiguration.Gov_Vendor_License_IDs);
               }
            if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Product_Name)) {
              req.setHeader('Gov-Vendor-Product-Name',AFUserConfiguration.Gov_Vendor_Product_Name);  
           } 
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Public_IP)) {
           req.setHeader('Gov-Vendor-Public-IP',AFUserConfiguration.Gov_Vendor_Public_IP);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Version)) {
           req.setHeader('Gov-Vendor-Version',AFUserConfiguration.Gov_Vendor_Version);
           }  
            req.setTimeout(60*1000);
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
            // system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //    system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Gov-Client-Connection-Method: '+req.getHeader('Gov-Client-Connection-Method'));
        //    system.debug('Request Header - :Gov-Client-Browser-Do-Not-Track: '+req.getHeader('Gov-Client-Browser-Do-Not-Track'));
        //   system.debug('Request Header - :Gov-Client-Browser-JS-User-Agent: '+req.getHeader('Gov-Client-Browser-JS-User-Agent'));
        //   system.debug('Request Header - :Gov-Client-Browser-Plugins: '+req.getHeader('Gov-Client-Browser-Plugins'));
        //   system.debug('Request Header - :Gov-Client-Device-ID: '+req.getHeader('Gov-Client-Device-ID'));
        //   system.debug('Request Header - :Gov-Client-Local-IPs: '+req.getHeader('Gov-Client-Local-IPs'));
        //   system.debug('Request Header - :Gov-Client-Multi-Factor: '+req.getHeader('Gov-Client-Multi-Factor'));
        //  system.debug('Request Header - :Gov-Client-Public-Port: '+req.getHeader('Gov-Client-Public-Port'));
         //  system.debug('Request Header - :Gov-Client-Public-IP: '+req.getHeader('Gov-Client-Public-IP'));
        //   system.debug('Request Header - :Gov-Client-Public-IP-Timestamp: '+req.getHeader('Gov-Client-Public-IP-Timestamp'));
       //    system.debug('Request Header - :Gov-Client-Screens: '+req.getHeader('Gov-Client-Screens'));
        //   system.debug('Request Header - :Gov-Client-Timezone: '+req.getHeader('Gov-Client-Timezone'));
        //   system.debug('Request Header - :Gov-Client-User-IDs: '+req.getHeader('Gov-Client-User-IDs'));
       //    system.debug('Request Header - :Gov-Client-Window-Size: '+req.getHeader('Gov-Client-Window-Size'));
        //   system.debug('Request Header - :Gov-Vendor-Forwarded: '+req.getHeader('Gov-Vendor-Forwarded'));
        //   system.debug('Request Header - :Gov-Vendor-License-IDs: '+req.getHeader('Gov-Vendor-License-IDs'));
        //   system.debug('Request Header - :Gov-Vendor-Product-Name: '+req.getHeader('Gov-Vendor-Product-Name'));
        //   system.debug('Request Header - :Gov-Vendor-Public-IP: '+req.getHeader('Gov-Vendor-Public-IP'));
        //   system.debug('Request Header - :Gov-Vendor-Version: '+req.getHeader('Gov-Vendor-Version'));
        //    system.debug('Request EndPoint: '+req.getEndpoint());
         //   system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
           
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
        //    system.debug('Response Is: '+res);
            for(string s : headerkeys){
        //       system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
       //    system.debug('Response Status Code: '+res.getStatusCode());
         //   system.debug('Response Body: '+res.getBody());
            
         if(res.getStatusCode()==200){
            return res.getBody();
        }else{
            throw new AuraHandledException(res.getBody());    
        }
    }
    return null;
}

// Get Token From the Access Code
public static String getVatLiabilities(String sessionID,String StartDate,String EndDate,String VRN,Map<String, String> userAgentUI){
    String companyId=getLoggedInUserCompany();
    String accessToken=getAccessToken(companyId);
   // VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
   aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId); 
   aedonCustomMetadataAccess.AFUserConfig AFUserConfiguration = aedonCustomMetadataAccess.getUserConfigDetails(companyId,userAgentUI);
   if(HMRCConfiguration!=null){
        String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/liabilities';
        RetrieveVatURL+='?from='+StartDate;
        RetrieveVatURL+='&to='+EndDate;
        
        //Getting access token from google
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(RetrieveVatURL);
        req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
        if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
            req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
        }
        req.setHeader((string)'Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
      if(!String.isBlank(AFUserConfiguration.Gov_Client_Connection_Method)){
        req.setHeader('Gov-Client-Connection-Method',AFUserConfiguration.Gov_Client_Connection_Method);
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Do_Not_Track)){
        req.setHeader('Gov-Client-Browser-Do-Not-Track',AFUserConfiguration.Gov_Client_Browser_Do_Not_Track);
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_JS_User_Agent)){
       req.setHeader('Gov-Client-Browser-JS-User-Agent',AFUserConfiguration.Gov_Client_Browser_JS_User_Agent);
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Plugins)) {
        req.setHeader('Gov-Client-Browser-Plugins',AFUserConfiguration.Gov_Client_Browser_Plugins);   
       }
        if(!String.isBlank(AFUserConfiguration.Gov_Client_Device_ID)) {
          req.setHeader('Gov-Client-Device-ID',AFUserConfiguration.Gov_Client_Device_ID);  
       }
        if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs)) {
          req.setHeader('Gov-Client-Local-IPs',AFUserConfiguration.Gov_Client_Local_IPs);
        }
        if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs_Timestamp)) {
          req.setHeader('Gov-Client-Local-IPs-Timestamp',AFUserConfiguration.Gov_Client_Local_IPs_Timestamp);  
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Client_Multi_Factor)) {
       req.setHeader('Gov-Client-Multi-Factor',AFUserConfiguration.Gov_Client_Multi_Factor);
        }
       if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP)) {
            req.setHeader('Gov-Client-Public-IP',AFUserConfiguration.Gov_Client_Public_IP);
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP_Timestamp)) {
          req.setHeader('Gov-Client-Public-IP-Timestamp',AFUserConfiguration.Gov_Client_Public_IP_Timestamp);  
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_Port)) {
       req.setHeader('Gov-Client-Public-Port',AFUserConfiguration.Gov_Client_Public_Port);
       }
     if(!String.isBlank(AFUserConfiguration.Gov_Client_Screens)) {
          req.setHeader('Gov-Client-Screens',AFUserConfiguration.Gov_Client_Screens);  
       }
        if(!String.isBlank(AFUserConfiguration.Gov_Client_Timezone)) {
          req.setHeader('Gov-Client-Timezone',AFUserConfiguration.Gov_Client_Timezone);  
       }
        if(!String.isBlank(AFUserConfiguration.Gov_Client_User_IDs)) {
           req.setHeader('Gov-Client-User-IDs',AFUserConfiguration.Gov_Client_User_IDs);
        }
        if(!String.isBlank(AFUserConfiguration.Gov_Client_Window_Size)) {
          req.setHeader('Gov-Client-Window-Size',AFUserConfiguration.Gov_Client_Window_Size);  
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Forwarded)) {
       req.setHeader('Gov-Vendor-Forwarded',AFUserConfiguration.Gov_Vendor_Forwarded);
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Vendor_License_IDs)) {
          req.setHeader('Gov-Vendor-License-IDs',AFUserConfiguration.Gov_Vendor_License_IDs);
           }
        if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Product_Name)) {
          req.setHeader('Gov-Vendor-Product-Name',AFUserConfiguration.Gov_Vendor_Product_Name);  
       } 
       if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Public_IP)) {
       req.setHeader('Gov-Vendor-Public-IP',AFUserConfiguration.Gov_Vendor_Public_IP);
       }
       if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Version)) {
       req.setHeader('Gov-Vendor-Version',AFUserConfiguration.Gov_Vendor_Version);
       }  
        req.setTimeout(60*1000);
        
        Http h = new Http();
     
        HttpResponse res = h.send(req);
        string[] headerkeys = res.getHeaderKeys();
        for(string s : headerkeys){
        }
            
            
            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        
    	/*Date fromDate = Date.valueOf(StartDate);
        Date toDate = Date.valueOf(EndDate);
       	User_Company__c userCompany = [SELECT Id, Current_Logged_In_Company__c,Current_Logged_In_Company__r.VAT_Registration_Number__c
                                       FROM User_Company__c WHERE User__c =: UserInfo.getUserId() WITH SECURITY_ENFORCED];
      
        List<VAT_Period_Config__c> lstVatConfig = [select Id, name,VAT_Period__c,From_Date__c,To_Date__c,VAT_Return_Deadline__c,VAT_Return_Submitted__c from VAT_Period_Config__c where From_Date__c =:fromDate and To_Date__c =:toDate and Company__c =: userCompany.Current_Logged_In_Company__c  WITH SECURITY_ENFORCED order by From_Date__c asc limit 1];  
        
        if(lstVatConfig.size()>0){
          return lstVatConfig[0].name;  
        }*/
           
       return '';
    }
    
    // Get Token From the Access Code 
    global static String getViewVatReturnConfig(String sessionID,String StartDate,String EndDate,String VRN,String periodKey){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/returns/'+ EncodingUtil.urlEncode(periodKey, 'UTF-8');
            //RetrieveVatURL+='?from='+StartDate;
            //RetrieveVatURL+='&to='+EndDate;
            //system.debug('RetrieveVatURL:::'+RetrieveVatURL);
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader((string)'Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
            req.setTimeout(60*1000);
            
            Http h = new Http();
         //   system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
         //  system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
         //   system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
        //    system.debug('Request EndPoint: '+req.getEndpoint());
         //   system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
            
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
         //   system.debug('Response Is: '+res);
            for(string s : headerkeys){
            //    system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
         //   system.debug('Response Body: '+res.getBody());
            

            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        return null;
    }
    
    //new method
    // Get Token From the Access Code 
    public static String getViewVatReturnConfig1(String sessionID,String StartDate,String EndDate,String VRN,String periodKey,Map<String, String> userAgentUI){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        aedonCustomMetadataAccess.AFUserConfig AFUserConfiguration = aedonCustomMetadataAccess.getUserConfigDetails(companyId,userAgentUI);
        if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/returns/'+ EncodingUtil.urlEncode(periodKey, 'UTF-8');
            //RetrieveVatURL+='?from='+StartDate;
            //RetrieveVatURL+='&to='+EndDate;
            //system.debug('RetrieveVatURL:::'+RetrieveVatURL);
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader((string)'Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Connection_Method)){
				req.setHeader('Gov-Client-Connection-Method',AFUserConfiguration.Gov_Client_Connection_Method);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Do_Not_Track)){
				req.setHeader('Gov-Client-Browser-Do-Not-Track',AFUserConfiguration.Gov_Client_Browser_Do_Not_Track);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_JS_User_Agent)){
			   req.setHeader('Gov-Client-Browser-JS-User-Agent',AFUserConfiguration.Gov_Client_Browser_JS_User_Agent);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Plugins)) {
				req.setHeader('Gov-Client-Browser-Plugins',AFUserConfiguration.Gov_Client_Browser_Plugins);   
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Device_ID)) {
				  req.setHeader('Gov-Client-Device-ID',AFUserConfiguration.Gov_Client_Device_ID);  
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs)) {
				  req.setHeader('Gov-Client-Local-IPs',AFUserConfiguration.Gov_Client_Local_IPs);
				}
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs_Timestamp)) {
				  req.setHeader('Gov-Client-Local-IPs-Timestamp',AFUserConfiguration.Gov_Client_Local_IPs_Timestamp);  
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Multi_Factor)) {
			   req.setHeader('Gov-Client-Multi-Factor',AFUserConfiguration.Gov_Client_Multi_Factor);
				}
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP)) {
					req.setHeader('Gov-Client-Public-IP',AFUserConfiguration.Gov_Client_Public_IP);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP_Timestamp)) {
				  req.setHeader('Gov-Client-Public-IP-Timestamp',AFUserConfiguration.Gov_Client_Public_IP_Timestamp);  
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_Port)) {
			   req.setHeader('Gov-Client-Public-Port',AFUserConfiguration.Gov_Client_Public_Port);
			   }
			 if(!String.isBlank(AFUserConfiguration.Gov_Client_Screens)) {
				  req.setHeader('Gov-Client-Screens',AFUserConfiguration.Gov_Client_Screens);  
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Timezone)) {
				  req.setHeader('Gov-Client-Timezone',AFUserConfiguration.Gov_Client_Timezone);  
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_User_IDs)) {
				   req.setHeader('Gov-Client-User-IDs',AFUserConfiguration.Gov_Client_User_IDs);
				}
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Window_Size)) {
				  req.setHeader('Gov-Client-Window-Size',AFUserConfiguration.Gov_Client_Window_Size);  
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Forwarded)) {
			   req.setHeader('Gov-Vendor-Forwarded',AFUserConfiguration.Gov_Vendor_Forwarded);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_License_IDs)) {
				  req.setHeader('Gov-Vendor-License-IDs',AFUserConfiguration.Gov_Vendor_License_IDs);
				   }
				if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Product_Name)) {
				  req.setHeader('Gov-Vendor-Product-Name',AFUserConfiguration.Gov_Vendor_Product_Name);  
			   } 
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Public_IP)) {
			   req.setHeader('Gov-Vendor-Public-IP',AFUserConfiguration.Gov_Vendor_Public_IP);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Version)) {
			   req.setHeader('Gov-Vendor-Version',AFUserConfiguration.Gov_Vendor_Version);
			   }  
            req.setTimeout(60*1000);
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //   system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
        //    system.debug('Request Header - :Gov-Client-Connection-Method: '+req.getHeader('Gov-Client-Connection-Method'));
			//	system.debug('Request Header - :Gov-Client-Browser-Do-Not-Track: '+req.getHeader('Gov-Client-Browser-Do-Not-Track'));
			//   system.debug('Request Header - :Gov-Client-Browser-JS-User-Agent: '+req.getHeader('Gov-Client-Browser-JS-User-Agent'));
			//   system.debug('Request Header - :Gov-Client-Browser-Plugins: '+req.getHeader('Gov-Client-Browser-Plugins'));
			//   system.debug('Request Header - :Gov-Client-Device-ID: '+req.getHeader('Gov-Client-Device-ID'));
			//   system.debug('Request Header - :Gov-Client-Local-IPs: '+req.getHeader('Gov-Client-Local-IPs'));
			//   system.debug('Request Header - :Gov-Client-Local-IPs-Timestamp: '+req.getHeader('Gov-Client-Local-IPs-Timestamp'));
			//   system.debug('Request Header - :Gov-Client-Multi-Factor: '+req.getHeader('Gov-Client-Multi-Factor'));
			//   system.debug('Request Header - :Gov-Client-Public-Port: '+req.getHeader('Gov-Client-Public-Port'));
			//   system.debug('Request Header - :Gov-Client-Public-IP: '+req.getHeader('Gov-Client-Public-IP'));
			//   system.debug('Request Header - :Gov-Client-Public-IP-Timestamp: '+req.getHeader('Gov-Client-Public-IP-Timestamp'));
			//   system.debug('Request Header - :Gov-Client-Screens: '+req.getHeader('Gov-Client-Screens'));
			//   system.debug('Request Header - :Gov-Client-Timezone: '+req.getHeader('Gov-Client-Timezone'));
			 //  system.debug('Request Header - :Gov-Client-User-IDs: '+req.getHeader('Gov-Client-User-IDs'));
			//   system.debug('Request Header - :Gov-Client-Window-Size: '+req.getHeader('Gov-Client-Window-Size'));
			//   system.debug('Request Header - :Gov-Vendor-Forwarded: '+req.getHeader('Gov-Vendor-Forwarded'));
			//   system.debug('Request Header - :Gov-Vendor-License-IDs: '+req.getHeader('Gov-Vendor-License-IDs'));
			//   system.debug('Request Header - :Gov-Vendor-Product-Name: '+req.getHeader('Gov-Vendor-Product-Name'));
			//   system.debug('Request Header - :Gov-Vendor-Public-IP: '+req.getHeader('Gov-Vendor-Public-IP'));
			//   system.debug('Request Header - :Gov-Vendor-Version: '+req.getHeader('Gov-Vendor-Version'));
				
        //    system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
            
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
        //    system.debug('Response Is: '+res);
            for(string s : headerkeys){
        //       system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            

            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        return null;
    }
     
    // Get Token From the Access Code 
    global static String getViewVatPaymentConfig(String sessionID,String StartDate,String EndDate,String VRN){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/payments';
            RetrieveVatURL+='?from='+StartDate;
            RetrieveVatURL+='&to='+EndDate;
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader((string)'Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
            req.setTimeout(60*1000);
            //new code
            
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //   system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
        //    system.debug('Request EndPoint: '+req.getEndpoint());
         //   system.debug('Request Method: '+req.getMethod());
        //   system.debug('Request Body: '+req.getBody());
            
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
        //    system.debug('Response Is: '+res);
            for(string s : headerkeys){
        //       system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            

            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        return null;
    }
    
    //new method
    // Get Token From the Access Code 
    global static String getViewVatPaymentConfig1(String sessionID,String StartDate,String EndDate,String VRN,Map<String, String> userAgentUI){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        aedonCustomMetadataAccess.AFUserConfig AFUserConfiguration = aedonCustomMetadataAccess.getUserConfigDetails(companyId,userAgentUI);
        if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/payments';
            RetrieveVatURL+='?from='+StartDate;
            RetrieveVatURL+='&to='+EndDate;
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader((string)'Authorization','Bearer '+accessToken );//'Bearer 899ad902b181dd57ffc209606d918812');
             if(!String.isBlank(AFUserConfiguration.Gov_Client_Connection_Method)){
				req.setHeader('Gov-Client-Connection-Method',AFUserConfiguration.Gov_Client_Connection_Method);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Do_Not_Track)){
				req.setHeader('Gov-Client-Browser-Do-Not-Track',AFUserConfiguration.Gov_Client_Browser_Do_Not_Track);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_JS_User_Agent)){
			   req.setHeader('Gov-Client-Browser-JS-User-Agent',AFUserConfiguration.Gov_Client_Browser_JS_User_Agent);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Plugins)) {
				req.setHeader('Gov-Client-Browser-Plugins',AFUserConfiguration.Gov_Client_Browser_Plugins);   
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Device_ID)) {
				  req.setHeader('Gov-Client-Device-ID',AFUserConfiguration.Gov_Client_Device_ID);  
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs)) {
				  req.setHeader('Gov-Client-Local-IPs',AFUserConfiguration.Gov_Client_Local_IPs);
				}
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs_Timestamp)) {
				  req.setHeader('Gov-Client-Local-IPs-Timestamp',AFUserConfiguration.Gov_Client_Local_IPs_Timestamp);  
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Multi_Factor)) {
			   req.setHeader('Gov-Client-Multi-Factor',AFUserConfiguration.Gov_Client_Multi_Factor);
				}
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP)) {
					req.setHeader('Gov-Client-Public-IP',AFUserConfiguration.Gov_Client_Public_IP);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP_Timestamp)) {
				  req.setHeader('Gov-Client-Public-IP-Timestamp',AFUserConfiguration.Gov_Client_Public_IP_Timestamp);  
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_Port)) {
			   req.setHeader('Gov-Client-Public-Port',AFUserConfiguration.Gov_Client_Public_Port);
			   }
			 if(!String.isBlank(AFUserConfiguration.Gov_Client_Screens)) {
				  req.setHeader('Gov-Client-Screens',AFUserConfiguration.Gov_Client_Screens);  
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Timezone)) {
				  req.setHeader('Gov-Client-Timezone',AFUserConfiguration.Gov_Client_Timezone);  
			   }
				if(!String.isBlank(AFUserConfiguration.Gov_Client_User_IDs)) {
				   req.setHeader('Gov-Client-User-IDs',AFUserConfiguration.Gov_Client_User_IDs);
				}
				if(!String.isBlank(AFUserConfiguration.Gov_Client_Window_Size)) {
				  req.setHeader('Gov-Client-Window-Size',AFUserConfiguration.Gov_Client_Window_Size);  
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Forwarded)) {
			   req.setHeader('Gov-Vendor-Forwarded',AFUserConfiguration.Gov_Vendor_Forwarded);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_License_IDs)) {
				  req.setHeader('Gov-Vendor-License-IDs',AFUserConfiguration.Gov_Vendor_License_IDs);
				   }
				if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Product_Name)) {
				  req.setHeader('Gov-Vendor-Product-Name',AFUserConfiguration.Gov_Vendor_Product_Name);  
			   } 
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Public_IP)) {
			   req.setHeader('Gov-Vendor-Public-IP',AFUserConfiguration.Gov_Vendor_Public_IP);
			   }
			   if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Version)) {
			   req.setHeader('Gov-Vendor-Version',AFUserConfiguration.Gov_Vendor_Version);
			   }  
            req.setTimeout(60*1000);
            //new code
            
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //    system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
        //    system.debug('Request Header - :Gov-Client-Connection-Method: '+req.getHeader('Gov-Client-Connection-Method'));
		//		system.debug('Request Header - :Gov-Client-Browser-Do-Not-Track: '+req.getHeader('Gov-Client-Browser-Do-Not-Track'));
		//	   system.debug('Request Header - :Gov-Client-Browser-JS-User-Agent: '+req.getHeader('Gov-Client-Browser-JS-User-Agent'));
		//	   system.debug('Request Header - :Gov-Client-Browser-Plugins: '+req.getHeader('Gov-Client-Browser-Plugins'));
		//	   system.debug('Request Header - :Gov-Client-Device-ID: '+req.getHeader('Gov-Client-Device-ID'));
		//	   system.debug('Request Header - :Gov-Client-Local-IPs: '+req.getHeader('Gov-Client-Local-IPs'));
		//	   system.debug('Request Header - :Gov-Client-Local-IPs-Timestamp: '+req.getHeader('Gov-Client-Local-IPs-Timestamp'));
		//	   system.debug('Request Header - :Gov-Client-Multi-Factor: '+req.getHeader('Gov-Client-Multi-Factor'));
		//	   system.debug('Request Header - :Gov-Client-Public-Port: '+req.getHeader('Gov-Client-Public-Port'));
		//	   system.debug('Request Header - :Gov-Client-Public-IP: '+req.getHeader('Gov-Client-Public-IP'));
		//	   system.debug('Request Header - :Gov-Client-Public-IP-Timestamp: '+req.getHeader('Gov-Client-Public-IP-Timestamp'));
		//	   system.debug('Request Header - :Gov-Client-Screens: '+req.getHeader('Gov-Client-Screens'));
		//	   system.debug('Request Header - :Gov-Client-Timezone: '+req.getHeader('Gov-Client-Timezone'));
		//	   system.debug('Request Header - :Gov-Client-User-IDs: '+req.getHeader('Gov-Client-User-IDs'));
		//	   system.debug('Request Header - :Gov-Client-Window-Size: '+req.getHeader('Gov-Client-Window-Size'));
		//	   system.debug('Request Header - :Gov-Vendor-Forwarded: '+req.getHeader('Gov-Vendor-Forwarded'));
		//	   system.debug('Request Header - :Gov-Vendor-License-IDs: '+req.getHeader('Gov-Vendor-License-IDs'));
		//	   system.debug('Request Header - :Gov-Vendor-Product-Name: '+req.getHeader('Gov-Vendor-Product-Name'));
		//	   system.debug('Request Header - :Gov-Vendor-Public-IP: '+req.getHeader('Gov-Vendor-Public-IP'));
		//	   system.debug('Request Header - :Gov-Vendor-Version: '+req.getHeader('Gov-Vendor-Version'));
        //    system.debug('Request EndPoint: '+req.getEndpoint());
         //   system.debug('Request Method: '+req.getMethod());
         //   system.debug('Request Body: '+req.getBody());
            
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
         //   system.debug('Response Is: '+res);
            for(string s : headerkeys){
            //    system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
         //   system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            

            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        
        Date fromDate = Date.valueOf(StartDate);
        Date toDate = Date.valueOf(EndDate);
        User_Company__c userCompany = [SELECT Id, Current_Logged_In_Company__c,Current_Logged_In_Company__r.VAT_Registration_Number__c
                                       FROM User_Company__c WHERE User__c =: UserInfo.getUserId() WITH SECURITY_ENFORCED];
      
        List<VAT_Period_Config__c> lstVatConfig = [select Id, name,VAT_Period__c,From_Date__c,To_Date__c,VAT_Return_Deadline__c,VAT_Return_Submitted__c from VAT_Period_Config__c where From_Date__c =:fromDate and To_Date__c =:toDate and Company__c =: userCompany.Current_Logged_In_Company__c  WITH SECURITY_ENFORCED order by From_Date__c asc limit 1];  
        
        if(lstVatConfig.size()>0){
          return lstVatConfig[0].name;  
        }
        
        return '';
    }
    
    // Get Token From the Access Code 
    global static String getViewVatLiabilitiesConfig(String sessionID,String StartDate,String EndDate,String VRN){
        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        if(HMRCConfiguration!=null){
            String RetrieveVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/liabilities';
            RetrieveVatURL+='?from='+StartDate;
            RetrieveVatURL+='&to='+EndDate;
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(RetrieveVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            if(!String.isBlank(HMRCConfiguration.GOV_TEST_SCENARIO)){
                req.setHeader('Gov-Test-Scenario', HMRCConfiguration.GOV_TEST_SCENARIO);
            }
            req.setHeader((string)'Authorization','Bearer '+DecryptSessionToken(sessionID) );//'Bearer 899ad902b181dd57ffc209606d918812');
            req.setTimeout(60*1000);
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //    system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
        //    system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
            
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
         //   system.debug('Response Is: '+res);
            for(string s : headerkeys){
        //       system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            
            
            
            if(res.getStatusCode()==200){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        return null;
    }
    
    // Get Token From the Access Code
    global static String submitVatConfig(String sessionID,String VRN,String periodKey,Decimal vatDueSales,Decimal vatDueAcquisitions,Decimal totalVatDue,
                                        Decimal vatReclaimedCurrPeriod,Decimal netVatDue,Decimal totalValueSalesExVAT,
                                        Decimal totalValuePurchasesExVAT,Decimal totalValueGoodsSuppliedExVAT,Decimal totalAcquisitionsExVAT
                                       ){
         String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        
        if(HMRCConfiguration!=null){
            String SubmitVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/returns';
            Map<String,Object> requestBody=new Map<String,Object>();
            requestBody.put('periodKey', periodKey);
            requestBody.put('vatDueSales', vatDueSales);
            requestBody.put('vatDueAcquisitions', vatDueAcquisitions);
            requestBody.put('totalVatDue', totalVatDue);
            requestBody.put('vatReclaimedCurrPeriod',vatReclaimedCurrPeriod);
            requestBody.put('netVatDue', netVatDue);
            requestBody.put('totalValueSalesExVAT', Math.round(totalValueSalesExVAT));
            requestBody.put('totalValuePurchasesExVAT', Math.round(totalValuePurchasesExVAT));
            requestBody.put('totalValueGoodsSuppliedExVAT',Math.round( totalValueGoodsSuppliedExVAT));
            requestBody.put('totalAcquisitionsExVAT', Math.round(totalAcquisitionsExVAT));
            requestBody.put('finalised', true);
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(SubmitVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader((string)'Authorization','Bearer '+accessToken);//DecryptSessionToken(sessionID) 'Bearer 899ad902b181dd57ffc209606d918812');
           
            req.setTimeout(60*1000);
            req.setBody(JSON.serialize(requestBody));
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //    system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
            

        //    system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
            
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
        //    system.debug('Response Is: '+res);
            for(string s : headerkeys){
        //       system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());
            
            
            
            
            if(res.getStatusCode()==201){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        return null;
    }
    
    public static String submitVatConfig1(String sessionID,String VRN,String periodKey,Decimal vatDueSales,Decimal vatDueAcquisitions,Decimal totalVatDue,
                                        Decimal vatReclaimedCurrPeriod,Decimal netVatDue,Decimal totalValueSalesExVAT,
                                        Decimal totalValuePurchasesExVAT,Decimal totalValueGoodsSuppliedExVAT,Decimal totalAcquisitionsExVAT,
                                        Map<String, String> userAgentUI,String batchJOBId){
		
        User_Company__c userCompany = [SELECT Id, Current_Logged_In_Company__c, Current_Logged_In_Company__r.VAT_Registration_Number__c,Current_Logged_In_Company__r.VAT_Method__c FROM User_Company__c WHERE User__c =: UserInfo.getUserId() WITH SECURITY_ENFORCED];

        String companyId=getLoggedInUserCompany();
        String accessToken=getAccessToken(companyId);
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        aedonCustomMetadataAccess.AFUserConfig AFUserConfiguration = aedonCustomMetadataAccess.getUserConfigDetails(companyId,userAgentUI);
        if(HMRCConfiguration!=null){
            String SubmitVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/returns';
            Map<String,Object> requestBody=new Map<String,Object>();
            requestBody.put('periodKey', periodKey);
            requestBody.put('vatDueSales', vatDueSales);
            requestBody.put('vatDueAcquisitions', vatDueAcquisitions);
            requestBody.put('totalVatDue', totalVatDue);
            requestBody.put('vatReclaimedCurrPeriod',vatReclaimedCurrPeriod);
            requestBody.put('netVatDue', netVatDue);
            requestBody.put('totalValueSalesExVAT', Math.round(totalValueSalesExVAT));
            requestBody.put('totalValuePurchasesExVAT', Math.round(totalValuePurchasesExVAT));
            requestBody.put('totalValueGoodsSuppliedExVAT',Math.round( totalValueGoodsSuppliedExVAT));
            requestBody.put('totalAcquisitionsExVAT', Math.round(totalAcquisitionsExVAT));
            requestBody.put('finalised', true);
            
            //Shravya adding new code to capture request and response headers and body
            VAT_Return__c objVatReturn = new VAT_Return__c();
            List<VAT_Return__c> objVatReturnList = new List<VAT_Return__c>();
			
            List<VAT_Return__c> vatReturnObjList = [SELECT Id, Name,Submit_VAT_Request__c,Submit_VAT_Response__c, 
                                                    Box1_Amount__c, Box2_Amount__c, Box3_Amount__c, Box4_Amount__c, 
                                                    Box5_Amount__c, Box6_Amount__c, Box7_Amount__c, Box8_Amount__c, 
                                                    Box9_Amount__c, Company__c, Deadline_Date__c, From_Date__c, 
                                                    Late_VAT_Claims_included__c, Registration_Number__c, Status__c,
                                                    Processing_Date__c,
                                                    To_Date__c, VAT_Method__c, VAT_Period_Config__c, VAT_Period_covered_by_the_return__c
													FROM VAT_Return__c WHERE Company__c =:userCompany.Current_Logged_In_Company__c and 
                                                    Id=:batchJOBId WITH SECURITY_ENFORCED];
             for(VAT_Return__c a : vatReturnObjList){
                    String submitRequest  = ('HEADERS::'+//'Gov-Test-Scenario:-'+//req.getHeader('Gov-Test-Scenario')+','+
                                                   'Accept:-'+ 'application/vnd.hmrc.1.0+json'+','+
                                             		'Content-Type:-'+'application/json'+','+
                                             		'Authorization:-'+'Bearer '+accessToken+','+
                                                   'Gov-Client-Connection-Method:-'+AFUserConfiguration.Gov_Client_Connection_Method+','+
                                                 'Gov-Client-Browser-Do-Not-Track:-'+AFUserConfiguration.Gov_Client_Browser_Do_Not_Track+','+
                                                 'Gov-Client-Browser-JS-User-Agent:-'+AFUserConfiguration.Gov_Client_Browser_JS_User_Agent+','+
                                                 'Gov-Client-Browser-Plugins:-'+AFUserConfiguration.Gov_Client_Browser_Plugins+','+
                                                 'Gov-Client-Device-ID:-'+AFUserConfiguration.Gov_Client_Device_ID+','+
                                                 'Gov-Client-Local-IPs:-'+AFUserConfiguration.Gov_Client_Local_IPs+','+        
                                                 'Gov-Client-Local-IPs-Timestamp:-'+AFUserConfiguration.Gov_Client_Local_IPs_Timestamp+','+
                                                 'Gov-Client-Multi-Factor:-'+AFUserConfiguration.Gov_Client_Multi_Factor+','+            
                                                 'Gov-Client-Public-Port:-'+AFUserConfiguration.Gov_Client_Public_Port+','+
                                                 'Gov-Client-Public-IP:-'+AFUserConfiguration.Gov_Client_Public_IP+','+
                                                 'Gov-Client-Public-IP-Timestamp:-'+AFUserConfiguration.Gov_Client_Public_IP_Timestamp+','+
                                                 'Gov-Client-Screens:-'+AFUserConfiguration.Gov_Client_Screens+','+
                                                 'Gov-Client-Timezone:-'+AFUserConfiguration.Gov_Client_Timezone+','+
                                                 'Gov-Client-User-IDs:-'+AFUserConfiguration.Gov_Client_User_IDs+','+
                                                 'Gov-Client-Window-Size:-'+AFUserConfiguration.Gov_Client_Window_Size+','+
                                                 'Gov-Vendor-Forwarded:-'+AFUserConfiguration.Gov_Vendor_Forwarded+','+
                                                 'Gov-Vendor-License-IDs:-'+AFUserConfiguration.Gov_Vendor_License_IDs+','+
                                                 'Gov-Vendor-Product-Name:-'+AFUserConfiguration.Gov_Vendor_Product_Name+','+
                                                 'Gov-Vendor-Public-IP:-'+AFUserConfiguration.Gov_Vendor_Public_IP+','+
                                                 'Gov-Vendor-Version:-'+AFUserConfiguration.Gov_Vendor_Version+','+
                                                 'BODY::'+JSON.serialize(requestBody));
                        
                        Integer maxSize = 100000;
                        if(submitRequest.length()>maxSize){
                            a.Submit_VAT_Request__c = submitRequest.substring(0,maxSize-1);    
                        }
                        else{
                           a.Submit_VAT_Request__c = submitRequest;
                        }
                    }
              
                         
            
            //Getting access token from google
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(SubmitVatURL);
            req.setHeader('Accept', 'application/vnd.hmrc.1.0+json');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader((string)'Authorization','Bearer '+accessToken);//DecryptSessionToken(sessionID) 'Bearer 899ad902b181dd57ffc209606d918812');
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Connection_Method)){
            req.setHeader('Gov-Client-Connection-Method',AFUserConfiguration.Gov_Client_Connection_Method);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Do_Not_Track)){
            req.setHeader('Gov-Client-Browser-Do-Not-Track',AFUserConfiguration.Gov_Client_Browser_Do_Not_Track);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_JS_User_Agent)){
           req.setHeader('Gov-Client-Browser-JS-User-Agent',AFUserConfiguration.Gov_Client_Browser_JS_User_Agent);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Browser_Plugins)) {
            req.setHeader('Gov-Client-Browser-Plugins',AFUserConfiguration.Gov_Client_Browser_Plugins);   
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Device_ID)) {
              req.setHeader('Gov-Client-Device-ID',AFUserConfiguration.Gov_Client_Device_ID);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs)) {
              req.setHeader('Gov-Client-Local-IPs',AFUserConfiguration.Gov_Client_Local_IPs);
            }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Local_IPs_Timestamp)) {
              req.setHeader('Gov-Client-Local-IPs-Timestamp',AFUserConfiguration.Gov_Client_Local_IPs_Timestamp);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Multi_Factor)) {
           req.setHeader('Gov-Client-Multi-Factor',AFUserConfiguration.Gov_Client_Multi_Factor);
            }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP)) {
                req.setHeader('Gov-Client-Public-IP',AFUserConfiguration.Gov_Client_Public_IP);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_IP_Timestamp)) {
              req.setHeader('Gov-Client-Public-IP-Timestamp',AFUserConfiguration.Gov_Client_Public_IP_Timestamp);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Client_Public_Port)) {
           req.setHeader('Gov-Client-Public-Port',AFUserConfiguration.Gov_Client_Public_Port);
           }
         if(!String.isBlank(AFUserConfiguration.Gov_Client_Screens)) {
              req.setHeader('Gov-Client-Screens',AFUserConfiguration.Gov_Client_Screens);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Timezone)) {
              req.setHeader('Gov-Client-Timezone',AFUserConfiguration.Gov_Client_Timezone);  
           }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_User_IDs)) {
               req.setHeader('Gov-Client-User-IDs',AFUserConfiguration.Gov_Client_User_IDs);
            }
            if(!String.isBlank(AFUserConfiguration.Gov_Client_Window_Size)) {
              req.setHeader('Gov-Client-Window-Size',AFUserConfiguration.Gov_Client_Window_Size);  
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Forwarded)) {
           req.setHeader('Gov-Vendor-Forwarded',AFUserConfiguration.Gov_Vendor_Forwarded);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_License_IDs)) {
              req.setHeader('Gov-Vendor-License-IDs',AFUserConfiguration.Gov_Vendor_License_IDs);
               }
            if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Product_Name)) {
              req.setHeader('Gov-Vendor-Product-Name',AFUserConfiguration.Gov_Vendor_Product_Name);  
           } 
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Public_IP)) {
           req.setHeader('Gov-Vendor-Public-IP',AFUserConfiguration.Gov_Vendor_Public_IP);
           }
           if(!String.isBlank(AFUserConfiguration.Gov_Vendor_Version)) {
           req.setHeader('Gov-Vendor-Version',AFUserConfiguration.Gov_Vendor_Version);
           }  
            req.setTimeout(60*1000);
            req.setBody(JSON.serialize(requestBody));
            
            Http h = new Http();
        //    system.debug('VAT Environment :'+HMRCConfiguration.VAT_ENVIRONMENT);
        //    system.debug('Request Is: '+req);
            //system.debug('Request Header - :Authorization : Bearer '+req.getHeader('Authorization')+''+req.getHeader('Bearer'));
        //    system.debug('Request Header - :Gov-Test-Scenario: '+req.getHeader('Gov-Test-Scenario')); 
        //    system.debug('Request Header - :Accept: '+req.getHeader('Accept'));
        //    system.debug('Request Header - :Gov-Client-Connection-Method: '+req.getHeader('Gov-Client-Connection-Method'));
        //    system.debug('Request Header - :Gov-Client-Browser-Do-Not-Track: '+req.getHeader('Gov-Client-Browser-Do-Not-Track'));
       //    system.debug('Request Header - :Gov-Client-Browser-JS-User-Agent: '+req.getHeader('Gov-Client-Browser-JS-User-Agent'));
        //   system.debug('Request Header - :Gov-Client-Browser-Plugins: '+req.getHeader('Gov-Client-Browser-Plugins'));
        //   system.debug('Request Header - :Gov-Client-Device-ID: '+req.getHeader('Gov-Client-Device-ID'));
        //   system.debug('Request Header - :Gov-Client-Local-IPs: '+req.getHeader('Gov-Client-Local-IPs'));
        //   system.debug('Request Header - :Gov-Client-Local-IPs-Timestamp: '+req.getHeader('Gov-Client-Local-IPs-Timestamp'));
        //   system.debug('Request Header - :Gov-Client-Multi-Factor: '+req.getHeader('Gov-Client-Multi-Factor'));
         //  system.debug('Request Header - :Gov-Client-Public-Port: '+req.getHeader('Gov-Client-Public-Port'));
        //   system.debug('Request Header - :Gov-Client-Public-IP: '+req.getHeader('Gov-Client-Public-IP'));
        //   system.debug('Request Header - :Gov-Client-Public-IP-Timestamp: '+req.getHeader('Gov-Client-Public-IP-Timestamp'));
        //   system.debug('Request Header - :Gov-Client-Screens: '+req.getHeader('Gov-Client-Screens'));
        //   system.debug('Request Header - :Gov-Client-Timezone: '+req.getHeader('Gov-Client-Timezone'));
        //   system.debug('Request Header - :Gov-Client-User-IDs: '+req.getHeader('Gov-Client-User-IDs'));
        //   system.debug('Request Header - :Gov-Client-Window-Size: '+req.getHeader('Gov-Client-Window-Size'));
        //   system.debug('Request Header - :Gov-Vendor-Forwarded: '+req.getHeader('Gov-Vendor-Forwarded'));
        //   system.debug('Request Header - :Gov-Vendor-License-IDs: '+req.getHeader('Gov-Vendor-License-IDs'));
        //   system.debug('Request Header - :Gov-Vendor-Product-Name: '+req.getHeader('Gov-Vendor-Product-Name'));
        //   system.debug('Request Header - :Gov-Vendor-Public-IP: '+req.getHeader('Gov-Vendor-Public-IP'));
        //   system.debug('Request Header - :Gov-Vendor-Version: '+req.getHeader('Gov-Vendor-Version'));

        //    system.debug('Request EndPoint: '+req.getEndpoint());
        //    system.debug('Request Method: '+req.getMethod());
        //    system.debug('Request Body: '+req.getBody());
            
           
            HttpResponse res = h.send(req);
            string[] headerkeys = res.getHeaderKeys();
         //   system.debug('Response Is: '+res);
            for(string s : headerkeys){
            //    system.debug('Response Header: ' + s + ' value: ' + res.getHeader(s));
            }
        //    system.debug('Response Status Code: '+res.getStatusCode());
        //    system.debug('Response Body: '+res.getBody());

        /*    system.debug('Shravya Request: '+('HEADERS::'+'Gov-Test-Scenario:-'+req.getHeader('Gov-Test-Scenario')+','+
                                           'Accept:-'+ 'application/vnd.hmrc.1.0+json'+','+
                                           'Gov-Client-Connection-Method:-'+AFUserConfiguration.Gov_Client_Connection_Method+','+
                                         'Gov-Client-Browser-Do-Not-Track:-'+req.getHeader('Gov-Client-Browser-Do-Not-Track')+','+
                                         'Gov-Client-Browser-JS-User-Agent:-'+req.getHeader('Gov-Client-Browser-JS-User-Agent')+','+
                                         'Gov-Client-Browser-Plugins:-'+req.getHeader('Gov-Client-Browser-Plugins')+','+
                                         'Gov-Client-Device-ID:-'+req.getHeader('Gov-Client-Device-ID')+','+
                                         'Gov-Client-Local-IPs:-'+req.getHeader('Gov-Client-Local-IPs')+','+        
                                         'Gov-Client-Local-IPs-Timestamp:-'+req.getHeader('Gov-Client-Local-IPs-Timestamp')+','+
                                         'Gov-Client-Multi-Factor:-'+req.getHeader('Gov-Client-Multi-Factor')+','+            
                                         'Gov-Client-Public-Port:-'+req.getHeader('Gov-Client-Public-Port')+','+
                                         'Gov-Client-Public-IP:-'+req.getHeader('Gov-Client-Public-IP')+','+
                                         'Gov-Client-Public-IP-Timestamp:-'+req.getHeader('Gov-Client-Public-IP-Timestamp')+','+
                                         'Gov-Client-Screens:-'+req.getHeader('Gov-Client-Screens')+','+
                                         'Gov-Client-Timezone:-'+req.getHeader('Gov-Client-Timezone')+','+
                                         'Gov-Client-User-IDs:-'+req.getHeader('Gov-Client-User-IDs')+','+
                                         'Gov-Client-Window-Size:-'+req.getHeader('Gov-Client-Window-Size')+','+
                                         'Gov-Vendor-Forwarded:-'+req.getHeader('Gov-Vendor-Forwarded')+','+
                                         'Gov-Vendor-License-IDs:-'+req.getHeader('Gov-Vendor-License-IDs')+','+
                                         'Gov-Vendor-Product-Name:-'+req.getHeader('Gov-Vendor-Product-Name')+','+
                                         'Gov-Vendor-Public-IP:-'+req.getHeader('Gov-Vendor-Public-IP')+','+
                                         'Gov-Vendor-Version:-'+req.getHeader('Gov-Vendor-Version')+','+
                                         'BODY::'+req.getBody(); */
            
         /*   system.debug('Shravya Response: '+('HEADERS::'+'Transfer-Encoding:-'+res.getHeader('Transfer-Encoding')+','+
                                         'X-Cache:-'+res.getHeader('X-Cache')+','+
                                         'X-Envoy-Upstream-Service-Time:-'+res.getHeader('X-Envoy-Upstream-Service-Time')+','+
                                         'X-Content-Type-Options:-'+res.getHeader('X-Content-Type-Options')+','+
                                         'X-Amz-Cf-Pop:-'+res.getHeader('X-Amz-Cf-Pop')+','+
                                         'X-Correlationid:-'+res.getHeader('X-Correlationid')+','+
                                         'Connection:-'+res.getHeader('Connection')+','+
                                         'Receipt-Timestamp:-'+res.getHeader('Receipt-Timestamp')+','+
                                         'Receipt-Id:-'+res.getHeader('Receipt-Id')+','+
                                         'Date:-'+res.getHeader('Date')+','+
                                         'Via:-'+res.getHeader('Via')+','+
                                         'X-Frame-Options:-'+res.getHeader('X-Frame-Options')+','+
                                         'Strict-Transport-Security:-'+res.getHeader('Strict-Transport-Security')+','+
                                         'Cache-Control:-'+res.getHeader('Cache-Control')+','+
                                         'Content-Security-Policy:-'+res.getHeader('Content-Security-Policy')+','+
                                         'X-Amz-Cf-Id:-'+res.getHeader('X-Amz-Cf-Id')+','+
                                         'Receipt-Signature:-'+res.getHeader('Receipt-Signature')+','+
                                         'Content-Type:-'+res.getHeader('Content-Type')+','+
                                         'BODY::'+res.getBody())); */
            
           for(VAT_Return__c a : vatReturnObjList){
   				/*String submitRequest  = ('HEADERS::'+'Gov-Test-Scenario:-'+req.getHeader('Gov-Test-Scenario')+','+
                                           'Accept:-'+ 'application/vnd.hmrc.1.0+json'+','+
                                           'Gov-Client-Connection-Method:-'+AFUserConfiguration.Gov_Client_Connection_Method+','+
                                         'Gov-Client-Browser-Do-Not-Track:-'+req.getHeader('Gov-Client-Browser-Do-Not-Track')+','+
                                         'Gov-Client-Browser-JS-User-Agent:-'+req.getHeader('Gov-Client-Browser-JS-User-Agent')+','+
                                         'Gov-Client-Browser-Plugins:-'+req.getHeader('Gov-Client-Browser-Plugins')+','+
                                         'Gov-Client-Device-ID:-'+req.getHeader('Gov-Client-Device-ID')+','+
                                         'Gov-Client-Local-IPs:-'+req.getHeader('Gov-Client-Local-IPs')+','+        
                                         'Gov-Client-Local-IPs-Timestamp:-'+req.getHeader('Gov-Client-Local-IPs-Timestamp')+','+
                                         'Gov-Client-Multi-Factor:-'+req.getHeader('Gov-Client-Multi-Factor')+','+            
                                         'Gov-Client-Public-Port:-'+req.getHeader('Gov-Client-Public-Port')+','+
                                         'Gov-Client-Public-IP:-'+req.getHeader('Gov-Client-Public-IP')+','+
                                         'Gov-Client-Public-IP-Timestamp:-'+req.getHeader('Gov-Client-Public-IP-Timestamp')+','+
                                         'Gov-Client-Screens:-'+req.getHeader('Gov-Client-Screens')+','+
                                         'Gov-Client-Timezone:-'+req.getHeader('Gov-Client-Timezone')+','+
                                         'Gov-Client-User-IDs:-'+req.getHeader('Gov-Client-User-IDs')+','+
                                         'Gov-Client-Window-Size:-'+req.getHeader('Gov-Client-Window-Size')+','+
                                         'Gov-Vendor-Forwarded:-'+req.getHeader('Gov-Vendor-Forwarded')+','+
                                         'Gov-Vendor-License-IDs:-'+req.getHeader('Gov-Vendor-License-IDs')+','+
                                         'Gov-Vendor-Product-Name:-'+req.getHeader('Gov-Vendor-Product-Name')+','+
                                         'Gov-Vendor-Public-IP:-'+req.getHeader('Gov-Vendor-Public-IP')+','+
                                         'Gov-Vendor-Version:-'+req.getHeader('Gov-Vendor-Version')+','+
                                         'BODY::'+req.getBody());
               
           //    system.debug('Shravya Request: '+submitRequest);
                
                Integer maxSize = 100000;
                if(submitRequest.length()>maxSize){
                	a.Submit_VAT_Request__c = submitRequest.substring(0,maxSize-1);    
                }
                else{
                   a.Submit_VAT_Request__c = submitRequest;
                }*/
            	Integer maxSize = 100000;
                String submitResponse = ('HEADERS::'+'Transfer-Encoding:-'+res.getHeader('Transfer-Encoding')+','+
                                         'X-Cache:-'+res.getHeader('X-Cache')+','+
                                         'X-Envoy-Upstream-Service-Time:-'+res.getHeader('X-Envoy-Upstream-Service-Time')+','+
                                         'X-Content-Type-Options:-'+res.getHeader('X-Content-Type-Options')+','+
                                         'X-Amz-Cf-Pop:-'+res.getHeader('X-Amz-Cf-Pop')+','+
                                         'X-Correlationid:-'+res.getHeader('X-Correlationid')+','+
                                         'Connection:-'+res.getHeader('Connection')+','+
                                         'Receipt-Timestamp:-'+res.getHeader('Receipt-Timestamp')+','+
                                         'Receipt-Id:-'+res.getHeader('Receipt-Id')+','+
                                         'Date:-'+res.getHeader('Date')+','+
                                         'Via:-'+res.getHeader('Via')+','+
                                         'X-Frame-Options:-'+res.getHeader('X-Frame-Options')+','+
                                         'Strict-Transport-Security:-'+res.getHeader('Strict-Transport-Security')+','+
                                         'Cache-Control:-'+res.getHeader('Cache-Control')+','+
                                         'Content-Security-Policy:-'+res.getHeader('Content-Security-Policy')+','+
                                         'X-Amz-Cf-Id:-'+res.getHeader('X-Amz-Cf-Id')+','+
                                         'Receipt-Signature:-'+res.getHeader('Receipt-Signature')+','+
                                         'Content-Type:-'+res.getHeader('Content-Type')+','+
                                         'BODY::'+res.getBody());
                
           //    system.debug('Shravya Response: '+submitResponse);
                if(submitResponse.length()>maxSize){
                	a.Submit_VAT_Response__c = submitResponse.substring(0,maxSize-1);    
                }
                else{
                    a.Submit_VAT_Response__c = submitResponse;
                }
                
			}
            
            vatReturnObjList = aedonAppExUtils.aedonUpdate(vatReturnObjList);
           // update vatReturnObjList;
            
           
           
           
			
            List<VAT_Return__c> objVatReturnResponse = [SELECT Id, Name,Submit_VAT_Request__c,Submit_VAT_Response__c, Processing_Date__c,
                                                        formBundleNumber__c,paymentIndicator__c,chargeRefNumber__c,
                                                    Box1_Amount__c, Box2_Amount__c, Box3_Amount__c, Box4_Amount__c, 
                                                    Box5_Amount__c, Box6_Amount__c, Box7_Amount__c, Box8_Amount__c, 
                                                    Box9_Amount__c, Company__c, Deadline_Date__c, From_Date__c, 
                                                    Late_VAT_Claims_included__c, Registration_Number__c, Status__c, 
                                                    To_Date__c, VAT_Method__c, VAT_Period_Config__c, VAT_Period_covered_by_the_return__c
													FROM VAT_Return__c WHERE Company__c =:userCompany.Current_Logged_In_Company__c and Id=:batchJOBId WITH SECURITY_ENFORCED];
            
            
            parsedResponse returnResponse = (parsedResponse)JSON.deserialize(res.getBody(), parsedResponse.class);
            for(VAT_Return__c resp : objVatReturnResponse){
            	resp.Processing_Date__c=returnResponse.processingDate;  
                resp.formBundleNumber__c=returnResponse.formBundleNumber;  
                resp.paymentIndicator__c=returnResponse.paymentIndicator;  
                resp.chargeRefNumber__c=returnResponse.chargeRefNumber;  
            }
            
            //system.debug('Shravya parsed date: '+objVatReturnResponse.Processing_Date__c);
            
            objVatReturnResponse = aedonAppExUtils.aedonUpdate(objVatReturnResponse);
            //update objVatReturnResponse;
            if(res.getStatusCode()==201){
                return res.getBody();
            }else{
                throw new AuraHandledException(res.getBody());    
            }
        }
        return null;
    }
    
    //capturing the request when there is an error
    @AuraEnabled
    public static String capturingErrorRequest(String sessionID,String VRN,String periodKey,Decimal vatDueSales,Decimal vatDueAcquisitions,Decimal totalVatDue,
                                        Decimal vatReclaimedCurrPeriod,Decimal netVatDue,Decimal totalValueSalesExVAT,
                                        Decimal totalValuePurchasesExVAT,Decimal totalValueGoodsSuppliedExVAT,Decimal totalAcquisitionsExVAT,
                                 Map<String, String> userAgentUI,String batchJOBId){
        
                                    sessionID = (sessionID!=NULL?String.escapeSingleQuotes(sessionID):sessionID);
                                    VRN = (VRN!=NULL?String.escapeSingleQuotes(VRN):VRN);
                                    periodKey = (periodKey!=NULL?String.escapeSingleQuotes(periodKey):periodKey);
                                    batchJOBId = (batchJOBId!=NULL?String.escapeSingleQuotes(batchJOBId):batchJOBId);

    //    system.debug('Shravya entered request error method');
        User_Company__c userCompany = [SELECT Id, Current_Logged_In_Company__c, Current_Logged_In_Company__r.VAT_Registration_Number__c,Current_Logged_In_Company__r.VAT_Method__c FROM User_Company__c WHERE User__c =: UserInfo.getUserId() WITH SECURITY_ENFORCED];
   		String companyId=getLoggedInUserCompany();
                                     //System.debug('companyId'+companyId);
                                     //System.debug('accessToken'+getAccessToken(companyId));
                                      
        String accessToken=getAccessToken(companyId);
                                     
        //VAT_MTD_Integration__mdt HMRCConfiguration=aedonCustomMetadataAccess.getVAT_LDV_MTD_IntegrationByDeveloperName('HMRCConfiguration');
        aedonCustomMetadataAccess.HMRCConfig HMRCConfiguration =  aedonCustomMetadataAccess.getHMRCConfigDetails(companyId);
        aedonCustomMetadataAccess.AFUserConfig AFUserConfiguration = aedonCustomMetadataAccess.getUserConfigDetails(companyId,userAgentUI);
        if(HMRCConfiguration!=null){
            String SubmitVatURL=HMRCConfiguration.HMRC_BASE_URL+'/organisations/vat/'+VRN+'/returns';
            Map<String,Object> requestBody=new Map<String,Object>();
            requestBody.put('periodKey', periodKey);
            requestBody.put('vatDueSales', vatDueSales);
            requestBody.put('vatDueAcquisitions', vatDueAcquisitions);
            requestBody.put('totalVatDue', totalVatDue);
            requestBody.put('vatReclaimedCurrPeriod',vatReclaimedCurrPeriod);
            requestBody.put('netVatDue', netVatDue);
            requestBody.put('totalValueSalesExVAT', Math.round(totalValueSalesExVAT));
            requestBody.put('totalValuePurchasesExVAT', Math.round(totalValuePurchasesExVAT));
            requestBody.put('totalValueGoodsSuppliedExVAT',Math.round( totalValueGoodsSuppliedExVAT));
            requestBody.put('totalAcquisitionsExVAT', Math.round(totalAcquisitionsExVAT));
            requestBody.put('finalised', true);
        
        VAT_Return__c objVatReturn = new VAT_Return__c();
            List<VAT_Return__c> objVatReturnList = new List<VAT_Return__c>();
			
            List<VAT_Return__c> vatReturnObjList = [SELECT Id, Name,Submit_VAT_Request__c,Submit_VAT_Response__c, 
                                                    Box1_Amount__c, Box2_Amount__c, Box3_Amount__c, Box4_Amount__c, 
                                                    Box5_Amount__c, Box6_Amount__c, Box7_Amount__c, Box8_Amount__c, 
                                                    Box9_Amount__c, Company__c, Deadline_Date__c, From_Date__c, 
                                                    Late_VAT_Claims_included__c, Registration_Number__c, Status__c, 
                                                    To_Date__c, VAT_Method__c, VAT_Period_Config__c, VAT_Period_covered_by_the_return__c
													FROM VAT_Return__c WHERE Company__c =:userCompany.Current_Logged_In_Company__c and Id=:batchJOBId WITH SECURITY_ENFORCED];
      //  system.debug('Shravya vatReturnObjList: '+vatReturnObjList);
        
        for(VAT_Return__c a : vatReturnObjList){
            
            String submitRequest  = ('HEADERS::'+//'Gov-Test-Scenario:-'+req.getHeader('Gov-Test-Scenario')+','+
                                                    'Accept:-'+ 'application/vnd.hmrc.1.0+json'+','+
                                             		'Content-Type:-'+'application/json'+','+
                                             		'Authorization:-'+'Bearer '+accessToken+','+
                                                   'Gov-Client-Connection-Method:-'+AFUserConfiguration.Gov_Client_Connection_Method+','+
                                                 'Gov-Client-Browser-Do-Not-Track:-'+AFUserConfiguration.Gov_Client_Browser_Do_Not_Track+','+
                                                 'Gov-Client-Browser-JS-User-Agent:-'+AFUserConfiguration.Gov_Client_Browser_JS_User_Agent+','+
                                                 'Gov-Client-Browser-Plugins:-'+AFUserConfiguration.Gov_Client_Browser_Plugins+','+
                                                 'Gov-Client-Device-ID:-'+AFUserConfiguration.Gov_Client_Device_ID+','+
                                                 'Gov-Client-Local-IPs:-'+AFUserConfiguration.Gov_Client_Local_IPs+','+        
                                                 'Gov-Client-Local-IPs-Timestamp:-'+AFUserConfiguration.Gov_Client_Local_IPs_Timestamp+','+
                                                 'Gov-Client-Multi-Factor:-'+AFUserConfiguration.Gov_Client_Multi_Factor+','+            
                                                 'Gov-Client-Public-Port:-'+AFUserConfiguration.Gov_Client_Public_Port+','+
                                                 'Gov-Client-Public-IP:-'+AFUserConfiguration.Gov_Client_Public_IP+','+
                                                 'Gov-Client-Public-IP-Timestamp:-'+AFUserConfiguration.Gov_Client_Public_IP_Timestamp+','+
                                                 'Gov-Client-Screens:-'+AFUserConfiguration.Gov_Client_Screens+','+
                                                 'Gov-Client-Timezone:-'+AFUserConfiguration.Gov_Client_Timezone+','+
                                                 'Gov-Client-User-IDs:-'+AFUserConfiguration.Gov_Client_User_IDs+','+
                                                 'Gov-Client-Window-Size:-'+AFUserConfiguration.Gov_Client_Window_Size+','+
                                                 'Gov-Vendor-Forwarded:-'+AFUserConfiguration.Gov_Vendor_Forwarded+','+
                                                 'Gov-Vendor-License-IDs:-'+AFUserConfiguration.Gov_Vendor_License_IDs+','+
                                                 'Gov-Vendor-Product-Name:-'+AFUserConfiguration.Gov_Vendor_Product_Name+','+
                                                 'Gov-Vendor-Public-IP:-'+AFUserConfiguration.Gov_Vendor_Public_IP+','+
                                                 'Gov-Vendor-Version:-'+AFUserConfiguration.Gov_Vendor_Version+','+
                                                 'BODY::'+JSON.serialize(requestBody));
                        
                        Integer maxSize = 100000;
                        if(submitRequest.length()>maxSize){
                            a.Submit_VAT_Request__c = submitRequest.substring(0,maxSize-1);    
                        }
                        else{
                           a.Submit_VAT_Request__c = submitRequest;
                        }
        }

            vatReturnObjList = aedonAppExUtils.aedonUpdate(vatReturnObjList);
            //update vatReturnObjList;
            
            
         }
         return batchJOBId;
         }

    
    global class HMRCAuthResponse{
        public String access_token;
        public String refresh_token;
        public Integer expires_in;
        public String scope;
        public String token_type;
    }
    global class HMRCVatSubmitResponse{
        public String processingDate;
        public String paymentIndicator;
        public String formBundleNumber;
        public String chargeRefNumber;
    }
    global class HMRCVatObligationResponse{
        public List<HMRCVatObligations> obligations;
    }
    global class HMRCVatObligations{
        public String status;
        public String periodKey;
    }
    
   public with sharing class parsedResponse{

       
       public string processingDate {get;set;}
       public string formBundleNumber;
       public string paymentIndicator ;
       public string chargeRefNumber;

}
         
    
}