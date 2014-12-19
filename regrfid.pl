#!/usr/bin/perl
# Nicholas Mossor Rathmann, 2010, MediaLab.

# Sets user RFID access.
# Arguments: User, RFID ID, Level
# Example: regrfid.pl "philiph10" 99999 3
# Valid levels: 0, 1, 2, 3 See commonLibrary.pl RFID_ACCESS_LEVELS

require('/files/scripts/commonLibrary.pl');

# Get varaibles from arguments.
my ($nick, $RFID, $level) = ($ARGV[0], $ARGV[1], $ARGV[2]);

# Set RFID access.
exit CL::setRFID($nick, $RFID, $level);
