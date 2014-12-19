<?php
# Nicholas Mossor Rathmann, 2009-2010, All rights reserved.
require_once('commonWebLibrary.php');

class LimeSurveyHack extends CommonLibrary 
{
/* 
    In LimeSurvey's config-ldap.php do this: 
        require(THIS_FILE); 
        $ldap_queries = LimeSurveyHack::getLDAPqueries($serverID);
*/
public static function getLDAPqueries($serverID)
{
    $ldap_queries = array();
    $query_id = 0;
    foreach (self::getYearRange() as $year) {
        $ldap_queries[$query_id]['ldapServerId'] = 0;
        $ldap_queries[$query_id]['name'] = "Year $year-".($year+1);
        $ldap_queries[$query_id]['userbase'] = self::LDAP_DN_USERS;
        $ldap_queries[$query_id]['userfilter'] = '(&(objectClass=posixAccount)(|'.implode('', array_map(create_function('$usr', 'return "(uid=$usr)";'), array_keys(self::getMembersOfYear(sprintf('%02d', $year%100))))).'))';
        $ldap_queries[$query_id]['userscope'] = 'sub';
        $ldap_queries[$query_id]['firstname_attr'] = 'cn';
        $ldap_queries[$query_id]['lastname_attr'] = 'cn';
        $ldap_queries[$query_id]['email_attr'] = '';
        $ldap_queries[$query_id]['token_attr'] = 'uid';
        $ldap_queries[$query_id]['language'] = '';
        $ldap_queries[$query_id]['attr1'] = '';
        $ldap_queries[$query_id]['attr2'] = '';
        $query_id++;
    }
    foreach (self::getGroups() as $gid => $name) {
        $ldap_queries[$query_id]['ldapServerId'] = 0;
        $ldap_queries[$query_id]['name'] = 'Class '.$name;
        $ldap_queries[$query_id]['userbase'] = self::LDAP_DN_USERS;
        $ldap_queries[$query_id]['userfilter'] = '(&(objectClass=posixAccount)(|'.implode('', array_map(create_function('$usr', 'return "(uid=$usr)";'), array_keys(self::getMembersOfGroup($gid)))).'))';
        $ldap_queries[$query_id]['userscope'] = 'sub';
        $ldap_queries[$query_id]['firstname_attr'] = 'cn';
        $ldap_queries[$query_id]['lastname_attr'] = 'cn';
        $ldap_queries[$query_id]['email_attr'] = '';
        $ldap_queries[$query_id]['token_attr'] = 'uid';
        $ldap_queries[$query_id]['language'] = '';
        $ldap_queries[$query_id]['attr1'] = '';
        $ldap_queries[$query_id]['attr2'] = '';
        $query_id++;
    }
    return $ldap_queries;
}
}

?>
