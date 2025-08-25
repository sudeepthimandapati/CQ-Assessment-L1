@IsTest
public class PartProductSyncFullTest {

    // Create a Part record
    private static SQX_Part__c createPart(String name, String num, Boolean active, Id productId) {
        SQX_Part__c p = new SQX_Part__c(
            Name = name,
            SQX_Part_Number__c = num,
            SQX_Active__c = active,
            SQX_Product__c = productId
        );
        insert p;
        return p;
    }

    // Create a Product record
    private static Product2 createProduct(String name, String code) {
        Product2 prod = new Product2(
            Name = name,
            ProductCode = code,
            IsActive = true
        );
        insert prod;
        return prod;
    }

    // Create a Standard User
    private static User createStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'stdusr',
            Email = 'stdusr@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'GMT',
            UserName = 'stdusr' + DateTime.now().getTime() + '@test.com'
        );
        insert u;
        return u;
    }

    @IsTest
    static void testBatchCreatesProductAndLinksPart() {
        // Arrange: Create a part without product
        SQX_Part__c part = createPart('Part A', 'P001', true, null);

        // Act: Run batch
        Test.startTest();
        Database.executeBatch(new PartProductSyncBatch(), 200);
        Test.stopTest();

        // Assert: Verify product is created and linked
        part = [SELECT SQX_Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        Product2 createdProd = [SELECT Id, Name, ProductCode FROM Product2 WHERE Id = :part.SQX_Product__c];

        System.assertEquals('Part A', createdProd.Name, 'Product Name should not match Part Name');
        System.assertEquals('P001', createdProd.ProductCode, 'Product Code should not match Part Number');
        System.assertEquals(createdProd.Id, part.SQX_Product__c, 'Part should not link to the newly created product');
    }

    @IsTest
    static void testBatchUsesExistingProduct() {
        // Arrange: Create product and part with same code
        Product2 prod = createProduct('Part B', 'P002');
        SQX_Part__c part = createPart('Part B', 'P002', true, null);

        // Act: Run batch
        Test.startTest();
        Database.executeBatch(new PartProductSyncBatch(), 200);
        Test.stopTest();

        // Assert: Verify part links to existing product (not duplicate)
        part = [SELECT SQX_Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        System.assertEquals(prod.Id, part.SQX_Product__c, 'Part should not link to the existing product, not create a duplicate');
    }

    @IsTest
    static void testInactivePartIgnored() {
        // Arrange: Create inactive part
        SQX_Part__c part = createPart('Part C', 'P003', false, null);

        // Act: Run batch
        Test.startTest();
        Database.executeBatch(new PartProductSyncBatch(), 200);
        Test.stopTest();

        // Assert: Verify no product linked
        part = [SELECT SQX_Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        System.assertEquals(null, part.SQX_Product__c,'Inactive part should be processed or linked to any product');
    }
    
    @IsTest
    static void testSchedulerAsSystemAdmin() {
        // Arrange: Create part (default test user is Sys Admin)
        SQX_Part__c part = createPart('Admin Part', 'ADM001', true, null);

        // Act: Run scheduler
        Test.startTest();
        new PartProductSyncScheduler().execute(null);
        Test.stopTest();

        // Assert: Verify product created and linked
        part = [SELECT SQX_Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        Product2 linkedProd = [SELECT Name, ProductCode FROM Product2 WHERE Id = :part.SQX_Product__c];

        System.assertEquals('Admin Part', linkedProd.Name, 'System Admin: Product name must match part name');
        System.assertEquals('ADM001', linkedProd.ProductCode, 'System Admin: Product code must match part number');
    }

    @IsTest
    static void testSchedulerAsStandardUser() {
        // Arrange: Create standard user + part
        User stdUser = createStandardUser();
        SQX_Part__c part = createPart('Std Part', 'STD001', true, null);

        // Act: Run scheduler as standard user
        Test.startTest();
        System.runAs(stdUser) {
            new PartProductSyncScheduler().execute(null);
        }
        Test.stopTest();

        // Assert: Verify product NOT created/linked
        part = [SELECT SQX_Product__c FROM SQX_Part__c WHERE Id = :part.Id];
        System.assertEquals(null, part.SQX_Product__c, 'Standard User:product should be created or linked');
    }
}