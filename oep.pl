#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2009-2012, All rights reserved
# Links: http://cpansearch.perl.org/src/MARCUS/Curses-UI-0.94/examples/demo-widgets

# FIXME/TODO
# - reset mysql passwd for class fails => oep.pl exits.
# - project page not finished.
# - user log history not implemented

# DEBUG use $cui->leave_curses()

use warnings;
no warnings 'once';
use strict;
#no strict 'subs';
use utf8;
use Curses::UI;
use Array::Diff;
use Tie::IxHash;
require('/files/scripts/commonLibrary.pl');

####################
# Load all LDAP data
####################
#my %groups = CL::getAllGroups(1); # This only lists classes after the YYYY (year) syntax (see commonLibrary.pl)
my %groups = CL::getAllGroups(0); # This lists ALL LDAP groups

my %all;
foreach my $grp (values(%groups)) {
	$all{$grp} = [sort(CL::getGroupMembers($grp))];
}
#print @{$all{'2005_3'}}; # Contains the nicks of class 2005_3

####################
# Menu: Students
####################
my %years;
foreach my $groupname (keys(%all)) {
	my ($classyear, $classname);
	if ($groupname =~ m/^(\d{4})_(.*)$/) {
		($classyear, $classname) = ($1,$2);
	}
	else {
		next;
	}
	$years{$classyear}{$classname} = $all{$groupname};
}
#print @{$years{2005}{3}}; # Contains the nicks of class 2005_3

my @yrs;
foreach my $year (reverse(sort(keys(%years)))) {
	my %yr;
	$yr{'-label'} = $year;
	
	my @cls;
	foreach my $class (sort(keys(%{$years{$year}}))) {
		my %cl;
		$cl{'-label'} = $class;

		my @usrs;
		foreach my $user (sort(@{$years{$year}{$class}})) {
			my %usr;
			$usr{'-label'} = $user;
			$usr{'-submenu'} = _getUserMenu($user);
			push(@{$cl{'-submenu'}}, \%usr);
		}
                push(@{$yr{'-submenu'}}, \%cl);

	}
	push(@yrs, \%yr);
}
	# Add this entry at bottom of students/classes list.
my $usrpick = {'-label' => 'Open profile by user ID', '-value' => sub{return openUserProfile();}};
push(@yrs, $usrpick);

####################
# Menu: Admins
####################
my @admins;
foreach my $nick (CL::getGroupMembers($CL::GROUP_SUDO)) {
	my %admin;

	# Is the admin an LDAP user or a system user? We can't edit sys users, since they are not in the LDAP, of course.
	my $user = CL::mkUserObj($nick);
	if (!$user) {
		next;
	}

	$admin{'-label'} = $nick;
    $admin{'-submenu'} = _getUserMenu($nick);
	push(@admins, \%admin);
}

####################
# Menu: misc users
####################
my @misc;
foreach my $nick (CL::getGroupMembers('misc')) {
    my %miscuser;
    # Is the admin an LDAP user or a system user? We can't edit sys users, since they are not in the LDAP, of course.
    my $user = CL::mkUserObj($nick);
    if (!$user) {
       next;
    }
    $miscuser{'-label'} = $nick;
    $miscuser{'-submenu'} = _getUserMenu($nick);
    push(@misc, \%miscuser);
}
                                        

####################
# Menu: Classes
####################
my @classes;
foreach my $year (reverse(sort(keys(%years)))) {
        my %yr;
        $yr{'-label'} = $year;

        my @cls;
        foreach my $class (sort(keys(%{$years{$year}}))) {
            my %cl;
            $cl{'-label'} = $class;
			my $real_classname = "${year}_$class";
			$cl{'-submenu'} = [
	            	{'-label' => 'Show all members', '-value' => sub{return class__about($real_classname)}},
	            	{'-label' => 'Populate contact information', '-value' => sub{return class__popcontacts($real_classname)}},
			        {'-label' => 'Reset passwords', -submenu => [
            	        {'-label' => 'Reset LDAP passwords',     '-value' => sub{my @nicks = CL::getGroupMembers($real_classname); class__passwds(\@nicks, 'ldap', 0);}},
                        {'-label' => 'Reset MySQL psswords',     '-value' => sub{my @nicks = CL::getGroupMembers($real_classname); class__passwds(\@nicks, 'mysql', 0);}},
                        {'-label' => 'Scramble LDAP passwords',  '-value' => sub{my @nicks = CL::getGroupMembers($real_classname); class__passwds(\@nicks, 'ldap', 1);}},
                        {'-label' => 'Scramble MySQL passwords', '-value' => sub{my @nicks = CL::getGroupMembers($real_classname); class__passwds(\@nicks, 'mysql', 1);}},
                    ]},
                    {'-label' => 'Set disk quota limit', '-value' => sub{return class__quota($real_classname)}},
                    {'-label' => 'Create MySQL users + DBs for class', '-value' => sub{return class__mkmysql($real_classname)}},
                    {'-label' => 'Rename class', '-value' => sub{return class__rename($real_classname)}},
	        ];
            push(@{$yr{'-submenu'}}, \%cl);

        }
        push(@classes, \%yr);
}

####################
# Start Curses
####################

our $cui = new Curses::UI("-color_support" => 1, "-clear_on_exit" => 1, -debug => 0);
my @menu = (
	{-label => 'Main', -submenu => [
		{-label => 'Exit ^Q', -value => \&exit_dialog},
	]},
	{-label => 'Students', -submenu => [@yrs]},
	{-label => 'Admins', -submenu => [@admins]},
    {-label => 'Classes', -submenu => [@classes]},
    {-label => 'Misc-users', -submenu => [@misc]},
    {-label => 'Projects', -submenu => [
		{-label => 'New project', -value => \&new_project},
#		{-label => 'Edit project', -value => \&edit_project},
#		{-label => 'Show list of projects', -value => \&show_projects},
		{-label => 'Delete project', -value => \&del_project},
    ]},
);
my $menu = $cui->add('menu','Menubar', -menu => \@menu, -bg  => "blue", -fg => "white");
$cui->set_binding(sub {$menu->focus()}, "\cX");
$cui->set_binding( \&exit_dialog , "\cC");
$cui->set_binding( \&exit_dialog , "\cQ");
$cui->set_binding( \&exit_dialog , "\c[");

