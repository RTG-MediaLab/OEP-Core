#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2009-2010, All rights reserved.
package CL;
use warnings;
use strict;
use utf8;

# Do not add trailing / to the *_BASE variables below.
our $HOMES_BASE          = '/files'; # Path in which year-interval folders are create in which in turns the students' homes lie.
our $SYS_BASE            = '/files/scripts'; # Path in which script outputs are placed.
our $ADM_HOMES_BASE	 = '/files/system'; # Admin homes are located here.
our $BACKUP_BASE 	 = '/backup';

our $LDAP_HOST           = '127.0.0.1';
our $LDAP_BASE_ROOT      = 'dc=rtgkom';
our $LDAP_BASE_USERS     = 'ou=People,'.$LDAP_BASE_ROOT;
our $LDAP_BASE_GROUPS    = 'ou=Group,'.$LDAP_BASE_ROOT;

our $MYSQL_HOST		 = 'localhost'; # = 10.0.0.15

our $INFOFILE_PATH       = "$CL::SYS_BASE/passwd_files"; # Here student info files (password files) are stored.
our $INFOFILE_TITLE	 = "MediaLab elevkonto til www.rtgkom.dk";
our $INFOFILE_MESSAGE	 = "Husk at dit kodeord er HEMMELIGT!!!\nØnsker du at skifte dit kodeord så se her: http://rtgkom.dk/wiki/Guide:_UNIX_password";

our $GID_STUDENTS        = 1005; # Primary GID shared by all students.
our $SMB_SID_BASE        = 'S-1-0-0'; # You should in general NOT change this!

# Projects
our $PROJECTS_HOME = $HOMES_BASE.'/projects';
our $DB_NAME = 'rtgprojects';
our $LDAP_BASE_PROJECTS_USERS = 'ou=prusers,'.$LDAP_BASE_ROOT;
our $LDAP_BASE_PROJECTS_GROUPS = 'ou=prgroups,'.$LDAP_BASE_ROOT;


1;
