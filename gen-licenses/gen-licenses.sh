#!/bin/bash

# Creates a licenses directory and copies vendor licenses into it.

if [ -d licenses ]
then
    rm -rf licenses
fi

mkdir licenses
for lic in `find . \( -name "LICENSE*" -o -name "NOTICE*" \) | sed 's|^./||'`
do
    dir=licenses/`dirname $lic`
    mkdir -p $dir
    cp $lic $dir
done