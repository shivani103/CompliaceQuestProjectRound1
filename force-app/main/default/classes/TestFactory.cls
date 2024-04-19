@IsTest
public class TestFactory {
    
    private static Map<String, List<String>> profilePermissionSetsMap = new Map<String, List<String>>{
        'Standard User' => new List<String>{'Integration Admin PS'}
    };
        
    public static user createUser(String profileName){
        String randomNumber = string.valueOf(system.currentTimeMillis());   
        List<Profile> profiles = new List<Profile>();
        profiles = [SELECT ID FROM Profile WHERE Name =: profileName];
        System.assert(!profiles.isEmpty(), 'If Profile is empty '+profiles);
        User userRecord = new User();
        userRecord.Username = 'testUser'+profileName.deleteWhitespace()+'@abc.com';
        userRecord.Email = 'a' + randomNumber + '@abc' + randomNumber + '.com';
        userRecord.FirstName =  'abc' + randomNumber;
        userRecord.LastName = randomNumber;
        userRecord.CommunityNickname =  randomNumber;
        userRecord.ProfileId = profiles[0].id;
        userRecord.Alias =  randomNumber.mid(4,6);
        userRecord.EmailEncodingKey = 'UTF-8';
        userRecord.LanguageLocaleKey = 'en_US';
        userRecord.LocaleSidKey = 'en_US';
        userRecord.TimeZoneSidKey = 'America/Los_Angeles';
        userRecord.IsActive=true;
        insert userRecord;

        if(profilePermissionSetsMap.containsKey(profileName)){
            List<PermissionSet> permissionSets = [SELECT ID FROM PermissionSet WHERE Name IN: profilePermissionSetsMap.get(profileName)];
            List<PermissionSetAssignment> lstPSA = new list<PermissionSetAssignment>();
            
            for (permissionSet ps:  permissionSets){
                PermissionSetAssignment  psa =   new PermissionSetAssignment(AssigneeId=userRecord.Id, PermissionSetId=ps.Id);
                lstPSA.add(psa);
            }
            
            insert lstPSA;
        }

        return userRecord;
    }

    public static User getUser(String profileName){
        User usr = null;
        string usrName = 'testUser'+profileName.deleteWhitespace()+'@abc.com';
        List<User> usrs = [SELECT id,Name FROM user WHERE username LIKE: usrName LIMIT 1];
        System.assert(!usrs.isEmpty(), 'No User found with given '+profileName+' profile name');
        usr = usrs[0];
        return usr;
    }

}