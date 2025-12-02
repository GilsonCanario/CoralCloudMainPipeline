/**
 * Data loader class to create sample Credit Rule records for demo purposes.
 * This class can be executed in Anonymous Apex to populate the Credit_Rule__c object
 * with the four sample rules for automated credit assignment.
 */
public class CreditRuleDataLoader {
    
    /**
     * Creates sample Credit Rule records for demo purposes.
     * This method is designed to be called from Anonymous Apex.
     */
    public static void loadSampleData() {
        // Check if rules already exist to avoid duplicates
        List<Credit_Rule__c> existingRules = [SELECT Id FROM Credit_Rule__c LIMIT 1];
        if (!existingRules.isEmpty()) {
            System.debug('Credit Rules already exist. Skipping data load.');
            return;
        }
        
        List<Credit_Rule__c> rulesToInsert = new List<Credit_Rule__c>();
        
        // Rule 1: New Booking Bonus
        Credit_Rule__c bookingRule = new Credit_Rule__c(
            Name = 'New Booking Bonus',
            Trigger_Object__c = 'Booking',
            Trigger_Event__c = 'Created',
            Credit_Amount__c = 5.00,
            Active__c = true,
            Description__c = 'Automatically awards $5 resort credit when a guest creates a new booking for any experience.'
        );
        rulesToInsert.add(bookingRule);
        
        // Rule 2: Review Reward
        Credit_Rule__c reviewRule = new Credit_Rule__c(
            Name = 'Review Reward',
            Trigger_Object__c = 'Guest Review',
            Trigger_Event__c = 'Created',
            Credit_Amount__c = 5.00,
            Active__c = true,
            Description__c = 'Automatically awards $5 resort credit when a guest submits a review for an experience.'
        );
        rulesToInsert.add(reviewRule);
        
        // Rule 3: Case Assignment Credit
        Credit_Rule__c caseCreatedRule = new Credit_Rule__c(
            Name = 'Case Assignment Credit',
            Trigger_Object__c = 'Case',
            Trigger_Event__c = 'Created',
            Credit_Amount__c = 2.00,
            Active__c = true,
            Description__c = 'Automatically awards $2 resort credit when a case is created and assigned to a guest contact.'
        );
        rulesToInsert.add(caseCreatedRule);
        
        // Rule 4: Case Resolution Bonus
        Credit_Rule__c caseClosedRule = new Credit_Rule__c(
            Name = 'Case Resolution Bonus',
            Trigger_Object__c = 'Case',
            Trigger_Event__c = 'Closed',
            Credit_Amount__c = 2.00,
            Active__c = true,
            Description__c = 'Automatically awards $2 additional resort credit when a case assigned to a guest is successfully closed.'
        );
        rulesToInsert.add(caseClosedRule);
        
        try {
            insert rulesToInsert;
            System.debug('Successfully created ' + rulesToInsert.size() + ' Credit Rule records:');
            for (Credit_Rule__c rule : rulesToInsert) {
                System.debug('- ' + rule.Name + ': $' + rule.Credit_Amount__c + ' for ' + rule.Trigger_Object__c + ' ' + rule.Trigger_Event__c);
            }
        } catch (DmlException e) {
            System.debug('Error creating Credit Rule records: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Deletes all existing Credit Rule records (useful for testing/cleanup).
     * Use with caution - this will remove all rules!
     */
    public static void deleteAllRules() {
        List<Credit_Rule__c> allRules = [SELECT Id FROM Credit_Rule__c];
        if (!allRules.isEmpty()) {
            delete allRules;
            System.debug('Deleted ' + allRules.size() + ' Credit Rule records.');
        } else {
            System.debug('No Credit Rule records to delete.');
        }
    }
}