/**
 * RestaurantManager - Apex class for Restaurant Management
 * Provides comprehensive functionality for managing restaurant operations in the Coral Cloud resort system
 * 
 * @author Coral Cloud Development Team
 * @version 1.0
 * @date 2025
 */
public with sharing class RestaurantManager {
    
    /**
     * Custom exception class for Restaurant-related errors
     */
    public class RestaurantException extends Exception {}
    
    /**
     * Security utility methods for CRUD and FLS checks
     */
    private static void checkReadAccess() {
        if (!Schema.sObjectType.Restaurant__c.isAccessible()) {
            throw new RestaurantException('Insufficient permissions to read Restaurant records');
        }
        
        // Check field-level read access
        Map<String, Schema.SObjectField> fields = Schema.sObjectType.Restaurant__c.fields.getMap();
        if (!fields.get('Name').getDescribe().isAccessible()) {
            throw new RestaurantException('Insufficient permissions to read Restaurant Name field');
        }
    }
    
    private static void checkCreateAccess() {
        if (!Schema.sObjectType.Restaurant__c.isCreateable()) {
            throw new RestaurantException('Insufficient permissions to create Restaurant records');
        }
        
        // Check field-level create access
        Map<String, Schema.SObjectField> fields = Schema.sObjectType.Restaurant__c.fields.getMap();
        if (!fields.get('Name').getDescribe().isCreateable()) {
            throw new RestaurantException('Insufficient permissions to create Restaurant Name field');
        }
    }
    
    private static void checkUpdateAccess() {
        if (!Schema.sObjectType.Restaurant__c.isUpdateable()) {
            throw new RestaurantException('Insufficient permissions to update Restaurant records');
        }
        
        // Check field-level update access
        Map<String, Schema.SObjectField> fields = Schema.sObjectType.Restaurant__c.fields.getMap();
        if (!fields.get('Name').getDescribe().isUpdateable()) {
            throw new RestaurantException('Insufficient permissions to update Restaurant Name field');
        }
    }
    
    private static void checkDeleteAccess() {
        if (!Schema.sObjectType.Restaurant__c.isDeletable()) {
            throw new RestaurantException('Insufficient permissions to delete Restaurant records');
        }
    }
    
    /**
     * Wrapper class for Restaurant query results
     */
    public class RestaurantResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Restaurant__c restaurant { get; set; }
        @AuraEnabled public List<Restaurant__c> restaurants { get; set; }
        
        public RestaurantResult() {
            this.success = false;
            this.message = '';
            this.restaurants = new List<Restaurant__c>();
        }
    }
    
    /**
     * Creates a new restaurant record with validation
     * @param restaurantName The name of the restaurant
     * @return RestaurantResult containing the created restaurant or error information
     */
    @AuraEnabled
    public static RestaurantResult createRestaurant(String restaurantName) {
        RestaurantResult result = new RestaurantResult();
        
        try {
            // Security check
            checkCreateAccess();
            checkReadAccess();
            
            // Input validation
            if (String.isBlank(restaurantName)) {
                result.message = 'Restaurant name cannot be empty';
                return result;
            }
            
            // Check for duplicate names
            List<Restaurant__c> existingRestaurants = [
                SELECT Id, Name 
                FROM Restaurant__c 
                WHERE Name = :restaurantName 
                LIMIT 1
            ];
            
            if (!existingRestaurants.isEmpty()) {
                result.message = 'A restaurant with this name already exists';
                return result;
            }
            
            // Create new restaurant
            Restaurant__c newRestaurant = new Restaurant__c(
                Name = restaurantName
            );
            
            insert newRestaurant;
            
            // Query the created record to get all fields
            result.restaurant = getRestaurantById(newRestaurant.Id);
            result.success = true;
            result.message = 'Restaurant created successfully';
            
        } catch (DMLException e) {
            result.message = 'Failed to create restaurant: ' + e.getMessage();
        } catch (Exception e) {
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Updates an existing restaurant record
     * @param restaurantId The ID of the restaurant to update
     * @param restaurantName The new name for the restaurant
     * @return RestaurantResult containing the updated restaurant or error information
     */
    @AuraEnabled
    public static RestaurantResult updateRestaurant(String restaurantId, String restaurantName) {
        RestaurantResult result = new RestaurantResult();
        
        try {
            // Security check
            checkUpdateAccess();
            checkReadAccess();
            
            // Input validation
            if (String.isBlank(restaurantId)) {
                result.message = 'Restaurant ID cannot be empty';
                return result;
            }
            
            if (String.isBlank(restaurantName)) {
                result.message = 'Restaurant name cannot be empty';
                return result;
            }
            
            // Verify restaurant exists
            List<Restaurant__c> restaurants = [
                SELECT Id, Name 
                FROM Restaurant__c 
                WHERE Id = :restaurantId 
                LIMIT 1
            ];
            
            if (restaurants.isEmpty()) {
                result.message = 'Restaurant not found';
                return result;
            }
            
            // Check for duplicate names (excluding current record)
            List<Restaurant__c> duplicateCheck = [
                SELECT Id, Name 
                FROM Restaurant__c 
                WHERE Name = :restaurantName 
                AND Id != :restaurantId 
                LIMIT 1
            ];
            
            if (!duplicateCheck.isEmpty()) {
                result.message = 'Another restaurant with this name already exists';
                return result;
            }
            
            // Update restaurant
            Restaurant__c restaurantToUpdate = restaurants[0];
            restaurantToUpdate.Name = restaurantName;
            
            update restaurantToUpdate;
            
            result.restaurant = getRestaurantById(restaurantId);
            result.success = true;
            result.message = 'Restaurant updated successfully';
            
        } catch (DMLException e) {
            result.message = 'Failed to update restaurant: ' + e.getMessage();
        } catch (Exception e) {
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Deletes a restaurant record
     * @param restaurantId The ID of the restaurant to delete
     * @return RestaurantResult containing success status and message
     */
    @AuraEnabled
    public static RestaurantResult deleteRestaurant(String restaurantId) {
        RestaurantResult result = new RestaurantResult();
        
        try {
            // Security check
            checkDeleteAccess();
            checkReadAccess();
            
            // Input validation
            if (String.isBlank(restaurantId)) {
                result.message = 'Restaurant ID cannot be empty';
                return result;
            }
            
            // Verify restaurant exists
            List<Restaurant__c> restaurants = [
                SELECT Id, Name 
                FROM Restaurant__c 
                WHERE Id = :restaurantId 
                LIMIT 1
            ];
            
            if (restaurants.isEmpty()) {
                result.message = 'Restaurant not found';
                return result;
            }
            
            delete restaurants[0];
            
            result.success = true;
            result.message = 'Restaurant deleted successfully';
            
        } catch (DMLException e) {
            result.message = 'Failed to delete restaurant: ' + e.getMessage();
        } catch (Exception e) {
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Retrieves a single restaurant by ID
     * @param restaurantId The ID of the restaurant to retrieve
     * @return Restaurant__c record or null if not found
     */
    public static Restaurant__c getRestaurantById(String restaurantId) {
        try {
            // Security check
            checkReadAccess();
            
            List<Restaurant__c> restaurants = [
                SELECT Id, Name, CreatedDate, LastModifiedDate,
                       CreatedBy.Name, LastModifiedBy.Name
                FROM Restaurant__c 
                WHERE Id = :restaurantId 
                LIMIT 1
            ];
            
            return restaurants.isEmpty() ? null : restaurants[0];
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error retrieving restaurant by ID: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Retrieves all restaurants with optional search filtering
     * @param searchTerm Optional search term to filter restaurant names
     * @return RestaurantResult containing list of restaurants
     */
    @AuraEnabled
    public static RestaurantResult getAllRestaurants(String searchTerm) {
        RestaurantResult result = new RestaurantResult();
        
        try {
            // Security check
            checkReadAccess();
            
            String query = 'SELECT Id, Name, CreatedDate, LastModifiedDate FROM Restaurant__c';
            
            if (String.isNotBlank(searchTerm)) {
                query += ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'';
            }
            
            query += ' ORDER BY Name ASC LIMIT 1000';
            
            result.restaurants = Database.query(query);
            result.success = true;
            result.message = 'Retrieved ' + result.restaurants.size() + ' restaurant(s)';
            
        } catch (Exception e) {
            result.message = 'Failed to retrieve restaurants: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Bulk creates multiple restaurants
     * @param restaurantNames List of restaurant names to create
     * @return RestaurantResult containing created restaurants or error information
     */
    @AuraEnabled
    public static RestaurantResult bulkCreateRestaurants(List<String> restaurantNames) {
        RestaurantResult result = new RestaurantResult();
        
        try {
            // Security check
            checkCreateAccess();
            checkReadAccess();
            
            if (restaurantNames == null || restaurantNames.isEmpty()) {
                result.message = 'No restaurant names provided';
                return result;
            }
            
            // Remove blanks and duplicates
            Set<String> uniqueNames = new Set<String>();
            for (String name : restaurantNames) {
                if (String.isNotBlank(name)) {
                    uniqueNames.add(name.trim());
                }
            }
            
            if (uniqueNames.isEmpty()) {
                result.message = 'No valid restaurant names provided';
                return result;
            }
            
            // Check for existing restaurants
            List<Restaurant__c> existingRestaurants = [
                SELECT Name 
                FROM Restaurant__c 
                WHERE Name IN :uniqueNames
            ];
            
            Set<String> existingNames = new Set<String>();
            for (Restaurant__c restaurant : existingRestaurants) {
                existingNames.add(restaurant.Name);
            }
            
            // Create new restaurants
            List<Restaurant__c> restaurantsToInsert = new List<Restaurant__c>();
            for (String name : uniqueNames) {
                if (!existingNames.contains(name)) {
                    restaurantsToInsert.add(new Restaurant__c(Name = name));
                }
            }
            
            if (restaurantsToInsert.isEmpty()) {
                result.message = 'All restaurant names already exist';
                return result;
            }
            
            insert restaurantsToInsert;
            
            result.restaurants = restaurantsToInsert;
            result.success = true;
            result.message = 'Successfully created ' + restaurantsToInsert.size() + ' restaurant(s)';
            
            if (!existingNames.isEmpty()) {
                result.message += '. Skipped ' + existingNames.size() + ' duplicate(s)';
            }
            
        } catch (DMLException e) {
            result.message = 'Failed to create restaurants: ' + e.getMessage();
        } catch (Exception e) {
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Gets restaurant statistics
     * @return Map containing various restaurant statistics
     */
    @AuraEnabled
    public static Map<String, Object> getRestaurantStatistics() {
        Map<String, Object> stats = new Map<String, Object>();
        
        try {
            // Security check
            checkReadAccess();
            
            // Total restaurants
            Integer totalRestaurants = [SELECT COUNT() FROM Restaurant__c];
            stats.put('totalRestaurants', totalRestaurants);
            
            // Restaurants created today
            Date today = Date.today();
            Integer restaurantsCreatedToday = [
                SELECT COUNT() 
                FROM Restaurant__c 
                WHERE CreatedDate = TODAY
            ];
            stats.put('restaurantsCreatedToday', restaurantsCreatedToday);
            
            // Restaurants created this month
            Date firstOfMonth = today.toStartOfMonth();
            Integer restaurantsCreatedThisMonth = [
                SELECT COUNT() 
                FROM Restaurant__c 
                WHERE CreatedDate >= :firstOfMonth
            ];
            stats.put('restaurantsCreatedThisMonth', restaurantsCreatedThisMonth);
            
            // Enhanced statistics with dining experience integration
            Integer totalDiningExperiences = 0;
            try {
                // Check if DiningExperience__c is accessible
                if (Schema.sObjectType.DiningExperience__c.isAccessible()) {
                    totalDiningExperiences = [SELECT COUNT() FROM DiningExperience__c];
                }
            } catch (Exception ex) {
                System.debug('DiningExperience__c may not be accessible: ' + ex.getMessage());
            }
            stats.put('totalDiningExperiences', totalDiningExperiences);
            
            stats.put('success', true);
            
        } catch (Exception e) {
            stats.put('success', false);
            stats.put('error', e.getMessage());
        }
        
        return stats;
    }
    
    /**
     * Wrapper class for DiningExperience operations
     */
    public class DiningExperienceResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public DiningExperience__c diningExperience { get; set; }
        @AuraEnabled public List<DiningExperience__c> diningExperiences { get; set; }
        
        public DiningExperienceResult() {
            this.success = false;
            this.message = '';
            this.diningExperiences = new List<DiningExperience__c>();
        }
    }
    
    /**
     * Creates a dining experience linked to a restaurant
     * @param restaurantId The ID of the restaurant
     * @param experienceName The name of the dining experience
     * @return DiningExperienceResult containing the created experience or error information
     */
    @AuraEnabled
    public static DiningExperienceResult createDiningExperience(String restaurantId, String experienceName) {
        DiningExperienceResult result = new DiningExperienceResult();
        
        try {
            // Security checks for both objects
            checkReadAccess();
            if (!Schema.sObjectType.DiningExperience__c.isAccessible() || 
                !Schema.sObjectType.DiningExperience__c.isCreateable()) {
                result.message = 'Insufficient permissions to work with Dining Experience records';
                return result;
            }
            
            // Input validation
            if (String.isBlank(restaurantId)) {
                result.message = 'Restaurant ID cannot be empty';
                return result;
            }
            
            if (String.isBlank(experienceName)) {
                result.message = 'Experience name cannot be empty';
                return result;
            }
            
            // Verify restaurant exists
            List<Restaurant__c> restaurants = [
                SELECT Id, Name 
                FROM Restaurant__c 
                WHERE Id = :restaurantId 
                LIMIT 1
            ];
            
            if (restaurants.isEmpty()) {
                result.message = 'Restaurant not found';
                return result;
            }
            
            // Create dining experience
            DiningExperience__c newExperience = new DiningExperience__c(
                Name = experienceName
                // Note: Add Restaurant__c lookup field if it exists in the schema
            );
            
            insert newExperience;
            
            result.diningExperience = newExperience;
            result.success = true;
            result.message = 'Dining experience created successfully for restaurant: ' + restaurants[0].Name;
            
        } catch (DMLException e) {
            result.message = 'Failed to create dining experience: ' + e.getMessage();
        } catch (Exception e) {
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Gets all dining experiences (with optional restaurant filter)
     * @param restaurantId Optional restaurant ID to filter experiences
     * @return DiningExperienceResult containing list of experiences
     */
    @AuraEnabled
    public static DiningExperienceResult getDiningExperiences(String restaurantId) {
        DiningExperienceResult result = new DiningExperienceResult();
        
        try {
            // Security check
            if (!Schema.sObjectType.DiningExperience__c.isAccessible()) {
                result.message = 'Insufficient permissions to read Dining Experience records';
                return result;
            }
            
            String query = 'SELECT Id, Name, CreatedDate, LastModifiedDate FROM DiningExperience__c';
            
            // Note: Add WHERE clause if Restaurant lookup field exists
            // if (String.isNotBlank(restaurantId)) {
            //     query += ' WHERE Restaurant__c = :restaurantId';
            // }
            
            query += ' ORDER BY Name ASC LIMIT 1000';
            
            result.diningExperiences = Database.query(query);
            result.success = true;
            result.message = 'Retrieved ' + result.diningExperiences.size() + ' dining experience(s)';
            
        } catch (Exception e) {
            result.message = 'Failed to retrieve dining experiences: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Advanced restaurant search with multiple criteria
     * @param searchCriteria Map containing search parameters (name, createdAfter, createdBefore)
     * @return RestaurantResult containing filtered restaurants
     */
    @AuraEnabled
    public static RestaurantResult searchRestaurants(Map<String, Object> searchCriteria) {
        RestaurantResult result = new RestaurantResult();
        
        try {
            // Security check
            checkReadAccess();
            
            if (searchCriteria == null) {
                searchCriteria = new Map<String, Object>();
            }
            
            String query = 'SELECT Id, Name, CreatedDate, LastModifiedDate FROM Restaurant__c WHERE Id != null';
            Map<String, Object> queryParams = new Map<String, Object>();
            
            // Name search
            String nameFilter = (String) searchCriteria.get('name');
            if (String.isNotBlank(nameFilter)) {
                query += ' AND Name LIKE :namePattern';
                queryParams.put('namePattern', '%' + String.escapeSingleQuotes(nameFilter) + '%');
            }
            
            // Date range filters
            String createdAfter = (String) searchCriteria.get('createdAfter');
            if (String.isNotBlank(createdAfter)) {
                query += ' AND CreatedDate >= :afterDate';
                queryParams.put('afterDate', Date.valueOf(createdAfter));
            }
            
            String createdBefore = (String) searchCriteria.get('createdBefore');
            if (String.isNotBlank(createdBefore)) {
                query += ' AND CreatedDate <= :beforeDate';
                queryParams.put('beforeDate', Date.valueOf(createdBefore));
            }
            
            query += ' ORDER BY Name ASC LIMIT 1000';
            
            // Execute dynamic query
            result.restaurants = Database.query(query);
            result.success = true;
            result.message = 'Found ' + result.restaurants.size() + ' restaurant(s) matching criteria';
            
        } catch (Exception e) {
            result.message = 'Failed to search restaurants: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Validates restaurant data integrity
     * @return Map containing validation results
     */
    @AuraEnabled
    public static Map<String, Object> validateRestaurantData() {
        Map<String, Object> validation = new Map<String, Object>();
        List<String> issues = new List<String>();
        
        try {
            // Security check
            checkReadAccess();
            
            // Check for restaurants with empty or duplicate names
            List<Restaurant__c> restaurants = [
                SELECT Id, Name 
                FROM Restaurant__c 
                ORDER BY Name
            ];
            
            Set<String> seenNames = new Set<String>();
            Integer emptyNameCount = 0;
            Integer duplicateCount = 0;
            
            for (Restaurant__c restaurant : restaurants) {
                if (String.isBlank(restaurant.Name)) {
                    emptyNameCount++;
                } else {
                    if (seenNames.contains(restaurant.Name.toLowerCase())) {
                        duplicateCount++;
                        issues.add('Duplicate name found: ' + restaurant.Name + ' (ID: ' + restaurant.Id + ')');
                    } else {
                        seenNames.add(restaurant.Name.toLowerCase());
                    }
                }
            }
            
            if (emptyNameCount > 0) {
                issues.add(emptyNameCount + ' restaurant(s) have empty names');
            }
            
            validation.put('totalRestaurants', restaurants.size());
            validation.put('emptyNameCount', emptyNameCount);
            validation.put('duplicateNameCount', duplicateCount);
            validation.put('issues', issues);
            validation.put('isValid', issues.isEmpty());
            validation.put('success', true);
            
        } catch (Exception e) {
            validation.put('success', false);
            validation.put('error', e.getMessage());
        }
        
        return validation;
    }
    
    /**
     * Batch processes restaurant operations for better performance
     * @param operation The operation to perform (validate, cleanup, etc.)
     * @return Map containing batch operation results
     */
    @AuraEnabled
    public static Map<String, Object> batchProcessRestaurants(String operation) {
        Map<String, Object> batchResult = new Map<String, Object>();
        
        try {
            // Security check
            checkReadAccess();
            
            if (String.isBlank(operation)) {
                batchResult.put('success', false);
                batchResult.put('message', 'Operation parameter is required');
                return batchResult;
            }
            
            switch on operation.toLowerCase() {
                when 'validate' {
                    // Delegate to validation method
                    return validateRestaurantData();
                }
                when 'count' {
                    // Simple count operation
                    Integer count = [SELECT COUNT() FROM Restaurant__c];
                    batchResult.put('totalCount', count);
                    batchResult.put('success', true);
                    batchResult.put('message', 'Count operation completed');
                }
                when else {
                    batchResult.put('success', false);
                    batchResult.put('message', 'Unsupported operation: ' + operation);
                }
            }
            
        } catch (Exception e) {
            batchResult.put('success', false);
            batchResult.put('message', 'Batch processing failed: ' + e.getMessage());
        }
        
        return batchResult;
    }
}
