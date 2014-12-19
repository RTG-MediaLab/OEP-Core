<?php
# Nicholas Mossor Rathmann, 2011, All rights reserved.
require_once('commonWebLibrary.php');

class Publisher extends commonLibrary
{
#	const PUBL_HOST = '10.0.0.15';
	const PUBL_HOST = 'localhost';
	const PUBL_USER = 'xxx';
	const PUBL_DB = 'rtgprojects';
	const PUBL_PASSWD = 'xxx';
	const PUBL_TBL_PR = 'projects'; # Projects table
	const PUBL_TBL_MEMB = 'members'; # Members (of project) table

    const T_ALL = 0;
    const T_USER = 1;
    const T_CLASS = 2;
    const T_YEAR = 3;
#    public static $TYPES = array(, self::T_USER, self::T_CLASS, self::T_YEAR);
    public static $TYPES = array(self::T_USER => 'uid', self::T_CLASS => 'gid', self::T_YEAR => 'year', self::T_ALL => null);

    public $members = array('nick' => array('cn' => 'my cn', 'classes' => array('class1', 'class2')));
    public $full_member_names = array();
    public $classes = array();
    public $year = 0;
    public $about = '';
    public $thumbs = array(false, false, false); # Do pictures thumb1.jpg, thumb2.jpg and thumb3.jpg exist in the public_html dir?
    public $thumbs_wwwpath = array();

	const IMG_X = 400; # px

    function __construct($prid)
    {
		$project = (object) array();
    	$link = self::openDBconnection();

    	// Project data
        $query = "SELECT * FROM ".self::PUBL_TBL_PR." WHERE prid = $prid";
        $result = mysql_query($query);
        if (mysql_num_rows($result) == 0) {
	    	return null;
        }
        $project = mysql_fetch_object($result);
        foreach ($project as $key => $val) {
            $this->$key = $val;
        }

        // Members
        $query = "SELECT * FROM ".self::PUBL_TBL_MEMB." WHERE prid = $prid";
        $result = mysql_query($query);
        while ($member = mysql_fetch_object($result)) {
            $memb = self::getMember($member->uid);
            $this->members[$memb->nick]['cn'] = $memb->cn;
            $this->members[$memb->nick]['classes'][] = $member->gid;
            $this->full_member_names[$memb->nick] = $memb->cn;
        }

        // Classes
        $query = "SELECT DISTINCT year AS 'year' FROM ".self::PUBL_TBL_MEMB." WHERE prid = $prid";
        $result = mysql_query($query);
        $membrow = mysql_fetch_object($result);
        $this->year = $membrow->year;

        // Misc
        $this->url = 'http://www.'.self::WWW_DOMAIN."/~$this->name";

        // Stored files
        $PATH_HOME_NAME     = $this->name; # Repalce %PROJECTNAME% when used (str_replace()).
        $PATH_THUMB_NAME    = 'thumb%i%.jpg'; # %i% = {1,2,3}
        $PATH_PROJECTS      = self::PATH_BASE.'/projects';
	    $PATH_PUBLIC_HTML   = "$PATH_PROJECTS/$PATH_HOME_NAME/public_html";
	    $PATH_ABOUTTXT      = "$PATH_PUBLIC_HTML/about.txt";
	    $PATH_THUMBS        = "$PATH_PUBLIC_HTML/$PATH_THUMB_NAME";
	    //---
        $this->about = file_exists($PATH_ABOUTTXT) ? file_get_contents($PATH_ABOUTTXT, true) : "No description available. $PATH_ABOUTTXT is empty.";
        foreach (range(1,3) as $i) {
            $path = str_replace('%i%', $i, $PATH_THUMBS);
            if ($this->thumbs[$i] = file_exists($path)) {
                $this->thumbs_wwwpath[] = $this->url.'/'.str_replace('%i%', $i, $PATH_THUMB_NAME);
            }
        }
    }


   	public static function openDBconnection()
	{
        $link = mysql_connect(self::PUBL_HOST, self::PUBL_USER, self::PUBL_PASSWD);
       	if (!$link) {
            die('Cannot connect to DB: ' . mysql_error());
       	}
		mysql_select_db(self::PUBL_DB);
       	return $link;
	}

