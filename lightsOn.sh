#!/bin/bash
# lightsOn.sh

# Copyright (c) 2013 iye.cba at gmail com
# url: https://github.com/iye/lightsOn
# This script is licensed under GNU GPL version 2.0 or above

# Description: Bash script that prevents the screensaver and display power
# management (DPMS) to be activated when you are watching Flash Videos
# fullscreen on Firefox and Chromium.
# Can detect mplayer, minitube, and VLC when they are fullscreen too.
# Also, screensaver can be prevented when certain specified programs are running.
# lightsOn.sh needs xscreensaver or kscreensaver to work.

# HOW TO USE:
#
# Start the script either with no arguments or with the number of seconds
# you want the checks for fullscreen to be done. Example:
# "./lightsOn.sh 120 &" will Check every 120 seconds if Mplayer, Minitube,
# VLC, Firefox or Chromium are fullscreen and delay screensaver and Power Management if so.
#
# You want the number of seconds to be ~10 seconds less than the time it takes
# your screensaver or Power Management to activate.
#
# If the script is started with no arguments, ~/.xscreensaver is parsed for the "Blank After" timeout setting
# that xscreensaver is configured with, and uses that as the time argument, but with 10 seconds subtracted.
# Example: If the blank after timeout is 30 minutes (1800 seconds), then the timeout used will be 1790 seconds.
# If this process fails for some reason, for instance if ~/.xscreensaver doesn't exist or the format of the file
# changes, then the checks will be done at the default of every 50 seconds.
#
# An optional array variable exists here to add the names of programs that will delay the screensaver if they're running.
# This can be useful if you want to maintain a view of the program from a distance, like a music playlist for DJing,
# or if the screensaver eats up CPU that chops into any background processes you have running,
# such as realtime music programs like Ardour in MIDI keyboard mode.
# If you use this feature, make sure you use the name of the binary of the program (which may exist, for instance, in /usr/bin).
#
# Dealing with GNOME Session Idle (gnome-screensaver):
#
# Even after removing gnome-screensaver, the GNOME system may still turn off the screen
# after the idle timer in the gnome-control-center kicks in. Removing /usr/bin/gnome-screensaver-command may fix this,
# but you lose the ability to lock the screen from the Menu, or by Ctrl+Alt+L. Making gnome-screensaver-command a
# symlink to /usr/bin/xscreesaver-command will allow you to keep that feature, but may be the reason for the screen poweroff.
#
# Setting "gnome_session_inhibit_idle" to 1 will inhibit the GNOME SessionManager idle timer from taking place
# by running an accompanying python script that calls the Inhibit() function on the GNOME SessionManager DBUS.
# The python script and Inhibit() call will persist until either the lightsOn.sh process is killed or
# the python script process is killed. If the lightsOn.sh process is killed, the python script will sense it
# after a fixed amount of time, which can be specified when the python script is called, and then exit.
#
# More info on the GNOME SessionManager issue:
# http://www.lucidelectricdreams.com/2011/06/disabling-screensaverlock-screen-on.html


# Modify these variables if you want this script to detect if Mplayer,
# VLC, Minitube, or Firefox or Chromium Flash Video are Fullscreen and disable
# xscreensaver/kscreensaver and PowerManagement.
mplayer_detection=1
vlc_detection=1
firefox_flash_detection=1
chromium_flash_detection=1
minitube_detection=1

# Names of programs which, when running, you wish to delay the screensaver.
delay_progs=() # For example ('ardour2' 'gmpc')

# Whether to inhibit gnome session idle
gnome_session_inhibit_idle=1
helper_python_script="inhibit-gnome-session-idle.py"


# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE

