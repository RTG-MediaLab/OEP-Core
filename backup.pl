#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2009-2010, All rights reserved.

# Backs up important system and user files.
# Arguments: None.
# Example: backup.pl

use warnings;
use strict;
require '/files/scripts/commonLibrary_header.pl';
require '/files/scripts/commonLibrary_credentials.pl';

my $week = getWeek();
my $year = getYear();

# Determine directories to bacup, this includes:
# system, www, scripts, current user files, and 3 years back.
my @dirs_to_backup = (
    "$CL::HOMES_BASE/".($year-3).'-'.($year-2),
    "$CL::HOMES_BASE/".($year-2).'-'.($year-1),
    "$CL::HOMES_BASE/".($year-1).'-'.($year),
    "$CL::HOMES_BASE/".($year).  '-'.($year+1),
    "$CL::HOMES_BASE/scripts",
    "$CL::HOMES_BASE/www",
    "$CL::HOMES_BASE/system"
);

# Determine location to back various files up to.
my $dest = "$CL::BACKUP_BASE/week$week";
my $sql =  "$dest/mysql_${week}.sql";
my $ldif = "$dest/ldap_${week}.ldif";

# Remove anything at backup destination.
system("/bin/rm -R $dest");

# Make destination directory.
system("/bin/mkdir $dest");

# Copy directories to backup location.
system("/bin/cp -R ".join(' ', @dirs_to_backup)." $dest");

# Create a MySQL dump to the backup location.
system("/usr/bin/mysqldump -u $CL::MYSQL_ROOT -p$CL::MYSQL_ROOTPASSWD --all-databases > $sql");

# Backup all LDAP data to the backup location.
system("/usr/bin/ldapsearch -L -x -w $CL::LDAP_ROOTPASSWD -D '$CL::LDAP_ROOT' -b '$CL::LDAP_BASE_ROOT' > $ldif");

# Ensure file owner only, can read the MySQL and LDAP files.
chmod 0400, $ldif;
chmod 0400, $sql;

sub getWeek {
        my $week;
        $week = `date +%V`;
        chomp($week);
        return $week;
}

sub getYear {
        my $year;
        $year = `date +%Y`;
        chomp($year);
        return $year;
}