	public static function getRandProject()
	{
		$link = self::openDBconnection();
		$query = "SELECT prid FROM ".self::PUBL_TBL_PR." ORDER BY rand() LIMIT 1";
        $result = mysql_query($query);
		if (mysql_num_rows($result) == 0) {
			return null;
		}
		$project = mysql_fetch_object($result);
		return new self($project->prid);
	}

    public static function getProjectsOf($type, $id, $index = 'name')
    {
        if (!in_array($type, array_keys(self::$TYPES)) || ($index != 'name' && $index != 'prid')) {
            return null;
        }
		$link = self::openDBconnection();
        $query = "SELECT DISTINCT members.prid, name, title, date_create FROM members, projects WHERE members.prid = projects.prid ".(($type == self::T_ALL) ? '' : "AND ".self::$TYPES[$type]." = $id");
        $result = mysql_query($query);
        $projects = array();
        while ($project = mysql_fetch_object($result)) {
            $projects[(($index == 'name') ? $project->name : $project->prid)] = array('prid' => $project->prid, 'name' => $project->name, 'title' => $project->title, 'date_create' => $project->date_create);
        }
        return $projects;
    }

    public static function getGroups()
    {
        $struc = array('classes' => array(), 'years' => array());
		$link = self::openDBconnection();

        $query = "SELECT DISTINCT gid FROM members";
        $result = mysql_query($query);
        while ($class = mysql_fetch_object($result)) {
            $struct['classes'][] = $class->gid;
        }

        $query = "SELECT DISTINCT year FROM members";
        $result = mysql_query($query);
        while ($class = mysql_fetch_object($result)) {
            $struct['years'][] = $class->year;
        }

        return $struct;
    }
}

if (isset($_GET['show'])) {

	$show = $_GET['show'];

	if ($show == 'random') {
	        $project = Publisher::getRandProject();
	        ShowProject($project);
	}
	else if (is_numeric($show)) {
	        $project = new Publisher($show);
	        ShowProject($project);
	}
	else {
		echo "Invalid project ID";
	}
}
else if (isset($_GET['listby'])) {
	HTML_frame::beginFrame('Project publisher');
	$nick = $_GET['listby'];
        $user = Publisher::getMember($nick);
	if (!is_object($user)) die('Invalid username specified.');
        echo "<h1>Projects by ".$user->cn."</h1><hr>\n";
	echo "<table>\n";
        foreach (Publisher::getUserProjects($nick) as $pr) {
                mkPrRow($pr);
        }
	echo "</table>\n";
	HTML_frame::endFrame();
}
else {
	HTML_frame::beginFrame('Project publisher');
	echo "<h1>Project publisher</h1><hr>";
#	print_r(Publisher::getGroups());
	echo "<table>";
	foreach (Publisher::getProjectsOf(Publisher::T_ALL, 0, 'prid') as $pr) {
		mkPrRow($pr);
   	}
	echo "</table>";
    HTML_frame::endFrame();
}

function mkPrRow($pr) {
	echo "<tr>
		<td><a href='?show=".$pr['prid']."'>".$pr['title']."</a></td>
		<td>&nbsp;".HTML_frame::textdate($pr['date_create'])."</td>
	</tr>\n";
}

function ShowProject($project)
{
    ?>
    <html>
        <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        </head>
    <body bgcolor="#CCFFCC">
    <?php

    if (!isset($project)) {
        echo 'Invalid project';
    }

    echo "<h2>$project->title <span style='font-weight:normal;'> af ".implode(', ', $project->full_member_names).' '.HTML_frame::textdate($project->date_create)."</span></h2>\n";
    echo '<a href="'.htmlentities($project->url).'">'."<b><span style='font-size:16pt;'>".htmlentities($project->url)."</span></b></a>";
    echo "<hr>";
    echo "<table style='width: 100%'><tr>\n";
    foreach ($project->thumbs_wwwpath as $thumburl) {
        echo "<td><img width='".Publisher::IMG_X."' src='$thumburl' alt='imgurl' /></td>";
    }
    echo "</tr></table>\n";
    echo "<h2>Om projektet</h2><p style='font-size:14pt;'>$project->about</p>\n";
	echo "</body>\n";
	echo "</html>\n";
}
?>
