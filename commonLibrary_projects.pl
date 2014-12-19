#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2011, All rights reserved.
package CL;
use warnings;
use strict;
use utf8;
use Net::LDAP;
use DBI; # DB Interface
use File::Path; # mkpath() and rmtree()
require '/files/scripts/commonLibrary_header.pl';
require '/files/scripts/commonLibrary.pl';

sub createProject {

	my ($name, $title, $date_open, $date_close, $ref_members) = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#	$year = sprintf("%02d", ($year+1900) % 100);
#	$name = $name."_$year";
	return 1 if (length($name) > 32); # Max. unix name length is 32, we use "_XX" for year suffix.

	my $dbh = projectMysqlUp();
    	
	# Make DB entries
    $dbh->do("INSERT INTO projects (name, title, open, date_create, date_open, date_close) VALUES('$name', '$title', 1, NOW(), '$date_open', '$date_close')");
    my $sth = $dbh->prepare("SELECT prid FROM projects WHERE name = '$name'");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();  
    my $prid = $ref->{'prid'};
	foreach my $usr (@$ref_members) {
		CL::addMemberToProject($usr,$prid,$year);
	}
#    $dbh->disconnect();

    # Make project user
    CL::mkProjectLDAPUser($name);

	# Update LDAP group with members
	CL::makeProjectLDAPGroup($prid);
	CL::syncProjectLDAPGroup($prid);
	
	# Create folders etc
	CL::syncProjectDirStruct($prid);
	CL::lockProjectDirs($prid, 'open');
	return 0;                                                           
}

#sub editProject {}
#sub renameProject {}
sub deleteProject {
	my ($prid) = @_;
	# Delete LDAP entries
    my $ldap = CL::bindLDAP();
    my $prname = CL::getProjectName($prid);
	$ldap->delete(CL::getPrGroupDN($prname));
	$ldap->delete(CL::getPrUserDN($prname));
	# Delete files and dirs
	rmtree($CL::PROJECTS_HOME."/$prname");
	# MySQL entries
	my $dbh = CL::projectMysqlUp();
	$dbh->do("DELETE FROM members WHERE prid = $prid");
	$dbh->do("DELETE FROM projects WHERE prid = $prid");
	
	return 0;
}

sub addMemberToProject {
	my ($usr,$prid,$year) = @_;
    my $dbh = CL::projectMysqlUp();
	my $user = CL::mkUserObj($usr);
    my $uid = $user->get_value('uidNumber');
    foreach my $grp (CL::getGroupMemberships($usr)) {
    	next if ($grp !~ m/^\d{4}\_/);
    	my $group = CL::mkGroupObj($grp, 0);
    	my $gid = $group->get_value('gidNumber');
        $dbh->do("INSERT INTO members (prid, uid, gid, year) VALUES($prid, $uid, $gid, $year)");
    }
    $dbh->disconnect();
    return 0;                                                     
}

sub removeMemberFromProject {}

sub mkProjectLDAPUser
{
    my ($nick) = @_;
    my $passwd = CL::randPasswd();
    my ($passwd_crypt) = CL::passwdHashes($passwd);
    my $home = "$CL::PROJECTS_HOME/$nick";
    my $ldap = CL::bindLDAP();
    my $mesg = $ldap->add(CL::getPrUserDN($nick),
         attrs => [
              'uid'           => $nick,
              'cn'            => $nick,
              'userPassword'  => "{crypt}$passwd_crypt",
          	  'loginShell'    => '/bin/false',
              'uidNumber'     => CL::getFreeUID(),
              'gidNumber'     => $CL::GID_STUDENTS,
              'homeDirectory' => $home,
              'gecos'         => $nick,
              'sn'            => $nick,
              'mail'          => '',
              'mobile'        => '0',
              'employeeNumber'=> '0',
              'employeeType'  => '0',
#              'sambaAcctFlags'    => '[UX         ]',
#              'sambaLMPassword'   => $LMpasswd,
#              'sambaNTPassword'   => $NTpasswd,
#              'sambaSID'      => "$CL::SMB_SID_BASE-$sambaSID",
#              'sambaPrimaryGroupSID'  => "$CL::SMB_SID_BASE-$sambaPGSID",
              'objectclass'       => ['top', 'posixAccount', 'person', 'inetOrgPerson'],
         ]
     );
     #CL::unbindLDAP($ldap);
     return !$mesg->is_error();
}

sub makeProjectLDAPGroup {
	my ($prid) = @_;
	my $ldap = CL::bindLDAP();
	my $name = CL::getProjectName($prid);
    my $mesg = $ldap->add(CL::getPrGroupDN($name),
	    attrs => [
         'cn'           => $name,
         'userPassword' => "{crypt}*",
      	 'gidNumber'    => CL::getFreeGID(),
         'objectclass'  => ['top', 'posixGroup'],
        ]
   );
#   CL::unbindLDAP($ldap);
   return 0;   
}

sub syncProjectLDAPGroup {
	my ($prid) = @_;
	my %members = CL::getProjectMembers($prid);
	my @members = keys(%members);
	push @members, CL::getProjectName($prid); # Also add project user to own group.
    my $ldap = CL::bindLDAP();
    my $mesg = $ldap->modify(CL::getPrGroupDN(CL::getProjectName($prid)), replace => {memberUid => \@members});
#    CL::unbindLDAP($ldap);
    return !$mesg->is_error();
}

