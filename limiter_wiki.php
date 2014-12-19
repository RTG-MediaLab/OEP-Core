<?php
// Nicholas Mossor Rathmann Oct 2011
error_reporting(E_ALL);
$wgServerUser = 1; # User ID to use for logging if no user exists
$wgExtensionCredits['other'][] = array(
	'name'        => 'Limiter',
	'author'      => 'Nichoals Rathmann',
	'description' => 'Limiter',
	'url'         => '',
	'version'     => '0.1 Oct 2011',
	);

$lobj = (object) array();
$lobj_fields = array('domains','access', 'defaultaccess', 'grp','datefrom','dateto', 'msg'); # 'name' and 'author' fields are added later in Limiter_pageSave() when $paser has their values (wiki page name, wiki page submitter login) stored.

$wgHooks['ParserFirstCallInit'][] = 'efExampleParserFunction_Setup';
function efExampleParserFunction_Setup( &$parser ) {
    $parser->setHook( 'limiter', 'limiterRender' );
	return true;
}

function limiterRender( $text, $params = array(), $parser ) {
	global $lobj;
	global $lobj_fields;

    // Missing keys?
    sort($lobj_fields);
    $param_keys = array_keys($params);
    sort($param_keys);
	if ($lobj_fields !== $param_keys) {
    	return "<p style='color:red;'><b>Limiter error: You must supply all the limiter keys:</b> <br>".implode('<br>',$lobj_fields)."<br><b>You are missing:</b> <br>".implode('<br>', array_diff($lobj_fields, $param_keys))."</p>";
	}
//	return "RECIEVED KEYS: ".implode('<br>',  $param_keys);

    // Save keys for later processsng if page save is exec.
    foreach ($lobj_fields as $f) {
        $lobj->$f = $params[$f];
    }
    
    // Validate fields 
    $errors = array();
    foreach ($lobj_fields as $f){
        if (($f == 'datefrom' || $f == 'dateto') && !__isValidDateTime($lobj->$f)) {
           $errors[] = "You must specify the <i>$f</i> field in this format: Y-M-D H:M:S &nbsp;&nbsp; e.g.: 2011-11-28 15:30:00";
        }
        if (($f == 'access' || $f == 'defaultaccess') && $lobj->$f != 'yes' && $lobj->$f != 'no') {
           $errors[] = "You must specify the <i>$f</i> field as either <i>yes</i> or <i>no</i>";
        }
    }
    if (!empty($errors)) {
        $err = '';
        foreach ($errors as $e) {
            $err .= "<font color='red'><b>Limiter error: Bad field value:</b> $e</font><br>\n";
        }
        if (!empty($err)) {
            return $err;
        }
    }
	
	// Return/output HTML comment with keys
	$ret = '<!-- limiter active: ';
	foreach ($params as $k => $v) {
	    $ret .= "\n$k = $v";
	}
    return $ret."\n-->";
}
function __isValidDateTime($dateTime)
{
    if (preg_match("/^(\d{4})-(\d{2})-(\d{2}) ([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$/", $dateTime, $matches)) {
        if (checkdate($matches[2], $matches[3], $matches[1])) {
            return true;
        }
    }

    return false;
} 

// Hooks
$wgHooks['ArticleSaveComplete'][] = 'Limiter_pageSave';
function Limiter_pageSave(&$article, &$user, $text) {
    global $wgParser, $lobj;
    $lobj->name = str_replace(' ', '_', $wgParser->getOutput()->mTitleText);
    $lobj->author = strtolower($wgParser->mOptions->mUser->mName);
#    print_r($lobj);
#    print_r($wgParser->getOutput());
#    die();
    include('extensions/limiter_xmlconf_sync.php');
    xmlconf_sync($lobj);
    return true;
}

