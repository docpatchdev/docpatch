#!/usr/bin/env bash


## DocPatch -- patching documents that matter
## Copyright (C) 2012-18 Benjamin Heisig <https://benjamin.heisig.name/>
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.


##
## Help script
##


## Main method
function main {
    loginfo "How can I help you?"

    local manpage="$PROJECT_NAME"

    if [ -n "$SUB_COMMAND" ]; then
        manpage="$manpage-${SUB_COMMAND}"
    fi

    logdebug "Calling man page..."
    "$MAN" "$manpage"
    if [ $? -gt 0 ]; then
        logwarning "Application for man pages returned with an error."
        logerror "Cannot show man page for '${manpage}'."
        abort 1
    fi
    logdebug "Man page called."
}


## Prints command specific options.
function printCommandOptions {
    loginfo "Printing command specific options..."
    prntLn "    No options"
    logdebug "Options printed."
    return 0
}
