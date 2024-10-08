#!/bin/bash
set -e

REMEMBERPATH="$(pwd)"
SCRIPTDIR="$(echo $0 | sed 's/\/cullingOfStratholme.sh//g')"
ADDONLIST=cullingOfStratholme.list
ADDONPATH=~/Dropbox/WoW_Links/retail_links/Interface_Files/AddOns
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"

function dlAddon {
	echo "Finding Addon Provider for URL: ${GREEN}$1${CRESET}"
	PROVIDER=$(getAddonProvider $1)
	echo "Found Provider: ${GREEN}$PROVIDER${CRESET}"

	if [ "$PROVIDER" == "curseforge.com" ]
	then
		dlCurseAddon $1
	elif [ "$PROVIDER" == "wowinterface.com" ]
	then
	  dlWowIAddon $1
	elif [ "$PROVIDER" == "github.com" ]
	then
	  dlGitAddon $1
	elif [ "$PROVIDER" == "SKIP" ]
	then
	  echo "Skipping: $1"
	else
	  dlIndy $1
	fi
}

function getAddonProvider {
    if [[ $1 == \#* ]]; then
        echo "SKIP"
		elif [[ -z "${1// }" ]]; then
				echo "SKIP"
		else
        #echo "Finding Addon Provider for URL: ${GREEN}$1${CRESET}"
        local PROVIDER="$(echo $1 | grep -E -o '\w+\.com')"
        echo $PROVIDER
        #PROVIDER="$(echo $1 | grep -E -o 'w+.com')"
        #echo $PROVIDER
    fi
}

function printList {
	ADDONCOUNT=0
	for i in "${ADDONS[@]}";
	do
		echo "$ADDONCOUNT - $i"
		ADDONCOUNT=$((ADDONCOUNT + 1))
	done
	exit
}

function parseFileName {
	local FILENAME="$(echo $1 | grep -E -o '[^\/]+$')"
	echo "$FILENAME"
}

function parseCurseFileNameFromListURL {
	local FILENAME="$(echo $1 | grep -E -o 'addons/.+/download' | cut -f2 -d'/')"
	echo "${FILENAME}.zip"
}

function parseDirName {
	local DIRNAME="$(echo $1 | sed -E 's/.{4}$/ /g')"
}

function parseAddonDirName {
	echo "parse!"
	#Get the name of the addon directory from the zip file
	#local ADDONDIR="$(unzip -l /tmp/$ZFILE | grep -E -o '   \w+\/' | sort | uniq | grep -E -o '\w+')"
	#echo "Searching Addon archive and found directory named: ${GREEN}$ADDONDIR${CRESET}"
}

function dlCurseAddon {
	echo "Updating Addon from curseforge.com..."
	#Get the URL to download the file
	local DOMAIN="https://www.curseforge.com"
	local SLUG="$(basename $1)"
	local PAGEDATA=$(wget --random-wait -q -U "${UA}" $1 -O - | pup 'script#__NEXT_DATA__ json{}' | jq '.[].text' | jq -r .)
	SLUG_ID=$(echo $PAGEDATA | jq -r .props.pageProps.project.mainFile.id)
	FNAME=$(echo $PAGEDATA | jq -r .props.pageProps.project.mainFile.fileName | sed 's/ /%20/g')
	PROJECT_ID=$(echo $PAGEDATA | jq -r .props.pageProps.project.id)
	local CURSELINK="/api/v1/mods/${PROJECT_ID}/files/${SLUG_ID}/download"
	echo "CurseLink: ${GREEN}$CURSELINK${CRESET}"
	local DLURL="${DOMAIN}${CURSELINK}"

	#if [ "$DLURL" != '' ]
	#then
		echo "Download URL: ${GREEN}$DLURL${CRESET}"

		#Get the name of the file itself
		local ZFILE=${FNAME}
		echo "Zip File: ${GREEN}$ZFILE${CRESET}"

		#Get the name of just the zip file
		local ZDIRNAME=$(parseDirName $ZFILE)

		#Remove the temp dir if it exists
		rm -rf /tmp/CoS/tmpAddon

		#Re-create the dir
		mkdir -p /tmp/CoS/tmpAddon

		#Download the file
		echo "Downloading file: ${GREEN}$DLURL${CRESET}"
		cd /tmp/CoS
		wget --random-wait -U "${UA}" -O ${ZFILE} "$DLURL"

		#Unzip the file to a temp directory
		ZDIRNAME=tmpCurseDl
		echo "Unzipping file: ${GREEN}/tmp/$ZFILE${CRESET} to ${GREEN}/tmp/$ZDIRNAME${CRESET}"
		#unzip -o "/tmp/CoS/$ZFILE" -d /tmp/CoS/tmpAddon
		#This failed because skada had a trash file in their archive with illegal characters in it so I had to switch to p7zip
		7z x "/tmp/CoS/$ZFILE" -o/tmp/CoS/tmpAddon

		#Copy only new files into the Addon directory
		rsync -hvrPt /tmp/CoS/tmpAddon/ "$ADDONPATH"
	#else
	    #echo "Download failed for: $1"
	#fi
}

function dlIndy {
	echo "Updating Independent Addon..."
	#Get the URL to download the file
	local DLURL=$1
	echo "Download URL: ${GREEN}$DLURL${CRESET}"

	#Get the name of the file itself
	local ZFILE=$(parseFileName "$DLURL")
	echo "Zip File: ${GREEN}$ZFILE${CRESET}"

	#Get the name of just the zip file
	local ZDIRNAME=$(parseDirName $ZFILE)

	#Remove the temp dir if it exists
	rm -rf /tmp/CoS/tmpAddon

	#Re-create the dir
	mkdir -p /tmp/CoS/tmpAddon

	#Download the file
	echo "Downloading file: ${GREEN}$DLURL${CRESET}"
	cd /tmp/CoS
	wget --random-wait -N $DLURL

	#Unzip the file to a temp directory
	ZDIRNAME=tmpCurseDl
	echo "Unzipping file: ${GREEN}/tmp/$ZFILE${CRESET} to ${GREEN}/tmp/$ZDIRNAME${CRESET}"
	unzip -o "/tmp/CoS/$ZFILE" -d /tmp/CoS/tmpAddon

	#Copy only new files into the Addon directory
	rsync -hvrPt /tmp/CoS/tmpAddon/ "$ADDONPATH"
}

function dlGitAddon {
	echo "Updating Addon using git..."
	#Get the URL to download the file
	local DLURL=${1}
	echo "Download URL: ${GREEN}${DLURL}${CRESET}"

	#Get the string we will use for the directory name
	local GDIRNAME=$(echo ${DLURL} | grep -E -o '[-[:alnum:]]+.git$' | cut -f1 -d.)
	echo "Addon name: $GDIRNAME"

	if [ -d "${ADDONPATH}/${GDIRNAME}" ]
	then
		echo "Found existing folder for addon: ${GDIRNAME} at ${ADDONPATH}/${GDIRNAME}"
		#Is this a healthy git folder?
		if [ -d "${ADDONPATH}/${GDIRNAME}/.git" ]
		then
			echo "Pull from healthy git directory (${ADDONPATH}/${GDIRNAME}) for : ${GREEN}$GDIRNAME${CRESET}"
			cd ${ADDONPATH}/${GDIRNAME}
			git pull
			#git -C "${ADDONPATH}/${GDIRNAME}" pull ${DLURL}
		else
			echo "Removing git directory (${ADDONPATH}/${GDIRNAME}) for : ${GREEN}${GDIRNAME}${CRESET}"
			rm -rfv "${ADDONPATH}/${GDIRNAME}"
			echo "Cloning from git repository for : ${GREEN}${GDIRNAME}${CRESET}"
			git -C "${ADDONPATH}" clone ${DLURL}
		fi
	else
	echo "Could not find existing addon folder: ${ADDONPATH}/${GDIRNAME}"
		echo "Removing git directory (${ADDONPATH}/${GDIRNAME}) for : ${GREEN}${GDIRNAME}${CRESET}"
		rm -rfv "${ADDONPATH}/${GDIRNAME}"
		echo "Cloning from git repository for : ${GREEN}${GDIRNAME}${CRESET}"
		git -C "${ADDONPATH}" clone ${DLURL}
	fi
}

function dlWowIAddon {
	echo "Updating Addon from wowinterface.com..."

	#Get the URL to download the file
	local DLURL="https://www.wowinterface.com/downloads/getfile.php?id=$(wget --random-wait -q $1 -O - | grep landing | grep -E -o 'fileid=[[:digit:]]+' | uniq | cut -f2 -d=)"
	echo "Download URL: ${GREEN}$DLURL${CRESET}"

	#Get the name of the file itself
	local ZFILE=$(curl -Is $DLURL | grep content-disposition | cut -f2 -d\")
	echo "Zip File: ${GREEN}$ZFILE${CRESET}"

	#Get the name of just the zip file
	local ZDIRNAME=$(parseDirName $ZFILE)

	#Remove the temp dir if it exists
	rm -rf /tmp/CoS/tmpAddon

	#Re-create the dir
	mkdir -p /tmp/CoS/tmpAddon

	#Download the file
	echo "Downloading file: ${GREEN}$DLURL${CRESET}"
	cd /tmp/CoS
	wget --content-disposition --random-wait -N $DLURL

	#Unzip the file to a temp directory
	ZDIRNAME=tmpCurseDl
	echo "Unzipping file: ${GREEN}/tmp/$ZFILE${CRESET} to ${GREEN}/tmp/$ZDIRNAME${CRESET}"
	unzip -o "/tmp/CoS/$ZFILE" -d /tmp/CoS/tmpAddon

	#Copy only new files into the Addon directory
	rsync -hvrPt /tmp/CoS/tmpAddon/ "$ADDONPATH"

}

#############
# Main Loop #
#############
# Pre-check for required commands
for cmd in curl wget jq 7z; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is not installed or not in PATH."
    exit 1
  fi
done

if [ "$1" == "classic" ]
then
	echo "Install mods for classic..."
	ADDONLIST=cullingOfStratholme.classic.list
	ADDONPATH=/mnt/o/Games/World\ of\ Warcraft/_classic_/Interface/AddOns
	echo ${ADDONLIST}
	echo ${ADDONPATH}
fi

echo "Creating AddOns directory \"${ADDONPATH}\" if it doesn't exist..."
mkdir -p "${ADDONPATH}"

ALFULL=$SCRIPTDIR/$ADDONLIST

#Check to see if the text file exists
if [ ! -f $ALFULL ]
then
	echo "Could not find file: $ADDONLIST"
fi

declare -a ADDONS
ADDONCOUNT=0
while IFS= read -r f || [ -n "${f}" ]
do
	ADDONS[$ADDONCOUNT]=$f
	ADDONCOUNT=$(($ADDONCOUNT + 1))
done < $ALFULL

GREEN="$(tput setaf 2)"
CRESET="$(tput sgr0)"

if [ "$1" == "list" ]
	then
		printList
		cd ${REMEMBERPATH}
		exit
fi

if [ "$1" == "test" ]
	then
		ADDONURL=${ADDONS[$1]}
		dlAddon $ADDONURL
		cd ${REMEMBERPATH}
		exit
fi

for i in "${ADDONS[@]}";
do
	dlAddon $i
done

cd ${REMEMBERPATH}
