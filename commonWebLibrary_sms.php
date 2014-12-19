<?php
# Michael Bisbjerg, 2010, All rights reserved.
require_once('commonWebLibrary.php');

class Sms extends commonLibrary
{
	const LDAP_USER = 'xxx';
	const LDAP_PASS = 'xxx';

	// private helper method.
	protected static function _getMembers($filter)
	{
		$ldapconn = ldap_connect(self::LDAP_HOST, self::LDAP_PORT) or die("Could not connect to ".self::LDAP_HOST);
		@ldap_bind($ldapconn, self::LDAP_USER, self::LDAP_PASS);
		$result = ldap_search($ldapconn, self::LDAP_DN_USERS, $filter, array('uid', 'uidnumber', 'cn', 'mobile'));
		$data = ldap_get_entries($ldapconn, $result);
		$users = array();
		for ($i = 0; $i < $data['count']; $i++) {
			$users[$data[$i]['uid'][0]] = array('cn' => $data[$i]['cn'][0], 'uid' => $data[$i]['uidnumber'][0], 'mobile' => $data[$i]['mobile'][0]);
		}
		ksort($users, SORT_STRING);
		return $users;
	}

	public static function getMember($nick)
	{
		$members = self::_getMembers("(&(objectClass=posixAccount)(uid=$nick))");
		return (object) (count($members) == 0 ? null : $members[$nick]);
	}
}

?>