if [[ $gnome_session_inhibit_idle == 1 ]]; then
    # Get directory of this script
    # http://stackoverflow.com/a/179231
    pushd . > /dev/null
    SCRIPT_PATH="${BASH_SOURCE[0]}";
    if ([ -h "${SCRIPT_PATH}" ]) then
        while([ -h "${SCRIPT_PATH}" ]) do cd `dirname "$SCRIPT_PATH"`; SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
    fi
    cd `dirname ${SCRIPT_PATH}` > /dev/null
    SCRIPT_PATH=`pwd`;
    popd  > /dev/null

    LOCATION_PYTHON_SCRIPT="${SCRIPT_PATH}/${helper_python_script}"
    if [ -f $LOCATION_PYTHON_SCRIPT ]; then
        # Start python dbus script to inhibit GNOME session idle
        # It will sense if this bash script process dies and quit if so
        # Arguments are:
        #   #1  PID of this script
        #   #2  time in seconds to check that the PID is running
        $LOCATION_PYTHON_SCRIPT $$ 60 &
    else
        echo "Helper python script not found! Inhibiting the GNOME session from going idle will not work without it!"
    fi
fi

# enumerate all the attached screens
displays=""
while read id
do
    displays="$displays $id"
done < <(xvinfo | sed -n 's/^screen #\([0-9]\+\)$/\1/p')

# Detect screensaver been used (xscreensaver, kscreensaver or none)
screensaver=`pgrep -l xscreensaver | grep -wc xscreensaver`
if [ $screensaver -ge 1 ]; then
    screensaver=xscreensaver
else
    screensaver=`pgrep -l kscreensaver | grep -wc kscreensaver`
    if [ $screensaver -ge 1 ]; then
        screensaver=kscreensaver
    else
        screensaver=None
        echo "No screensaver detected"
    fi
fi

checkDelayProgs()
{
    for prog in "${delay_progs[@]}"; do
        if [ `pgrep -lfc "${prog}"` -ge 1 ]; then
            echo "Delaying the screensaver because a program on the delay list, \"${prog}\", is running..."
            delayScreensaver
            break
        fi
    done
}

checkFullscreen()
{
    # loop through every display looking for a fullscreen window
    for display in $displays
    do
        #get id of active window and clean output
        activ_win_id=`DISPLAY=:0.${display} xprop -root _NET_ACTIVE_WINDOW`
        #activ_win_id=${activ_win_id#*# } #gives error if xprop returns extra ", 0x0" (happens on some distros)
        activ_win_id=${activ_win_id:40:9}

        # Skip invalid window ids (commented as I could not reproduce a case
        # where invalid id was returned, plus if id invalid
        # isActivWinFullscreen will fail anyway.)
        #if [ "$activ_win_id" = "0x0" ]; then
        #     continue
        #fi

        # Check if Active Window (the foremost window) is in fullscreen state
        isActivWinFullscreen=`DISPLAY=:0.${display} xprop -id $activ_win_id | grep _NET_WM_STATE_FULLSCREEN`
            if [[ "$isActivWinFullscreen" = *NET_WM_STATE_FULLSCREEN* ]];then
                isAppRunning
                var=$?
                if [[ $var -eq 1 ]];then
                    delayScreensaver
                fi
            fi
    done
}


# check if active windows is mplayer, vlc or firefox
#TODO only window name in the variable activ_win_id, not whole line.
#Then change IFs to detect more specifically the apps "<vlc>" and if process name exist

