#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2009-2011, All rights reserved.
# See http://www.perl.com/lpt/a/637 for scoping rules.
# See http://www.openldap.org/faq/data/cache/347.html for base 64 encod, SSHA/SHA hashes etc.
package CL;
use warnings;
use strict;
use utf8;
use Net::LDAP;
use DBI; # DB Interface
use Quota;
use File::Basename; # basename() and dirname()
use File::Path; # mkpath() and rmtree()
#use HTTP::Request::Common qw(POST);
#use LWP::UserAgent;
require '/files/scripts/commonLibrary_credentials.pl';
require '/files/scripts/commonLibrary_header.pl';
require '/files/scripts/commonLibrary_passwd.pl';
require '/files/scripts/commonLibrary_projects.pl';

# These should generally not be changed.
our $GROUP_SUDO = 'wheel';
our $GROUP_WWW  = 'www-data';

our @SUPPORTED_COM_CHLS = ('sms', 'mail');
our %SUPPORTED_COM_CHLS__LDAP_INDEX = ('sms' => 'mobile', 'mail' => 'mail');

our @RFID_ACCESS_LEVELS = (1,2,3); # 3 is admin, 2 is SU, 1 is regular user.
our %RFID_ACCESS_LEVELS_DESC = (0 => '0 - No access', 1 => '1 - User access', 2 => '2 - SU access', 3 => '3 - Admin access');

########################
# General routines
########################

sub mkUser
{
    # Required arguments: Full name (UTF-encoded), beginning year (ex. 2004), class number (ex. 2).
    # Optional arguemnts: Nickname (i.e. username).
    my ($name, $year, $classnr, $pre_nick) = @_;
    # Ready user info.
    my $year_abbrev     = sprintf("%02d", $year % 100); # Ex. '05'
    my $year_intvl      = "$year-".($year+1);           # Ex. '2005-2006'
    my $classGID        = CL::getFreeGID();		# Secondary GID
    my $classGIDname    = "${year}_$classnr";           # Secondary group name.
    my $GID             = $CL::GID_STUDENTS;            # Primary GID
    my $UID             = CL::getFreeUID();
    my $sambaSID        = CL::mkSambaSID($UID);
    my $sambaPGSID      = CL::mkSambaPGSID($GID);
    my $passwd          = CL::randPasswd();
    my ($passwd_crypt, $LMpasswd, $NTpasswd) = CL::passwdHashes($passwd);
    my ($name_ascii, $name_b64enc, $surname) = CL::formatName($name); # Returns ASCII-ized full name, base 64 encoded full name and surname.
    my $nick            = (defined $pre_nick) ? $pre_nick : CL::mkNick($name_ascii, $year_abbrev);
    my $home            = "$CL::HOMES_BASE/$year_intvl/$nick";
    my $info_file       = "$CL::INFOFILE_PATH/$classGIDname/$nick.txt";
    # Do the following required steps to add user.
    mkpath($CL::SYS_BASE,   0, 0755);
    mkpath($CL::HOMES_BASE, 0, 0755);
    CL::mkHome($home, $UID, $GID);
    CL::mkLDAPUser($name_ascii, $name, $surname, $nick, $UID, $GID, $passwd_crypt, $home, ($sambaSID, $sambaPGSID, $LMpasswd, $NTpasswd));
    CL::mkLDAPGroupWithUser($classGID, $classGIDname, $nick);
    CL::mkInfoFile($name, $nick, $passwd, $classnr, $year_intvl, $info_file);
    return ($nick, $info_file);
}

