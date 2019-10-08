#!/bin/bash

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
	echo "Stopping build..."
	incredibuild_stop.bat
	exit 1
}

BUILDS="$1"
if [ -z "$BUILDS" ]; then
	if [ -z "$DEFAULT_BUILD" ]; then
		BUILDS="Release|Win64 OGL"
	else
		BUILDS="$DEFAULT_BUILD"  	  	
	fi
fi

#try to guess the IB preset
IB_PRESET=`guess_ib_preset.sh handheld/project/VS2015/Minecraft.ib_preset`

#restore NuGet packages manually because it doesn't work in IB
restore_nuget.sh

if [[ -z "$IB_PRESET" ]]; then
	echo "Building: $BUILDS"
	incredibuild.bat "$BUILDS"
else
	echo "Found preset $IB_PRESET"
	incredibuild_preset.bat "$IB_PRESET"
fi

if [ $? -ne 0 ]; then
	notify.bat "Incredibuild" "Finished with an error"
	exit 1
fi

notify.bat "Incredibuild" "Finished!"
