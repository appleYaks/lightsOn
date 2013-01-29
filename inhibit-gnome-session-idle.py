#!/usr/bin/env python

# This script is invoked by lightsOn.sh itself.

# This script exists because even after removing gnome-screensaver, the GNOME system may still turn off the screen
# after the idle timer in the gnome-control-center kicks in. Removing /usr/bin/gnome-screensaver-command may fix this,
# but you lose the ability to lock the screen from the Menu, or by Ctrl+Alt+L. Making gnome-screensaver-command a
# symlink to /usr/bin/xscreesaver-command will allow you to keep that feature, but may be the reason for the screen poweroff.
#
# This script will inhibit the GNOME SessionManager idle timer from taking place.
#
# More info:
# http://www.lucidelectricdreams.com/2011/06/disabling-screensaverlock-screen-on.html

import time
import dbus
import sys
import subprocess

bus = dbus.SessionBus()
proxy = bus.get_object('org.gnome.SessionManager', '/org/gnome/SessionManager')
# org.gnome.SessionManager.Inhibit(String app_id, UInt32 toplevel_xid, String reason, UInt32 flags) -> UInt32 inhibit_cookie
# Getting the cookie isn't necessary because quitting the script is another way to remove the Inhibit.
#
# More info on this DBUS API:
# http://people.gnome.org/~mccann/gnome-session/docs/gnome-session.html
proxy.Inhibit("lightsOn", dbus.UInt32(0), "Xscreensaver does the job now.", dbus.UInt32(8))

# Arguments for this script are:
#   * PID of the lightsOn.sh bash script
#   * Time interval to check the above PID is still running
#
# If no time interval is given, the default of 60 seconds kicks in.
# If the PID given is no longer running, this script will exit and close the DBUS connection, removing the Inhibiting of the GNOME session idle
if len(sys.argv) < 2:
    print "Error: Need at least one argument, the PID of the lightsOn.sh process, to continue."
    sys.exit(2)

if len(sys.argv) < 3:
    count = 60
else:
    count = int(sys.argv[2])

checkpid = "ps " + sys.argv[1] + " | wc -l"

while True:
    if int(subprocess.check_output(checkpid, shell=True)) == 1:
        print "The lightsOn pid " + sys.argv[1] + " has been killed! Restoring GNOME SessionManager idle timer."
        sys.exit(1)
    else:
        print "lightsOn script running on pid " + sys.argv[1] + " and GNOME SessionManager idle inhibited. Everything ok!"
    time.sleep(count)


sys.exit(0)
