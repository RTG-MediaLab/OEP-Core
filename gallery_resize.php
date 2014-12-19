<?php
require('/files/scripts/commonWebLibrary_gallery.php');
if (!isset($_SERVER["argv"][1])) {
	die("Please specify a gallery.\nUsage: ".$_SERVER["argv"][0]." GALLERY_NAME\n");
}
$gallery = $_SERVER["argv"][1]; 
if ($gallery == '__ALL__') {
	foreach (OEPGallery::getGalleryNames() as $gallery) {
		echo "Resizeing '$gallery', please wait (this may take a while)...";
	        OEPGallery::resizeGallery($gallery);
		echo "Done.\n";
	}
}
else {
	echo "Resizeing '$gallery', please wait (this may take a while)...";
	OEPGallery::resizeGallery($gallery);
	echo "Done.\n";
}
?>
