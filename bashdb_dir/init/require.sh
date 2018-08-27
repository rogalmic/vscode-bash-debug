#   Copyright (C) 2011 Rocky Bernstein <rocky@gnu.org>
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
if [[ -z $_Dbg_requires ]] ; then
    function _Dbg_expand_filename {
	typeset -r filename="$1"

	# Break out basename and dirname
	typeset basename="${filename##*/}"
	typeset -x dirname="${filename%/*}"

	# No slash given in filename? Then use . for dirname
	[[ $dirname == $basename ]] && [[ $filename != '/' ]] && dirname='.'

	# Dirname is ''? Then use / for dirname
	dirname=${dirname:-/}

	# Handle tilde expansion in dirname
	dirname=$(echo $dirname)

	typeset long_path

	if long_path=$( (cd "$dirname" ; pwd) 2>/dev/null ) ; then
	    if [[ "$long_path" == '/' ]] ; then
		echo "/$basename"
	    else
		echo "$long_path/$basename"
	    fi
	    return 0
	else
	    echo $filename
	    return 1
	fi
    }

    typeset -A _Dbg_requires
    require() {
	typeset file
	typeset expanded_file
	typeset source_dir
	typeset orig_dir
	orig_dir=$(pwd)
	source_dir=${BASH_SOURCE[1]%/*}
	if [[ $source_dir != ${BASH_SOURCE[1]} ]] ; then
	    builtin cd $source_dir
	fi
	for file in "$@" ; do
	    expanded_file=$(_Dbg_expand_filename "$file")
	    if [[ -z ${_Dbg_requires[$file]} \
		&& -z ${_Dbg_requires[$expanded_file]} ]] ; then
		source $expanded_file
		_Dbg_requires[$file]=$expanded_file
		_Dbg_requires[$expanded_file]=$expanded_file
	    fi
	done
	[[ -n $orig_dir ]] && builtin cd $orig_dir
    }
fi
