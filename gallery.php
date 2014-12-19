<?php
require('/files/scripts/commonWebLibrary.php');
require('/files/scripts/commonWebLibrary_gallery.php');
error_reporting(E_ALL);

if (isset($_GET['gallery'])) {
	$gallery = $_GET['gallery'];
	$title = OEPGallery::getTitle($gallery);
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
		<title><?php echo $title;?></title>
		<link rel="stylesheet" href="smoothgallery/css/layout.css" type="text/css" media="screen" charset="utf-8" />
		<link rel="stylesheet" href="smoothgallery/css/jd.gallery.css" type="text/css" media="screen" charset="utf-8" />
		<script src="smoothgallery/scripts/mootools-1.2.1-core-yc.js" type="text/javascript"></script>
		<script src="smoothgallery/scripts/mootools-1.2-more.js" type="text/javascript"></script>
		<script src="smoothgallery/scripts/jd.gallery.js" type="text/javascript"></script>
		<style type="text/css">
			#myGallery
			{
				width: <?php echo ceil(OEPGallery::$SCALES[OEPGallery::SCALE__MEDIUM]['new_height']*4.0/3);?>px !important;
				height: <?php echo OEPGallery::$SCALES[OEPGallery::SCALE__MEDIUM]['new_height'];?>px !important;
			} 
		</style>
	</head>
	<body>
		<h1><?php echo $title;?></h1>

		<script type="text/javascript">
			function startGallery() {
				var myGallery = new gallery($('myGallery'), {
					timed: true,
					showInfopane: false
				});
			}
			window.addEvent('domready',startGallery);
		</script>
		<div class="content">
			<div id="myGallery">
                <?php
                foreach (OEPGallery::getImageURLs($gallery) as $img ) {
			        ?>
			        <div class="imageElement">
				        <h3><?php echo $img;?></h3>
				        <p></p>
				        <a href="<?php echo $img;?>" title="open image" class="open"></a>
				        <img src="<?php echo OEPGallery::getPrefixedName($img, OEPGallery::SCALE__MEDIUM);?>" class="full"/>
				        <img src="<?php echo OEPGallery::getPrefixedName($img, OEPGallery::SCALE__THUMB);?>" class="thumbnail" />
			        </div>
			        <?php
		        }
                ?>
			</div>
		</div>
	</body>
</html>

<?php

}
else {
	HTML_frame::beginFrame('Gallery');
	echo "<h1>Image galleries</h1><hr>";
	foreach (array_reverse(OEPGallery::getGalleryNames()) as $gallery) {
		echo "<a href='?gallery=$gallery'>".OEPGallery::getTitle($gallery)."</a><br>\n";
	}
        HTML_frame::endFrame();
}

?>