# Explaination window
my $w0 = $cui->add(
 	'w0', 'Window', 
  	-border        => 0, 
	-y             => 4, 
);
$w0->add('explain', 'Label', 
    -text => "Welcome to the Open Education Platform (OEP)\n\nNavigation:\n-----------
   CTRL+C and ESC buttons close windows. 
   TAB and arrow keys moves cursor focus\n\n"
);
$w0->loose_focus();
$w0->focusable(0);

# Must define the window parameters for later window creation by mkWindow() etc.
our $w;
our %w;
our $cWin = 0; # Current Window nr.

# Go!
$cui->mainloop(); # Must come AFTER global var defs

####################
# Menu subroutines
####################

sub mkWindow {
    my ($title) = @_;
    my %args = (
        -border       => 1,
        -titlereverse => 0,
        -padtop       => 2,
        -padbottom    => 0,
        -ipad         => 1,
    );
    $cWin++; # Reserve the next ID number for the new window.
    $w{$cWin} = $cui->add(
        "window$cWin", 'Window',
        -title => $title,
        %args
    );
    return $cWin;
}

sub closeWindow {
    if ($cui->getobj("window$cWin")) {
        $cui->delete("window$cWin");
        $cWin -= int($cWin > 0);
    	$cui->draw();
	}
}

sub exit_dialog() {
	# If exit wanted (eg. Esc) but window open, then just close the window.
	if ($cui->getobj("window$cWin")) {
		closeWindow();
		return;
	}

    my $return = $cui->dialog(
        -message   => "Do you really want to quit?",
        -title     => "Are you sure?",
        -buttons   => ['yes', 'no'],
    );
    exit(0) if $return;
}

sub _getUserMenu {
    my ($nick) = @_;
	$menu = [
        {'-label' => 'User information', '-value' => sub{return usr__about($nick, 1)}},
        {'-label' => 'Reset password', -submenu => [
            {'-label' => 'Reset LDAP password',    '-value' => sub{return usr__ldappasswd($nick)}},
            {'-label' => 'Reset MySQL pssword',    '-value' => sub{return usr__mysqlpasswd($nick)}},
            {'-label' => 'Scramble LDAP password', '-value' => sub{return usr__scramble($nick, 'ldap')}},
            {'-label' => 'Scramble MySQL password', '-value' => sub{return usr__scramble($nick, 'mysql')}},            
    	]},
	    {'-label' => 'Statistics: Home directory content', '-value' => sub{return usr__stats_homedir($nick)}},
#        {'-label' => 'Statistics: User log', '-value' => sub{return usr__stats_log($nick)}},
    ];
	return $menu;
}

###########
# USERS
###########

