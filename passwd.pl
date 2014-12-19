#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2009, All rights reserved.
package CL;
#use warnings;
use strict;
use utf8;
use Term::ReadKey;
require '/files/scripts/commonLibrary_credentials.pl';
require '/files/scripts/commonLibrary_passwd.pl';

die("usage:\t\t$0 USERNAME\nEXAMPLE:\t$0 nicholasmr05\n") if (@ARGV != 1);
die("User $ARGV[0] does not exist.\n") unless getpwnam $ARGV[0];

print <<EOF;
---------------------
Password requirements
---------------------
EOF
my $password;
my ($req_ref,$desc_ref) = CL::getPasswdRequirements();
my %req = %$req_ref;
my %desc = %$desc_ref;
while ( my ($key, $value) = each(%req) ) {
	print "\t- ".$desc{$key}."\n";
}
print "\nRandomly generated password you may use: ".CL::randPasswd()."\n";
print "\nEnter new password: ";
ReadMode('noecho');
while($password = ReadLine(0)) {
	chomp($password);
	my (%failed) = CL::validatePasswd($password);
	my $failure = 0;
	print "\n";
	print <<EOF;

-----------------
Validation result
-----------------
EOF
	while (my ($key, $failed) = each(%failed) ) {
	    print ($failed ? 'Failed' : 'OK');
	    print "\t - " . $desc{$key} . "\n";
	    $failure = 1 if ($failed);
	}

	last if (!$failure);
	print "\nYour new password did not pass validation. Try again.\n";
	print "\nRandomly generated password you may use: ".CL::randPasswd()."\n";
	print "\nEnter new password: ";
}
print "\nPassword passed validation successfully.\n\n";
my $exitStatus = CL::chPasswd($ARGV[0], $password, $CL::LDAP_ROOTPASSWD, $CL::LDAP_ROOT);
ReadMode('restore');
print (($exitStatus) ? "Successfully changed LDAP password.\n\n" : "Failed to change LDAP password. ldappasswd exit status was $exitStatus\n\n");
exit 0;
