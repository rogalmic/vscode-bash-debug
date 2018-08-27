# -*- shell-script -*-
# shell.sh - helper routines for 'shell' debugger command
#
#   Copyright (C) 2011, 2017 Rocky Bernstein <rocky@gnu.org>
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

_Dbg_shell_temp_profile=$(_Dbg_tempname profile)

_Dbg_shell_append_typesets() {
    typeset -a words
    typeset -p | while read -a words ; do
	[[ declare != ${words[0]} ]] && continue
	var_name=${words[2]%%=*}
	((0 == _Dbg_set_debug)) && [[ $var_name =~ ^_Dbg_ ]] && continue
	flags=${words[1]}
	if [[ $flags =~ ^-.*x ]]; then
	    # Skip exported variables
	    continue
	elif [[ $flags =~ -.*r ]]; then
	    # handle read-only variables
	    echo "typeset -p ${var_name} &>/dev/null || $(typeset -p ${var_name})"
	elif [[ ${flags:0:1} == '-' ]] ; then
	    echo $(typeset -p ${var_name} 2>/dev/null)
	fi
    done >>$_Dbg_shell_temp_profile
}

_Dbg_shell_append_fn_typesets() {
    typeset -a words
    typeset -pf | while read -a words ; do
	[[ declare != ${words[0]} ]] && continue
	fn_name=${words[2]%%=*}
	((0 == _Dbg_set_debug)) && [[ $fn_name =~ ^_Dbg_ ]] && continue
	flags=${words[1]}
	echo $(typeset -pf ${fn_name} 2>/dev/null)
    done >>$_Dbg_shell_temp_profile
}

_Dbg_shell_new_shell_profile() {
    typeset -i _Dbg_o_vars; _Dbg_o_vars=${1:-1}
    typeset -i _Dbg_o_fns;  _Dbg_o_fns=${2:-1}

    echo '# debugger shell profile' > $_Dbg_shell_temp_profile

    ((_Dbg_o_vars)) && _Dbg_shell_append_typesets

    # Add where file to allow us to restore info and
    # Routine use can call to mark which variables should persist
    typeset -p _Dbg_restore_info >> $_Dbg_shell_temp_profile
    echo "source ${_Dbg_libdir}/data/shell.sh" >> $_Dbg_shell_temp_profile

    ((_Dbg_o_fns))  && _Dbg_shell_append_fn_typesets

}