sub usr__about {
    my ($nick, $edit) = @_;
    my $user = CL::mkUserObj($nick);
    my ($quotaCurrent, $quotaLimit) = CL::getQuota($nick);
    $quotaCurrent = sprintf("%.1f", $quotaCurrent);
    my $hasMySQL = CL::hasMysqlAcc($nick);
    my $hasRFID = CL::hasRFID($nick);
    my @admins = CL::getAdmins();
    my $isAdmin = int(CL::in_array(\@admins, $nick));
    my $wid = mkWindow("$nick");
    my ($y, $x1_max, $x2_max);
    $y = $x1_max = $x2_max = 0;
    my %fields;
    tie(%fields, "Tie::IxHash");
    %fields = (
            "Username" => {val => $nick,
                edit => 0,
            },
            "Full name" => {val => $user->get_value('cn'),
                edit => 0,
            },
            "Surname" => {val => $user->get_value('sn'),
                edit => 0,
            },
            "Home" => {val => $user->get_value('homeDirectory'),
		        edit => 0,
            },
            "Shell" => {val => $user->get_value('loginShell'),
            	edit => 0,
            },
            "UID" => {val => $user->get_value('uidNumber'),
                edit => 0,
            },
            "Mobile" => {val => $user->get_value('mobile'),
		        edit => 'str',
		        chfunc => \&setphone,
            },
            "Email" => {val => $user->get_value('mail'),
		        edit => 'str',
		        chfunc => \&setmail,
            },
            "RFID" => {val => $user->get_value('employeeNumber'),
                edit => 'str',
				chfunc => \&setRFIDtag,
            },
           "RFID access level" => {val => $user->get_value('employeeType'),
		        edit => 'menu',
		        menuvals => [0,1,2,3],
		        menulabels => {0 => '0 - No access', 1 => '1 - User access', 2 => '2 - Super User access', 3 => '3 - Administrator access'},
				chfunc => \&setRFIDlevel,
           },
           "Groups" => {val => join(', ', CL::getGroupMemberships($nick)),
		        edit => 'dialog',
                onpress => sub{chmemberships($nick); closeWindow(); usr__about($nick, $edit);},
           },
           "Disk quota" => {val => "Using $quotaCurrent MB of $quotaLimit MB",
		        edit => 'dialog',
                onpress => sub{chquota($nick); closeWindow(); usr__about($nick, $edit); },
           },
           "MySQL" => {val => ($hasMySQL ? 'Yes' : 'No'),
		        edit => (!$hasMySQL ? 'dialog' : 0),
                onpress => sub{mkmysqluser($nick); closeWindow(); usr__about($nick, $edit); },
           },
           "SSH access" => {val => int(CL::getLoginPermission($nick)),
		        edit => 'checkbox',
		        chfunc => \&chloginperm,
           },
           "Is admin" => {val => $isAdmin,
		        edit => 'checkbox',
		        chfunc => \&chadmin,
           },
    );
    foreach (keys(%fields)) {
            $x1_max = length($_) if (length($_) > $x1_max);
            $x2_max = length($fields{$_}{val}) if (length($fields{$_}{val}) > $x2_max);
            $w{$wid}->add(undef, 'Label', -x => 0, -y => $y++, -text => $_);
    }
    $y = 0;
    foreach (keys(%fields)) {
        $w{$wid}->add(undef, 'Label', -x => $x1_max+2, -y => $y, -text => $fields{$_}{val});
        if ($fields{$_}{edit} eq 'str' && $edit) {
            my $str = $w{$wid}->add($_, 'TextEntry', -x => $x1_max+2 + 0*($x2_max+2), -y => $y, -width => $x2_max+4, -sbborder => 1, -text => $fields{$_}{val});
            $str->focus();
        }
        elsif ($fields{$_}{edit} eq 'checkbox') {
            if ($edit) {
                my $cb = $w{$wid}->add($_, 'Checkbox', -x => $x1_max+2 + 0*($x2_max+2), -y => $y, -checked => $fields{$_}{val},);
                $cb->focus();

            }
            else {
    	        $w{$wid}->add($_, 'Label', -x => $x1_max+2, -y => $y, -text => $fields{$_}{val});
            }
        }
        elsif ($fields{$_}{edit} eq 'menu') {
            my $popupbox = $w{$wid}->add($_, 'Popupmenu', -x => $x1_max+2, -y => $y, -values => $fields{$_}{menuvals}, -labels => $fields{$_}{menulabels}, -selected => $fields{$_}{val});
            $popupbox->focus();
        }
	    else {
	        $w{$wid}->add($_, 'Label', -x => $x1_max+2, -y => $y, -text => $fields{$_}{val});
            if ($fields{$_}{edit} eq 'dialog' && $edit) {
                $w{$wid}->add($_.'_button', 'Buttonbox', -x => $x1_max+2+$x2_max + 2, -y => $y , -sbborder => 1, -width => 8, -buttons => [{'-label' => 'Change', '-onpress' => $fields{$_}{'onpress'} }]);
	        }
	    }
        $y++;
    }
	
	my $btn;
	if ($edit) {
		$btn = $w{$wid}->add(undef, 'Buttonbox', -x => 0, -y => $y+2, 
			-buttons => [
				{ -label => "< Save >", -value => "S", -onpress => sub{
						my $this = shift;
						my $user = CL::mkUserObj($nick);
						my %changes = ();
						my $changesMade = "";
						foreach (keys(%fields)) {
							if ($fields{$_}{edit} ne 'str' && $fields{$_}{edit} ne 'checkbox' && $fields{$_}{edit} ne 'menu') {
								next;
							}
							$changes{$_}{new} = $this->parent->getobj($_)->get();
							$changes{$_}{new} = '' if (!defined($changes{$_}{new}) || $changes{$_}{new} eq 'N/A');
							$changes{$_}{old} = $fields{$_}{val};
							$changes{$_}{old} = '' if (!defined($changes{$_}{old}));
							$changes{$_}{isChanged} = ($changes{$_}{new} ne $changes{$_}{old});
							$changesMade .= "$_: ".$changes{$_}{old}." -> ".$changes{$_}{new}."\n" if ($changes{$_}{isChanged});
							$changes{$_}{chfunc} = $fields{$_}{chfunc};
						}
						if ($cui->dialog(-message => "Are you sure you want to save the changes?\n\n".(($changesMade) ? "The following changed were made:\n$changesMade" : "None made.\n"), -buttons => ['yes', 'no'],)) {
							foreach (keys(%changes)) {
								if ($changes{$_}{isChanged}) {
									&{$changes{$_}{chfunc}}($nick, $changes{$_}{new});
								}
							}
						}
						else {
							$cui->error('Aborting');
						}
						closeWindow();
					} 
				},
				{ -label => "< Cancel >", -value => "C", -onpress => sub{closeWindow(); $cui->error('Aborting');} },
			],
		);
	}
	else {
		$btn = $w{$wid}->add(undef, 'Buttonbox', -x => 0, -y => $y+2, -buttons => [{-label => "< OK >", -value => "O", -onpress => sub{closeWindow();}},],);
	}
    $btn->focus();
    
    $w{$wid}->add(undef, 'TextViewer', -x => 0, -y => $y+2+2, -wrapping => 1, -text => "PLEASE NOTE:\n------------\n* Mobile phone numbers should have the country code prefixed! Eg. 0045 for Denmark.\n* Changing group memberhips has NO EFFECT in the menu until the program is restarted!\n* Changing disk quoata limits, group memberships and creating MySQL accounts happen straight away - pressing cancel in this window therefore has no effect once changes to these are made.");
    
    $w{$wid}->focus();
    return;
}

sub chadmin {
    my ($nick, $admin) = @_;
	return CL::setAdminState($nick, (($admin) ? 1 : 0));
}

sub chloginperm {
	my ($nick, $canSSH) = @_;
	return CL::setLoginPermission($nick, (($canSSH) ? 1 : 0));
}

sub setphone {
	my ($nick, $mobile) = @_;
	return CL::setPhone($nick, (!defined($mobile) || !$mobile) ? 0 : $mobile);
}

sub setmail {
	my ($nick, $mail) = @_;
	return CL::setMail($nick, (!defined($mail) || !$mail) ? "" : $mail);
}

sub setRFIDtag {
	my ($nick, $tag) = @_;
	my $user = CL::mkUserObj($nick);
	my $level = $user->get_value('employeeType');
	$level = 0 if (!defined($level) || !$level);
	return CL::setRFID($nick, $tag, $level);
}

sub setRFIDlevel {
	my ($nick, $level) = @_;
	my $user = CL::mkUserObj($nick);
	my $tag = $user->get_value('employeeNumber');
	$tag = 0 if (!defined($tag) || !$tag);
	return CL::setRFID($nick, $tag, $level);
}


sub chfullname {
	my ($nick) = @_;
	my $name = $cui->question("Please enter the new full name of the user.");
	$cui->error('Aborting') and return 0 if !$name;
	my $status = CL::setFullName($nick, $name);
	$cui->dialog((($status) ? "Success" : "Failed"));
	about($nick);
	return $status;
}

