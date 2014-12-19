#!/usr/bin/php -q
<?php
require('/files/scripts/commonWebLibrary_eventlogger.php');
EventLogger::setEvent(trim(`whoami`), EventLogger::EVENT_SSH_LOGIN);

?>

