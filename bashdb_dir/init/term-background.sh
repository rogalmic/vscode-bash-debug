#!/bin/bash
# Try to determine if we have dark or light terminal background

typeset -i success=0

# On return, variable is_dark_bg is set
# We follow Emacs logic (at least initially)
set_default_bg() {
    if [[ -n $TERM ]] ; then
	case $TERM in
	    xterm* | dtterm | eterm* )
		is_dark_bg=0
		;;
	    * )
		is_dark_bg=1
		;;
	esac
    fi
}

# Pass as parameters R G B values in hex
# On return, variable is_dark_bg is set
is_dark_rgb() {
    typeset r g b
    r=$1; g=$2; b=$3
    # 117963 = (* .6 (+ 65535 65535 65535))
    if (( (16#$r + 16#$g + 16#$b) < 117963 )) ; then
	is_dark_bg=1
    else
	is_dark_bg=0
    fi
}

# Consult (environment) variable COLORFGB
# On return, variable is_dark_bg is set
is_dark_colorfgbg() {
    case $COLORFGBG in
	'15;0' | '15;default;0' )
	    is_dark_bg=1
	    ;;
	'0;15' | '0;default;15' )
	    is_dark_bg=0
	    ;;
	* )
	    is_dark_bg=-1
	    ;;
    esac
}

is_sourced() {
    if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
	return 1
    else
	return 0
    fi
}

# Exit if we are not source.
# if sourced, then we just set exitrc
# which was assumed to be declared outside
exit_if_not_sourced() {
    exitrc=${1:-0}
    if ! is_sourced ; then
	exit $exitrc
    fi
}

# From:
# http://unix.stackexchange.com/questions/245378/common-environment-variable-to-set-dark-or-light-terminal-background/245381#245381
# and:
# https://bugzilla.gnome.org/show_bug.cgi?id=733423#c1
#
# User should set up RGB_fg and RGB_bg arrays
xterm_compatible_fg_bg() {
    typeset fg bg junk
    stty -echo
    # Issue command to get both foreground and
    # background color
    #            fg       bg
    echo -ne '\e]10;?\a\e]11;?\a'
    IFS=: read -t 0.1 -d $'\a' x fg
    IFS=: read -t 0.1 -d $'\a' x bg
    stty echo
    [[ -z $bg ]] && return 1
    typeset -p fg
    typeset -p bg
    IFS='/' read -ra RGB_fg <<< $fg
    IFS='/' read -ra RGB_bg <<< $bg
    typeset -p RGB_fg
    typeset -p RGB_bg
    return 0
}

typeset -i success=0
typeset -i is_dark_bg=0
typeset -i exitrc=0

set_default_bg

if [[ -n $TERM ]] ; then
    case $TERM in
	xterm* | gnome | rxvt* )
	    typeset -a RGB_fg RGB_bg
	    if xterm_compatible_fg_bg ; then
		is_dark_rgb ${RGB_bg[@]}
		success=1
	    fi
	    ;;
	* )
	    ;;
    esac
fi

if (( $success )) ; then
    if (( is_dark_bg == 1 )) ; then
	echo "Dark background from xterm control"
    else
	echo "Light background from xterm control"
    fi
elif [[ -n $COLORFGBG ]] ; then
    # Note that this can be wrong if
    # COLORFGBG was set prior invoking a terminal
    is_dark_colorfgbg
    case $is_dark_bg in
	0 )
	    echo "Light background from COLORFGBG"
	    ;;
	1 )
	    echo "Dark background from COLORFGBG"
	    ;;
	-1 | * )
	    echo "Can't decide from COLORFGBG"
	    exit_if_not_sourced 1
	    ;;
    esac
else
    echo "Can't decide"
    exit_if_not_sourced 1
fi

# If we were sourced, then set
# some environment variables
if (( is_sourced )) ; then
    if (( exitrc == 0 )) ; then
	if (( $is_dark_bg == 1 ))  ; then
	    export DARK_BG=1
	    export COLORFGBG='0;15'
	else
	    export DARK_BG=0
	    export COLORFGBG='15;0'
	fi
    fi
fi