sub chmemberships {
    my ($nick, $newMemberships) = @_; # If $newMemberships is set, this function behaves differently: We change memberships of $nick and exit.
    my $user = CL::mkUserObj($nick);
    my %grps = CL::getAllGroups(1);
	my %grps_rev = reverse(%grps); # Invert
	my @classes = values(%grps);
	my @gids = reverse(sort { $grps{$a} cmp $grps{$b} } keys %grps); # Sorts by VALUE (due to the {$a,$b}).
	my @memberships = CL::getGroupMemberships($nick);
	# OVERLOAD?
	if ($newMemberships) {
		my $status = 1;
		my @newMemberships = map($grps{$_}, @$newMemberships); # Translate the passed GIDs to group names.
		# Add new memberships
		foreach (@newMemberships) {
			if (!CL::in_array(\@memberships, $_)) {
		     		$status &= CL::modifyMembership($nick, 'add', $_);
			}
		}
		foreach (@memberships) {
			if (CL::in_array(\@classes, $_) && !CL::in_array(\@newMemberships, $_)) { # Prevent deleting non-class group memberships (www-data, students, wheel etc.). This option only allows changing class memberships. Use the demote/promote admin status for special groups.
				$status &= CL::modifyMembership($nick, 'remove', $_);
			}
		}
		#$cui->dialog("$nick was a member of: ".join(', ', @memberships). "\nBut is now a member of: ".join(', ', CL::getGroupMemberships($nick)));
		$cui->error("REMEMBER: New group memberships are NOT reflected in the main 'classes' menu until you restart oep.pl\n\n".$nick." is now a member of: ".join(', ', CL::getGroupMemberships($nick)));
		return $status; # Don't bring up window again -> quit.
	}
	# END of overload part
	my %selected;
	foreach (@memberships) {
		if (CL::in_array(\@classes, $_)) {
			for (my $i=0; $i<scalar(@gids); $i++) {
				$selected{$i} = 1 if ($gids[$i] == $grps_rev{$_});
			} 
		}
	}
	my $wid = mkWindow('Edit group memberships');
	my $listbox = $w{$wid}->add('groups', 'Listbox', -width => 30, -values => \@gids, -labels => \%grps, -selected => \%selected, -multi => 1, -title => 'Groups', -border => 1);
	$w{$wid}->add(undef, 'Label', -x => 32, -y => 1, -text => "Select which groups $nick should be a member of and click save.");
	$w{$wid}->add(undef, 'Buttonbox', -x => 32, -y => 3, 
		-buttons => [
			{ -label => "< Save >", -value => "S", -onpress => sub{my $this = shift; my @selection = $this->parent->getobj('groups')->get(); chmemberships($nick, \@selection); $this->parent->loose_focus();} },
			{ -label => "< Cancel >", -value => "C", -onpress => sub{my $this = shift; $cui->error('Aborting'); $this->parent->loose_focus();} },
    		],
	);
 	$w{$wid}->modalfocus();
    closeWindow();
	return;	
}

sub chquota {
    my ($nick) = @_;
	my ($bc, $bl) = CL::getQuota($nick);
	my $limit = '';
	while ($limit !~ m/^\d+$/) {
        $limit = $cui->question(((!$limit) ? '' : 'Invalid input, try again. ')."Please enter the new quota limit in MEGABYTES. Enter 0 for no limit.\n\nCurrent limit is $bl MB. Current usage is $bc MB.");
        # Cancel pressed?
        $cui->error('Aborting') and return 0 if !defined($limit);
	}
    my $status = CL::setQuota($nick, $limit);
    $cui->dialog((($status) ? "Success" : "Failed"));
	return $status;
}

sub usr__ldappasswd {
    my ($nick) = @_;
    my $user = CL::mkUserObj($nick);
    my @chls = CL::getComChls($nick);
    $cui->error('Aborting, please set at least one address for either of the communication channels '.join(', ', @CL::SUPPORTED_COM_CHLS). " before continuing.") and return 0 if (!@chls);
    
    my $chl = _askComChannel("Through which communication channel do you wish to send the new password?", \@chls);
    $cui->error('Aborting') and return 0 if !$chl;

    my $sure = $cui->dialog(-message => "Are you sure you want to reset the password of $nick and send the new password to '".$user->get_value($CL::SUPPORTED_COM_CHLS__LDAP_INDEX{$chl})."'?\n\nNote: if this address is incorrect please change it in user ${nick}'s menu.", -buttons => ['yes', 'no'],);

    if ($sure) {
        my $ret = CL::resetPasswd([$nick], $chl, 'ldap', 0);
        $cui->dialog((($ret) ? "Success" : "Failed"));
        return $ret;
    }
    else {
        $cui->error('Aborting');
        return 0;
    }
}

sub usr__scramble {
	my ($nick, $type) = @_;
    my $sure = $cui->dialog(-message => "Are you sure you wish to scrable the $type password?", -buttons => ['yes', 'no'],);
	if ($sure) {
		my $status;
		if ($type eq 'ldap') {
			$status = CL::chPasswd($nick, CL::randPasswd(), $CL::LDAP_ROOTPASSWD, $CL::LDAP_ROOT);
		}
		elsif ($type eq 'mysql') {
			$status = CL::chMysqlPasswd($nick, CL::randPasswd());
		}
		$cui->dialog((($status) ? "Success" : "Failed."));
		return $status;
	}
	else {
		$cui->error('Aborting');
		return 0;
	}
}

sub _mysqlAskSendPasswd {
	my ($nick, $passwd) = @_;
	my @chls = CL::getComChls($nick);
	my $commonStr = "The new MySQL password for $nick is $passwd\nThe names of the MySQL user and database are (both) $nick";
        if (@chls > 0) {
        my $chl = _askComChannel("$commonStr\n\nDo you wish to send the MySQL password directly to the user?", \@chls);
		return 1 if (!$chl);
		my @failed = CL::sendMessage([$nick], "Your MySQL password is $passwd", $chl);
		$cui->dialog((@failed == 0) ? 'Success' : 'Failed to send password');
		return (@failed == 0);
	}
	else {
        $cui->dialog("$commonStr\n\nNote: cannot suggest to send the password directly to the user, since the user does not have any addresses registered for any of the comunication channels: ".join(', ', @CL::SUPPORTED_COM_CHLS));
		return 1;
	}
}

