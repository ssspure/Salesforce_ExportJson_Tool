#!/bin/bash

# set encode UTF-8
export LANG=C.UTF-8

# execute.sh script file path
currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

parentdir="$(dirname "$currentDir")"

pwsh $parentdir/exportJsonDataForImport/execute.ps1 $currentDir