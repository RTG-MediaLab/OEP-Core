<?php
# Nicholas Mossor Rathmann, 2009-2010, All rights reserved.
require_once('commonWebLibrary.php');

class Publisher extends commonLibrary
{
#	const PUBL_HOST = '10.0.0.15';
	const PUBL_HOST = 'localhost';
	const PUBL_USER = 'xxx';
	const PUBL_DB = 'publisher';
	const PUBL_PASSWD = 'xxx';
	const PUBL_TBL = 'projects';

	# Maximum length of project title and description.
	const PUBL_MAX_TITLE = 40;
	const PUBL_MAX_DESC = 1000;

	# Preferred picture dimensions
	const PUBL_IMG_X = 400; # px

    	public static function openDBconnection()
	{
	        $link = mysql_connect(self::PUBL_HOST, self::PUBL_USER, self::PUBL_PASSWD);
        	if (!$link) {
	            die('Publisher cannot connect to DB: ' . mysql_error());
        	}
		mysql_select_db(self::PUBL_DB);
        	return $link;
	}

	public static function saveProject($nick, $title, $description, $projecturl, $imgurls)
	{
		$conn = self::openDBconnection();
		$query = "INSERT INTO ".self::PUBL_TBL." (uid, title, date, projecturl, img1url, img2url, img3url, description) VALUES (
				'$nick',
				'".mysql_real_escape_string($title)."',
				NOW(),
				'".mysql_real_escape_string($projecturl)."',
				'".mysql_real_escape_string($imgurls[0])."',
				'".mysql_real_escape_string($imgurls[1])."',
				'".mysql_real_escape_string($imgurls[2])."',
				'".mysql_real_escape_string($description)."'
			)";
		return mysql_query($query);
	}

	public static function getRandProject()
	{
		$link = self::openDBconnection();
		$query = "SELECT id FROM ".self::PUBL_TBL." ORDER BY rand() LIMIT 1";
                $result = mysql_query($query);
		if (mysql_num_rows($result) == 0) {
			return array(null,null);
		}
		$project = mysql_fetch_object($result);
		$project = self::getProjectByID($project->id);
		return $project;
	}
	public static function getProjectByID($id)
	{
		$link = self::openDBconnection();
                $query = "SELECT * FROM ".self::PUBL_TBL." WHERE id = $id";
                $result = mysql_query($query);
                if (mysql_num_rows($result) == 0) {
                        return array(null,null);
                }
                $project = mysql_fetch_object($result);
                $user = self::getMember($project->uid);
                return array($project, $user);
	}

	public static function getUserProjects($nick)
	{
		$link = self::openDBconnection();
                $query = "SELECT * FROM ".self::PUBL_TBL." WHERE uid = '$nick' ORDER BY date DESC";
		$result = mysql_query($query);
		$projects = array();
		while ($project = mysql_fetch_object($result)) {
                        $projects[] = array($project, self::getMember($project->uid));
		}
		return $projects;
	}
        public static function getAllProjects()
        {
                $link = self::openDBconnection();
                $query = "SELECT * FROM ".self::PUBL_TBL." ORDER BY date DESC";
                $result = mysql_query($query);
                $projects = array();
                while ($project = mysql_fetch_object($result)) {
                        $projects[] = array($project, self::getMember($project->uid));
                }
                return $projects;
        }

	public static function deleteProject($id)
	{
                $link = self::openDBconnection();
		return mysql_query("DELETE FROM ".self::PUBL_TBL." WHERE id = $id");
	}

	public static function setupTable()
	{
		$link = self::openDBconnection();
		$query = "CREATE TABLE ".self::PUBL_TB." (
				id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
				uid VARCHAR(50),
				title VARCHAR(".self::PUBL_MAX_TITLE."),
				date DATETIME,
			        projecturl VARCHAR(200),
				img1url VARCHAR(200),
				img2url VARCHAR(200),
			        img3url	VARCHAR(200),
				description VARCHAR(".self::PUBL_MAX_DESC."),
				INDEX (uid,date)
			)";

		return mysql_query($query);
	}
}

?>