sub mkAdmin
{
	my ($name, $nick) = @_;
	my $GID 	    = 0; # Root group.
  	my $UID             = CL::getFreeUID();
  	my $sambaSID        = CL::mkSambaSID($UID);
   	my $sambaPGSID      = CL::mkSambaPGSID($GID);
   	my $passwd          = CL::randPasswd();
   	my $home            = "$CL::ADM_HOMES_BASE/$nick";
	my ($passwd_crypt, $LMpasswd, $NTpasswd) = CL::passwdHashes($passwd);
    my ($name_ascii, $name_b64enc, $surname) = CL::formatName($name); # Returns ASCII-ized full name, base 64 encoded full name and surname.
	CL::mkHome($home, $UID, $GID);
	CL::mkLDAPUser($name_ascii, $name, $surname, $nick, $UID, $GID, $passwd_crypt, $home, ($sambaSID, $sambaPGSID, $LMpasswd, $NTpasswd));
	CL::setAdminState($nick, 1);
}

sub mkMiscUser
{
    my ($nick, $group) = @_;
    my $GID             = $CL::GID_STUDENTS;
    my $classGID        = CL::getFreeGID();
    my $UID             = CL::getFreeUID();
    my $sambaSID        = CL::mkSambaSID($UID);
    my $sambaPGSID      = CL::mkSambaPGSID($GID);
    my $passwd          = CL::randPasswd();
    my $home            = "$CL::ADM_HOMES_BASE/$nick";
    my ($passwd_crypt, $LMpasswd, $NTpasswd) = CL::passwdHashes($passwd);
    my ($name_ascii, $name_b64enc, $surname) = CL::formatName($nick); # Returns ASCII-ized full name, base 64 encoded full name and surname.
    CL::mkHome($home, $UID, $GID);
    CL::mkLDAPUser($name_ascii, $nick, $surname, $nick, $UID, $GID, $passwd_crypt, $home, ($sambaSID, $sambaPGSID, $LMpasswd, $NTpasswd));
    CL::mkLDAPGroupWithUser($classGID, $group, $nick);
}

sub mkLDAPUser
{
    my ($name_ascii, $name, $surname, $nick, $UID, $GID, $passwd_crypt, $home, @smb) = @_;
    my ($sambaSID, $sambaPGSID, $LMpasswd, $NTpasswd) = @smb;
    my $ldap = CL::bindLDAP();
    my $mesg = $ldap->add(CL::getUserDN($nick),
        attrs => [
            'uid' 			=> $nick,
			'cn'			=> $name,
            'userPassword'  => "{crypt}$passwd_crypt",
			'loginShell'	=> '/bin/bash',
			'uidNumber'		=> $UID,
			'gidNumber'		=> $GID,
			'homeDirectory'	=> $home,
			'gecos'			=> $name_ascii,
			'sn'			=> $surname,
			'mail'			=> '',
			'mobile'		=> '0',
			'employeeNumber'=> '0',
			'employeeType'  => '0',
			'sambaAcctFlags' 	=> '[UX         ]',
			'sambaLMPassword' 	=> $LMpasswd,
			'sambaNTPassword' 	=> $NTpasswd,
			'sambaSID'              => "$CL::SMB_SID_BASE-$sambaSID",
			'sambaPrimaryGroupSID' 	=> "$CL::SMB_SID_BASE-$sambaPGSID",
            'objectclass' 		=> ['top', 'posixAccount', 'sambaSamAccount', 'person', 'inetOrgPerson'],
        ]
    );
    CL::unbindLDAP($ldap);
    return !$mesg->is_error();
}

sub hasMysqlAcc {
        my ($nick) = @_;
        my $dbh = DBI->connect("DBI:mysql:database=mysql;host=".$CL::MYSQL_HOST, $CL::MYSQL_ROOT, $CL::MYSQL_ROOTPASSWD, {'RaiseError' => 1});
	my $sth = $dbh->prepare("SELECT user FROM mysql.user WHERE user='$nick'");
	$sth->execute();
	my $result = $sth->fetchrow_arrayref();
	$sth->finish; 
 	$dbh->disconnect();
	return (1 && $result);
}

