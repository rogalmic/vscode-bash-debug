# -*- shell-script -*-
# help.sh - Debugger Help Routines
#
#   Copyright (C) 2002-2008, 2010-2012, 2016
#   Rocky Bernstein <rocky@gnu.org>
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation; either version 2, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; see the file COPYING.  If not, write to
#   the Free Software Foundation, 59 Temple Place, Suite 330, Boston,
#   MA 02111 USA.

# A place to put help command text
typeset -A _Dbg_command_help
export _Dbg_command_help
typeset -a _Dbg_command_names_sorted=()

# List of debugger commands.
# FIXME: for now we are attaching this to _Dbg_help_add which
# is whe this is here. After moving somewhere more appropriate, relocate
# the definition.
typeset -A _Dbg_debugger_commands

# Add help text $2 for command $1
function _Dbg_help_add {
    (($# < 2)) || (($# > 4))  && return 1
    typeset -i add_command; add_command=${3:-1}
    _Dbg_command_help[$1]="$2"
    (( add_command )) && _Dbg_debugger_commands[$1]="_Dbg_do_$1"
    if (($# == 4)); then
        complete -F "$4" "$1"
    fi
    return 0
}

# Add help text $3 for in subcommand $1 under key $2
function _Dbg_help_add_sub {
    add_command=${4:-1}
    (($# != 3)) && (($# != 4))  && return 1
    eval "_Dbg_command_help_$1[$2]=\"$3\""
    if (( add_command )) ; then
        eval "_Dbg_debugger_${1}_commands[$2]=\"_Dbg_do_${1}_${2}\""
    fi
    return 0
}

_Dbg_help_sort_command_names() {
    ((${#_Dbg_command_names_sorted} > 0 )) && return 0

    typeset -a list
    list=("${!_Dbg_command_help[@]}")
    sort_list 0 ${#list[@]}-1
    _Dbg_sorted_command_names=("${list[@]}")
}

_Dbg_help_set() {

    typeset subcmd
    if (( $# == 0 )) ; then
        typeset -a list
        list=("${!_Dbg_command_help_set[@]}")
        sort_list 0 ${#list[@]}-1
        for subcmd in ${list[@]}; do
            _Dbg_help_set $subcmd 1
        done
        return 0
    fi

    subcmd="$1"
    typeset label="$2"

    if [[ -n "${_Dbg_command_help_set[$subcmd]}" ]] ; then
        if [[ -z $label ]] ; then
            _Dbg_msg_rst "${_Dbg_command_help_set[$subcmd]}"
            return 0
        else
            label=$(builtin printf "set %-12s-- " $subcmd)
        fi
    fi

    case $subcmd in
        ar | arg | args )
            _Dbg_msg \
                "${label}Set argument list to give program when restarted."
            return 0
            ;;
        an | ann | anno | annot | annota | annotat | annotate )
            if [[ -z $label ]] ; then
                typeset post_label='
0 == normal;     1 == fullname (for use when running under emacs).'
            fi
            _Dbg_msg \
                "${label}Set annotation level.$post_label"
            return 0
            ;;
        autoe | autoev | autoeva | autoeval )
            _Dbg_help_set_onoff 'autoeval' 'autoeval' \
                "Evaluate unrecognized commands"
            return 0
            ;;
        autol | autoli | autolis | autolist )
            typeset onoff="on."
            [[ -z ${_Dbg_cmdloop_hooks['list']} ]] && onoff='off.'
            _Dbg_msg \
                "${label}Run list command is ${onoff}"
            return 0
            ;;
        b | ba | bas | base | basen | basena | basenam | basename )
            _Dbg_help_set_onoff 'basename' 'basename' \
                "Set short filenames (the basename) in debug output"
            return 0
            ;;
        de|deb|debu|debug )
            _Dbg_help_set_onoff 'debug' 'debug' \
              "Set debugging the debugger"
            return 0
            ;;
        di|dif|diff|diffe|differe|differen|different )
            typeset onoff=${1:-'on'}
            (( _Dbg_set_different )) && onoff='on.'
            _Dbg_msg \
                "${label}Set to stop at a different line is" $onoff
            return 0
            ;;
        do|doll|dolla|dollar|dollar0 )
            _Dbg_msg "${label}Set \$0"
            return 0
            ;;
        e | ed | edi | edit | editi | editin | editing )
            _Dbg_msg_nocr \
                "${label}Set editing of command lines as they are typed is "
            if [[ -z $_Dbg_edit ]] ; then
                _Dbg_msg 'off.'
            else
                _Dbg_msg 'on.'
            fi
            return 0
            ;;
        high | highl | highlight )
            _Dbg_msg_nocr \
                "${label}Set syntax highlighting of source listings is "
            if [[ -z $_Dbg_edit ]] ; then
                _Dbg_msg 'off.'
            else
                _Dbg_msg 'on.'
            fi
            return 0
            ;;
        his | hist | history )
            _Dbg_msg_nocr \
                "${label}Set record command history is "
            if [[ -z $_Dbg_set_edit ]] ; then
                _Dbg_msg 'off.'
            else
                _Dbg_msg 'on.'
            fi
            ;;
        si | siz | size )
            eval "$_seteglob"
            if [[ -z $2 ]] ; then
                _Dbg_errmsg "Argument required (integer to set it to.)."
            elif [[ $2 != $int_pat ]] ; then
                _Dbg_errmsg "Integer argument expected; got: $2"
                eval "$_resteglob"
                return 1
            fi
            eval "$_resteglob"
            _Dbg_write_journal_eval "_Dbg_history_length=$2"
            return 0
            ;;
        lin | line | linet | linetr | linetra | linetrac | linetrace )
            typeset onoff='off.'
            (( _Dbg_set_linetrace )) && onoff='on.'
            _Dbg_msg \
                "${label}Set tracing execution of lines before executed is" $onoff
            if (( _Dbg_set_linetrace )) ; then
                _Dbg_msg \
                    "set linetrace delay -- delay before executing a line is" $_Dbg_set_linetrace_delay
            fi
            return 0
            ;;
        lis | list | lists | listsi | listsiz | listsize )
            _Dbg_msg \
                "${label}Set number of source lines $_Dbg_debugger_name will list by default."
            ;;
        p | pr | pro | prom | promp | prompt )
            _Dbg_msg \
                "${label}${_Dbg_debugger_name}'s prompt is:\n" \
                "      \"$_Dbg_prompt_str\"."
            return 0
            ;;
        sho|show|showc|showco|showcom|showcomm|showcomma|showcomman|showcommand )
            _Dbg_msg \
                "${label}Set showing the command to execute is $_Dbg_set_show_command."
            return 0
            ;;
        sty | style )
            [[ -n $label ]] && label='set style       -- '
            _Dbg_msg_nocr \
                "${label}Set pygments highlighting style is "
            if [[ -z $_Dbg_set_style ]] ; then
                _Dbg_msg 'off.'
            else
		_Dbg_msg "${_Dbg_set_style}"
            fi
	    ;;
        t|tr|tra|trac|trace|trace-|tracec|trace-co|trace-com|trace-comm|trace-comma|trace-comman|trace-command|trace-commands )
            _Dbg_msg \
                "${label}Set showing debugger commands is $_Dbg_set_trace_commands."
            return 0
            ;;
        tt|tty )
            typeset dbg_tty=$_Dbg_tty
            [[ -n $dbg_tty ]] && dbg_tty=$(tty)
            _Dbg_msg \
                "${label}Debugger output goes to $dbg_tty."
            return 0
            ;;
        wi|wid|widt|width )
            _Dbg_msg \
                "${label}Set maximum width of lines is $_Dbg_set_linewidth."
            return 0
            ;;
        * )
            _Dbg_errmsg \
                "There is no \"set $subcmd\" command."
    esac
}