sub mkmysqluser {
    my ($nick) = @_;
    $cui->error("Aborting. $nick already exists as a MySQL user.") and return 0 if (CL::hasMysqlAcc($nick));
	if ($cui->dialog(-message => "Really want to create a MySQL user + DB for $nick?", -title => "Are you sure?", -buttons => ['yes', 'no'],)) {
		my $passwd = CL::mkMysqlUser($nick);
		return 0 if (!$passwd);
		my $ret = _mysqlAskSendPasswd($nick, $passwd);
		about($nick) if $passwd;
        return 1;
	}
	else {
        $cui->error("Aborting");
		return 0;
	}
}

sub usr__mysqlpasswd {
    my ($nick) = @_;
    $cui->error("Aborting, $nick does not have a MySQL user.") and return 0 if !CL::hasMysqlAcc($nick);
    if ($cui->dialog(-message => "Continue? This will reset the MySQL password to a new random password.", -title => "Are you sure?",  -buttons => ['yes', 'no'],)) {
		my $passwd = CL::randPasswd();
        my $status = CL::chMysqlPasswd($nick, $passwd);
		$cui->error("Failed") and return 0 if !$status;
        my $ret = _mysqlAskSendPasswd($nick, $passwd);
		return 1;
	}
	else {
        $cui->error('Aborting');
		return 0;
	}
}

sub usr__stats_homedir {
	my ($nick) = @_;
	my ($yr, $intvl);
	if ($nick =~ /^.*(\d\d)$/) {
        	$yr = int('20'.$1);
       		$intvl = $yr.'-'.($yr+1);
	}
	else {
		$intvl = 'system';
	}
 	my $heredoc = sprintf("%-6s %10s %6s  %-40s\n", 'Week', 'Home size', 'Files', 'Backup');
	$heredoc .= "--------------------------------\n";
	$cui->status('Please wait, this may take a some time...');
        foreach my $w (1..52) {
        	$w = "0$w" if ($w <= 9);
                my $home = $CL::BACKUP_BASE."/week$w/$intvl/$nick";
		my ($size, $fcount);
		if (-d $home) {
			$size = `du -h --summarize $home`;
			chomp($size);
			$size =~ /^([A-Za-z0-9,]*)/;
			$size = $1;
			$fcount = `find $home | wc -l`;
			chomp($fcount);
		}
		else {
			$size = $fcount = 0;
			$home = 'N/A';
		}
		$heredoc .= sprintf("%-6s %10s %6s  %-40s\n", $w, $size, $fcount, $home);
	}
	$cui->nostatus();

	my $wid = mkWindow('Statistics: Home directory');
	$w{$wid}->add(undef, 'Label', -text => "These are the statistics of $nick.\n");
	$w{$wid}->add(
	    'stats_homedir', 'TextViewer',
	    -y => 2, -x => 0, -border => 1, -padbottom => 0, -width => 90, -vscrollbar => 1, -hscrollbar => 1,
	    -title => $nick,
	    -text => $heredoc,
	);
	
	$w{$wid}->focus();
}

sub usr__stats_log {
	my ($nick) = @_;
    my $wid = mkWindow('Statistics: Log');
        $w{$wid}->add(undef, 'Label', -text => "This is the log history of $nick.\n");
#        self::EVENT_WIKI_LOGIN      => 'Wiki login',
#        self::EVENT_WIKI_PAGE_EDIT  => 'Wiki page edit',
#        self::EVENT_SSH_LOGIN       => 'SSH cmd login',

        $w{$wid}->add(
            'stats_log_wikilogin', 'TextViewer',
            -y => 2, -x => 0, -border => 1,
            -padbottom => 0,
            -width => 30,
            -title => "Wiki login",
            -vscrollbar => 1,
            -hscrollbar => 1,
            -text => "abc" # "$heredoc,
        );
        $w{$wid}->add(
            'stats_log_wikipageedit', 'TextViewer',
            -y => 2, -x => 30, -border => 1,
            -padbottom => 0,
            -width => 30,
            -title => "Wiki page edit",
            -vscrollbar => 1,
            -hscrollbar => 1,
            -text => "abc" # "$heredoc,
        );
        $w{$wid}->add(
            'stats_log_sshshelllogin', 'TextViewer',
            -y => 2, -x => 60, -border => 1,
            -padbottom => 0,
            -width => 30,
            -title => "SSH shell login",
            -vscrollbar => 1,
            -hscrollbar => 1,
            -text => "abc" # "$heredoc,
        );
        $w{$wid}->add(
            'stats_log_ls', 'TextViewer',
            -y => 2, -x => 90, -border => 1,
            -padbottom => 0,
            -width => 30,
            -title => "Lime surveys taken",
            -vscrollbar => 1,
            -hscrollbar => 1,
            -text => "abc" # "$heredoc,
        );
        
	$w{$wid}->focus();
}

##################
# CLASSES
##################

sub _class_getMemberObjs {
	my ($class) = @_;
	my @members = sort(CL::getGroupMembers($class));
	my %members;
	foreach (@members) {
		$members{$_} = CL::mkUserObj($_);
	}
	return %members;
}

sub _class_getLarLen {
    my ($class, $field) = @_;
    my %members = _class_getMemberObjs($class);
    my $larlen = 0;
	foreach (keys(%members)) {
		my $len = length($members{$_}->get_value($field));
		$larlen = $len if ($len > $larlen);
	}
	return $larlen;
}