isAppRunning()
{
    #Get title of active window
    activ_win_title=`xprop -id $activ_win_id | grep "WM_CLASS(STRING)"`   # I used WM_NAME(STRING) before, WM_CLASS more accurate.



    # Check if user want to detect Video fullscreen on Firefox, modify variable firefox_flash_detection if you dont want Firefox detection
    if [ $firefox_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *unknown* || "$activ_win_title" = *plugin-container* ]];then
        # Check if plugin-container process is running
            flash_process=`pgrep -l plugin-containe | grep -wc plugin-containe`
            #(why was I using this line avobe? delete if pgrep -lc works ok)
            #flash_process=`pgrep -lc plugin-containe`
            if [[ $flash_process -ge 1 ]];then
                return 1
            fi
        fi
    fi


    # Check if user want to detect Video fullscreen on Chromium, modify variable chromium_flash_detection if you dont want Chromium detection
    if [ $chromium_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *exe* ]];then
        # Check if Chromium/Chrome Flash process is running
            flash_process=`pgrep -lfc ".*((c|C)hrome|chromium).*flashp.*"`
            if [[ $flash_process -ge 1 ]];then
                return 1
            fi
        fi
    fi


    #check if user want to detect mplayer fullscreen, modify variable mplayer_detection
    if [ $mplayer_detection == 1 ];then
        if [[ "$activ_win_title" = *mplayer* || "$activ_win_title" = *MPlayer* ]];then
            #check if mplayer is running.
            #mplayer_process=`pgrep -l mplayer | grep -wc mplayer`
            mplayer_process=`pgrep -lc mplayer`
            if [ $mplayer_process -ge 1 ]; then
                return 1
            fi
        fi
    fi


    # Check if user want to detect vlc fullscreen, modify variable vlc_detection
    if [ $vlc_detection == 1 ];then
        if [[ "$activ_win_title" = *vlc* ]];then
            #check if vlc is running.
            #vlc_process=`pgrep -l vlc | grep -wc vlc`
            vlc_process=`pgrep -lc vlc`
            if [ $vlc_process -ge 1 ]; then
                return 1
            fi
        fi
    fi

    # Check if user want to detect minitube fullscreen, modify variable minitube_detection
    if [ $minitube_detection == 1 ];then
        if [[ "$activ_win_title" = *minitube* ]];then
            #check if minitube is running.
            #minitube_process=`pgrep -l minitube | grep -wc minitube`
            minitube_process=`pgrep -lc minitube`
            if [ $minitube_process -ge 1 ]; then
                return 1
            fi
        fi
    fi


return 0
}


delayScreensaver()
{

    # reset inactivity time counter so screensaver is not started
    if [ "$screensaver" == "xscreensaver" ]; then
      xscreensaver-command -deactivate > /dev/null
    elif [ "$screensaver" == "kscreensaver" ]; then
      qdbus org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity > /dev/null
    fi


    #Check if DPMS is on. If it is, deactivate and reactivate again. If it is not, do nothing.
    dpmsStatus=`xset -q | grep -ce 'DPMS is Enabled'`
    if [ $dpmsStatus == 1 ];then
          xset -dpms
          xset dpms
  fi

}

checkDelay() {
    if [ -n "$1" ]; then
        delay=$1

        # If argument is not integer, quit.
        if [[ $1 = *[^0-9]* ]]; then
            echo "The Argument \"$1\" is not valid, not an integer"
            echo "Please use the time in seconds you want the checks to repeat."
            echo "You want it to be ~10 seconds less than the time it takes your screensaver or DPMS to activate"
            exit 1
        fi
    else
        # Detect timeout value automatically and use it minus 10 seconds to get the perfect val every time
        delay=`grep timeout ~/.xscreensaver | tail -1 | cut -d ':' -f 3`

        # make sure delay is an integer and one minute or more
        if [[ $delay != *[^0-9]* && $delay -gt 0 ]]; then
            delay=$(( 10#$delay )) # number has a leading zero and interpreted as octal - this forces base 10
            #delay=${delay#0} # Also, as a hack, parameter expansion can be used to evaluate the number
            echo "Delay is ${delay} minutes, minus 10 seconds."
            delay=$(( $delay * 60 - 10))
        # use 50 seconds as default.
        else
            echo "~/.xscreensaver does not exist or value interpreted was rejected. Using default delay of 50."
            delay=50
        fi
    fi
}

while true
do
    checkDelayProgs
    checkFullscreen
    checkDelay "$@" # passes all arguments to the function. you should (almost) always put $@ in double-quotes to avoid misparsing of arguments with spaces in them
    sleep $delay
done


exit 0
