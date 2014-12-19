<html>
<head>
</head>
<body>
<?php
error_reporting(E_ALL);
require_once('commonWebLibrary.php');
HTML_frame::beginFrame('StudieWebs');
$klasser = CommonLibrary::getGroups();


if ( ! function_exists('glob_recursive'))
{
    // Does not support flag GLOB_BRACE
        
            function glob_recursive($pattern, $flags = 0)
                {
                        $files = glob($pattern, $flags);
                                
                                        foreach (glob(dirname($pattern).'/*', GLOB_ONLYDIR|GLOB_NOSORT) as $dir)
                                                {
                                                            $files = array_merge($files, glob_recursive($dir.'/'.basename($pattern), $flags));
                                                                    }
                                                                            
                                                                                    return $files;
                                                                                        }
                                                                                        }


if (!isset($_POST['action'])) {
	?>
	<center><h1>Mappe statistik</h1></center>
	<form method='POST'>
	<b>Klasse</b><br>
	<select name='gid'>
	<?php
	foreach (array_reverse($klasser,true) as $gid => $name)
    	print "<option value='$gid'>$name</option>\n";
	?>
	</select><br>
	<br><b>Søg efter mappen</b><br>
	<input type='text' value='html/PROJEKTKMAPPE' size='60' name='dir'>
	<input type='hidden' name='action' value='class_status'><br>
	<br><input type='submit' value='Vis statistik'>
	</form>
	<?php
}
elseif ($_POST['action'] == 'class_status') {
	echo '<h1>'.$klasser[$_POST['gid']]."</h1>\n";
	echo '<h3>Søger efter mappen "'.$_POST['dir'].'"</h3>';
	echo "<hr>";
	echo "<table width='100%' border='0'>\n";
	echo "<tr style='font-weight:bold'><td>Navn</td> <td>Mappe oprettet?</td> <td>Antal filer</td> <td>Størrelse</td> <td>Seneste redigering</td> <td>Tidligste redigering</td>  <td>Vis alle filer i mappen</td></tr>";
	echo "<tr><td></td></tr>";
	$users = CommonLibrary::getMembersOfGroup((int) $_POST['gid']);
    foreach ($users as $nick => $about) {
    	$usr = CommonLibrary::getMember($nick);
    	$usr->home = CommonLibrary::getField($nick, 'homeDirectory');
    	$dir = $usr->home."/$_POST[dir]"; 
    	?>
    	<tr>
    	<td>
	        <?php print "$usr->cn\n"; ?>
        </td>
        <td><?php echo is_dir($dir) ? 'Ja': '<font color="red"><b>Nej</b></font>';?></td>
        <td><?php echo count(glob_recursive($dir. "/*"))?></td>
        <td>
        <?php
        $output = exec('du -sk ' . $dir);
        echo sprintf('%.1f',trim(str_replace($dir, '', $output))) .'KB';
        ?>
        </td>
        <td>
            <?php echo exec("ls -lrt $dir/ | awk '{print \$6,\$7,\$8}' | tail -n1"); ?>
        </td>
        <td>
            <?php echo exec("ls -lrt $dir/ | awk '{print \$6,\$7,\$8}' | head -n2"); ?>
        </td>
        <td>
        	<i>Ikke implementeret</i>
        </td>
		</tr>
		<?php
    }
    echo "<tr><td colspan='4'></td> <td colspan='2'><b>BEMÆRK: Seneste og tidligste redigeringsdatoer<br> gælder KUN for filer i den søgte mappe,<br> men IKKE for filer i undermapper!</b></td> <td></td></tr>";
	echo "</table>\n";
	?>
	<br>
	<hr>
	<table>
	<tr>
	<td valign="top">
	
	<b>Ønsker du at oprette denne mappe for alle elever?</b><br>
	Log på webserveren via shell/putty, og kopire de understående kommandoer ind i terminalen, og tryk enter.<br><hr><br>
	<small><i>
	<?php 
	foreach ($users as $user => $about) {
		echo "sudo mkdir -p ~$user/$_POST[dir];<br>";
		echo "sudo chown $user ~$user/$_POST[dir];<br>";
	}
	echo "</i></small>";
	?>
	</td>
	<td valign="top">
	
	<b>Ønsker du at låse denne mappe for alle elever, så de <i>ikke</i> kan skrive til mappen længere?</b><br>
	Log på webserveren via shell/putty, og kopire de understående kommandoer ind i terminalen, og tryk enter.<br><hr><br>
	<small><i>
	<?php 
	foreach ($users as $user => $about) {
		echo "sudo chown root ~$user/$_POST[dir];<br>";
	}
	echo "</i></small>";
	?>
	                                        
	</td>
	<td valign="top">
    <b>Ønsker du at låse op for denne mappe for alle elever, så de <i>kan</i> skrive til mappen?</b><br>
	Log på webserveren via shell/putty, og kopire de understående kommandoer ind i terminalen, og tryk enter.<br><hr><br>
    <small><i>
    <?php 
    foreach ($users as $user => $about) {
    	echo "sudo chown $user ~$user/$_POST[dir];<br>";
    }
    echo "</i></small>";
    ?>
	</td>
	</tr>
	</table>
	<?php
}
elseif ($_POST['action'] == 'student_status') {

}
HTML_frame::endFrame();


?>
</body>

</html>