_Dbg_help_show() {
    if (( $# == 0 )) ; then
        typeset -a list
        list=("${!_Dbg_command_help_show[@]}")
        sort_list 0 ${#list[@]}-1
        typeset subcmd
        for subcmd in ${list[@]}; do
            [[ $subcmd != 'version' ]] && _Dbg_help_show $subcmd 1
        done
        return 0
    fi

    typeset subcmd=$1
    typeset label="$2"

    if [[ -n "${_Dbg_command_help_show[$subcmd]}" ]] ; then
        if [[ -z $label ]] ; then
            _Dbg_msg_rst "${_Dbg_command_help_show[$subcmd]}"
            return 0
        else
            label=$(builtin printf "show %-12s-- " $subcmd)
        fi
    fi

    case $subcmd in
        al | ali | alia | alias | aliase | aliases )
            _Dbg_msg \
                "${label}Show list of aliases currently in effect."
            return 0
            ;;
        ar | arg | args )
            _Dbg_msg \
                "${label}Show argument list to give program on restart."
            return 0
            ;;
        an | ann | anno | annot | annota | annotat | annotate )
            _Dbg_msg \
                "${label}Show annotation_level"
            return 0
            ;;
        autoe | autoev | autoeva | autoeval )
            _Dbg_msg \
                "${label}Show if we evaluate unrecognized commands."
            return 0
            ;;
        autol | autoli | autolis | autolist )
            _Dbg_msg \
                "${label}Run list before command loop?"
            return 0
            ;;
        b | ba | bas | base | basen | basena | basenam | basename )
            _Dbg_msg \
                "${label}Show if we are are to show short or long filenames."
            return 0
            ;;
        com | comm | comma | comman | command | commands )
            _Dbg_msg \
                "${label}commands [+|n] -- Show the history of commands you typed.
