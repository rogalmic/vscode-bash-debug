# -*- shell-script -*-
# "info signals" debugger command
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

_Dbg_help_add_sub info signals \
"**info signals**

Show what debugger does when program gets various signals.

See also:
---------

 \"signal\"." 1

# List signal handlers in effect.
function _Dbg_do_info_signals {
  typeset -i i=0
  typeset signal_name
  typeset handler
  typeset stop_flag
  typeset print_flag

  _Dbg_msg "Signal       Stop   Print   Stack     Value"
  _Dbg_printf_nocr "%-12s %-6s %-7s %-9s " EXIT \
    ${_Dbg_sig_stop[0]:-nostop} ${_Dbg_sig_print[0]:-noprint} \
    ${_Dbg_sig_show_stack[0]:-nostack}

  # This is a horrible hack, but I can't figure out how to get
  # trap -p 0 into a variable; handler=`trap -p 0` doesn't work.
  if [[ -n $_Dbg_tty  ]] ; then
    builtin trap -p 0 >>$_Dbg_tty
  else
    builtin trap -p 0
  fi

  while (( 1 )) ; do
    signal_name=$(builtin kill -l $i 2>/dev/null) || break
    handler=$(builtin trap -p $i)
    if [[ -n $handler ]] ; then
      _Dbg_printf "%-12s %-6s %-7s %-9s %-6s" $signal_name \
	${_Dbg_sig_stop[$i]:-nostop} ${_Dbg_sig_print[$i]:-noprint} \
        ${_Dbg_sig_show_stack[$i]:-nostack} "$handler"
    fi
    ((i++))
  done
}
