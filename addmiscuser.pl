#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2009-2010, All rights reserved.

# Adds a miscellaneous user to the system.
# Arguments: Username
# Example: addmiscuser.pl "brobyg13"

use warnings;
use strict;
use utf8;
require '/files/scripts/commonLibrary.pl';

# Ensure that user entered exactly one argument.
die("Usage:\t\t$0 NICKNAME\nEXAMPLE:\t$0 brobyg13\n") unless (@ARGV == 1);

# Exit if user already exists.
die("User $ARGV[0] already exists.\n") if (getpwnam $ARGV[0]);

# Get username from argument.
my ($nick) = @ARGV;

# Make misc user with the given name.
CL::mkMiscUser($nick,'misc');

# Check if user was correctly added to the LDAP datbase.
my $user = CL::mkUserObj($nick);
if ($user) {
	print "OK. To set the password of for $nick run the passwd script.\n";
	exit 0;
}
else {
	print "Some unexplained error occurred. The admin could not be created.\n";
	exit 1;
}
