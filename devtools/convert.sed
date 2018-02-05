#!/bin/sed -f
s/$ch{geoss_dir} = $GEOSS_DIR;/$ch{geoss_dir} = $GEOSS_DIR; $ch{version} = $VERSION;/g
