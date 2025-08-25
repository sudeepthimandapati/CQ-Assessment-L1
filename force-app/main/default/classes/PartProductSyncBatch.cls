public class PartProductSyncBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Step 1: Find all active Parts where Product link is empty
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, SQX_Part_Number__c, SQX_Active__c, SQX_Product__c FROM SQX_Part__c WHERE SQX_Active__c = true AND SQX_Product__c = null]);
    }

    // Step 2: For each batch of Parts
    public void execute(Database.BatchableContext bc, List<SQX_Part__c> scope) {
        Map<String, Product2> productMap = new Map<String, Product2>();

        // Collect all part numbers from this batch
        Set<String> partNumbers = new Set<String>();
        for (SQX_Part__c part : scope) {
            if (String.isNotBlank(part.SQX_Part_Number__c)) {
                partNumbers.add(part.SQX_Part_Number__c);
            }
        }

        // Look up existing Products that have the same Part Number
        for (Product2 prod : [SELECT Id, Name, ProductCode FROM Product2 WHERE ProductCode IN :partNumbers]) {
            productMap.put(prod.ProductCode, prod);
        }

        // Prepare lists for new Products to create and Parts to update
        List<Product2> toInsertProducts = new List<Product2>();
        List<SQX_Part__c> toUpdateParts = new List<SQX_Part__c>();

        // For each Part in scope, check if Product already exists
        for (SQX_Part__c part : scope) {
            Product2 existingProd = productMap.get(part.SQX_Part_Number__c);

            if (existingProd != null) {
                // If Product exists, link the Part to that Product
                part.SQX_Product__c = existingProd.Id;
                toUpdateParts.add(part);
            } else {
                // If Product does not exist, prepare to create a new one
                Product2 newProd = new Product2();
                newProd.Name = part.Name;
                newProd.ProductCode = part.SQX_Part_Number__c;
                newProd.IsActive = true;

                toInsertProducts.add(newProd);

                // Act:Add to map so we don't create duplicates in the same batch
                productMap.put(part.SQX_Part_Number__c, newProd);
            }
        }

        //Act:Insert new Products
        if (!toInsertProducts.isEmpty()) {
            insert toInsertProducts;

            //Act:After insert, link the new Products back to their Parts
            for (Product2 prod : toInsertProducts) {
                for (SQX_Part__c part : scope) {
                    if (part.SQX_Part_Number__c == prod.ProductCode) {
                        part.SQX_Product__c = prod.Id;
                        toUpdateParts.add(part);
                    }
                }
            }
        }

        //Act: Update all Parts with Product links
        if (!toUpdateParts.isEmpty()) {
            update toUpdateParts;
        }
    }

    //Act: Finish 
    public void finish(Database.BatchableContext bc) {
    }
}