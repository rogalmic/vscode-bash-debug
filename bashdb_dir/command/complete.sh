# complete.sh - gdb-like 'complete' command
#
#   Copyright (C) 2010-2011, 2016 Rocky Bernstein <rocky@gnu.org>
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

if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    dirname=${BASH_SOURCE[0]%/*}
    [[ $dirname == $0 ]] && top_dir='..' || top_dir=${dirname}/..
    for lib_file in help alias ; do source $top_dir/lib/${lib_file}.sh; done
fi

_Dbg_help_add complete \
'**complete** *prefix-str*...


Show command completion strings for *prefix-str*
'

_Dbg_do_complete() {
    typeset -a args; args=($@)
    _Dbg_matches=()
    if (( ${#args[@]} == 2 )) ; then
      _Dbg_subcmd_complete ${args[0]} ${args[1]}
    elif (( ${#args[@]} == 1 )) ; then
	# FIXME: add in aliases
	typeset list; list=("${!_Dbg_debugger_commands[@]}")
	sort_list 0 ${#list[@]}-1
	cmd="builtin compgen -W \"${list[@]}\" -- ${args[0]}"
	typeset -a _Dbg_matches=( $(eval $cmd) )
    fi
    typeset -i i
    for (( i=0;  i < ${#_Dbg_matches[@]}  ; i++ )) ; do
      _Dbg_msg ${_Dbg_matches[$i]}
    done
}

# Demo it.
if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    source ${top_dir}/lib/msg.sh
    for _Dbg_file in ${top_dir}/command/{c*,help}.sh ; do
	source $_Dbg_file
    done

    _Dbg_args='complete'
    _Dbg_do_help complete
    _Dbg_do_complete c
fi
