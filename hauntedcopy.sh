#!/bin/bash

usage(){
	echo "Usage: $0 [--debug] -d /path/to/dictionary [-p /path/to/pool] /path/to/target/folder /path/to/another/target/folder"
}

help(){
	echo -e "Copies a randomly selected file from a given pool to a random location among those passed with a name generated from a dictionary."
	echo -e "Is especially amusing to use with a cronjob on an unsuspecting person's machine."
	echo -e "\n"
	echo -e "Options :"
	echo -e "--debug\t\tShows the selected file and destination"
	echo -e "-p/--pool\tNot required, but recommanded. Folder containing the files that will be copied. Leaving it unspecified will default to the script's location, which mean the script could copy itself."
	echo -e "-d/--dictionary\tLocation of the file used to generate names. It should be a simple file with words separated by UNIX-style linebreaks."
	echo -e "-c/--copy\tUses cp instead of ln to duplicatethe file, which is slower and more noticable, but does not requires write permissions."
	echo -e "\n"
	echo "Error codes :"
	echo "1 : Invalid arguments"
	echo "2 : Invalid file or directory"
	echo "3 : Blocked by permissions"
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
chosenFile="$(find "$poolLocation" -maxdepth 1 -type f | shuf -n 1)"

generatedName="$(shuf -n 2 "$dictionary" | tr '\n' ' ' | sed 's/ *$//')"

chosenLocation="$(echo "$targetLocationsList" | shuf -n 1)"

fileExt="$(echo "$chosenFile" | rev | cut -d. -f 1 | rev)"

finalPath="$chosenLocation/$generatedName.$fileExt"

if [ "$copy" = true ];then
	if [ -r "$chosenFile" ]; then
		cp "$chosenFile" "$finalPath"
		##TODO : Add a check for sucessful completion
	else
		echo "Cannot create a copy unless the chosen file is readable."
		echo "chosenFile : $chosenFile"
		exit 3
	fi
else
	if [ -r "$chosenFile" ] && [ -w "$chosenFile" ]; then
		ln -T "$chosenFile" "$finalPath"
		##TODO : Add a check for sucessful completion
	else
		echo "Cannot create a link unless the chosen file is both readable and writable."
		echo "chosenFile : $chosenFile"
		exit 3
	fi
fi

if [ "$debug" = "true" ]; then
	#echo "dictionary : $dictionary"
	#echo "poolLocation : $poolLocation"
	echo "chosenFile : $chosenFile"
	#echo "generatedName : $generatedName"
	#echo "chosenLocation : $chosenLocation"
	#echo "fileExt : $fileExt"
	echo "finalPath : $finalPath"
fi
