# -*- shell-script -*-
# vars.sh - Bourne Again Shell Debugger Global Variables
#
#   Copyright (C) 2002, 2003, 2004, 2006, 2007, 2008, 2009 Rocky Bernstein 
#   2011 <rocky@gnu.org>
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

# Note: the trend now is to move initializations which are generally
# used in only one sub-part (e.g. variables for break/watch/actions) to 
# the corresponding file.

[[ -z $_Dbg_init_ver ]] || return

typeset _Dbg_cur_fn          # current function of debugged program

# If called from bashdb script rather than via "bash --debugger", skip
# over some initial setup commands, like the initial "source" function
# of debugged shell script.

typeset -i _Dbg_have_set0=0
if [[ -r $_Dbg_libdir/builtin/set0 ]] ; then
  if enable -f $_Dbg_libdir/builtin/set0  set0 >/dev/null 2>&1 ; then
    _Dbg_have_set0=1
  fi
fi

typeset _Dbg_orig_0=$0
if [[ -n $_Dbg_script ]] ; then 
  if ((_Dbg_have_set0)) && [[ -n $_Dbg_script_file ]] ; then
      builtin set0 $_Dbg_script_file
  fi
  _Dbg_step_ignore=3
else 
  typeset -i _Dbg_n=$#
  typeset -i _Dbg_i
fi

typeset -i _Dbg_need_input=1   # True if we need to reassign input.
typeset -i _Dbg_brkpt_num=0    # If nonzero, the breakpoint number that we 
                               # are currently stopped at.
typeset last_next_step_cmd='s' # Default is step.
typeset _Dbg_last_print=''     # expression on last print command
typeset _Dbg_last_printe=''    # expression on last print expression command

# strings to save and restore the setting of `extglob' in debugger functions
# that need it
typeset _seteglob='local __eopt=-u ; shopt -q extglob && __eopt=-s ; shopt -s extglob'
typeset _resteglob='shopt $__eopt extglob'

typeset int_pat='[0-9]*([0-9])'
typeset _Dbg_signed_int_pat='?([-+])+([0-9])'

# Set tty to use for output. 
if [[ -z $_Dbg_tty ]] ; then 
  typeset -x _Dbg_tty
  _Dbg_tty=$(tty)
  [[ $? != 0 ]] && _Dbg_tty=''
fi

# If _Dbg_QUIT_LEVELS is set to a positive number, this is the number
# of levels (subshell or shell nestings) or we should exit out of.
[[ -z $_Dbg_QUIT_LEVELS ]] && _Dbg_QUIT_LEVELS=0
