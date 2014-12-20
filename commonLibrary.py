def userExists(username):
    if (username == "philiph10"):
        return True
    else:
        return False


def makeUser(full_name, year, class_number, username=None):
    if (not username):
        username = genUsername(full_name, year)
    return username, (username + ".txt")


def genUsername(full_name, year):
    full_name = full_name.lower()
    name_parts = full_name.split()
    if (len(name_parts) > 1):
        username = name_parts[0] + name_parts[len(name_parts) - 1][0]
    else:
        username = full_name
    username += year[2:]
    return username
