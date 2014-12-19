<?php
/* 
    Nicholas Mossor Rathmann, 2009, All rights reserved.
*/
error_reporting(E_ALL);
require_once('commonWebLibrary.php');
HTML_frame::beginFrame('StudieWebs');
$klasser = CommonLibrary::getGroups();

if (isset($_GET['year'])) {
    echo "<h1>Årgang $_GET[year]'</h1><hr><br>\n";
    foreach (CommonLibrary::getMembersOfYear($_GET['year']) as $usr => $about)
        print "<a href='http://www.rtgkom.dk/~$usr'>$about[cn]</a><br>\n";     
}
else if (isset($_GET['gid'])) {
    echo '<h1>'.$klasser[$_GET['gid']]."</h1><hr>\n";
    $users = array();
    foreach (CommonLibrary::getMembersOfGroup((int) $_GET['gid']) as $usr => $about) {
        print "<a href='http://www.rtgkom.dk/~$usr'>$about[cn]</a><br>\n";
        $users[] = "window.open('http://www.rtgkom.dk/~$usr');";
    }
    echo "<br>- <b>".count($users)." users total<b><br>";
    echo "- <a href='#' onclick=\"".implode('', $users)."\"><b>Open all studiewebs in new tabs/windows</b></a><br>";
}
else {
    ?>
    <table style='width:100%;'><tr valign='top'><td style='width: 60%;'>
        <h1>Klasser</h1> <hr><br>
        <?php
        foreach (array_reverse($klasser,true) as $gid => $name)
            print "<a href='students.php?gid=$gid'>$name</a><br>\n";
        ?>
        </td><td>
        <h1>Årgange</h1> <hr><br>
        <?php
        foreach (CommonLibrary::getYearRange() as $year)
            print "<a href='students.php?year=".sprintf('%02d', $year%100)."'>$year-".($year+1)."</a><br>\n";
        ?>
        </td></tr></table>
        <?php
}
HTML_frame::endFrame();
?>

