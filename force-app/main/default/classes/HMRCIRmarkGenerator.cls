public class HMRCIRmarkGenerator {
    
    /**
     * Generate IRmark for HMRC submission following official specification
     * @param xmlBody Complete XML document as string
     * @return Map containing 'base64' and 'base32' IRmark values
     */
    public static Map<String, String> generateIRmark(String xmlBody) {
        try {
            // Instead of using DOM parsing which adds unwanted formatting,
            // work directly with the string
            
            // Step 1: Extract the namespace from GovTalkMessage
            String govTalkNamespace = extractGovTalkNamespace(xmlBody);
            //System.debug('GovTalkMessage namespace: ' + govTalkNamespace);
            
            // Step 2: Extract Body content
            String bodyContent = extractBodyContent(xmlBody);
            //System.debug('Body content extracted');
            
            // Step 3: Add namespace to Body element
            String bodyWithNamespace = addNamespaceToBody(bodyContent, govTalkNamespace);
            //System.debug('Body with namespace added');
            
            // Step 4: Remove IRmark element
            String bodyWithoutIRmark = removeIRmarkElement(bodyWithNamespace);
            //System.debug('IRmark element removed');
            
            // Step 5: Canonicalize
            String canonicalXml = canonicalizeXml(bodyWithoutIRmark);
            
            /*System.debug('========================================');
            System.debug('Canonical XML:');
            System.debug(canonicalXml);
            System.debug('========================================');
            System.debug('Canonical XML length: ' + canonicalXml.length());*/
            
            // Step 6: Generate SHA-1 hash
            Blob xmlBlob = Blob.valueOf(canonicalXml);
            Blob hash = Crypto.generateDigest('SHA1', xmlBlob);
            
            //System.debug('SHA-1 hash (hex): ' + EncodingUtil.convertToHex(hash));
            
            // Step 7: Encode to base-64
            String base64IRmark = EncodingUtil.base64Encode(hash);
            
            // Step 8: Encode to base-32
            String base32IRmark = encodeBase32(hash);
            
            Map<String, String> result = new Map<String, String>();
            result.put('base64', base64IRmark);
            result.put('base32', base32IRmark.toUpperCase());
            result.put('canonical', canonicalXml);
            
            //System.debug('Generated IRmark (base-64): ' + base64IRmark);
            //System.debug('Generated IRmark (base-32): ' + base32IRmark.toUpperCase());
            
            return result;
            
        } catch (Exception e) {
            throw new IRmarkException('IRmark generation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
    
    /**
     * Extract GovTalkMessage namespace using regex
     */
    private static String extractGovTalkNamespace(String xmlBody) {
        Pattern p = Pattern.compile('<GovTalkMessage[^>]*xmlns="([^"]*)"');
        Matcher m = p.matcher(xmlBody);
        
        if (m.find()) {
            return m.group(1);
        }
        
        return null;
    }
    
    /**
     * Extract everything inside <Body>...</Body> tags
     */
    private static String extractBodyContent(String xmlBody) {
        // Find Body start and end positions
        Integer bodyStart = xmlBody.indexOf('<Body>');
        Integer bodyEnd = xmlBody.indexOf('</Body>');
        
        if (bodyStart == -1 || bodyEnd == -1) {
            throw new IRmarkException('Body element not found');
        }
        
        // Extract Body including tags
        return xmlBody.substring(bodyStart, bodyEnd + 7); // 7 = length of '</Body>'
    }
    
    /**
     * Add namespace to Body element if not already present
     */
    private static String addNamespaceToBody(String bodyXml, String namespace) {
        if (namespace != null) {
            return bodyXml.replace('<Body>', '<Body xmlns="' + namespace + '">');
        }
        return bodyXml;
    }
    
    /**
     * Remove IRmark element from XML
     * Preserves whitespace around the IRmark tags per HMRC spec
     */
    private static String removeIRmarkElement(String xmlBody) {
        // Remove IRmark element including its content
        // Use regex to handle variations in attributes and content
        String result = xmlBody.replaceAll('<IRmark[^>]*>.*?</IRmark>', '');
        
        return result;
    }
    
    /**
     * Canonicalize XML according to W3C C14N specification
     * This implements the key canonicalization rules for HMRC
     */
    private static String canonicalizeXml(String xml) {
        String canonical = xml;
        
        // 1. Remove XML declaration
        canonical = canonical.replaceAll('<\\?xml[^>]*\\?>', '');
        
        // 2. Normalize line endings to LF (do NOT remove all whitespace)
        canonical = canonical.replaceAll('\\r\\n', '\n');
        canonical = canonical.replaceAll('\\r', '\n');
        
        // 3. Remove comments
        canonical = canonical.replaceAll('<!--.*?-->', '');
        
        // 4. Trim leading and trailing whitespace only
        canonical = canonical.trim();
        
        // DO NOT normalize whitespace between tags for HMRC
        // The XML should be kept as-is per HMRC spec section 2.1
        
        return canonical;
    }
    
    /**
     * Encode binary data to base-32 (RFC 4648)
     * Uses alphabet: A-Z and 2-7 (easily human readable)
     */
    private static String encodeBase32(Blob data) {
        String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        List<Integer> bytes = new List<Integer>();
        
        // Convert blob to byte array
        String hexString = EncodingUtil.convertToHex(data);
        for (Integer i = 0; i < hexString.length(); i += 2) {
            String byteHex = hexString.substring(i, i + 2);
            bytes.add(hexToInt(byteHex));
        }
        
        Integer bits = 0;
        Integer value = 0;
        String output = '';
        
        for (Integer b : bytes) {
            value = (value << 8) | b;
            bits += 8;
            
            while (bits >= 5) {
                Integer index = (value >> (bits - 5)) & 31;
                output += alphabet.substring(index, index + 1);
                bits -= 5;
            }
        }
        
        if (bits > 0) {
            Integer index = (value << (5 - bits)) & 31;
            output += alphabet.substring(index, index + 1);
        }
        
        // Pad to 32 characters
        while (Math.mod(output.length(), 8) != 0) {
            output += '=';
        }
        
        return output;
    }
    
    /**
     * Convert hexadecimal string to integer
     */
    private static Integer hexToInt(String hex) {
        Map<String, Integer> hexMap = new Map<String, Integer>{
            '0' => 0, '1' => 1, '2' => 2, '3' => 3,
            '4' => 4, '5' => 5, '6' => 6, '7' => 7,
            '8' => 8, '9' => 9, 'a' => 10, 'b' => 11,
            'c' => 12, 'd' => 13, 'e' => 14, 'f' => 15
        };
        
        hex = hex.toLowerCase();
        Integer result = 0;
        
        for (Integer i = 0; i < hex.length(); i++) {
            String digit = hex.substring(i, i + 1);
            result = result * 16 + hexMap.get(digit);
        }
        
        return result;
    }
    
    /**
     * Insert IRmark into XML document
     */
    public static String insertIRmarkIntoXml(String xmlBody, String base64IRmark) {
        // Find and replace existing IRmark value
        String result = xmlBody.replaceAll(
            '(<IRmark[^>]*Type="generic"[^>]*>)[^<]*(</IRmark>)',
            '$1' + base64IRmark + '$2'
        );
        
        if (result.equals(xmlBody)) {
            throw new IRmarkException('IRmark element with Type="generic" not found');
        }
        
        return result;
    }
    
    /**
     * Complete processing: generate and insert IRmark
     */
    public static String processCharitySubmission(String xmlBody) {
        Map<String, String> irmark = generateIRmark(xmlBody);
        
        /*System.debug('===========================================');
        System.debug('IRmark Generated');
        System.debug('===========================================');
        System.debug('Base-64 (for submission): ' + irmark.get('base64'));
        System.debug('Base-32 (for display): ' + irmark.get('base32'));*/
        
        String completeXml = insertIRmarkIntoXml(xmlBody, irmark.get('base64'));
        
        return completeXml;
    }
    
    // Custom exception class
    public class IRmarkException extends Exception {}
}