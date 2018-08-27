# -*- shell-script -*-
# "Examine" debugger command.
#
#   Copyright (C) 2002-2004, 2006, 2008, 2011, 2016 Rocky Bernstein
#   <rocky@gnu.org>
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

_Dbg_help_add 'examine' \
"**examine** *expr*

Print value of an expression via \"typeset\", \"let\", and failing these,
\"eval\".

To see the structure of a variable do not prepeand a leading $.

Arithmetic expressions also do not need leading $ for
their value is to be substituted.

However if *expr* falls into neither these, categories variables
witih *expr* need $ to have their value substituted.

Examples:
---------

   # code:
   # typeset -a typeset -a x=(2 3 4)
   # typeset -ir p=1
   bashdb<1> examine x   # note no $
   declare -a x='([0]="2" [1]="3" [2]="4")'
   bashdb<2> examine $x  # note with $
   1  # because this is how bash evaluates $x
   bashdb<3> x p
   declare -ir p="1"
   bashdb<3> x p+2
   3
   bashdb<3> x $p+2
   3

See also:
---------

**eval** and **pr**."

function _Dbg_do_examine {
    typeset -r _Dbg_expr=${@:-"$_Dbg_last_x_args"}
    typeset _Dbg_result
    typeset isblank=$_Dbg_expr
    if [[ -z $isblank ]] ; then
	_Dbg_msg "$_Dbg_expr"
    elif _Dbg_defined $_Dbg_expr ; then
	_Dbg_result=$(typeset -p $_Dbg_expr)
	_Dbg_msg "$_Dbg_result"
    elif _Dbg_is_function "$_Dbg_expr" $_Dbg_set_debug; then
	_Dbg_result=$(typeset -f $_Dbg_expr)
	_Dbg_msg "$_Dbg_result"
    else
	typeset -i _Dbg_rc
	eval let _Dbg_result=$_Dbg_expr 2>/dev/null; _Dbg_rc=$?
	if (( _Dbg_rc != 0 )) ; then
	    _Dbg_do_print "$_Dbg_expr"
	else
	    _Dbg_msg "$_Dbg_result"
	fi
    fi
    _Dbg_last_x_args="$_Dbg_x_args"
    return 0
}

_Dbg_alias_add 'x' 'examine'

# Demo it.
if [[ $0 == ${BASH_SOURCE[0]} ]] ; then
    for _Dbg_file in fns msg ; do
	source $top_dir/lib/${_Dbg_file}.sh
    done
    source $top_dir/command/help.sh
    _Dbg_args='examine'
    _Dbg_do_help x
    _Dbg_do_examine top_dir
fi
