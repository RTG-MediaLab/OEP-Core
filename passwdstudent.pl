#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2010, All rights reserved.
package CL;
#use warnings;
use strict;
use utf8;
use Term::ReadKey;
require '/files/scripts/commonLibrary_passwd.pl';

#########################################
# passwd.pl difference
#########################################

sub verifyUserLogin
{
        my ($nick, $passwd) = @_;
        my $ldap = Net::LDAP->new($CL::LDAP_HOST) or die "$@";
        my $mesg = $ldap->bind("uid=$nick,$CL::LDAP_BASE_USERS", password => $passwd);
        $ldap->unbind();
        return !$mesg->is_error();
}

$ARGV[0] = `whoami`;
chomp($ARGV[0]);
die("User $ARGV[0] does not exist.\n") unless getpwnam $ARGV[0];

print "Changing password for $ARGV[0].\n";
ReadMode('noecho');
my $password_old;
do {
	print "What is your current password, $ARGV[0]?\n";
	$password_old = ReadLine(0);
	chomp($password_old);
} while (!verifyUserLogin($ARGV[0], $password_old));

########################################
# The rest is identical to passwd.pl
########################################

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
#my $exitStatus = CL::chPasswd($ARGV[0], $password, $CL::LDAP_ROOTPASSWD, $CL::LDAP_ROOT);
my $exitStatus = CL::chPasswd($ARGV[0], $password, $password_old);
ReadMode('restore');
print (($exitStatus) ? "Successfully changed LDAP password.\n\n" : "Failed to change LDAP password. ldappasswd exit status was $exitStatus\n\n");
exit 0;