You can supply a command number to start with, or a + to start after
the previous command number shown. A negative number indicates the
number of lines to list."
            ;;
        cop | copy| copyi | copyin | copying )
            _Dbg_msg \
                "${label}Conditions for redistributing copies of debugger."
            ;;
        d|de|deb|debu|debug)
            _Dbg_msg \
                "${label}Show if we are set to debug the debugger."
            return 0
            ;;
        different | force)
            _Dbg_msg \
                "${label}Show if debugger stops at a different line."
            return 0
            ;;
        dir|dire|direc|direct|directo|director|directori|directorie|directories)
            _Dbg_msg \
                "${label}Show file directories searched for listing source."
            ;;
        editing )
            _Dbg_msg \
                "${label}Show editing of command lines and edit style."
            ;;
        highlight )
            _Dbg_msg \
                "${label}Show if we syntax highlight source listings."
            return 0
            ;;
        history )
            _Dbg_msg \
                "${label}Show if we are recording command history."
            return 0
            ;;
        lin | line | linet | linetr | linetra | linetrac | linetrace )
            _Dbg_msg \
                "${label}Show whether to trace lines before execution."
            ;;
        lis | list | lists | listsi | listsiz | listsize )
            _Dbg_msg \
                "${label}Show number of source lines debugger will list by default."
            ;;
        p | pr | pro | prom | promp | prompt )
            _Dbg_msg \
                "${label}Show debugger prompt."
            return 0
            ;;
        sty | style )
            _Dbg_msg \
                "show style       -- Show pygments style in source-code listings."
            ;;
        t|tr|tra|trac|trace|trace-|trace-c|trace-co|trace-com|trace-comm|trace-comma|trace-comman|trace-command|trace-commands )
            _Dbg_msg \
               'show trace-commands -- Show if we are echoing debugger commands.'
            return 0
            ;;
        tt | tty )
            _Dbg_msg \
                "${label}Where debugger output goes to."
            return 0
            ;;
        wa | war | warr | warra | warran | warrant | warranty )
            _Dbg_msg \
                "${label}Various kinds of warranty you do not have."
            return 0
            ;;
        width )
            _Dbg_msg \
                "${label}maximum width of a line."
            return 0
            ;;
        * )
            _Dbg_msg \
                "Undefined show command: \"$subcmd\".  Try \"help show\"."
    esac
}
