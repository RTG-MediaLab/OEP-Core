#!/usr/bin/env python3

# Philip Peder Hansen, 2014.

# Adds a user to the system.
# Arguments: Full name of user, year, class number, [username]
# Example: adduser.py "Nicholas Mossor Rathmann" 2005 3

import sys
import commonLibrary


def main(argv):
    if (correct_argument_count(argv)):
        try_make_user(argv)
    else:
        usage()


def try_make_user(argv):
    full_name, year, class_number, username = get_variables(argv)

    if (username and commonLibrary.userExists(username)):
        user_exists(username)

    username, info_file = commonLibrary.makeUser(full_name, year, class_number, username)
    user_created(full_name, username, info_file)


def correct_argument_count(argv):
    return ((len(argv) == 3) or (len(argv) == 4))


def get_variables(argv):
    return argv[0], argv[1], argv[2], (argv[3] if len(argv) > 3 else None)


def user_exists(username):
    print("Username: " + username + " already in use!")
    sys.exit(1)


def user_created(full_name, username, info_file):
    print(full_name + " was created as " + username + ".")
    print("Info file generated at: " + info_file)


def usage():
    print("Usage: adduser.py full_name year class [username]")

if __name__ == "__main__":
    main(sys.argv[1:])
