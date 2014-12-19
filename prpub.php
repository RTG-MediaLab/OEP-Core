<?php
require('/files/scripts/commonWebLibrary.php');
require('/files/scripts/commonWebLibrary_publisher.php');

if (isset($_GET['show'])) {

	$show = $_GET['show'];

	if ($show == 'random') {
	        list($project, $user) = Publisher::getRandProject();
	        ShowProject($project, $user);
	}
	else if (is_numeric($show)) {
	        $id = $show;
	        list($project, $user) = Publisher::getProjectById($id);
	        ShowProject($project, $user);
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
else if (isset($_GET['new'])) {
	if (!isset($_SERVER['LAN_VISITOR'])) { # Only allow LAN users for security reasons.
		die('Only local access (LAN) allowed.');
	}
        HTML_frame::beginFrame('Project publisher');
	if (isset($_POST['submit']) && CommonLibrary::authUser($_POST['user'], $_POST['password'])) {
		$res = Publisher::saveProject($_POST['user'], $_POST['title'], $_POST['desc'], $_POST['url'], array($_POST['img1'], $_POST['img2'], $_POST['img3']));
                echo "<h1>Add new project</h1><hr><br>";
		echo $res ? 'Your project was successfully added.' : 'Failed to add your project.';
		echo "<br><br>";
		echo "<a href='?listby=$_POST[user]'>View submitted projects by $_POST[user]</a>";
	}
	else {
		?>
		<h1>Add new project</h1><hr><br>
                <?php
		$FAIL = isset($_POST['submit']);
		if ($FAIL) {
                        echo "<b><font color='red'>Login failed, try again.</font></b><br><br>";
                }
		?>
		<form method='POST' name='form' onsubmit="desc = document.getElementById('desc'); if (desc.value.length > <?php echo Publisher::PUBL_MAX_DESC;?>){alert('Your description text is too long. It must be less than <?php echo Publisher::PUBL_MAX_DESC;?> characters - you are using '+desc.value.length); return false;}">
			<b>Username</b><br>
			<input type='text' name='user' value='<?php echo ($FAIL) ? $_POST['user'] : '';?>'><br>
			<br>
			<b>Password</b><br>
			<input type='password' name='password'><br>
			<br>
			<b>Title</b><br>
                        <input type='text' name='title' maxlength='<?php echo Publisher::PUBL_MAX_TITLE;?>' size='<?php echo Publisher::PUBL_MAX_TITLE;?>' value='<?php echo ($FAIL) ? $_POST['title'] : 'Project title in maximum '.Publisher::PUBL_MAX_TITLE.' characters.';?>'><br>
			<br>
			<b>Project URL</b><br>
                        <input type='text' name='url' size='60' value='<?php echo ($FAIL) ? $_POST['url'] : '';?>'><br>
			<br>
			<b>Image 1</b><br>
                        <input type='text' name='img1' size='60' value='<?php echo ($FAIL) ? $_POST['img1'] : '';?>'><br>
			<br>
                        <b>Image 2</b><br>
                        <input type='text' name='img2' size='60' value='<?php echo ($FAIL) ? $_POST['img2'] : '';?>'><br>
			<br>
                        <b>Image 3</b><br>
                        <input type='text' name='img3' size='60' value='<?php echo ($FAIL) ? $_POST['img3'] : '';?>'><br>
			<br>
			<b>Project description</b><br>
			<textarea name='desc' id='desc' cols='60' rows='10' maxlength='<?php echo Publisher::PUBL_MAX_DESC;?>'><?php echo ($FAIL) ? $_POST['desc'] : 'Write a description of you project here in maximum '.Publisher::PUBL_MAX_DESC.' characters.' ;?></textarea>
			<br><br>
			<input type='hidden' name='submit' value='1'>
			<input type="submit" value="Submit">
		</form>
		<?php
	}
        HTML_frame::endFrame();
}
else {
	HTML_frame::beginFrame('Project publisher');
	echo "<h1>Project publisher</h1><hr>";
	echo "<a href='?new=1'>Add new project</a><br><br>\n";
	echo "<table>";
	foreach (Publisher::getAllProjects() as $pr) {
		mkPrRow($pr);
       	}
	echo "</table>";
        HTML_frame::endFrame();
}

function mkPrRow($pr) {
	echo "<tr>
		<td><a href='?show=".$pr[0]->id."'>".$pr[0]->title."</a></td>
		<td> by <a href='?listby=".$pr[0]->uid."'>".$pr[1]->cn."</a></td>
		<td>".HTML_frame::textdate($pr[0]->date)."</td>
	</tr>\n";
}

function ShowProject($project, $user) 
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
	else {
	        echo "<h2>$project->title <span style='font-weight:normal;'> af $user->cn, ".HTML_frame::textdate($project->date)."</span></h2>\n";
	        echo '<a href="' . htmlentities($project->projecturl) . '">' . "<b><span style='font-size:16pt;'>".htmlentities($project->projecturl)."</span></b></a>";
		echo "<hr>";
	        echo "<table style='width: 100%'><tr>\n";
	        foreach (array($project->img1url,$project->img2url,$project->img3url) as $imgurl)
	                echo "<td><img width='".Publisher::PUBL_IMG_X."' src='$imgurl' alt='$imgurl' /></td>";
	        echo "</tr></table>\n";
	        echo "<h2>Om projektet</h2><p style='font-size:14pt;'>$project->description</p>\n";
	}
	echo "</body>\n";
	echo "</html>\n";
}
?>
