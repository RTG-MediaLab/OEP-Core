<?php
require('/files/scripts/commonWebLibrary.php');

$MY_LISTS = array(
	'Gode_eksempler' => array('jan', 'gkb', 'nicholasmr05', 'mette', 'brw', 'nielsoj05', 'kreanvh05'),
);

if (isset($_GET['browse'])) {
	$grp = $_GET['browse'];
	$cnt = 0;
	$members = isset($MY_LISTS[$grp]) ? array_combine($MY_LISTS[$grp], $MY_LISTS[$grp]) : CommonLibrary::getMembersOfGroup($grp);
	do {
		$selected = array_rand($members);
	} while (!userHasWebsite($selected) && $cnt++ < 25);
	$name = is_array($members[$selected]) ? $members[$selected]['cn'] : $selected;
	echo '
	<html>
       	<head>
          	<meta http-equiv="Content-Type" content="text/html;charset=utf-8">
                <title>'.$name.'</title>
		<script type="text/javascript" src="jquery144.js"></script>
		<script type="text/javascript">
			$(document).ready(function() {
                        	$("#who").delay(15000).fadeOut("slow");

			});
		</script>
	</head>
	<body>
';
	echo "<div id='who'><h2>StudieWeb of $name</h2><hr></div>\n";
	echo "<iframe src='http://www.".CommonLibrary::WWW_DOMAIN."/~$selected' width='100%' height='100%' scrolling='auto' frameborder='0'></iframe>";
	echo "</body></html>";
} 
else {
	HTML_frame::beginFrame('Random StudieWeb viewer');
	echo "<h1>Random StudieWeb viewer</h1><hr>\n";
	echo "<b>What is this?</b><br>\nThis script will randomly pick a member of the selected group below and show the user's website.<br><br>\n";
	foreach ( array_merge(array_keys($MY_LISTS), array_reverse(CommonLibrary::getGroups())) as $grp) {
		print "<a href='?browse=$grp'>$grp</a><br>\n";
	}
	HTML_frame::endFrame();
}

function userHasWebsite($usr) {
        $server = "www.".CommonLibrary::WWW_DOMAIN; 
        $errno = $errstr = 0;
	$fp=fsockopen($server,80,$errno,$errstr,30);
	$page = "/~$usr/index.html";
	$out="GET /$page HTTP/1.1\r\n"; 
	$out.="Host: $server\r\n"; 
	$out.="Connection: Close\r\n\r\n";
	fwrite($fp,$out);
	$content=fgets($fp);
	return !preg_match('/404/', $content); # Not Found status?
}

?>
