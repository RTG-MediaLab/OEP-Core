import os           # OS - Path, directories etc.
import ldap         # LDAP
import MySQLdb      # MySQL
import re           # Regex

# Common Library - Python
# Michael Bisbjerg - 2010

class commonLibrary:
    # Settings
    
    # MySQL
    global MYSQL_HOST
    
    MYSQL_HOST = 'localhost'

    # LDAP
    global LDAP_HOST
    global LDAP_PORT
    global LDAP_DN_GROUPS
    global LDAP_DN_USERS
    
    LDAP_HOST = '10.0.0.18';
    LDAP_PORT = 389;
    LDAP_DN_GROUPS = 'ou=Group,dc=rtgkom';
    LDAP_DN_USERS = 'ou=People,dc=rtgkom';

    def mysql(self, DB):
        return MySQLdb.connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, DB)
    
    def getGroups(self):
        oldap = ldap.open(LDAP_HOST, LDAP_PORT)
        oldap.simple_bind_s()
        resultset = ['cn', 'gidnumber']
        result = oldap.search_s(LDAP_DN_GROUPS, 1, '(objectClass=posixGroup)', resultset)

        regex = [re.compile("\d\d\d\d_\d\Z"), re.compile(".*\d\d\Z")]
        resultset = {}
        for i in enumerate(result):
            v = i[1][1]
            gidNum = v['gidNumber'][0]
            cn = v['cn'][0]

            for p in regex:
                if p.match(cn):
                    resultset[gidNum] = cn
        
        return resultset
        
    def _getMembers(self, filter):
        oldap = ldap.open(LDAP_HOST, LDAP_PORT)
        oldap.simple_bind_s()
        resultset = ['uid', 'cn', 'uidnumber', 'gidnumber', 'mobile']
        result = oldap.search_s(LDAP_DN_USERS, 1, filter, resultset)

        resultset = {}
        for i in enumerate(result):
            v = i[1][1]
            uidNum = v['uidNumber'][0]
            cn = v['cn'][0]
            uid = v['uid'][0]
            gidNum = v['gidNumber'][0]
	    mobile = v['mobile'][0]

            resultset[uid] = {'cn':cn, 'uid':uidNum, 'gid':gidNum, 'mobile':mobile}
        
        return resultset

    def getMember(self, userid):
        members = self._getMembers('(&(objectClass=posixAccount)(uid=' + userid + '))')
        if len(members) == 0:
            return null
        else:
            return members[userid]
        
    def getMembersOfGroup(self, group):
        oldap = ldap.open(LDAP_HOST, LDAP_PORT)
        oldap.simple_bind_s()
        resultset = ['gidnumber', 'cn', 'memberuid']
        if str(group).isdigit():
            # Group ID
            filter = "(&(objectClass=posixGroup)(gidnumber=" + str(group) + "))"
        else:
            # Common Name
            filter = "(&(objectClass=posixGroup)(cn=" + str(group) + "))"
        
        result = oldap.search_s(LDAP_DN_GROUPS, 1, filter, resultset)

        v = result[0][1]

        if 'memberUid' in v:
            filter = ""
            for i in v['memberUid']:
                filter += "(uid=" + i + ")"
            filter = "(&(objectClass=posixAccount)(|" + filter + "))"

        if filter != "":
            return self._getMembers(filter)
        else:
            return  {}

class Handin(commonLibrary):
    # Settings
    global HANDIN_BASEDIR
    
    HANDIN_BASEDIR = '/filer/handins/'
    
    # MySQL
    global MYSQL_DB
    global MYSQL_USER
    global MYSQL_PASS
    
    MYSQL_DB = 'handin'
    MYSQL_USER = 'michaelgb07'
    MYSQL_PASS = 'mysqlpassword'

    def AddHandin(self, user, title, description, url, groups, duedate):
        # Add notification
        db = self.mysql(MYSQL_DB)
        cursor = db.cursor()
        cursor.execute("INSERT INTO `tasks` (`tauthor`, `tdue`, `ttitle`, `tdescription`, `tgroups`, `turl` ) " +
                       "VALUES (%s, %s, %s, %s, %s, %s);",
                        [ user, duedate, title, description, groups, url ])

        # Get ID
        handin_id = int(cursor.lastrowid)
        
        # Make folders
        # Check access - if sudo or root is used, everything is ok
        access = os.access(HANDIN_BASEDIR, os.F_OK | os.R_OK | os.W_OK)

        if access == True:
            # Valid
            handin_curdir = HANDIN_BASEDIR + str(handin_id) + "/"
            os.makedirs(handin_curdir)

            # Iterate users in groups
            for i in groups.split(";"):
                members = self.getMembersOfGroup(i)
                for v in members.keys():
                    # Make dir
                    os.makedirs(handin_curdir + str(v))

            # Done
            print "Done making handin"
        else:
            print "Access error. Are you root?"

        
    def CreateTable(self):
        db = self.mysql(MYSQL_DB)
        cursor = db.cursor()
        cursor.execute("CREATE TABLE `tasks` ( " + 
                          "`tid` int(11) NOT NULL AUTO_INCREMENT, " + 
                          "`tauthor` varchar(50) COLLATE utf8_bin NOT NULL, " + 
                          "`tdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, " +
                          "`tdue` date NOT NULL, " + 
                          "`ttitle` varchar(200) COLLATE utf8_bin NOT NULL, " + 
                          "`tdescription` text COLLATE utf8_bin NOT NULL, " + 
                          "`tgroups` varchar(250) COLLATE utf8_bin NOT NULL, " + 
                          "`turl` varchar(255) COLLATE utf8_bin NOT NULL, " + 
                          "PRIMARY KEY (`tid`) " + 
                        ") ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_bin")
        

def TestLib():
    test = commonLibrary()
    result = test.getGroups()

    print "Groups Test"
    print "Got result: " + str(len(result)) + " groups"
    #print result
    print "Group ID 8610: " + result['8610']
    print "SUCCESS!"

    print ""
    print "Members Test"

    result = test._getMembers('(objectClass=posixAccount)')

    print "Got result: " + str(len(result)) + " users"
    #print result
    print "User ID michaelgb07: "
    print result['michaelgb07']
    print "SUCCESS!"

    print ""
    print "Member Test"

    result = test.getMember('michaelgb07')
    print result
    print "SUCCESS!"

    print ""
    print "Members by Group Test (2005_5)"
    result = test.getMembersOfGroup('2005_5')
    print result
    print "SUCCESS!"

    print ""
    print "Members by Group Test (1005)"
    result = test.getMembersOfGroup('1005')
    print result
    print "SUCCESS!"

    print ""
    print "Members by Group Test (2406)"
    result = test.getMembersOfGroup('2406')
    print result
    print "SUCCESS!"

    print "All sucessfull"
