public with sharing class Sample {
    
    /**
     * Creates a new Account record.
     * 
     * @param accountName The name of the new Account.
     * @param industryType The industry of the new Account.
     * @return The Salesforce ID of the newly created Account.
     */
    public static Id createAccount(String accountName, String industryType) {
        // 1. Initialize the new sObject
        Account newAccount = new Account(
            Name = accountName,
            Industry = industryType
        );
        
        // 2. Perform the DML operation to save it to the database
        try {
            insert newAccount;
        } catch (DmlException e) {
            System.debug('An error occurred while inserting the Account: ' + e.getMessage());
            return null;
        }
        
        // 3. Return the generated ID
        return newAccount.Id;
    }
}