sub mkMysqlUser 
{
        my ($nick) = @_;
  	my $dbh = DBI->connect("DBI:mysql:database=mysql;host=".$CL::MYSQL_HOST, $CL::MYSQL_ROOT, $CL::MYSQL_ROOTPASSWD);
	$dbh->{mysql_auto_reconnect} = 1;
	my $passwd;
	do {
		$passwd = CL::randPasswd();
	} while ($passwd =~ m/'/); # Get new rand pass until it does not contain single quotes (the below sql query will have bad string termination othewise).
	$dbh->do("CREATE USER '$nick'\@'localhost' IDENTIFIED BY '$passwd'");
  	$dbh->func("createdb", $nick, 'admin');
        $dbh->do("GRANT ALL PRIVILEGES ON $nick.* TO '$nick'\@'localhost'");
 	$dbh->disconnect();
	return (CL::hasMysqlAcc($nick)) ? $passwd : undef;
}

sub chMysqlPasswd
{
    my ($nick, $passwd) = @_;
	$passwd =~ s/(['])/\\$1/g;
    my $dbh = DBI->connect("DBI:mysql:database=mysql;host=".$CL::MYSQL_HOST, $CL::MYSQL_ROOT, $CL::MYSQL_ROOTPASSWD, {'RaiseError' => 1});
    my $rc = $dbh->do("SET PASSWORD FOR '$nick'\@'localhost' = PASSWORD('$passwd')");
	$dbh->disconnect();
	return (1 && $rc);
}

sub delMysqlUser 
{
        my ($nick) = @_;
        my $dbh = DBI->connect("DBI:mysql:database=mysql;host=".$CL::MYSQL_HOST, $CL::MYSQL_ROOT, $CL::MYSQL_ROOTPASSWD);
        $dbh->{mysql_auto_reconnect} = 1;
        $dbh->func("dropdb", $nick, 'admin');
        $dbh->do("DROP USER $nick\@localhost");
        $dbh->disconnect();
        return !CL::hasMysqlAcc($nick);
}

sub delUser 
{
	my ($nick) = @_;
	# Remove group memberships
	foreach my $grp (CL::getGroupMemberships($nick)) {
		CL::modifyMembership($nick, 'delete', $grp);
	}
	# Delete user
    	my $ldap = CL::bindLDAP();
	my $user = CL::mkUserObj($nick);
	my $mesg = $ldap->delete(CL::getUserDN($nick));
    	CL::unbindLDAP($ldap);
	CL::delMysqlUser($nick);
	# Delete user's home directory
	rmtree($user->get_value('homeDirectory'));
	return;
}

sub mkUserObj
{
	my ($nick) = @_;
	my $ldap = CL::bindLDAP();
 	my $mesg = $ldap->search(filter => "(".(($nick =~ m/[a-z]/) ? 'uid' : 'uidNumber')."=$nick)", base => $CL::LDAP_BASE_USERS);
        CL::unbindLDAP($ldap);
	if ($mesg->is_error()) {
		return 0;
	}
	my @entries = $mesg->entries();
	return $entries[0];
}

sub mkLDAPGroupWithUser
{
    my ($classGID, $classGIDname, $nick) = @_;
    # First, make sure the group entry exists.
    my $ldap = CL::bindLDAP();
    my $mesg = $ldap->add(CL::getGroupDN($classGIDname),
                      attrs => [
                        'cn'           => $classGIDname,
			'userPassword' => "{crypt}*",
			'gidNumber'    => $classGID,
                        'objectclass'  => ['top', 'posixGroup'],
                      ]
                     );
    CL::unbindLDAP($ldap);
    return CL::modifyMembership($nick, 'add', $classGIDname);    
}

sub renameGroup 
{
	my ($grp, $newName) = @_;
    	my $ldap = CL::bindLDAP();
	my $mesg = $ldap->moddn(CL::getGroupDN($grp), newrdn => "cn=$newName", deleteoldrdn => 1);
    	CL::unbindLDAP($ldap);
	return !$mesg->is_error();
}

sub mkInfoFile
{
    my ($name, $nick, $passwd, $class, $year_intvl, $info_file) = @_;
    mkpath(dirname($info_file), 0, 0440);
    open(INFOFILE, ">$info_file");
    print INFOFILE <<END;
====================================
$CL::INFOFILE_TITLE
====================================
Date       	${\scalar localtime}
Class     	$class
Year      	$year_intvl
------------------------------------
Name 	  	$name
User name	$nick
Password  	$passwd
------------------------------------
$CL::INFOFILE_MESSAGE
END
    close(INFOFILE);
    chmod 0440, $info_file;
}

sub mkHome
{
    my ($home, $UID, $GID) = @_;
    mkpath($home, 0, 0755);
    chown $UID, $GID, $home;
}

sub formatName
{   
    my ($name) = @_;
    my ($name_ascii, $name_b64enc, $surname);
    $name_ascii    = CL::recode_utf8_to_latin1($name);
    $name_ascii    = CL::recode_custom_to_ascii($name_ascii);
    $name_ascii    = CL::recode_latin1_to_utf8($name_ascii);
    $name_b64enc   = CL::encode_base64($name, "");
    my @name_parts = split(/ /, $name);
    $surname = $name_parts[-1];
    return ($name_ascii, $name_b64enc, $surname);
}

sub mkNick
{
    my ($name, $suffix) = @_;
    $name =~ s/(^\w+)|[a-z]+|\s|\.|\-/ defined($1) && $1/ge;
    $name = lc $name;
    $name .= $suffix;
    
    foreach ('a'..'z') {
        last unless getpwnam $name;
        if ($_ eq 'a') {
            $name =~ s/$suffix$/$_$suffix/;
        }
        else {
            $name =~ s/\w$suffix$/$_$suffix/;    # Remove the added \w from past loop.
        }            
    }
    
    return $name;
}

sub getUserDN
{
	my ($nick) = @_;
	return "uid=$nick,$CL::LDAP_BASE_USERS";
}

sub getGroupDN
{
        my ($grp) = @_;
        return "cn=$grp,$CL::LDAP_BASE_GROUPS";
}

sub mkSambaSID {
    my ($UID) = @_;
    return $UID*2+1000
}

sub mkSambaPGSID {
    my ($GID) = @_;
    return $GID*2+1001
}

sub getFreeUID {
    my $UID_START = 1010;
    while (defined(getpwuid($UID_START))) {
        $UID_START++;
    } 
    return $UID_START;
}

sub getFreeGID {
    my $GID_START = 2000;
    while (defined(getgrgid($GID_START))) {
        $GID_START++;
    }
    return $GID_START;
}

sub setFullName {
        my ($nick, $name) = @_;
        my $ldap = CL::bindLDAP();
        my ($name_ascii, $name_b64enc, $surname) = CL::formatName($name);
        my $mesg = $ldap->modify(CL::getUserDN($nick), replace => {cn => $name, sn => $surname, gecos => $name_ascii});
        CL::unbindLDAP($ldap);
        return !$mesg->is_error();
}

sub setLoginPermission {

    my ($nick, $login_allowed) = @_;
    my $shell = ($login_allowed) ? '/bin/bash'  : '/usr/sbin/nologin';
    my $ldap = CL::bindLDAP();
    my $mesg = $ldap->modify(CL::getUserDN($nick), replace => {loginShell => $shell});
    CL::unbindLDAP($ldap);
    return !$mesg->is_error();
}

sub getLoginPermission {
   my ($nick) = @_;
   my $user = CL::mkUserObj($nick);
   return ($user->get_value('loginShell') ne '/usr/sbin/nologin');
}

sub setAdminState {
    my ($nick, $state) = @_;
    my $ldap = CL::bindLDAP();
    my $mesg;
    $mesg = $ldap->modify(CL::getGroupDN($CL::GROUP_SUDO), (($state) ? 'add' : 'delete') => {'memberUid' => $nick});
    $mesg = $ldap->modify(CL::getGroupDN($CL::GROUP_WWW),  (($state) ? 'add' : 'delete') => {'memberUid' => $nick});
    CL::unbindLDAP($ldap);
    return !$mesg->is_error();
}

sub getAllYears {
	my @years;
	my %groups = CL::getAllGroups(1);
	foreach my $grp (values(%groups)) {
		if ($grp =~ m/^(\d{4})\_.*$/ && !CL::in_array(\@years, $1)) {
			push(@years, $1);
		}
	}
	@years = sort(@years);
	return @years;
}

sub getAllGroups {
	my ($ONLY_CLASSES) = @_;
        my $ldap = CL::bindLDAP(1);
	my $mesg = $ldap->search(filter => (($ONLY_CLASSES) ? "(|(cn=19*_*)(cn=20*_*))" : "(cn=*)"), base => $CL::LDAP_BASE_GROUPS, attrs => ['cn', 'gidNumber']);
        CL::unbindLDAP($ldap);
	my %groups;
	foreach my $entry ($mesg->entries()) {
		$groups{$entry->get_value('gidNumber')} = $entry->get_value('cn');
	}
	return %groups;
}

sub getGroupMembers {
	my ($grp) = @_;
        my $ldap = CL::bindLDAP(1);
        my $mesg = $ldap->search(filter => "(cn=$grp)", base => $CL::LDAP_BASE_GROUPS, attrs => ['memberUid']);
        CL::unbindLDAP($ldap);
	my @entries = $mesg->entries();
	my @members = $entries[0]->get_value('memberUid');
	return @members;
}

sub getAdmins {
	return CL::getGroupMembers($CL::GROUP_SUDO);
}

sub getYearMembers {
        my ($year) = @_;
		my $ldap = CL::bindLDAP(1);
        my $mesg = $ldap->search(filter => "(uid=*".substr($year, -2).")", base => $CL::LDAP_BASE_USERS, attrs => ['uid']);
        CL::unbindLDAP($ldap);
	my @members;
        foreach ($mesg->entries()) {
	        push(@members, $_->get_value('uid'));
	}
	@members = sort(@members);
        return @members;
}

sub getGroupMemberships {
	my ($nick) = @_;
	my $memberships_str = `id -G -n $nick`;
	chomp($memberships_str);
	my @memberships = split(/ /, $memberships_str);
	return @memberships;
}

sub getGroupsInYear {
	my ($year) = @_;
        my $ldap = CL::bindLDAP(1);
        my $mesg = $ldap->search(filter => "(cn=${year}_*)", base => $CL::LDAP_BASE_GROUPS, attrs => ['cn']);
        CL::unbindLDAP($ldap);
        my @groups;
        foreach ($mesg->entries()) {
                push(@groups, $_->get_value('cn'));
        }
        return @groups;
}

sub modifyMembership {
	my ($nick, $op, $grp) = @_;
        my $ldap = CL::bindLDAP();
        my $mesg = $ldap->modify(CL::getGroupDN($grp), 
		(($op eq 'add') ? 'add' : 'delete') => {'memberUid' => $nick});
        CL::unbindLDAP($ldap);
        return !$mesg->is_error();
}

sub setPhone {
        my ($nick, $phone) = @_;
        my $ldap = CL::bindLDAP();
	my $mesg = $ldap->modify(CL::getUserDN($nick), replace => {mobile => $phone});
        CL::unbindLDAP($ldap);
	return !$mesg->is_error();
}

sub setMail {
        my ($nick, $mail) = @_;
        my $ldap = CL::bindLDAP();
        my $mesg = $ldap->modify(CL::getUserDN($nick), replace => {mail => $mail});
        CL::unbindLDAP($ldap);
        return !$mesg->is_error();
}

sub getComChls {
        my ($nick) = @_;
        my $user = CL::mkUserObj($nick);
        return () if !$user;
        my @chls = ();
        push(@chls, 'sms') if $user->get_value('mobile');
        push(@chls, 'mail') if $user->get_value('mail');                                        
        return @chls;
}

sub hasRFID {
	my ($nick) = @_;
        my $user = CL::mkUserObj($nick);
        return 0 if !$user;
        return $user->get_value('employeeType') && $user->get_value('employeeNumber');
}

sub setRFID {
        my ($nick, $rfid, $level) = @_;
	return 0 if (!CL::in_array(\@CL::RFID_ACCESS_LEVELS, $level) && $level != 0); # 0 is the unset value.
        my $ldap = CL::bindLDAP();
        my $mesg = $ldap->modify(CL::getUserDN($nick), replace => {employeeType => $level, employeeNumber => $rfid});
        CL::unbindLDAP($ldap);
        return !$mesg->is_error();

}

sub sendMessage {
	my ($ref_nicks, $msg, $chl) = @_;
	return 0 if (!CL::in_array(\@CL::SUPPORTED_COM_CHLS, $chl));
	my @failed = ();
	foreach (@$ref_nicks) {
		my $user = CL::mkUserObj($_);
		if ($chl eq 'sms') {
			my $phone = $user->get_value('mobile');
			push(@failed, $_) if (!$phone || $phone !~ m/^\d{4,}$/); # Don't send to invalid phone nubmers!
			my $exec = "python /files/scripts/sms/smssend.py -f 'MediaLab' -m \"$msg\" $phone";
			system($exec);
			push(@failed, $_) if $?;
		}
		elsif ($chl eq 'mail') {
            my $mail = $user->get_value('mail');
            push(@failed, $_) if (!$mail || $mail !~ m/\@/); # Don't send to invalid email addresses!
            my $openstr = "| sendEmail -q -f ".$CL::GMAIL_USER."\@gmail.com -t $mail -u \"OEP message\" -s smtp.gmail.com -o tls=yes -xu ".$CL::GMAIL_USER." -xp ".$CL::GMAIL_USERPASSWD;
			open(MAIL, "| sendEmail -q -f ".$CL::GMAIL_USER."\@gmail.com -t $mail -u \"OEP message\" -s ".$CL::GMAIL_SMTP." -o tls=yes -xu ".$CL::GMAIL_USER." -xp ".$CL::GMAIL_USERPASSWD) || (push(@failed, $_) and next);
			print MAIL $msg;
			close(MAIL);
			#debug:
			print $openstr;
        	        #push(@failed, $_) if $?;
		}
	}
	return @failed;
}

sub sendSMS {
	my ($recv, $msg) = @_;
	my $phone = 0;
	if ($recv =~ /[a-z]/) { # Has non numeric chars? => assume user name as recv => fetch his/her phone number.
		my $user = CL::mkUserObj($recv);
		$phone = $user->get_value('mobile');
	}
	else {
		$phone = $recv;
	}
#	my $ua = LWP::UserAgent->new;
#    my $req = POST $CL::SMS_URL, [ username => $CL::SMS_USER, password => $CL::SMS_USERPASSWD, recipient => $phone, message => $msg, from => $CL::SMS_FROM ];
#    print $ua->request($req)->as_string;
}

sub getQuota {
  	my ($nick) = @_;
	my $dev = Quota::getqcarg($CL::HOMES_BASE);
	my $user = CL::mkUserObj($nick);
	my $uid = $user->get_value('uidNumber');
	return (undef,undef) if (!$user);
	my ($bc,$bs,$bh,$bt, $ic,$is,$ih,$it) = Quota::query($dev, $uid, 0);
	$bc /= 1024;
	$bh /= 1024;
	return ($bc,$bh); # Block current, block limit hard.
}

sub setQuota {
        my ($nick, $limitInMB) = @_;
        my $dev = Quota::getqcarg($CL::HOMES_BASE);
        my $user = mkUserObj($nick);
        my $uid = $user->get_value('uidNumber'); 
        return (undef,undef) if (!$user);
	my ($bh,$bs, $ih,$is, $tlo);
        $bs = $bh = $limitInMB * 1024; # Number of blocks
        $is = $ih = 0;
        $tlo = 1; # 7 days - this does not matter, since soft limits = hard limits (ie. no grace period).
	return !Quota::setqlim($dev, $uid, $bs,$bh, $is,$ih, $tlo, 0); # 0 is success, therefore invert ret val.
}

sub isUncommunicatable {
	my ($ref_users, $chl) = @_;
	my @uncommunicatable = ();
	foreach (@$ref_users) {
		my @chls = CL::getComChls($_);
		push(@uncommunicatable, $_) if (!CL::in_array(\@chls, $chl));
	}
	return @uncommunicatable;
}

sub resetPasswd {
	my ($ref_nicks, $chl, $type, $quiet) = @_;
	return -2 if (!CL::in_array(\@CL::SUPPORTED_COM_CHLS, $chl));
	my $ret = 1;
	foreach my $nick (@$ref_nicks) {
	    my $tmp_passwd = CL::randPasswd();
        $ret &= ($type eq 'ldap') 
        	? CL::chPasswd($nick, $tmp_passwd, $CL::LDAP_ROOTPASSWD, $CL::LDAP_ROOT) 
        	: CL::chMysqlPasswd($nick, $tmp_passwd);
		my @chls = CL::getComChls($nick);
		next if !CL::in_array(\@chls, $chl);
		if (!$quiet) {
	      	$ret &= (scalar(CL::sendMessage([$nick], "Your new ".(($type eq 'mysql') ? 'MySQL' : '')." password is $tmp_passwd", $chl)) == 0);
	    }
	}
	return $ret;
}

#############################
# TOOLS
#############################

sub bindLDAP {
	my ($anom) = @_;
	my $ldap = Net::LDAP->new($CL::LDAP_HOST) or die "$@";
        my $mesg = (defined($anom) && $anom) ? $ldap->bind() : $ldap->bind($CL::LDAP_ROOT, password => $CL::LDAP_ROOTPASSWD);
	return $ldap;
}

sub unbindLDAP() {
	my ($ldap) = @_;
	my $mesg = $ldap->unbind();
	return;
}

sub in_array {
     my ($arr,$search_for) = @_;
     my %items = map {$_ => 1} @$arr; # create a hash out of the array values
     return (exists($items{$search_for}))?1:0;
}

##########################################
# ROUTINES FROM migrationtools
##########################################

sub recode_latin1_to_utf8
{
	my ($content) = @_;
	for ($content) {
		s/([\x80-\xFF])/chr(0xC0|ord($1)>>6).chr(0x80|ord($1)&0x3F)/eg;
	}
	return ($content)
}

sub recode_utf8_to_latin1
{
	my ($content) = @_;
	for ($content) {
		s/([\xC2\xC3])([\x80-\xBF])/chr(ord($1)<<6&0xC0|ord($2)&0x3F)/eg;
	}
	return ($content)
}

sub recode_custom_to_ascii
{
	my ($content) = @_;
	for ($content) {
		s/\xc0/A/g; # latin capital letter a with grave
		s/\xc1/A/g; # latin capital letter a with acute
		s/\xc2/A/g; # latin capital letter a with circumflex
		s/\xc3/A/g; # latin capital letter a with tilde
		s/\xc4/Ae/g; # latin capital letter a with diaeresis
		s/\xc5/Aa/g; # latin capital letter a with ring above
		s/\xc6/Ae/g; # latin capital letter ae
		s/\xc7/C/g; # latin capital letter c with cedilla
		s/\xc8/E/g; # latin capital letter e with grave
		s/\xc9/E/g; # latin capital letter e with acute
		s/\xca/E/g; # latin capital letter e with circumflex
		s/\xcb/Ee/g; # latin capital letter e with diaeresis
		s/\xcc/I/g; # latin capital letter i with grave
		s/\xcd/I/g; # latin capital letter i with acute
		s/\xce/I/g; # latin capital letter i with circumflex
		s/\xcf/Ie/g; # latin capital letter i with diaeresis
		s/\xd0/Dh/g; # latin capital letter eth (icelandic)
		s/\xd1/N/g; # latin capital letter n with tilde
		s/\xd2/O/g; # latin capital letter o with grave
		s/\xd3/O/g; # latin capital letter o with acute
		s/\xd4/O/g; # latin capital letter o with circumflex
		s/\xd5/O/g; # latin capital letter o with tilde
		s/\xd6/Oe/g; # latin capital letter o with diaeresis
		s/\xd8/Oe/g; # latin capital letter o with stroke
		s/\xd9/U/g; # latin capital letter u with grave
		s/\xda/U/g; # latin capital letter u with acute
		s/\xdb/U/g; # latin capital letter u with circumflex
		s/\xdc/Ue/g; # latin capital letter u with diaeresis
		s/\xdd/Y/g; # latin capital letter y with acute
		s/\xde/TH/g; # latin capital letter thorn (icelandic)
		s/\xdf/ss/g; # latin small letter sharp s (german)
		s/\xe0/a/g; # latin small letter a with grave
		s/\xe1/a/g; # latin small letter a with acute
		s/\xe2/a/g; # latin small letter a with circumflex
		s/\xe3/a/g; # latin small letter a with tilde
		s/\xe4/ae/g; # latin small letter a with diaeresis
		s/\xe5/aa/g; # latin small letter a with ring above
		s/\xe6/ae/g; # latin small letter ae
		s/\xe7/c/g; # latin small letter c with cedilla
		s/\xe8/e/g; # latin small letter e with grave
		s/\xe9/e/g; # latin small letter e with acute
		s/\xea/e/g; # latin small letter e with circumflex
		s/\xeb/ee/g; # latin small letter e with diaeresis
		s/\xec/i/g; # latin small letter i with grave
		s/\xed/i/g; # latin small letter i with acute
		s/\xee/i/g; # latin small letter i with circumflex
		s/\xef/ii/g; # latin small letter i with diaeresis
		s/\xf0/dh/g; # latin small letter eth (icelandic)
		s/\xf1/n/g; # latin small letter n with tilde
		s/\xf2/o/g; # latin small letter o with grave
		s/\xf3/o/g; # latin small letter o with acute
		s/\xf4/o/g; # latin small letter o with circumflex
		s/\xf5/o/g; # latin small letter o with tilde
		s/\xf6/oe/g; # latin small letter o with diaeresis
		s/\xf8/oe/g; # latin small letter o with stroke
		s/\xf9/u/g; # latin small letter u with grave
		s/\xfa/u/g; # latin small letter u with acute
		s/\xfb/u/g; # latin small letter u with circumflex
		s/\xfc/ue/g; # latin small letter u with diaeresis
		s/\xfd/y/g; # latin small letter y with acute
		s/\xfe/th/g; # latin small letter thorn (icelandic)
		s/\xff/ye/g; # latin small letter y with diaeresis
	}
	return ($content);
}

sub encode_base64
# Found in email by Baruzzi Giovanni <giovanni.baruzzi@allianz-leben.de> on openldap mailinglist

# Historically this module has been implemented as pure perl code.
# The XS implementation runs about 20 times faster, but the Perl
# code might be more portable, so it is still here.
{
	my $res = "";
	my $eol = $_[1];
	$eol = "\n" unless defined $eol;
	pos($_[0]) = 0; # ensure start at the beginning
	while ($_[0] =~ /(.{1,45})/gs) {
		$res .= substr(pack('u', $1), 1);
		chop($res);
	}
	$res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
	# fix padding at the end
	my $padding = (3 - length($_[0]) % 3) % 3;
	$res =~ s/.{$padding}$/'=' x $padding/e if $padding;
	# break encoded string into lines of no more than 76 characters each
	if (length $eol) {
		$res =~ s/(.{1,76})/$1$eol/g;
	}
	$res;
}

sub validate_ascii
{
	my ($content) = @_;
	$content =~ /^[\x20-\x7E]*$/;
}

sub validate_utf8
{
	my ($content) = @_;
	if (&validate_ascii($content)) {
		return 1;
	}
	if ($] >= 5.8) {
		## No Perl support for UTF-8! ;-/
		return undef;
	}
	$content =~ /^[\x20-\x7E\x{0080}-\x{FFFF}]*$/;
}

1;
