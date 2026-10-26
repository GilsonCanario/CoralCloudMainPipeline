/**
 * Centralized factory for creating test data with sensible defaults.
 * All methods accept a doInsert flag for flexibility.
 * Bulk methods create multiple records; single-record methods delegate to bulk.
 */
@isTest
public class TestDataFactory {

    // ─── Restaurants ──────────────────────────────────────────────────────

    /**
     * Creates Restaurant records for testing.
     * @param count Number of restaurants to create
     * @param doInsert Whether to insert the records
     * @return List of Restaurant records
     */
    public static List<Restaurant__c> createRestaurants(Integer count, Boolean doInsert) {
        List<Restaurant__c> restaurants = new List<Restaurant__c>();
        for (Integer i = 0; i < count; i++) {
            restaurants.add(new Restaurant__c(
                Name = 'Test Restaurant ' + i
            ));
        }
        if (doInsert) {
            insert restaurants;
        }
        return restaurants;
    }

    /**
     * Creates a single Restaurant record.
     * @param doInsert Whether to insert the record
     * @return Restaurant record
     */
    public static Restaurant__c createRestaurant(Boolean doInsert) {
        return createRestaurants(1, doInsert)[0];
    }

    // ─── Restaurant Bookings ──────────────────────────────────────────────

    /**
     * Creates Restaurant Booking records for testing.
     * @param restaurants List of restaurants to link bookings to
     * @param countPerRestaurant Number of bookings per restaurant
     * @param doInsert Whether to insert the records
     * @return List of RestaurantBooking records
     */
    public static List<RestaurantBooking__c> createRestaurantBookings(
        List<Restaurant__c> restaurants, 
        Integer countPerRestaurant, 
        Boolean doInsert
    ) {
        List<RestaurantBooking__c> bookings = new List<RestaurantBooking__c>();
        Integer idx = 0;
        
        for (Restaurant__c restaurant : restaurants) {
            for (Integer i = 0; i < countPerRestaurant; i++) {
                bookings.add(new RestaurantBooking__c(
                    Guest_Name__c = 'Test Guest ' + idx,
                    Guest_Email__c = 'testguest' + idx + '@example.com',
                    Guest_Phone__c = '+1555000' + String.valueOf(1000 + idx).leftPad(4, '0'),
                    Restaurant__c = restaurant.Id,
                    Booking_Date_Time__c = DateTime.now().addDays(1 + i),
                    Party_Size__c = 2 + Math.mod(i, 6),
                    Special_Requests__c = 'Test special request ' + idx,
                    Dietary_Restrictions__c = 'None',
                    Status__c = 'Pending'
                ));
                idx++;
            }
        }
        
        if (doInsert) {
            insert bookings;
        }
        return bookings;
    }

    /**
     * Creates Restaurant Booking records with field overrides.
     * @param restaurant Restaurant to link booking to
     * @param count Number of bookings to create
     * @param fieldOverrides Map of field names to values
     * @param doInsert Whether to insert the records
     * @return List of RestaurantBooking records
     */
    public static List<RestaurantBooking__c> createRestaurantBookingsWithOverrides(
        Restaurant__c restaurant,
        Integer count,
        Map<String, Object> fieldOverrides,
        Boolean doInsert
    ) {
        List<RestaurantBooking__c> bookings = new List<RestaurantBooking__c>();
        
        for (Integer i = 0; i < count; i++) {
            RestaurantBooking__c booking = new RestaurantBooking__c(
                Guest_Name__c = 'Test Guest ' + i,
                Guest_Email__c = 'testguest' + i + '@example.com',
                Restaurant__c = restaurant.Id,
                Booking_Date_Time__c = DateTime.now().addDays(1 + i),
                Party_Size__c = 4,
                Status__c = 'Pending'
            );
            
            // Apply field overrides
            for (String fieldName : fieldOverrides.keySet()) {
                booking.put(fieldName, fieldOverrides.get(fieldName));
            }
            
            bookings.add(booking);
        }
        
        if (doInsert) {
            insert bookings;
        }
        return bookings;
    }

    /**
     * Creates a single Restaurant Booking record.
     * @param restaurant Restaurant to link booking to
     * @param doInsert Whether to insert the record
     * @return RestaurantBooking record
     */
    public static RestaurantBooking__c createRestaurantBooking(Restaurant__c restaurant, Boolean doInsert) {
        return createRestaurantBookings(new List<Restaurant__c>{ restaurant }, 1, doInsert)[0];
    }
}
