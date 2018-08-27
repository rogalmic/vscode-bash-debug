# -*- shell-script -*-
# signal.sh - gdb-like "signal" debugger command
#
#   Copyright (C) 2002, 2003, 2004, 2005, 2006, 2008 Rocky Bernstein
#   rocky@gnu.org
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

_Dbg_help_add signal \
"signal SIGNAL

Send a signal to the debugged program.

SIGNAL can be a name like \"TERM\" (for SIGTERM) or a positive number like 
15 (which in \*nix systems is the equivalent number. On \*nix systems the
command \"kill -l\" sometimes will give a list of signal names and numbers.

The signal is sent to process \$\$ (which is $$ right now).

Also similar is the \"kill\" command."

_Dbg_do_signal() {
  typeset sig=$1
  typeset -i signum
  if [[ -z $sig ]] ; then
    _Dbg_errmsg "Missing signal name or signal number."
    return 1
  fi

  eval "$_seteglob"
  if [[ $sig == $int_pat ]]; then
    eval "$_resteglob"
    signame=$(_Dbg_signum2name $sig)
    if (( $? != 0 )) ; then
      _Dbg_msg "Bad signal number: $sig"
      return 1
    fi
    signum=sig
  else
    eval "$_resteglob"
    typeset signum;
    signum=$(_Dbg_name2signum $sig)
    if (( $? != 0 )) ; then
      _Dbg_msg "Bad signal name: $sig"
      return 1
    fi
  fi
  kill -$signum $$
  return 0
}
