#!/usr/bin/perl
# Nicholas Mossor Rathmann, August 2009, All rights reserved.

# Adds a user to the system.
# Arguments: Full name of user, year, class number, (username).
# Example: addadmin.pl "Nicholas Mossor Rathmann" 2005 3

use warnings;
use strict;
use utf8;
require '/files/scr,ipts/commonLibrary.pl';

# Ensure that user entered three or four arguments.
die ("Usage:\t\t$0 \"Full name\" Year Classnumber [Username]\nEXAMPLE:\t$0 \"Nicholas Mossor Rathmann\" 2005 3\nEXAMPLE:\t$0 \"Nicholas Mossor Rathmann\" 2005 3 alternativeuid05\n") if (@ARGV != 3 && @ARGV != 4);

# Get variables from arguments.
my ($name, $year, $classnr, $custom_nick) = @ARGV;

# Exit if user already exists.
die("User $custom_nick already exist.\n") if (defined($custom_nick) && getpwnam $custom_nick);

# Get nickname and password file for user.
my ($nick, $infofile) = CL::mkUser($name, $year, $classnr, $custom_nick);

print "User '$name' was created as '$nick'. The password file has been saved at: '$infofile'.\n";
