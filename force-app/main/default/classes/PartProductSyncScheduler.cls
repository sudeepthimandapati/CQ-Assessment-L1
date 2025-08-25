global class PartProductSyncScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        //Act: Only allow execution for System Admins or users with CQ Product Admin permission set
        if (hasAccess()) {
            Database.executeBatch(new PartProductSyncBatch(), 200);
        }
    }

    private Boolean hasAccess() {
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        if (p.Name == 'System Administrator') return true;

        //Act: Check permission set
        List<PermissionSetAssignment> psa = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = 'CQ_Product_Admin'];
        return !psa.isEmpty();
    }
}