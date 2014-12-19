<?php
error_reporting(E_ALL);

class OEPGallery 
{
	const PATH = '/files/www/images';
	const URL_PATH = "http://www.rtgkom.dk/gallery";

	const SCALE__MEDIUM = 'medium'; # Index for $SCALES, NOT actual scale values.
	const SCALE__SMALL  = 'small';
	const SCALE__THUMB  = 'thumb';
	public static $SCALES = array(
		self::SCALE__MEDIUM => array('new_height' => 864), 
		self::SCALE__SMALL  => array('new_height' => 400), 
		self::SCALE__THUMB  => array('new_height' => 75), 
	);
	
	const CompressionQuality = 90; # For JPG on image scaling.

/*
	const DIM__THUMB_SG_X = 100;
	const DIM__THUMB_SG_Y = 75;
	const DIM__WIKI_SG_X = 520;
	const DIM__WIKI_SG_Y = 400;
	const DIM__FULL_SG_X = 1152;
	const DIM__FULL_SG_Y = 864;
	public static $DIM__ALL = array(
		'THUMB_SG' => array(self::DIM__THUMB_SG_X, self::DIM__THUMB_SG_Y), 
		'WIKI_SG'  => array(self::DIM__WIKI_SG_X,  self::DIM__WIKI_SG_Y), 
		'FULL_SG'  => array(self::DIM__FULL_SG_X,  self::DIM__FULL_SG_Y),
	);
*/

	public static function getGalleryNames() {
		return array_map(create_function('$dir', 'return basename($dir);'), self::getGalleries());
	}

	public static function getGalleries() {
		$galleries = glob(self::PATH.'/*' , GLOB_ONLYDIR);
		return $galleries;
	}

	public static function getImages($gallery, $onlyFileNames = false) {
		$images = glob(self::PATH."/$gallery/*.{jpg,JPG,jpeg,JPEG,png,PNG,gif,GIF,tiff,TIFF,bmp,BMP}", GLOB_BRACE);
#               print_r($images);
#		$images = array_filter($images, create_function('$f', 'return substr_count($f, ".") < 2;'));
		$images = array_filter($images, "self::isOrigional");
##               print_r($images);
#foreach ($images as $img) {
#	print "$img, ".substr_count($img, ".")."<br>\n";
#}
		return ($onlyFileNames) ? array_map(create_function('$img', 'return str_replace("'.self::PATH."/".'", "", $img);'), $images) : $images;
	}

    public static function getImageURLs($gallery) { 
            return array_map(create_function('$img', 'return "'.self::URL_PATH.'/$img";'), self::getImages($gallery, true));
    }

	public static function resizeGallery($gallery) {
        foreach (self::getImages($gallery) as $file) {
#            if (!self::isOrigional($file)) { # Tested for in getImages()
#                continue;
#            }
			foreach (self::$SCALES as $scale => $desc) {
                		$thumb = new Imagick($file);
                		$geo = $thumb->getImageGeometry();
    					list($w, $h) = array($geo['width'], $geo['height']);
                		$thumb->scaleImage(0, $desc['new_height']); # This scales the image such that it is now $desc['new_height'] pixels wide, and automatically calculates the height to keep the image at the same aspect ratio.
                        if (1) { # Check if .jpg 
                            $thumb->setImageCompression(imagick::COMPRESSION_JPEG);
                            $thumb->setImageCompressionQuality(self::CompressionQuality);
                            $thumb->stripImage();
                        }
                		$thumb->writeImage(self::getPrefixedName($file, $scale));
                		$thumb->destroy();
			}
		}
	}
    
    public static function isOrigional($file) {
        return !preg_match("/^(".implode('|', array_keys(self::$SCALES)).")/i", basename($file));
    }

	public static function getPrefixedName($file, $scale) {
	    return dirname($file).'/'.$scale.'_'.basename($file);
	}
	
//------------------- Deprecated !
/*
	        public static function getResizeSuffix($file, $dim) {
		        return "_".self::$DIM__ALL[$dim][0]."_x_".self::$DIM__ALL[$dim][1].'.'.self::getExt($file);
	        }

	        private static function getExt($file) {
		        $file = basename($file);
		        return $ext = substr($file, strrpos($file, '.') + 1);
	        }
*/
//-------------------
	public static function getTitle($gallery) {
	        $date = preg_replace('/(\d{4})\_(\d{2})\_(\d{2})\_\_(.*)/i', '$1/$2/$3', $gallery);
	        $name = preg_replace('/(\d{4})\_(\d{2})\_(\d{2})\_\_(.*)/i', '$4', $gallery);
	        $name = str_replace('_', ' ', $name);
	        return $title = "$date &nbsp;- &nbsp;$name";
	}

	public static function getInfo($gallery) {
		$filename = self::PATH."/$gallery/info.txt";
		if (!file_exists($filename)) {
			return array();
		}
		$lines = file($filename);
		$info = array();
		foreach ($lines as $l) {
			list($file, $desc) = explode(':', $l);
			$info[$file] = $desc;
		}
		return $info;
	}
}
?>
