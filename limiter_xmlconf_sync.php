<?php
error_reporting(E_ALL);
// Nicholas Mossor Rathmann, 2011
define('PROXY_HOST', '10.0.0.202');
define('PROXY_USR', 'xxx');
define('PROXY_PASSWD', 'xxx');
define('WORK_DIR', '/tmp');
define('OLD_CONF',       WORK_DIR.'/OLD_config.xml');
define('NEW_CONF',       WORK_DIR.'/NEW_config.xml');
//define('TRANF_CONFNAME', WORK_DIR.'/config.xml');

// Funcs
# Main
function xmlconf_sync($lobj) {
    if (!is_user_admin($lobj->author)) {
        return;
    }
    $conn = mysql_connect('127.0.0.1','xxx', 'xxx');
    mysql_select_db("limiter", $conn) or die(mysql_error());
#    _create_dbstruct();
    insert_ACL($lobj);
    $ACLs = get_ACLs();
    update_pfsense_confxml($ACLs);
    reload_pfsense_proxy();
}

function is_user_admin($nick) {
    return true;
}

function insert_ACL($lobj) {
    mysql_query("DELETE FROM acls WHERE name='$lobj->name'");
    return mysql_query($q="INSERT INTO acls(name, author, domains, access, default_access, date_from, date_to, msg)
    VALUES('$lobj->name','$lobj->author','$lobj->domains',".(($lobj->access == 'yes') ? 1 : 0).",".(($lobj->defaultaccess == 'yes') ? 1 : 0).",'$lobj->datefrom',
    '$lobj->dateto','".mysql_real_escape_string($lobj->msg)."')") or die(mysql_error().$q);
}

function get_ACLs() {
	$ACLs = array();
	$result = mysql_query("SELECT * FROM acls WHERE date_from <= NOW() AND date_to >= NOW()") or die(mysql_error());
	while ($ACL = mysql_fetch_object($result)) {
		$ACLs[] = $ACL;
	}
	return  $ACLs;
}

function update_pfsense_confxml($ACLs) {
	$cmd = 'scp '.PROXY_USR.'@'.PROXY_HOST.':/cf/conf/config.xml '.OLD_CONF;
	system($cmd);
	sleep(1); // Wait for download
	if (!file_exists(OLD_CONF)) {
		die(OLD_CONF." could not be fetched from proxy.");
	}
	$xml = simplexml_load_file(OLD_CONF);
	$common_acl = array();
	$common_acl_allow_all = 0;
    unset($xml->installedpackages->squidguarddest->config);
	foreach ($ACLs as $ACL) {
		$not = ($ACL->access) ? '' : ' not';
                $common_acl[] = (($ACL->access) ? '' : '!').$ACL->name;
		$common_acl_allow_all |= $ACL->default_access;
		$config = $xml->installedpackages->squidguarddest->addChild('config');
		$config->addChild('name', $ACL->name);
		$config->addChild('domains', $ACL->domains);
		$config->addChild('urls', '');
		$config->addChild('expressions', '');
		$config->addChild('redirect_mode', 'rmod_int');
		$config->addChild('redirect', "$ACL->msg | These sites are$not allowed: $ACL->domains");
		$config->addChild('enablelog', '');
		$config->addChild('description', "Made by $ACL->author. ID = $ACL->id");
	}
	$xml->installedpackages->squidguarddefault->config->deniedmessage = 'Siden er blokeret';
    $xml->installedpackages->squidguarddefault->config->redirect = 'Denne side er blokeret og er derfor kke tilgængelig';
	$common_acl[] = (($common_acl_allow_all) ? '' : '!').'all';
    $xml->installedpackages->squidguarddefault->config->dest = implode(' ',$common_acl);
#    	print_r($xml->installedpackages->squidguarddefault);
#		print_r($xml->installedpackages->squidguarddest);
#		die($xml->asXML());
	file_put_contents(NEW_CONF, $xml->asXML());
}

function reload_pfsense_proxy() {
	// SSH into the proxy and get it to fetch the new pfsense XML config and install it.
	system('scp '.NEW_CONF.' '.PROXY_USR.'@'.PROXY_HOST.':/root/config.xml');
	system('ssh '.PROXY_USR.'@'.PROXY_HOST.' "php -f /root/limiter_proxyupdate.php"');
}

function _create_dbstruct() {
	mysql_query("CREATE TABLE IF NOT EXISTS acls (
		id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
		name VARCHAR(100) NOT NULL,
		author VARCHAR(30) NOT NULL,
		domains VARCHAR(1000) NOT NULL,
		access BOOLEAN NOT NULL,
		default_access BOOLEAN NOT NULL,
		date_from DATETIME NOT NULL,
		date_to DATETIME NOT NULL,
		msg VARCHAR(500) NOT NULL
	)
	");
}
?>
