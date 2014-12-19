<?php
# Nicholas Mossor Rathmann, 2009-2011, All rights reserved.

error_reporting(E_ALL);

class CommonLibrary
{

/****************
    SETTINGS
 ****************/

const WWW_DOMAIN = 'rtgkom.dk'; # Don't add any sub domain components (eg. www).
 
// LDAP
const LDAP_HOST = '127.0.0.1';
const LDAP_PORT = 389;
const LDAP_DN_GROUPS = 'ou=Group,dc=rtgkom';
const LDAP_DN_USERS = 'ou=People,dc=rtgkom';

# For various purposes these two numbers define the lower and upper limits of "students years".
const LDAP_YEARRANGE_LOW = 1999;
#const LDAP_YEARRANGE_UP  = 2014; // Value is not used.

//Other
const PATH_BASE = '/files';
const BACKUP_BASE = '/backup';



/****************
    Routines
 ****************/

public static function getYearRange() {
    return range(self::LDAP_YEARRANGE_LOW, (date("Y")+0) /* self::LDAP_YEARRANGE_UP */ );
}

public static function getCurrentYearRange() {
    $y = date("Y");
    return range($y-3, $y);
}

public static function getGroups()
{
    # The cn of the LDAP group(s) must match one of the following regexes.
    $regexes = array("/\d\d\d\d\_\d/", '/.*\d\d/'); # ex. (1) 2007_1

    $ldapconn = ldap_connect(self::LDAP_HOST, self::LDAP_PORT) or die("Could not connect to ".self::LDAP_HOST);
    @ldap_bind($ldapconn);
    $filter = "(objectClass=posixGroup)";
    $justthese = array('cn', 'gidnumber');
    $result = ldap_search($ldapconn, self::LDAP_DN_GROUPS, $filter, $justthese);
    $data = ldap_get_entries($ldapconn, $result);
    $groups = array();
    for ($i = 0; $i < $data['count']; $i++) {
        foreach ($regexes as $regex) {
            if (preg_match($regex, $data[$i]['cn'][0])) {
                $groups[$data[$i]['gidnumber'][0]] = $data[$i]['cn'][0];
                break;
            }
        }
    }
    asort($groups,SORT_STRING);
    return $groups;
}

// private helper method.
protected static function _getMembers($filter)
{
    $ldapconn = ldap_connect(self::LDAP_HOST, self::LDAP_PORT) or die("Could not connect to ".self::LDAP_HOST);
    @ldap_bind($ldapconn);
    $result = ldap_search($ldapconn, self::LDAP_DN_USERS, $filter, array('uid', 'uidnumber', 'cn'));
    $data = ldap_get_entries($ldapconn, $result);
    $users = array();
    for ($i = 0; $i < $data['count']; $i++) {
        $users[$data[$i]['uid'][0]] = array('cn' => $data[$i]['cn'][0], 'uid' => $data[$i]['uidnumber'][0], 'nick' => $data[$i]['uid'][0]);
    }
    ksort($users, SORT_STRING);
    return $users;
}

public static function getMember($nick)
{
    $members = self::_getMembers("(&(objectClass=posixAccount)(".((is_numeric($nick)) ? 'uidNumber' : 'uid')."=$nick))");
    return (object) (count($members) == 0 ? null : array_shift($members));
}

public static function getField($nick, $field)
{
    $ldapconn = ldap_connect(self::LDAP_HOST, self::LDAP_PORT) or die("Could not connect to ".self::LDAP_HOST);
    @ldap_bind($ldapconn);
    $filter="(&(objectClass=posixAccount)(".((is_numeric($nick)) ? 'uidNumber' : 'uid')."=$nick))";
    $result = ldap_search($ldapconn, self::LDAP_DN_USERS, $filter, array($field));
    $data = ldap_get_entries($ldapconn, $result);
    return $data[0][strtolower($field)][0];
}

public static function getMembersOfYear($abbrev_year) # ex = '05' for 2005, '11' for 2011.
{
    return self::_getMembers("(&(objectClass=posixAccount)(uid=*$abbrev_year))");
}

public static function getMembersOfGroup($group) # $group may be (int) GID or (str) cn (LDAP cn of group).
{
    # First fetch group members.
    $ldapconn = ldap_connect(self::LDAP_HOST, self::LDAP_PORT) or die("Could not connect to ".self::LDAP_HOST);
    @ldap_bind($ldapconn);
    $filter = "(&(objectClass=posixGroup)(".(is_numeric($group) ? 'gidnumber' : 'cn')."=$group))";
    $justthese = array('gidnumber', 'cn', 'memberuid');
    $result = ldap_search($ldapconn, self::LDAP_DN_GROUPS, $filter, $justthese);
    $data = ldap_get_entries($ldapconn, $result);
    $users = $data[0]['memberuid'];
    unset($users['count']);
    sort($users);
    # ..then look up members.
    return self::_getMembers("(&(objectClass=posixAccount)(|".implode('', array_map(create_function('$usr', 'return "(uid=$usr)";'), $users))."))");
}

public static function authUser($user, $passwd) {
	$ldapconn = ldap_connect(self::LDAP_HOST, self::LDAP_PORT) or die("Could not connect to ".self::LDAP_HOST);
	$ldapset = ldap_set_option($ldapconn,LDAP_OPT_PROTOCOL_VERSION,3);
	// binding to ldap server
    	$ldapbind = @ldap_bind($ldapconn, self::getUserDN($user), $passwd);
	return (bool) $ldapbind;
}

public static function getUserDN($user) {
	return "uid=$user,ou=People,dc=rtgkom";
}

}


class HTML_frame
{
	public static function beginFrame($title, $extraHeadTags = array())
	{	
		print '
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
		<html>
			<head>
			    <meta http-equiv="Content-Type" content="text/html;charset=utf-8">
			    <style type="text/css">
			        body       {background-color: #4C6260}
				div.main   {font-family: monospace; font-size: 11pt; width:70%; margin-left:15%; margin-right:15%; padding: 20px; background-color: #f2f2f2; }
			    </style>
			    <title>'.$title.'</title>
		            '.implode("\n", $extraHeadTags).'
			</head>
			<body>
			    <div class="main">

		';
	}

	public static function endFrame()
	{
		print "
			</div>
			</body>
			</html>
		";
	}
	
	public static function textdate($mysqldate) {
	    return date("D M j Y", strtotime($mysqldate));
	}
}

?>