sub class__about {

	my ($class) = @_;
    my %members = _class_getMemberObjs($class);
    my $gocos_larlen = _class_getLarLen($class, 'gecos');
    
	my $str = sprintf(
	    "%3s  %-${gocos_larlen}s %-20s %-10s %-12s %19s %10s %10s %10s\n", 
	    "\#", 'Name', 'User ID', 'UID', 'RFID level', 'Quota [MB]', 'MySQL', 'SSH acc.', 'Admin'
    );
	$str .= "-------------------\n";
	my $n = 1;
    my @admins = CL::getAdmins();
	foreach (sort(keys(%members))) {
		my $user = $members{$_}; # same as CL::mkUserObj($_);
	        my ($quotaCurrent, $quotaLimit) = CL::getQuota($_);
	    	$quotaCurrent = sprintf("%.1f", $quotaCurrent);
	        my $hasMysql = CL::hasMysqlAcc($_) ? 'Yes' : 'No';
    		my $canSSH = CL::getLoginPermission($_) ? 'Yes' : 'No';
            my $isadmin = int(CL::in_array(\@admins, $_)) ? 'Yes' : 'No';
		$str .= sprintf(
		    "%3s  %-${gocos_larlen}s %-20s %-10s %-12s %19s %10s %10s %10s\n", 
		    $n++, $user->get_value('gecos'), $_, $user->get_value('UidNumber'), $CL::RFID_ACCESS_LEVELS_DESC{$user->get_value('employeeType')}, (($quotaCurrent >= $quotaLimit && $quotaCurrent != 0) ? '[!!] ' : '')."$quotaCurrent of $quotaLimit", $hasMysql, $canSSH, $isadmin
	    );
	}

        my $wid = mkWindow("Class members of $class");
#        $w{$wid}->add(undef, 'Label', -text => "Class $class has ".scalar(keys(%members))." members.\n\nPress ESC to close this windows.\n");
        $w{$wid}->add(undef, 'Label', -text => "Press ESC to close this window.\n");
        $w{$wid}->add(
            'stats_homedir', 'TextViewer',
            -y => 2, -x => 0, -border => 1, -padbottom => 0, -padtop => 0, -vscrollbar => 1, -hscrollbar => 1,
            -title => "$class",
            -text => $str,
        );
        $w{$wid}->focus();
}

sub class__popcontacts {

	my ($class) = @_;
    my %members = _class_getMemberObjs($class);
    my $gocos_larlen = _class_getLarLen($class, 'gecos');
    my $wid = mkWindow("$class");
    my $y = 0;
    my %fields;
    tie(%fields, "Tie::IxHash");
    %fields = (
        "Username" => {val => 'uid',
            edit => 0,
        },
        "Full name" => {val => 'gecos',
            edit => 0,
        },
        "Mobile" => {val => 'mobile',
	        edit => 'str',
	        minlength => length('Mobile')+2,
	        maxlength => 14,
	        chfunc => \&setphone,
        },
        "Email" => {val => 'mail',
	        edit => 'str',
	        minlength => length('Email')+2,
	        maxlength => 20,
            chfunc => \&setmail,
        },
        "RFID" => {val => 'employeeNumber',
            edit => 'str',
            length => 12,
            chfunc => \&setRFIDtag,
        },
       "RFID access level" => {val => 'employeeType',
	        edit => 'menu',
	        length => 14,
	        menuvals => [0,1,2,3],
	        menulabels => \%CL::RFID_ACCESS_LEVELS_DESC, # {0 => '0 - No access', 1 => '1 - User access', 2 => '2 - SU access', 3 => '3 - Admin access'},
	        chfunc => \&setRFIDlevel,
       },
    );
    my %lengths;
    my %lengths_culm;
    foreach (keys(%fields)) {
        $lengths{$_} = (defined($fields{$_}{length})) ? $fields{$_}{length} : _class_getLarLen($class, $fields{$_}{val});
        $lengths{$_} = $fields{$_}{minlength} if (defined($fields{$_}{minlength}) && $lengths{$_} < $fields{$_}{minlength});
        $lengths{$_} = $fields{$_}{maxlength} if (defined($fields{$_}{maxlength}) && $lengths{$_} > $fields{$_}{maxlength});
        my $culm = 0; ($culm += $_) for values(%lengths); 
        $lengths_culm{$_} = $culm + 4*(scalar(keys(%lengths))-1);
        $w{$wid}->add(undef, 'Label', -x => $lengths_culm{$_} - $lengths{$_}, -y => 0, -text => $_);
        $w{$wid}->add(undef, 'Label', -x => $lengths_culm{$_} - $lengths{$_}, -y => 1, -text => '-' x length($_));
    }
    $y+=2;

    foreach my $nick (sort(keys(%members))) {
        foreach (keys(%fields)) {
            if ($fields{$_}{edit} eq 'str') {
                my $str = $w{$wid}->add($nick.'_'.$fields{$_}{'val'}, 'TextEntry', -x => $lengths_culm{$_} - $lengths{$_}, -y => $y, -width => $lengths{$_}+3, -sbborder => 1, -text => $members{$nick}->get_value($fields{$_}{'val'}));
#                $str->focus();
            }
            elsif ($fields{$_}{edit} eq 'menu') {
                my $popupbox = $w{$wid}->add($nick.'_'.$fields{$_}{'val'}, 'Popupmenu', -x => $lengths_culm{$_} - $lengths{$_}, -y => $y, -values => $fields{$_}{menuvals}, -labels => $fields{$_}{menulabels}, -selected => $members{$nick}->get_value($fields{$_}{'val'}));
#                $popupbox->focus();
            }
            else {
    	        $w{$wid}->add($nick.'_'.$fields{$_}{'val'}, 'Label', -x => $lengths_culm{$_} - $lengths{$_}, -y => $y, -text => $members{$nick}->get_value($fields{$_}{'val'}));
            }
	    }
        $y++;
        $w{$wid}->draw(); # We update on the fly because this screen may take a while to create, and we don't want the user to think something is wrong (don't want to use a progressbar either).
    }
    
	my $btn = $w{$wid}->add(undef, 'Buttonbox', -x => 0, -y => $y+2, 
		-buttons => [
			{ -label => "< Save >", -value => "S", -onpress => sub{
					my $this = shift;
					my %changes;
					my $changesMade = 0;
                    foreach my $nick (sort(keys(%members))) {
                        foreach (keys(%fields)) {
							$changes{$nick}{$_}{new} = $this->parent->getobj($nick.'_'.$fields{$_}{val})->get();
							$changes{$nick}{$_}{new} = '' if (!defined($changes{$nick}{$_}{new}));
							$changes{$nick}{$_}{old} = $members{$nick}->get_value($fields{$_}{val});
							$changes{$nick}{$_}{old} = '' if (!defined($changes{$nick}{$_}{old}));
							$changes{$nick}{$_}{isChanged} = ($changes{$nick}{$_}{new} ne $changes{$nick}{$_}{old});
							$changesMade++ if $changes{$nick}{$_}{isChanged};
							$changes{$nick}{$_}{chfunc} = $fields{$_}{chfunc};
						}
                    }
                    
					if ($changesMade == 0) {
						$cui->error('No changes made');
					}
					elsif ($cui->dialog(-message => "Are you sure you want to save the changes?\n$changesMade changes were made.", -buttons => ['yes', 'no'],)) {
						foreach my $nick (keys(%changes)) {
							foreach (keys(%fields)) {
								if ($changes{$nick}{$_}{isChanged}) {
									my $func = $changes{$nick}{$_}{chfunc};
									&$func($nick, $changes{$nick}{$_}{new});
								}
							}
						}
					}
					else {
						$cui->error('Aborting');
					}
					$cui->dialog('Success');
					closeWindow();
				} 
			},
			{ -label => "< Cancel >", -value => "C", -onpress => sub{$cui->error('Aborting'); closeWindow();} },
		],
	);
    $btn->focus();
    $w{$wid}->add(undef, 'TextViewer', -x => 0, -y => $y+2+2, -wrapping => 1, -text => "PLEASE NOTE:\n------------\n* Mobile phone numbers should have the country code prefixed! Eg. 0045 for Denmark.\n");
    $w{$wid}->focus();
    return;
}

