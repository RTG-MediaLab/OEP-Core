<?php
# Nicholas Mossor Rathmann 2010
 
if (!defined('MEDIAWIKI')) die('Not an entry point.');

require_once('/files/scripts/commonWebLibrary_eventlogger.php');

define('EVENTLOGGER_VERSION','0.1 May 2010');
 
$wgServerUser = 1; # User ID to use for logging if no user exists
 
#$wgExtensionFunctions[] = 'wfSetupUserLoginLog';
$wgExtensionCredits['other'][] = array(
	'name'        => 'EventLogger',
	'author'      => 'Nichoals Mossor Rathmann',
	'description' => 'Logs events to MySQL',
	'url'         => '',
	'version'     => EVENTLOGGER_VERSION
	);
 

$wgHooks['UserLoginComplete'][] = 'wfUserLogin';
#$wgHooks['EditFilter'][] = 'wfUserEditedPage';
 
 
function wfUserLogin(&$user) {
    return EventLogger::setEvent(strtolower($user->getName()), EventLogger::EVENT_WIKI_LOGIN);
}
 
function wfUserEditedPage(&$EditPage, $text, &$resultArr) {
    global $wgUser;
    return EventLogger::setEvent(strtolower($wgUser->getName()), EventLogger::EVENT_WIKI_PAGE_EDIT, array('articleID' => $EditPage->mTitle->mArticleID));
}
