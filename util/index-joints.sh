#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cat $DIR/../model/cassie.xml | grep "joint name=" | sed "s;\s*<joint name='\([^']*\)' type='\([^']*\)'.*;\1 \2;" | sed "s;ball;\n\n\n;" | sed "s;hinge;;" | sed 's;\(left-hip-roll\);\n\n\n\n\n\n\1;' | cat -n