sub class__rename {
	my ($grp) = @_;
	$grp =~ m/^(\d{4})\_(.*)$/;
	my $year = $1;
	my $oldName = $2;
    my $newName = $cui->question(-question => "What would you like to rename '$grp' as?\nIMPORTANT: Ommiting the year prefix will keep the current prefix '${year}_' of '$grp'. Adding the prefx explicitly will not only rename the class but also move the class to the year that the prefix represents.");
    $cui->error('Aborting') and return 0 if (!defined($newName) || !$newName || !$cui->dialog(-message => "You entered '$newName', do you wish to continue?", -buttons => ['yes', 'no'],));
	if ($newName !~ m/^\d{4}\_/) {
		$newName = "${year}_$newName";
	}
	my $status = CL::renameGroup($grp, $newName);
    $cui->dialog((($status) ? "Success" : "Failed"));
	return $status;
}

sub class__quota {
	my ($class) = @_;
    my @members = CL::getGroupMembers($class);
    my $limit = '';
    while ($limit !~ m/^\d+$/) {
        $limit = $cui->question(((!$limit) ? '' : 'Invalid input, try again. ')."Please enter the new quota limit in MEGABYTES. Enter 0 for no limit.\n");
        # Cancel pressed?
        $cui->error('Aborting') and return 0 if !defined($limit);
    }
	my $status = 1;
    foreach (@members) {
        $status &&= CL::setQuota($_, $limit);
	}        
	$cui->dialog((($status) ? "Success" : "Failed"));
    return class__about($class);
}

sub class__mkmysql {
	my ($class) = @_;
	my $chl = _askComChannel("Through which channel do you wish to send the MySQL passwords to each user?", \@CL::SUPPORTED_COM_CHLS);
	$cui->error('Aborting') and return 0 if (!$chl);
    my @users; 
	@users = CL::getGroupMembers($class);
    my @noAddr = CL::isUncommunicatable(\@users, $chl);
    if (@noAddr > 0) {
        $cui->error('Aborting') and return 0 if (!$cui->dialog(-message => "The following users do not have a registered address for the communication channel '$chl' (ie. cannot send their MySQL passwords to them). Do you wish to continue anyway?\n\nThe uncommunicatable users are:\n".join(', ', @noAddr), -buttons => ['yes', 'no'],));
    }
	my @failed;
	my @existing;
	my @success;
	foreach (@users) {
	    if (CL::in_array(\@noAddr, $_)) {
	        next;
	    }
		if (CL::hasMysqlAcc($_)) {
		    push(@existing, $_);
			next;
		}
		my $passwd = CL::mkMysqlUser($_);
		my @fail = CL::sendMessage([$_], "Your MySQL password is $passwd", $chl);
		push(@failed, $_) if (@fail != 0);
	}
    $cui->dialog("Status:\n\n".
        scalar(@success)." created successfully.\n\n".
        scalar(@noAddr)." had no registred address.\n\n".
        scalar(@failed)." failed: ".join(', ', @failed)."\n\n".
        scalar(@existing)." already has MySQL: ".join(', ', @existing)
    );
    return class__about($class);
}

sub class__passwds {
	my ($ref_nicks, $type, $quite) = @_;
	my $user_cnt = scalar(@$ref_nicks);
	$cui->error('Aborting') and return 0 if (!$cui->dialog(-message => "Are you sure you wish to ".(($quite) ? 'scramble' : 'reset')." the ".(($type eq 'ldap') ? 'LDAP' : 'MySQL')." password of $user_cnt users?", -buttons => ['yes', 'no']));

	my $chl = 0;
	if (!$quite) {
	    $chl = _askComChannel("Through which communication channel do you wish to send the new passwords?\nNOTE: The users who do not have this channel registered cannot recieve their password.", \@CL::SUPPORTED_COM_CHLS);
	    $cui->error('Aborting') and return 0 if !$chl;
	}
	$cui->status('Please wait, this may take a some time...');
	my $OK = CL::resetPasswd($ref_nicks, $chl, $type, $quite);
	$cui->nostatus();
	return $OK;
}

####################
# Projects
####################

