#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2009-2010, All rights reserved.

# Adds an administrative user to the system.
# Arguments: Full name of user, username.
# Example: addadmin.pl "Nicholas Mossor Rathmann" "nmr"

use warnings;
use strict;
use utf8;
require '/files/scripts/commonLibrary.pl';

# Ensure that user entered exactly two arguments.
die("Usage:\t\t$0 \"Full name\" USERNAME\nEXAMPLE:\t$0 \"Nicholas Mossor Rathmann\" nmr\n") unless (@ARGV == 2);

# Exit if user already exists.
die("User $ARGV[0] already exists.\n") if (getpwnam $ARGV[1]);

# Get name and username from arguments.
my ($name, $nick) = @ARGV;

# Make admin user with the given name.
CL::mkAdmin($name, $nick);

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
