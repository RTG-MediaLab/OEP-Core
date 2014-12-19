#!/usr/bin/perl
# System status reporter, Nicholas Mossor Rathmann, 2010.
require "/files/scripts/commonLibrary.pl";

my @admins = CL::getAdmins();
my %recps;
foreach (@admins) {
	my @chls = CL::getComChls($_);
	if (CL::in_array(\@chls, 'mail')) {
		my $user = CL::mkUserObj($_);
		$recps{$_} = $user->get_value('mail');
	}
}

print("None of the admin users ".join(', ', @admins)." have registered an email address in LDAP.\n") and exit 1 if (keys(%recps) == 0);

print "Will send reports to the following admins, who have their mail address registered in LDAP:\n";
foreach (keys(%recps)){
	print $_." at ".$recps{$_}."\n";
}

my $df = `df -h | grep -v none`;
my $mdadm = `mdadm --detail /dev/md0 | egrep -w 'Persistence|Total|Active|Working|Failed|Number|dev'`;
my $dirs = " $CL::BACKUP_BASE/week".(($b1 = ($a1=`date +%W -d 'last week'`+0)) < 10 ? "0$b1" : $b1 ). 
		   " $CL::BACKUP_BASE/week".(($b2 = ($a2=`date +%W               `+0)) < 10 ? "0$b2" : $b2 ). 
		   " $CL::BACKUP_BASE/week".(($b3 = ($a3=`date +%W -d 'next week'`+0)) < 10 ? "0$b3" : $b3 ); 
my $backups = `du -h --summarize --time $dirs`;
my $clamscan = `clamscan -i -r $CL::HOMES_BASE /tmp /bin /sbin`;
	#my $clamscan = `clamscan -i -r /tmp`; # For testing script only
my $rkhunter = `rkhunter --cronjob --report-warnings-only`;
my $chkrootkit = `chkrootkit -q `;
`apt-get update`; # Must be run before upgrade to renew package list.
my $newpkgs = `apt-get -s upgrade`;
# Disk SMART
my @disks = ('/dev/sda', '/dev/sdb', '/dev/sdc', '/dev/sdd');
my $smartctl = '';
$smartctl .= "$_ ".`smartctl -H $_ | grep 'Status'` foreach (@disks);

my $startend = '=' x 15; 
my $report = <<END;
OEP automated fileserver (fs) status report

$startend  DISK USAGE  $startend
$df

$startend  RAID STATUS $CL::HOMES_BASE  $startend
$mdadm

$startend  DISK HEALTH  $startend
$smartctl

$startend  BACKUP STATUS  $startend
$backups

$startend  ROOTKIT SCANNER "rkhunter"  $startend
$rkhunter

$startend  ROOTKIT SCANNER "chkrootkit"  $startend
$chkrootkit

$startend  CLAM ANTIVIRUS SCAN  $startend
$clamscan

$startend  OUTDATED SOFTWARE  $startend
$newpkgs

---------- END OF REPORT ----------
END

print "SENDING THIS MESSAGE:\n".$report."MESSAGE END\n";
foreach (keys(%recps)) {
	print "Sending to $_...";
	my @failed = CL::sendMessage([$_],  $report, 'mail');
	print ((scalar(@failed) > 0) ? "failed.\n" : "done\n");
}
exit 0;