sub projectPage {
    my ($new, @parms) = @_;
    my ($user, $title, $quota, $opendate, $closedate, @members) = @parms;
    my $wid = mkWindow("Project");
    my $y = 0;
    my $name_length = 29;
    $w{$wid}->add(undef, 'Label', -x => 0, -y => $y++, -text => "Project user name");
    $w{$wid}->add('user', 'TextEntry', -x => 0, -y => $y++, -width => $name_length+5, -maxlength => $name_length, -sbborder => 1, -text => defined($user) ? $user : "Username (max $name_length characters)");
    $y++;
    $w{$wid}->add(undef, 'Label', -x => 0, -y => $y++, -text => "Title");
    $w{$wid}->add('title', 'TextEntry', -x => 0, -y => $y++, -width => 40, -maxlength => 100, -sbborder => 1, -text => defined($title) ? $title : 'Title text (max 100 characters)'); 
    $y++;       
    $w{$wid}->add(undef, 'Label', -x => 0, -y => $y++, -text => "Quota in MB");
    $w{$wid}->add('quota', 'TextEntry', -x => 0, -y => $y++, -width => 10, -maxlength => 6, -sbborder => 1, -text => defined($quota) ? $quota : '30');
    $y++;        
    $w{$wid}->add(undef, 'Label', -x => 0, -y => $y++, -text => "Open date");
    $w{$wid}->add('opendate', 'TextEntry', -x => 0, -y => $y++, -width => 14, -maxlength => 10, -sbborder => 1, -text => defined($opendate) ? $opendate : 'yyyy-mm-dd'); 
    $y++;        
    $w{$wid}->add(undef, 'Label', -x => 0, -y => $y++, -text => "Close date");
    $w{$wid}->add('closedate', 'TextEntry', -x => 0, -y => $y++, -width => 14, -maxlength => 10, -sbborder => 1, -text => defined($closedate) ? $closedate : 'yyyy-mm-dd'); 
    $y++;
    $w{$wid}->add(undef, 'Label', -x => 0, -y => $y++, -text => "Members");
    $w{$wid}->add('members', 'TextEntry', -x => 0, -y => $y++, -width => 70, -sbborder => 1, -text => (@members && scalar(@members) > 0) ? join(',', @members) : 'userid1,userid2,userid2');
    
	my $btn1 = $w{$wid}->add(undef, 'Buttonbox', -x => 0, -y => $y+2,
    	-buttons => [
                { -label => "< Save >", -value => "S", -onpress => sub{
					my $this = shift;
                    my $errmsg = '';
					my $user = $this->parent->getobj('user')->get();
					$errmsg = 'Username may not contain spaces. Use underscores instead.' if ($user =~ m/\s/);
					my $title = $this->parent->getobj('title')->get();
					$errmsg = 'Title may not contain either kind of apostrophes/quotation marks.' if ($title =~ m/(\'|\")/);
					my $quota = $this->parent->getobj('quota')->get();
					$errmsg = 'The quota must be a number.' if ($quota =~ m/[^0-9]/);
					my $opendate = $this->parent->getobj('opendate')->get();
					my $closedate = $this->parent->getobj('closedate')->get();
					$errmsg = 'Please use the format yyyy-mm-dd for the date with NO spaces.' if ($opendate !~ m/^\d{4}\-\d{2}\-\d{2}$/ || $closedate !~ m/^\d{4}\-\d{2}\-\d{2}$/);
					my $members = $this->parent->getobj('members')->get();
					$members =~ s/\s//g;
					my @members = split(/,/, $members);
					foreach (@members) {
					    my $member = CL::mkUserObj($_);
					    $errmsg = "The user '$_' does not exist" if (!$member);
					}
					$cui->dialog("Error!\n\n$errmsg") and return if ($errmsg);
					my $status = CL::createProject($user, $title, $opendate, $closedate, \@members);
#					CL::setQuota($user, $quota); # DOES NOT WORK. mkUserObj in this func uses the wrong LDAP base tree for users (ou=People, not ou=prusers).
					$cui->dialog(((!$status) ? "Success" : "Failed")); # Statuses are "unix inverted" (0 = OK).
					closeWindow();
                }},
                { -label => "< Cancel >", -value => "C", -onpress => sub{ $cui->error('Aborting'); closeWindow();}}, #Delete and refresh
        ]
    );
    
}

sub new_project {
    projectPage(1);
}

sub edit_project {
    projectPage(0, 'edit');
}

sub del_project {
	DEL_PR__ENTER_NAME:
	my $prname = $cui->question('Please enter the project user name');
	$cui->error('Aborting') and return 0 if !defined($prname);
	my $prid = CL::getProjectID($prname);
	$cui->error("A project by the name '$prname' does not exist.") and goto DEL_PR__ENTER_NAME if !$prid;
	if (!CL::deleteProject($prid)) {
		$cui->dialog('Success');
	}
	else {
		$cui->error('Failed');
	}
	return 0;
}

sub show_projects {
}

####################
# Misc
####################

sub openUserProfile {
	
	USRPROF__ENTER_USER_ID:
	my $nick = $cui->question('Please enter user ID');
	$cui->error('Aborting') and return 0 if !defined($nick);
	my $user = CL::mkUserObj($nick);
	$cui->error("User does '$nick' not exist, try again.") and goto USRPROF__ENTER_USER_ID if !$user;
    usr__about($nick, 1);
}

sub _askComChannel {
    my ($msg, $ref_allowedChls) = @_;
    my @buttons;
    push(@buttons, {-label => '<Send by SMS>',      -value => 2, -shortcut => 's'}) if CL::in_array($ref_allowedChls, 'sms');
    push(@buttons, {-label => '<Send by email>',    -value => 1, -shortcut => 'm'}) if CL::in_array($ref_allowedChls, 'mail');
    push(@buttons, {-label => '<Don\'t send>',      -value => 0, -shortcut => 'd'});
    my $chl = $cui->dialog(-message => $msg, -title => "Select communication channel", -buttons => \@buttons);
    return (($chl == 2) ? 'sms' : (($chl == 1) ? 'mail' : 0));
}

