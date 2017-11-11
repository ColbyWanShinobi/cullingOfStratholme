#!/bin/bash

set -e

PWD="$(pwd)"
SCRIPTDIR="$(echo $0 | sed 's/\/cullingOfStratholme.sh//g')"
ADDONLIST=cullingOfStratholme.list
ALFULL=$SCRIPTDIR/$ADDONLIST

#Check to see if the text file exists
if [ ! -f $ALFULL ]
then
	echo "Could not find file: $ADDONLIST"
fi

declare -a ADDONS
ADDONCOUNT=0
while read f
do
	ADDONS[$ADDONCOUNT]=$f
	ADDONCOUNT=$(($ADDONCOUNT + 1))
done < $ALFULL

#Default WoW install path on OSX
#ADDONPATH=/Applications/World\ of\ Warcraft/Interface/AddOns

#If we're on Linux, then change path
if [ -f /etc/lsb-release ]
then
  echo Found Linux!
  ADDONPATH=~/Dropbox/WoW/Interface/AddOns
fi

GREEN="$(tput setaf 2)"
CRESET="$(tput sgr0)"

function getAddonProvider {
	#echo "Finding Addon Provider for URL: ${GREEN}$1${CRESET}"
	local PROVIDER="$(echo $1 | grep -E -o '\w+\.com')"
	echo $PROVIDER
	#PROVIDER="$(echo $1 | grep -E -o 'w+.com')"
	#echo $PROVIDER
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
	local CURSELINK="$(wget --random-wait -q $1 -O - | grep -i "If your download" | grep -E -o 'href=\".+\"' | cut -f2 -d'"')"
	echo "CurseLink: ${GREEN}$CURSELINK${CRESET}"
	local DLURL="${DOMAIN}${CURSELINK}"

	#if [ "$DLURL" != '' ]
	#then
		echo "Download URL: ${GREEN}$DLURL${CRESET}"

		#Get the name of the file itself
		local ZFILE=$(parseCurseFileNameFromListURL "$DLURL")
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
		wget --random-wait -N -O ${ZFILE} "$DLURL"

		#Unzip the file to a temp directory
		ZDIRNAME=tmpCurseDl
		echo "Unzipping file: ${GREEN}/tmp/$ZFILE${CRESET} to ${GREEN}/tmp/$ZDIRNAME${CRESET}"
		unzip -o "/tmp/CoS/$ZFILE" -d /tmp/CoS/tmpAddon

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
	local DLURL=$1
	echo "Download URL: ${GREEN}$DLURL${CRESET}"

	#Get the name of just the zip file
	local GDIRNAME=$(echo $DLURL | grep -E -o '\w+.git' | cut -f1 -d.)

	if [ -d "$ADDONPATH/$GDIRNAME" ]
	then
		echo "Updating from git repository for : ${GREEN}$GDIRNAME${CRESET}"
		git -C "$ADDONPATH/$GDIRNAME" pull
	else
		echo "Cloning from git repository for : ${GREEN}$GDIRNAME${CRESET}"
		git -C "$ADDONPATH" clone $DLURL
	fi
}

function dlWowIAddon {
	echo "Updating Addon from wowinterface.com..."

	#Get the URL to download the file
	local DLURL="http://www.wowinterface.com/downloads/getfile.php?id=$(wget --random-wait -q $1 -O - | grep landing | grep -E -o 'fileid=[[:digit:]]+' | uniq | cut -f2 -d=)"
	echo "Download URL: ${GREEN}$DLURL${CRESET}"

	#Get the name of the file itself
	local ZFILE=$(curl -Is $DLURL | grep Content-disposition | cut -f2 -d\")
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
	else
	  dlIndy $1
	fi
}

#function getGitAddons {

#}

if [ "$1" != "" ]
then
	if [ "$1" == "list" ]
	then
		printList
	else
		ADDONURL=${ADDONS[$1]}
		dlAddon $ADDONURL
	fi
else
	for i in "${ADDONS[@]}";
	do
		dlAddon $i
	done
fi

cd $PWD
