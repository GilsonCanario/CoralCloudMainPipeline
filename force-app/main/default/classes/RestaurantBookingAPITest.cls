/**
 * Test class for RestaurantBookingAPI REST Resource.
 * Covers all HTTP methods (GET, POST, PATCH, DELETE) with positive, negative, and bulk scenarios.
 * Tests with 251+ records to validate bulkification across trigger batch boundaries.
 */
@isTest
private class RestaurantBookingAPITest {

    // ─── Test Setup ───────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        // Create 3 restaurants
        List<Restaurant__c> restaurants = TestDataFactory.createRestaurants(3, true);
        
        // Create 251 bookings (84 per restaurant, with 3 extra on first restaurant)
        TestDataFactory.createRestaurantBookings(new List<Restaurant__c>{ restaurants[0] }, 87, true);
        TestDataFactory.createRestaurantBookings(new List<Restaurant__c>{ restaurants[1] }, 82, true);
        TestDataFactory.createRestaurantBookings(new List<Restaurant__c>{ restaurants[2] }, 82, true);
    }

    // ─── POST Tests ───────────────────────────────────────────────────────

    /**
     * Test successful booking creation via POST.
     */
    @isTest
    static void shouldCreateBooking_WhenValidPayload() {
        // Given
        Restaurant__c restaurant = [SELECT Id FROM Restaurant__c LIMIT 1];
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'guestName' => 'John Doe',
            'guestEmail' => 'john.doe@example.com',
            'guestPhone' => '+15551234567',
            'restaurantId' => restaurant.Id,
            'bookingDateTime' => DateTime.now().addDays(2),
            'partySize' => 4,
            'specialRequests' => 'Window seat please',
            'dietaryRestrictions' => 'Vegetarian'
        });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doPost();
        Test.stopTest();

        // Then
        Assert.areEqual(true, response.success, 'Response should indicate success');
        Assert.areEqual(201, res.statusCode, 'Status code should be 201 Created');
        Assert.isNotNull(response.recordId, 'Record ID should be returned');
        Assert.isNotNull(response.data, 'Created booking data should be returned');
        
        List<RestaurantBooking__c> bookings = [
            SELECT Id, Guest_Name__c, Confirmation_Number__c, Status__c 
            FROM RestaurantBooking__c 
            WHERE Guest_Email__c = 'john.doe@example.com'
        ];
        Assert.areEqual(1, bookings.size(), 'Booking should be created in database');
        Assert.areEqual('John Doe', bookings[0].Guest_Name__c, 'Guest name should match');
        Assert.areEqual('Pending', bookings[0].Status__c, 'Status should default to Pending');
        Assert.isNotNull(bookings[0].Confirmation_Number__c, 'Confirmation number should be auto-generated');
    }

    /**
     * Test POST with missing required field.
     */
    @isTest
    static void shouldReturnError_WhenMissingGuestName() {
        // Given
        Restaurant__c restaurant = [SELECT Id FROM Restaurant__c LIMIT 1];
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'guestEmail' => 'test@example.com',
            'restaurantId' => restaurant.Id,
            'bookingDateTime' => DateTime.now().addDays(2),
            'partySize' => 4
        });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doPost();
        Test.stopTest();

        // Then
        Assert.areEqual(false, response.success, 'Response should indicate failure');
        Assert.areEqual(400, res.statusCode, 'Status code should be 400 Bad Request');
        Assert.isTrue(response.message.contains('guestName'), 'Error message should mention missing field');
    }

    /**
     * Test POST with empty request body.
     */
    @isTest
    static void shouldReturnError_WhenEmptyRequestBody() {
        // Given
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'POST';
        req.requestBody = null;
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doPost();
        Test.stopTest();

        // Then
        Assert.areEqual(false, response.success, 'Response should indicate failure');
        Assert.areEqual(400, res.statusCode, 'Status code should be 400 Bad Request');
        Assert.isTrue(response.message.contains('required'), 'Error message should indicate body is required');
    }

    /**
     * Test POST with invalid party size.
     */
    @isTest
    static void shouldReturnError_WhenInvalidPartySize() {
        // Given
        Restaurant__c restaurant = [SELECT Id FROM Restaurant__c LIMIT 1];
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'guestName' => 'Test Guest',
            'guestEmail' => 'test@example.com',
            'restaurantId' => restaurant.Id,
            'bookingDateTime' => DateTime.now().addDays(2),
            'partySize' => 0
        });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doPost();
        Test.stopTest();

        // Then
        Assert.areEqual(false, response.success, 'Response should indicate failure');
        Assert.areEqual(400, res.statusCode, 'Status code should be 400 Bad Request');
        Assert.isTrue(response.message.contains('Party size'), 'Error message should mention party size');
    }

    // ─── GET Tests ────────────────────────────────────────────────────────

    /**
     * Test retrieving a single booking by ID.
     */
    @isTest
    static void shouldRetrieveBooking_WhenValidId() {
        // Given
        RestaurantBooking__c booking = [SELECT Id FROM RestaurantBooking__c LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/' + booking.Id;
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doGet();
        Test.stopTest();

        // Then
        Assert.areEqual(true, response.success, 'Response should indicate success');
        Assert.areEqual(200, res.statusCode, 'Status code should be 200 OK');
        Assert.isNotNull(response.data, 'Booking data should be returned');
        Assert.areEqual(booking.Id, response.recordId, 'Returned record ID should match');
    }

    /**
     * Test retrieving booking list with pagination.
     */
    @isTest
    static void shouldRetrieveBookingList_WhenPaginationParameters() {
        // Given
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'GET';
        req.params.put('pageSize', '50');
        req.params.put('offset', '0');
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doGet();
        Test.stopTest();

        // Then
        Assert.areEqual(true, response.success, 'Response should indicate success');
        Assert.areEqual(200, res.statusCode, 'Status code should be 200 OK');
        Assert.isNotNull(response.records, 'Records list should be returned');
        Assert.areEqual(50, response.records.size(), 'Should return requested page size');
        Assert.areEqual(50, response.pageSize, 'Page size should match request');
        Assert.areEqual(0, response.offset, 'Offset should match request');
    }

    /**
     * Test retrieving booking list with status filter.
     */
    @isTest
    static void shouldFilterBookings_WhenStatusProvided() {
        // Given
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'GET';
        req.params.put('status', 'Pending');
        req.params.put('pageSize', '100');
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doGet();
        Test.stopTest();

        // Then
        Assert.areEqual(true, response.success, 'Response should indicate success');
        Assert.areEqual(200, res.statusCode, 'Status code should be 200 OK');
        Assert.isNotNull(response.records, 'Records list should be returned');
        
        // Verify all returned bookings have Pending status
        for (SObject record : response.records) {
            RestaurantBooking__c booking = (RestaurantBooking__c) record;
            Assert.areEqual('Pending', booking.Status__c, 'All bookings should have Pending status');
        }
    }

    /**
     * Test bulk retrieval - fetching all 251 bookings in pages.
     */
    @isTest
    static void shouldRetrieveAllBookings_WhenBulkRequest() {
        // Given - fetch in pages of 200
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'GET';
        req.params.put('pageSize', '200');
        req.params.put('offset', '0');
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doGet();
        Test.stopTest();

        // Then
        Assert.areEqual(true, response.success, 'Response should indicate success');
        Assert.areEqual(200, response.records.size(), 'Should return 200 records (max page size)');
        
        // Verify total count in database
        Integer totalCount = [SELECT COUNT() FROM RestaurantBooking__c];
        Assert.areEqual(251, totalCount, 'Should have 251 total bookings in database');
    }

    /**
     * Test GET with invalid booking ID.
     */
    @isTest
    static void shouldReturnNotFound_WhenInvalidId() {
        // Given
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/a0012345678901AAA';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doGet();
        Test.stopTest();

        // Then
        Assert.areEqual(false, response.success, 'Response should indicate failure');
        Assert.areEqual(404, res.statusCode, 'Status code should be 404 Not Found');
    }

    // ─── PATCH Tests ──────────────────────────────────────────────────────

    /**
     * Test updating a booking via PATCH.
     */
    @isTest
    static void shouldUpdateBooking_WhenValidPatch() {
        // Given
        RestaurantBooking__c booking = [SELECT Id FROM RestaurantBooking__c LIMIT 1];
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'partySize' => 6,
            'status' => 'Confirmed',
            'specialRequests' => 'Birthday celebration'
        });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/' + booking.Id;
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doPatch();
        Test.stopTest();

        // Then
        Assert.areEqual(true, response.success, 'Response should indicate success');
        Assert.areEqual(200, res.statusCode, 'Status code should be 200 OK');
        
        RestaurantBooking__c updated = [
            SELECT Party_Size__c, Status__c, Special_Requests__c 
            FROM RestaurantBooking__c 
            WHERE Id = :booking.Id
        ];
        Assert.areEqual(6, updated.Party_Size__c, 'Party size should be updated');
        Assert.areEqual('Confirmed', updated.Status__c, 'Status should be updated');
        Assert.areEqual('Birthday celebration', updated.Special_Requests__c, 'Special requests should be updated');
    }

    /**
     * Test PATCH with missing booking ID.
     */
    @isTest
    static void shouldReturnError_WhenPatchMissingId() {
        // Given
        String requestBody = JSON.serialize(new Map<String, Object>{ 'partySize' => 6 });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doPatch();
        Test.stopTest();

        // Then
        Assert.areEqual(false, response.success, 'Response should indicate failure');
        Assert.areEqual(400, res.statusCode, 'Status code should be 400 Bad Request');
    }

    // ─── DELETE Tests ─────────────────────────────────────────────────────

    /**
     * Test deleting a booking via DELETE.
     */
    @isTest
    static void shouldDeleteBooking_WhenValidId() {
        // Given
        RestaurantBooking__c booking = [SELECT Id FROM RestaurantBooking__c LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/' + booking.Id;
        req.httpMethod = 'DELETE';
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doDelete();
        Test.stopTest();

        // Then
        Assert.areEqual(true, response.success, 'Response should indicate success');
        Assert.areEqual(200, res.statusCode, 'Status code should be 200 OK');
        
        List<RestaurantBooking__c> deleted = [
            SELECT Id FROM RestaurantBooking__c WHERE Id = :booking.Id
        ];
        Assert.areEqual(0, deleted.size(), 'Booking should be deleted from database');
    }

    /**
     * Test DELETE with invalid booking ID.
     */
    @isTest
    static void shouldReturnNotFound_WhenDeleteInvalidId() {
        // Given
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/RestaurantBooking/v1/a0012345678901AAA';
        req.httpMethod = 'DELETE';
        
        RestContext.request = req;
        RestContext.response = res;

        // When
        Test.startTest();
        RestaurantBookingAPI.ApiResponse response = RestaurantBookingAPI.doDelete();
        Test.stopTest();

        // Then
        Assert.areEqual(false, response.success, 'Response should indicate failure');
        Assert.areEqual(404, res.statusCode, 'Status code should be 404 Not Found');
    }
}