sub syncProjectDirStruct {
    my ($prid) = @_;
	my $name = CL::getProjectName($prid);
	my $home = $CL::PROJECTS_HOME."/$name";
    mkpath($home, 0, 				{owner => $name, group => $name});
    mkpath("$home/public", 0, 		{owner => $name, group => $name});
    mkpath("$home/public_html", 0,  {owner => $name, group => $name});
    mkpath("$home/private", 0, 		{owner => $name, group => $name});
    my %members = CL::getProjectMembers($prid);
    foreach my $member (keys(%members)) {
    	mkpath("$home/$member", 0, {owner => $member, group => $name, mode => 0755});
    }
    `touch $home/public_html/about.txt`;
    `touch $home/public_html/thumb1.jpg`;
    `touch $home/public_html/thumb2.jpg`;
    `touch $home/public_html/thumb3.jpg`;
#    CL::lockProjectDirs($prid, 'open'); # Sets the common folders' umask.
    
    return 0;
}

sub lockProjectDirs {

	my ($prid, $lockopen) = @_;
    my $name = CL::getProjectName($prid);
    my $user = mkProjectUserObj($name);
    my $group = mkGroupObj($name, 1);
    my $uid = $user->get_value('uidNumber');
    my $gid = $group->get_value('gidNumber');
    my $home = $CL::PROJECTS_HOME."/$name";
    
    return 1 if ($lockopen ne 'open' && $lockopen ne 'lock');
    
    my ($m_public, $m_public_html, $m_private, $m_member) = ($lockopen eq 'open') ? (775, 775, 770, 755) : (755, 755, 750, 755);
        
    `chmod $m_public -R $home/public`;
    `chown -R $uid $home/public`;
    `chgrp -R $gid $home/public`;
    `chmod $m_public_html -R $home/public_html`;
    `chown -R $uid $home/public_html`;
   `chgrp -R $gid $home/public_html`;
    `chmod $m_private -R $home/private`;
    `chown -R $uid $home/private`;
    `chgrp -R $gid $home/private`;
    my %members = CL::getProjectMembers($prid);
    foreach my $member (keys(%members)) {
      my $memberUID = ($lockopen eq 'open') ? $members{$member} : $uid;
      `chmod $m_member -R $home/$member`;
      `chown -R $memberUID $home/$member`;
      `chgrp -R $gid $home/$member`;
    }
    return 0;
}

#sub syncLocked

sub projectMysqlUp {
    my $dbh = DBI->connect("DBI:mysql:database=".$CL::DB_NAME.";host=".$CL::MYSQL_HOST, $CL::MYSQL_ROOT, $CL::MYSQL_ROOTPASSWD);
    $dbh->{mysql_auto_reconnect} = 1;
    return $dbh;    
}

sub getProjectMembers {
	my ($prid) =  @_;
    my $dbh = CL::projectMysqlUp();
    my $sth = $dbh->prepare("SELECT DISTINCT uid FROM members WHERE prid = $prid");
    $sth->execute();
    my %nicks = ();
    while (my $ref = $sth->fetchrow_hashref()) {
	    my $user = mkUserObj($ref->{'uid'});
		$nicks{$user->get_value('uid')} = $ref->{'uid'};
    }
    $dbh->disconnect();
	return %nicks;
}

sub getPrGroupDN {
	my ($prid) = @_;
    return "cn=$prid,$CL::LDAP_BASE_PROJECTS_GROUPS";
}

sub getPrUserDN {
    my ($prid) = @_;
    return "uid=$prid,$CL::LDAP_BASE_PROJECTS_USERS";
}

sub mkGroupObj {
    my ($grp, $isProjectGroup) = @_;
	my $ldap = CL::bindLDAP(1);
    my $mesg = $ldap->search(
    	filter => "(".(($grp =~ m/[^0-9]/) ? 'cn' : 'gidNumber')."=$grp)", 
    	base => (($isProjectGroup) ? $CL::LDAP_BASE_PROJECTS_GROUPS : $CL::LDAP_BASE_GROUPS), 
    );
#    CL::unbindLDAP($ldap);
    my @entries = $mesg->entries();
    return $entries[0];
}
                            
sub getProjectName {
	my ($prid) = @_;
    my $dbh = projectMysqlUp();
    my $sth = $dbh->prepare("SELECT name FROM projects WHERE prid = $prid");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
	return $ref->{'name'};
}

sub getProjectID {
    my ($name) = @_;
    my $dbh = projectMysqlUp();
    my $sth = $dbh->prepare("SELECT prid FROM projects WHERE name = '$name'");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    return $ref->{'prid'};
}
                            
sub mkProjectUserObj
{
    my ($nick) = @_;
    my $ldap = CL::bindLDAP(1);
    my $mesg = $ldap->search(filter => "(".(($nick =~ m/[a-z]/) ? 'uid' : 'uidNumber')."=$nick)", base => $CL::LDAP_BASE_PROJECTS_USERS);
#    CL::unbindLDAP($ldap);
    if ($mesg->is_error()) {
        return 0;
    }
    my @entries = $mesg->entries();
    return $entries[0];
}
