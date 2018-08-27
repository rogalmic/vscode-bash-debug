# -*- shell-script -*-
# Eval and Print commands.
#
#   Copyright (C) 2002, 2003-2004, 2006, 2008, 2011, 2015 Rocky Bernstein
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

# temp file for internal eval'd commands
typeset _Dbg_evalfile=$(_Dbg_tempname eval)

_Dbg_help_add eval \
'**eval** *cmd*

**eval**

**eval?**

In the first form *cmd* is a string *cmd* is a string sent to special
shell builtin eval.

In the second form, use evaluate the current source line text.

Often when one is stopped at the line of the first part of an "if",
"elif", "case", "return", "while" compound statement or an assignment
statement, one wants to eval is just the expression portion.  For
this, use eval?. Actually, any alias that ends in ? which is aliased
to eval will do thie same thing.

See also:
---------

**print** and **set autoeval**.' 1 _Dbg_complete_eval

typeset -i _Dbg_show_eval_rc; _Dbg_show_eval_rc=1

# Command completion for a debugger "eval" command.
_Dbg_complete_eval() {
    typeset -a words;
    typeset subcmds
    IFS=' ' words=( $COMP_LINE )
    # If no
    if (( ${#words[@]} == 1 )); then
	if [[ ${words[0]} == 'eval?' ]] ; then
	    typeset extracted
	    _Dbg_eval_extract_condition "$_Dbg_source_line"
	    COMPREPLY=("$extracted")
	else
            COMPREPLY=("$_Dbg_source_line")
	fi
    else
	COMPREPLY=()
    fi
}

complete -F _Dbg_complete_eval 'eval?'

_Dbg_do_eval() {

  builtin echo ". ${_Dbg_libdir}/dbg-set-d-vars.inc" > $_Dbg_evalfile
   if (( $# == 0 )) ; then
       # FIXME: add parameter to get unhighlighted line, or
       # always save a copy of that in _Dbg_get_source_line
       typeset source_line_save="$_Dbg_source_line"
       typeset highlight_save=$_Dbg_set_highlight
       _Dbg_set_highlight=''
       _Dbg_get_source_line

       # Were we called via ? as the suffix?
       typeset suffix
       suffix=${_Dbg_orig_cmd:${#_Dbg_orig_cmd}-1:1}
       typeset source_line
       if [[ '?' == "$suffix" ]] ; then
	   typeset extracted
	   _Dbg_eval_extract_condition "$_Dbg_source_line"
	   source_line="$extracted"
	   source_line_save="$extracted"
       else
	   source_line="$_Dbg_bash_command"
       fi

       builtin echo "$source_line" >> $_Dbg_evalfile
       _Dbg_msg "eval: ${source_line}"
       _Dbg_source_line="$source_line_save"
       _Dbg_set_highlight=$_Dbg_highlight_save
   else
       builtin echo "$@" >> $_Dbg_evalfile
   fi
  if [[ -n $_Dbg_tty  ]] ; then
    . $_Dbg_evalfile >>$_Dbg_tty
  else
    . $_Dbg_evalfile
  fi
  _Dbg_rc=$?
  (( _Dbg_show_eval_rc )) && _Dbg_msg "\$? is $_Dbg_rc"
  # We've reset some variables like IFS and PS4 to make eval look
  # like they were before debugger entry - so reset them now.
  _Dbg_set_debugger_internal
  _Dbg_last_cmd='eval'
  return 0
}

_Dbg_alias_add 'ev' 'eval'
_Dbg_alias_add 'ev?' 'eval'
_Dbg_alias_add 'eval?' 'eval'

# The arguments in the last "print" command.
typeset _Dbg_last_print_args=''

_Dbg_help_add print \
'print EXPRESSION -- Print EXPRESSION.

EXPRESSION is a string like you would put in a print statement.
See also eval.

The difference between eval and print. Suppose cmd has the value "ls".

print $cmd # prints "ls"
eval $cmd  # runs an ls command
'

_Dbg_do_print() {
  typeset _Dbg_expr=${@:-"$_Dbg_last_print_args"}
  typeset dq_expr; dq_expr=$(_Dbg_esc_dq "$_Dbg_expr")
  . ${_Dbg_libdir}/dbg-set-d-vars.inc
  eval "_Dbg_msg $_Dbg_expr"
  typeset -i rc=$?
  _Dbg_last_print_args="$dq_expr"
  return $rc
}

_Dbg_alias_add 'pr' 'print'
