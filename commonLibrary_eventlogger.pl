<?php
# Nicholas Mossor Rathmann, 2009-2010, All rights reserved.
require_once('commonWebLibrary.php');

class EventLogger extends commonLibrary 
{

#    const EVENTLOG_MYSQL_HOST = '10.0.0.15';
    const EVENTLOG_MYSQL_HOST = 'localhost';
    const EVENTLOG_MYSQL_USER = 'eventlogger';
    const EVENTLOG_MYSQL_PASSWD = 'zhjppVaaw3JpdDuQ';
    const EVENTLOG_MYSQL_DB = 'eventlogger';

    const TBL = 'events';
    
    const EVENT_WIKI_LOGIN     = 1;
    const EVENT_WIKI_PAGE_EDIT = 2;
    const EVENT_SSH_LOGIN      = 3; # These do NOT include sftp/scp login events!!!
    
    public static $eventDescriptions = array(
        self::EVENT_WIKI_LOGIN      => 'Wiki login',
        self::EVENT_WIKI_PAGE_EDIT  => 'Wiki page edit',
        self::EVENT_SSH_LOGIN       => 'SSH cmd login',
    );

    public static function openDBconnection()
    {
        $link = mysql_connect(self::EVENTLOG_MYSQL_HOST, self::EVENTLOG_MYSQL_USER, self::EVENTLOG_MYSQL_PASSWD);
        if (!$link) {
            die('Event logger cannot connect to DB: ' . mysql_error());
        }
	    mysql_select_db(self::EVENTLOG_MYSQL_DB);
        return $link;    
    }

    public static function setupDB()
    {
        $link = self::openDBconnection();
        mysql_query("CREATE TABLE ".self::TBL."(
            id    INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            uid   INT UNSIGNED NOT NULL,
            event TINYINT UNSIGNED NOT NULL DEFAULT 0,
            date  DATETIME,
            id_a BIGINT UNSIGNED DEFAULT NULL,
            INDEX (uid,date),
            INDEX (event,date)
        )");
    }

    public static function setEvent($user, $event, $opts = array())
    {
        $link = self::openDBconnection();
        $members = self::_getMembers("(&(objectClass=posixAccount)(uid=$user))");
        $uid  = (int) $members[$user]['uid'];
        
        switch ($event) 
        {
            case self::EVENT_WIKI_LOGIN:
                $success = mysql_query("INSERT INTO ".self::TBL." (uid,event,date) VALUES ($uid,".self::EVENT_WIKI_LOGIN.",NOW())");
                break;
                
            case self::EVENT_WIKI_PAGE_EDIT:
	        # uses id_a as article's ID
                $success = mysql_query("INSERT INTO ".self::TBL." (uid,event,date,id_a) VALUES ($uid,".self::EVENT_WIKI_PAGE_EDIT.",NOW(),$opts[articleID])");
                break;
            
            case self::EVENT_SSH_LOGIN:
                $success = mysql_query("INSERT INTO ".self::TBL." (uid,event,date) VALUES ($uid,".self::EVENT_SSH_LOGIN.",NOW())");
                break;
        }
        
        if (!$success) {
            die("Event logger failed to save eventnumber $event for uid = '$user' (LDAP UID = $uid). MySQL error: ".mysql_error($link));
        }

    	return true;
    }
    
    public static function getEvents($user)
    {
        $link = self::openDBconnection();
        mysql_select_db(self::EVENTLOG_MYSQL_DB);
        $members = self::_getMembers("(&(objectClass=posixAccount)(uid=$user))");
        $uid  = (int) $members[$user]['uid'];
        $events = array();
        $result = mysql_query("SELECT * FROM ".self::TBL." WHERE uid = $uid ORDER BY date DESC");
        while ($row = mysql_fetch_assoc($result)) {
            $events[] = $row;
        }
        return $events;
    }
}

?>
