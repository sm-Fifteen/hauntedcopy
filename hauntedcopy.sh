#!/bin/bash

usage(){
	echo "Usage: $0 [--debug] -d /path/to/dictionary [-p /path/to/pool] /path/to/target/folder /path/to/another/target/folder"
}

help(){
	echo -e  << EOF
Copies a randomly selected file from a given pool to a random location among those passed with a name generated from a dictionary.
Is especially amusing to use with a cronjob or a systemd timer on an unsuspecting person's machine.

Options :
	--debug\t\tShows the selected file and destination
	-p/--pool\tNot required, but recommanded. Folder containing the files that will be copied. Leaving it unspecified will default to the script's location, which mean the script could copy itself.
	-d/--dictionary\tLocation of the file used to generate names. It should be a simple file with words separated by UNIX-style linebreaks.
	-c/--copy\tUses cp instead of ln to duplicatethe file, which is slower and more noticable, but does not requires write permissions.

Error codes :
	1 : Invalid arguments
	2 : Invalid file or directory
	3 : Blocked by permissions
EOF
}

# Check for arguments
if [ $# -eq 0 ]; then
	echo "This script must be called with arguments."
	usage
	exit 1
fi

arguments=$(getopt -o "h,c,d:,p:" -l "help,copy,debug,dictionary:,pool:" \
             -n "hauntedcopy" -- "$@")

#Not sure what this does, but everybody's doing it.
eval set -- "$arguments"

while true
do
	case "$1" in
	-h | --help )
		help; exit;;
	
	-d | --dictionary )
		dictionary="$2";
		if [ -f "$dictionary" ];then
			shift 2
		else
			echo "Dictionary file does not exist : $dictionary"
			exit 2
		fi
		;;
	-p | --pool )
		poolLocation="$2";
		if [ -d "$poolLocation" ];then
			shift 2
		else
			echo "The specified pool is not a valid directory : $poolLocation"
			exit 2
		fi
		;;
	-c | --copy )
		copy="true"
		shift;;
	--debug )
		debug="true"
		shift;;
	-- )
		shift; break;;
		# Keep stripping the args until this point.

	esac
done

if [ -z "$poolLocation" ]; then
	#poolLocation defaults to the script's location, although
	#this poses the risk that the script could select and
	#copy itself.
	poolLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

if [ -z "$dictionary" ]; then
	echo "You must specify a dictionary file."	
	exit 2
fi

if [ $# -eq 0 ]; then
	echo "You must specify at least one target folder."
	usage
	exit 1
fi

if [ $? -ne 0 ]; then
	## Bad arguments
	usage
	exit 1
fi

for dir in "$@"; do
	if [ ! -d "$dir" ];then
		echo "One of the specified target folders is not a directory ($dir)."
		exit 3
	elif [ ! -w "$dir" ];then
		echo "One of the specified target folders does not have write permissions ($dir)."
	else
		if [ -n "$targetLocationList" ];then		
			targetLocationsList="$targetLocationsList\n$dir"
		else
			targetLocationsList="$dir"
		fi
	fi
done

###############################

#Select random file in the directory where the script is located
# \( ! -ipath ${BASH_SOURCE[0]} \)

if [ "$copy" = "true" ];then
	foundFiles="$(find "$poolLocation" -maxdepth 1 -type f -readable)"
else
	foundFiles="$(find "$poolLocation" -maxdepth 1 -type f -readable -writable)"
fi

if [ $(echo "$foundFiles" | wc -w) -eq  0 ];then
	[[ "$copy" = "true" ]] && echo "No files eligible for copy (Readable)" || echo "No files eligible for linking (Readable and Writable)"
	exit 3;
fi

chosenFile="$(echo "$foundFiles" | shuf -n 1)"

generatedName="$(shuf -n 2 "$dictionary" | tr '\n' ' ' | sed 's/ *$//')"

chosenLocation="$(echo "$targetLocationsList" | shuf -n 1)"

fileExt="$(echo "$chosenFile" | rev | cut -d. -f 1 | rev)"

finalPath="$chosenLocation/$generatedName.$fileExt"

if [ "$copy" = "true" ];then
	cp "$chosenFile" "$finalPath"
	##TODO : Add a check for sucessful completion
else
	chosenFileDevice="$(stat -c '%d' "$chosenFile")"
	chosenLocationDevice="$(stat -c '%d' "$chosenLocation")"

	if [ $chosenFileDevice -eq $chosenLocationDevice ];then
		ln -T "$chosenFile" "$finalPath"
		##TODO : Add a check for sucessful completion
	else
		echo "Cannot create a link between two files on different filesystems."
		echo "Try the copy mode (-c) instead."
		exit 3
	fi
fi

if [ "$debug" = "true" ]; then
	[[ "$copy" = "true" ]] && echo "Found $(echo "$foundFiles" | wc -l) files eligible for copy (Readable)" || echo "Found $(echo "$foundFiles" | wc -l) files eligible for linking (Readable and Writable)"
	#echo "dictionary : $dictionary"
	#echo "poolLocation : $poolLocation"
	echo "chosenFile : $chosenFile"
	#echo "generatedName : $generatedName"
	#echo "chosenLocation : $chosenLocation"
	#echo "fileExt : $fileExt"
	echo "finalPath : $finalPath"
fi
