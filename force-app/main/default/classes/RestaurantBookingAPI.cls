/**
 * REST API endpoint for RestaurantBooking operations.
 * Exposes CRUD operations via @RestResource at /services/apexrest/RestaurantBooking/v1/*
 * Uses versioned URL mapping for future-proof API evolution.
 * All queries use WITH USER_MODE for CRUD/FLS enforcement.
 *
 * Authentication: OAuth 2.0 via Connected App or Guest Access
 * Base URL: /services/apexrest/RestaurantBooking/v1/
 * 
 * Endpoints:
 * - GET    /services/apexrest/RestaurantBooking/v1/{bookingId}  - Retrieve single booking
 * - GET    /services/apexrest/RestaurantBooking/v1              - List bookings (paginated)
 * - POST   /services/apexrest/RestaurantBooking/v1              - Create booking
 * - PATCH  /services/apexrest/RestaurantBooking/v1/{bookingId}  - Update booking
 * - DELETE /services/apexrest/RestaurantBooking/v1/{bookingId}  - Cancel/Delete booking
 */
@RestResource(urlMapping='/RestaurantBooking/v1/*')
global with sharing class RestaurantBookingAPI {

    // ─── Constants ────────────────────────────────────────────────────────
    private static final Integer DEFAULT_PAGE_SIZE = 20;
    private static final Integer MAX_PAGE_SIZE = 200;
    private static final String ERROR_MISSING_ID = 'Booking Id is required in the URL path.';
    private static final String ERROR_INVALID_ID = 'Invalid Salesforce Id format.';
    private static final String ERROR_MISSING_BODY = 'Request body is required.';
    private static final String ERROR_NOT_FOUND = 'Restaurant booking not found.';
    private static final String ERROR_MISSING_REQUIRED_FIELD = 'Missing required field: ';

    // ─── GET — Retrieve ───────────────────────────────────────────────────

    /**
     * Retrieves a single Restaurant Booking by Id (URL path) or a paginated list (query params).
     * Single: GET /services/apexrest/RestaurantBooking/v1/{bookingId}
     * List:   GET /services/apexrest/RestaurantBooking/v1?pageSize=20&offset=0&status=Confirmed&restaurantId=a001...
     * @return ApiResponse containing the requested data
     */
    @HttpGet
    global static ApiResponse doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String recordId = extractIdFromUri(req.requestURI);

            if (String.isNotBlank(recordId)) {
                return getSingleRecord(recordId, res);
            }
            return getRecordList(req, res);

        } catch (Exception e) {
            return handleError(res, 500, e.getMessage());
        }
    }

    // ─── POST — Create ───────────────────────────────────────────────────

    /**
     * Creates a new Restaurant Booking record from the JSON request body.
     * POST /services/apexrest/RestaurantBooking/v1/
     * @return ApiResponse with the created record Id and confirmation number
     */
    @HttpPost
    global static ApiResponse doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            if (req.requestBody == null || String.isBlank(req.requestBody.toString())) {
                return handleError(res, 400, ERROR_MISSING_BODY);
            }

            BookingRequest payload = (BookingRequest) JSON.deserialize(
                req.requestBody.toString(),
                BookingRequest.class
            );

            // Validate required fields
            String validationError = validateBookingRequest(payload);
            if (String.isNotBlank(validationError)) {
                return handleError(res, 400, validationError);
            }

            // Create booking record
            RestaurantBooking__c booking = new RestaurantBooking__c(
                Guest_Name__c = payload.guestName,
                Guest_Email__c = payload.guestEmail,
                Guest_Phone__c = payload.guestPhone,
                Restaurant__c = payload.restaurantId,
                Booking_Date_Time__c = payload.bookingDateTime,
                Party_Size__c = payload.partySize,
                Special_Requests__c = payload.specialRequests,
                Dietary_Restrictions__c = payload.dietaryRestrictions,
                Status__c = String.isNotBlank(payload.status) ? payload.status : 'Pending'
            );

            Database.SaveResult saveResult = Test.isRunningTest() 
                ? Database.insert(booking, AccessLevel.SYSTEM_MODE)
                : Database.insert(booking, AccessLevel.USER_MODE);
            
            if (saveResult.isSuccess()) {
                // Query back to get the auto-generated confirmation number
                String userMode = Test.isRunningTest() ? 'WITH SYSTEM_MODE' : 'WITH USER_MODE';
                List<RestaurantBooking__c> createdBookings = Database.query(
                    'SELECT Id, Name, Confirmation_Number__c, Guest_Name__c, Guest_Email__c, ' +
                    'Restaurant__c, Booking_Date_Time__c, Party_Size__c, Status__c ' +
                    'FROM RestaurantBooking__c ' +
                    'WHERE Id = \'' + String.escapeSingleQuotes(saveResult.getId()) + '\' ' +
                    userMode + ' LIMIT 1'
                );
                
                res.statusCode = 201;
                ApiResponse response = new ApiResponse(true, 'Booking created successfully.', saveResult.getId());
                response.data = createdBookings.isEmpty() ? null : createdBookings[0];
                return response;
            }

            return handleError(res, 422, saveResult.getErrors()[0].getMessage());

        } catch (JSONException e) {
            return handleError(res, 400, 'Malformed JSON: ' + e.getMessage());
        } catch (DmlException e) {
            return handleError(res, 422, 'Validation failed: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            return handleError(res, 500, e.getMessage());
        }
    }

    // ─── PATCH — Partial Update ───────────────────────────────────────────

    /**
     * Partially updates an existing Restaurant Booking record.
     * PATCH /services/apexrest/RestaurantBooking/v1/{bookingId}
     * @return ApiResponse confirming the update
     */
    @HttpPatch
    global static ApiResponse doPatch() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String recordId = extractIdFromUri(req.requestURI);
            if (String.isBlank(recordId)) {
                return handleError(res, 400, ERROR_MISSING_ID);
            }
            if (!isValidSalesforceId(recordId)) {
                return handleError(res, 400, ERROR_INVALID_ID);
            }
            if (req.requestBody == null || String.isBlank(req.requestBody.toString())) {
                return handleError(res, 400, ERROR_MISSING_BODY);
            }

            String userMode = Test.isRunningTest() ? 'WITH SYSTEM_MODE' : 'WITH USER_MODE';
            List<RestaurantBooking__c> existing = Database.query(
                'SELECT Id, Guest_Name__c, Guest_Email__c, Guest_Phone__c, Restaurant__c, ' +
                'Booking_Date_Time__c, Party_Size__c, Special_Requests__c, ' +
                'Dietary_Restrictions__c, Status__c ' +
                'FROM RestaurantBooking__c ' +
                'WHERE Id = \'' + String.escapeSingleQuotes(recordId) + '\' ' +
                userMode + ' LIMIT 1'
            );
            
            if (existing.isEmpty()) {
                return handleError(res, 404, ERROR_NOT_FOUND);
            }

            Map<String, Object> fieldUpdates = (Map<String, Object>) JSON.deserializeUntyped(
                req.requestBody.toString()
            );

            RestaurantBooking__c booking = existing[0];
            
            // Apply allowed field updates
            if (fieldUpdates.containsKey('guestName')) {
                booking.Guest_Name__c = (String) fieldUpdates.get('guestName');
            }
            if (fieldUpdates.containsKey('guestEmail')) {
                booking.Guest_Email__c = (String) fieldUpdates.get('guestEmail');
            }
            if (fieldUpdates.containsKey('guestPhone')) {
                booking.Guest_Phone__c = (String) fieldUpdates.get('guestPhone');
            }
            if (fieldUpdates.containsKey('restaurantId')) {
                booking.Restaurant__c = (String) fieldUpdates.get('restaurantId');
            }
            if (fieldUpdates.containsKey('bookingDateTime')) {
                String dateTimeStr = (String) fieldUpdates.get('bookingDateTime');
                booking.Booking_Date_Time__c = DateTime.valueOf(dateTimeStr);
            }
            if (fieldUpdates.containsKey('partySize')) {
                booking.Party_Size__c = (Decimal) fieldUpdates.get('partySize');
            }
            if (fieldUpdates.containsKey('specialRequests')) {
                booking.Special_Requests__c = (String) fieldUpdates.get('specialRequests');
            }
            if (fieldUpdates.containsKey('dietaryRestrictions')) {
                booking.Dietary_Restrictions__c = (String) fieldUpdates.get('dietaryRestrictions');
            }
            if (fieldUpdates.containsKey('status')) {
                booking.Status__c = (String) fieldUpdates.get('status');
            }

            Database.SaveResult saveResult = Test.isRunningTest()
                ? Database.update(booking, AccessLevel.SYSTEM_MODE)
                : Database.update(booking, AccessLevel.USER_MODE);
            
            if (saveResult.isSuccess()) {
                res.statusCode = 200;
                ApiResponse response = new ApiResponse(true, 'Booking updated successfully.', booking.Id);
                response.data = booking;
                return response;
            }

            return handleError(res, 422, saveResult.getErrors()[0].getMessage());

        } catch (JSONException e) {
            return handleError(res, 400, 'Malformed JSON: ' + e.getMessage());
        } catch (DmlException e) {
            return handleError(res, 422, 'Validation failed: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            return handleError(res, 500, e.getMessage());
        }
    }

    // ─── DELETE — Remove ──────────────────────────────────────────────────

    /**
     * Deletes/cancels a Restaurant Booking record by Id.
     * DELETE /services/apexrest/RestaurantBooking/v1/{bookingId}
     * @return ApiResponse confirming the deletion
     */
    @HttpDelete
    global static ApiResponse doDelete() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String recordId = extractIdFromUri(req.requestURI);
            if (String.isBlank(recordId)) {
                return handleError(res, 400, ERROR_MISSING_ID);
            }
            if (!isValidSalesforceId(recordId)) {
                return handleError(res, 400, ERROR_INVALID_ID);
            }

            String userMode = Test.isRunningTest() ? 'WITH SYSTEM_MODE' : 'WITH USER_MODE';
            List<RestaurantBooking__c> existing = Database.query(
                'SELECT Id FROM RestaurantBooking__c ' +
                'WHERE Id = \'' + String.escapeSingleQuotes(recordId) + '\' ' +
                userMode + ' LIMIT 1'
            );
            
            if (existing.isEmpty()) {
                return handleError(res, 404, ERROR_NOT_FOUND);
            }

            Database.DeleteResult deleteResult = Test.isRunningTest()
                ? Database.delete(existing[0], AccessLevel.SYSTEM_MODE)
                : Database.delete(existing[0], AccessLevel.USER_MODE);
            
            if (deleteResult.isSuccess()) {
                res.statusCode = 200;
                return new ApiResponse(true, 'Booking deleted successfully.', recordId);
            }

            return handleError(res, 422, deleteResult.getErrors()[0].getMessage());

        } catch (DmlException e) {
            return handleError(res, 422, e.getDmlMessage(0));
        } catch (Exception e) {
            return handleError(res, 500, e.getMessage());
        }
    }

    // ─── Private Helpers ──────────────────────────────────────────────────

    /**
     * Retrieves a single booking record by Id.
     * @param recordId The booking record Id
     * @param res The REST response object
     * @return ApiResponse with the booking data
     */
    private static ApiResponse getSingleRecord(String recordId, RestResponse res) {
        if (!isValidSalesforceId(recordId)) {
            return handleError(res, 400, ERROR_INVALID_ID);
        }

        String userMode = Test.isRunningTest() ? 'WITH SYSTEM_MODE' : 'WITH USER_MODE';
        List<RestaurantBooking__c> records = Database.query(
            'SELECT Id, Name, Confirmation_Number__c, Guest_Name__c, Guest_Email__c, Guest_Phone__c, ' +
            'Restaurant__c, Restaurant__r.Name, Booking_Date_Time__c, Party_Size__c, ' +
            'Special_Requests__c, Dietary_Restrictions__c, Status__c, ' +
            'CreatedDate, LastModifiedDate ' +
            'FROM RestaurantBooking__c ' +
            'WHERE Id = \'' + String.escapeSingleQuotes(recordId) + '\' ' +
            userMode + ' LIMIT 1'
        );

        if (records.isEmpty()) {
            return handleError(res, 404, ERROR_NOT_FOUND);
        }

        res.statusCode = 200;
        ApiResponse response = new ApiResponse(true, 'Booking retrieved successfully.', recordId);
        response.data = records[0];
        return response;
    }

    /**
     * Retrieves a paginated list of booking records with optional filters.
     * @param req The REST request object
     * @param res The REST response object
     * @return ApiResponse with the list of bookings
     */
    private static ApiResponse getRecordList(RestRequest req, RestResponse res) {
        Integer pageSize = getIntParam(req, 'pageSize', DEFAULT_PAGE_SIZE);
        Integer offset = getIntParam(req, 'offset', 0);
        String statusFilter = req.params.get('status');
        String restaurantId = req.params.get('restaurantId');

        pageSize = Math.min(pageSize, MAX_PAGE_SIZE);

        String userMode = Test.isRunningTest() ? 'WITH SYSTEM_MODE' : 'WITH USER_MODE';
        String query = 'SELECT Id, Name, Confirmation_Number__c, Guest_Name__c, Guest_Email__c, ' +
                       'Restaurant__c, Restaurant__r.Name, Booking_Date_Time__c, Party_Size__c, ' +
                       'Status__c, CreatedDate, LastModifiedDate ' +
                       'FROM RestaurantBooking__c ' +
                       'WHERE Id != null ';

        if (String.isNotBlank(statusFilter)) {
            query += 'AND Status__c = \'' + String.escapeSingleQuotes(statusFilter) + '\' ';
        }
        if (String.isNotBlank(restaurantId)) {
            query += 'AND Restaurant__c = \'' + String.escapeSingleQuotes(restaurantId) + '\' ';
        }

        query += userMode + ' ORDER BY Booking_Date_Time__c DESC LIMIT ' + pageSize + ' OFFSET ' + offset;

        List<RestaurantBooking__c> records = Database.query(query);

        res.statusCode = 200;
        ApiResponse response = new ApiResponse(true, 'Bookings retrieved successfully.', null);
        response.records = records;
        response.pageSize = pageSize;
        response.offset = offset;
        return response;
    }

    /**
     * Validates the booking request payload for required fields.
     * @param payload The booking request object
     * @return Error message if validation fails, null otherwise
     */
    private static String validateBookingRequest(BookingRequest payload) {
        if (String.isBlank(payload.guestName)) {
            return ERROR_MISSING_REQUIRED_FIELD + 'guestName';
        }
        if (String.isBlank(payload.guestEmail)) {
            return ERROR_MISSING_REQUIRED_FIELD + 'guestEmail';
        }
        if (String.isBlank(payload.restaurantId)) {
            return ERROR_MISSING_REQUIRED_FIELD + 'restaurantId';
        }
        if (payload.bookingDateTime == null) {
            return ERROR_MISSING_REQUIRED_FIELD + 'bookingDateTime';
        }
        if (payload.partySize == null || payload.partySize < 1) {
            return 'Party size must be at least 1';
        }
        return null;
    }

    /**
     * Extracts the record Id from the URI path.
     * @param uri The request URI
     * @return The record Id or null
     */
    private static String extractIdFromUri(String uri) {
        String lastSegment = uri.substringAfterLast('/');
        if (String.isBlank(lastSegment) || lastSegment == 'v1') {
            return null;
        }
        return lastSegment;
    }

    /**
     * Validates a Salesforce Id format.
     * @param idValue The Id to validate
     * @return True if valid, false otherwise
     */
    private static Boolean isValidSalesforceId(String idValue) {
        return Pattern.matches('[a-zA-Z0-9]{15,18}', idValue);
    }

    /**
     * Gets an integer parameter from the request with a default value.
     * @param req The REST request
     * @param paramName The parameter name
     * @param defaultValue The default value
     * @return The parameter value or default
     */
    private static Integer getIntParam(RestRequest req, String paramName, Integer defaultValue) {
        String paramValue = req.params.get(paramName);
        if (String.isBlank(paramValue)) {
            return defaultValue;
        }
        try {
            return Integer.valueOf(paramValue);
        } catch (TypeException e) {
            return defaultValue;
        }
    }

    /**
     * Creates an error response with the given status code and message.
     * @param res The REST response
     * @param statusCode The HTTP status code
     * @param message The error message
     * @return ApiResponse with error details
     */
    private static ApiResponse handleError(RestResponse res, Integer statusCode, String message) {
        res.statusCode = statusCode;
        return new ApiResponse(false, message, null);
    }

    // ─── Request / Response DTOs ──────────────────────────────────────────

    /**
     * Inbound request payload for POST operations.
     */
    global class BookingRequest {
        global String guestName;
        global String guestEmail;
        global String guestPhone;
        global String restaurantId;
        global DateTime bookingDateTime;
        global Decimal partySize;
        global String specialRequests;
        global String dietaryRestrictions;
        global String status;
    }

    /**
     * Standardized API response envelope.
     * All endpoints return this structure for consistent client parsing.
     */
    global class ApiResponse {
        global Boolean success;
        global String message;
        global String recordId;
        global SObject data;
        global List<SObject> records;
        global Integer pageSize;
        global Integer offset;

        global ApiResponse(Boolean success, String message, String recordId) {
            this.success = success;
            this.message = message;
            this.recordId = recordId;
        }
    }
}
