#!/bin/bash
### FILL THESE VARIABLES TO CORRECT WORK OF THE SCRIPT ###
USER_NAME=
SERVER_ADDRESS=
SERVER_PATH=
##########################################################
### DO NOT TOUCH THESE VARIABLES ###
REMOTE_INDEX_HTML="http://climb.li/index.default.html"
INDEX_NAME="index.html"
JSON_NAME="content.json"
##########################################################


# Function to display the art work

function art()
{
    echo -e "\E[31m "
    echo "      ___           ___                   ___           ___     "
    echo "     /\  \         /\__\      ___        /\__\         /\  \    "
    echo "    /::\  \       /:/  /     /\  \      /::|  |       /::\  \   "
    echo "   /:/\:\  \     /:/  /      \:\  \    /:|:|  |      /:/\:\  \  "
    echo "  /:/  \:\  \   /:/  /       /::\__\  /:/|:|__|__   /::\~\:\__\ "
    echo " /:/__/ \:\__\ /:/__/     __/:/\/__/ /:/ |::::\__\ /:/\:\ \:|__|"
    echo " \:\  \  \/__/ \:\  \    /\/:/  /    \/__/~~/:/  / \:\~\:\/:/  /"
    echo "  \:\  \        \:\  \   \::/__/           /:/  /   \:\ \::/  / "
    echo "   \:\  \        \:\  \   \:\__\          /:/  /     \:\/:/  /  "
    echo "    \:\__\        \:\__\   \/__/         /:/  /       \::/__/   "
    echo "     \/__/         \/__/                 \/__/         ~~       "
    echo "                Command Line Interface Micro Blog"
    echo -e "\033[0m"  
}

# The function that displays help/usage for the script
function usage()
{
    echo
    echo "To initialize your server:"
    echo "${0} -i"
    echo 
    echo "To upload a new record to your blog:"
    echo "${0} -c 'a comment for the image' image.jpg"
    echo OR
    echo "${0} image.jpg -c 'a comment for the image'"
    echo
    echo "Return codes:"
    echo "1 - missing values in the variables in the head of the script"
    echo "2 - no command line parameters are provided"
    echo "3 - provided invalid command line"
    echo "4 - not provided value for the option -c"
    echo "5 - some troubles with SSH connection"
    echo "6 - some troubles with downloading of the ${INDEX_NAME}"
    echo
    echo "For print this help type ${0} -h"
}

function prepare_json_record()
{
    # ${1} - IMAGE_NAME
    # ${2} - COMMENT
    # ${3} - delimiter (\t or \n)
    local result
    if [ ! -z "${1}" ] && [ ! -z "${2}" ]
    then
	result="{${3}\"img\":\"${1}\",${3}\"comment\":\"${2}\"${3}}"
    elif [ ! -z "${1}" ]
    then
	result="{${3}\"img\":\"${1}\"${3}}"
    else
	result="{${3}\"comment\":\"${2}\"${3}}"
    fi
    echo "${result}"
}

function check_ssh_type()
{
    # ${1} - USER_NAME
    # ${2} - SERVER_ADDRESS
    local BATCH_MODE
    
    SSH_BATCH_ERROR_MESSAGE=$(ssh -o BatchMode=yes ${1}@${2} who 2>&1 >/dev/null)
    SSH_BATCH_RETURN_CODE=$(echo $?)
    
    if [ ${SSH_BATCH_RETURN_CODE} -eq 0 ]
    then
	BATCH_MODE=true
    elif [ ${SSH_BATCH_RETURN_CODE} -ne 0 ] && [[ "${SSH_BATCH_ERROR_MESSAGE}" == "Permission denied (publickey,password)"* ]]
    then
	BATCH_MODE=false
    else
	echo -e "There is an error in your SSH connection. The exit code is ${SSH_BATCH_RETURN_CODE}.\nThe error message: ${SSH_BATCH_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
	exit 5
    fi

    echo ${BATCH_MODE}
}

function update_remote_json()
{
    local BATCH_MODE

    # ${1} - USER_NAME
    # ${2} - SERVER_ADDRESS
    # ${3} - SERVER_PATH
    # ${4} - IMAGE_NAME
    # ${5} - COMMENT
    #local USER_NAME="${1}"
    #local SERVER_ADDRESS="${2}"
    #local SERVER_PATH="${3}"
    #local IMAGE_NAME="${4}"
    #local COMMENT="${5}"
    
    local TEMP_FILE="temp.json"
    # Force delete the temp file before starting
    rm -f ${TEMP_FILE} 2> /dev/null

    echo "Trying to download the JSON file from the server"
    SCP_ERROR_MESSAGE=$(scp -q ${USER_NAME}@${SERVER_ADDRESS}:"${SERVER_PATH}${JSON_NAME}" ${TEMP_FILE} 2>&1 >/dev/null)
    SCP_RETURN_CODE=$(echo $?)
    if [ ${SCP_RETURN_CODE} -eq 0 ]
    then
	# The remote file is exists
	JSON_IS_EMPTY=false
    elif [ ${SCP_RETURN_CODE} -ne 0 ] && [[ "${SCP_ERROR_MESSAGE}" == *"No such file or directory" ]]
    then
	# The remote file is not exists
	JSON_IS_EMPTY=true
    else
	echo -e "There is an error in your SSH connection. The exit code is ${SCP_RETURN_CODE}.\nThe error message: ${SCP_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
	exit 5
    fi

    echo "Processing of the JSON file"
    # If there is no JSON before, then create it
    if [[ ${JSON_IS_EMPTY} == "true" ]]
    then
	json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\n')
	echo -e "[\n${json_output}\n]" > ${TEMP_FILE}
    else
	if [ $(grep -Pzoq '\[[[:space:]]*{[[:space:]]*"comment"' ${TEMP_FILE} ; echo $?) -eq 0 ]
	then
	    temp_var="$(<${TEMP_FILE})"
	    json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\t')
	    # The case then the top record contains begins with word "comment"
	    echo -e "${temp_var}" | tr '\n' '\t' | sed "s/\[[[:space:]]*\({[[:space:]]*\"comment\"\)/\[\t${json_output},\t\1/g" | tr '\t' '\n' > ${TEMP_FILE}
	elif [ $(grep -Pzoq '\[[[:space:]]*{[[:space:]]*"img"' ${TEMP_FILE} ; echo $?) -eq 0 ]
	then
	    temp_var="$(<${TEMP_FILE})"
	    json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\t')
	    # The case then the top record contains begins with word "img"
	    echo -e "${temp_var}" | tr '\n' '\t' | sed "s/\[[[:space:]]*\({[[:space:]]*\"img\"\)/\[\t${json_output},\t\1/g" | tr '\t' '\n' > ${TEMP_FILE}
	else
	    json_output=$(prepare_json_record "${IMAGE_NAME}" "${COMMENT}" '\n')
	    # If there is no previous records in the JSON - just append new block to it
	    echo -e "[\n${json_output}\n]" >> ${TEMP_FILE}
	fi
    fi
    
    # Upload the image and the result JSON file to the server
    echo "Uploading an updated JSON to the server"
    SCP_ERROR_MESSAGE=$(scp -q ${TEMP_FILE} ${USER_NAME}@${SERVER_ADDRESS}:"${SERVER_PATH}${JSON_NAME}" 2>&1 >/dev/null)
    SCP_RETURN_CODE=$(echo $?)
    if [ ${SCP_RETURN_CODE} -ne 0 ]
    then
	echo -e "There is an error in your SSH connection. The exit code is ${SCP_RETURN_CODE}.\nThe error message: ${SCP_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
	exit 5
    fi
    
    if [ ! -z "${IMAGE_NAME}" ]
    then
	echo "Uploading the image ${IMAGE_NAME} to the server"
	SCP_ERROR_MESSAGE=$(scp -rq "${IMAGE_NAME}" ${USER_NAME}@${SERVER_ADDRESS}:"${SERVER_PATH}" 2>&1 >/dev/null)
	SCP_RETURN_CODE=$(echo $?)
	if [ ${SCP_RETURN_CODE} -ne 0 ]
	then
	    echo -e "There is an error in your SSH connection. The exit code is ${SCP_RETURN_CODE}.\nThe error message: ${SCP_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
	    exit 5
	fi
    fi

    rm -f ${TEMP_FILE}
}

function init()
{
    # Test if the index file are already exists on the server
    if [ $(ssh -q ${USER_NAME}@${SERVER_ADDRESS} "test -e ${INDEX_NAME}"; echo $?) -eq 0 ]
    then
	echo -e "Site is already initialized. Would you like to re-upload a new files?\nThis would wipe out any change you've made to your page!"
	while true
	do
	    read -r -p "Are you sure? [Y/N] " input
	    case $input in
		[yY])
		    break
		    ;;
		
		[nN])
		    exit 0
	       	    ;;
		
		*)
		    echo "Please enter Y or N."
		    ;;
	    esac
	done
    fi

    # Download the index page template and save it under the name ${INDEX_NAME}
    echo "Downloading the file ${INDEX_NAME}"
    if [ $(curl -s -o "${INDEX_NAME}" -w "%{http_code}" "${REMOTE_INDEX_HTML}") -ne 200 ]
    then
	echo "There is some error in 'curl' when downloading from the ${REMOTE_INDEX_HTML}" 2>&1
	exit 6
    fi
    
    # Upload the index page to the server
    echo "Uploading of the ${INDEX_NAME} to the server"
    SCP_ERROR_MESSAGE=$(scp -q "${INDEX_NAME}" ${USER_NAME}@${SERVER_ADDRESS}:"${SERVER_PATH}${INDEX_NAME}" 2>&1 >/dev/null)
    SCP_RETURN_CODE=$(echo $?)
    if [ ${SCP_RETURN_CODE} -ne 0 ]
    then
	echo -e "There is an error in your SSH connection. The exit code is ${SCP_RETURN_CODE}.\nThe error message: ${SCP_ERROR_MESSAGE}\nPlease, review values of the variables in the head of the script."
	exit 5
    fi
    
    # Remove useless copy of the ${INDEX_NAME}
    rm -f "${INDEX_NAME}"
}

### ACTUAL RUNNING OF THE SCRIPT ###

# Check the case when nothing is provided to the script
if [ -z "$*" ]
then
    art
    echo "At least, one of the parameters need to be provided!" >&2
    usage
    exit 2
fi

# Check the case when the user provided to the script more than three parameters
if [ $# -gt 3 ]
then
    echo "You have provided too many parameters!" >&2
    usage
    exit 2
fi

# Check the case when the user provided to the script the option -i and something else
if [ "${1}" == "-i" ] && [ $# -gt 1 ]
then
    echo "You should not provide any options or parameters after the option -i!" >&2
    usage
    exit 2
fi

# If the first argument is positional
if [ ! -z "${1}" ] && [[ ! "${1}" == -* ]]
then
    if [ "${2}" == "-c" ] || [ $# -eq 1 ]
    then
	IMAGE_NAME="${1}"
	shift
    else
	echo "Invalid command line. Please, check your syntax and try again." >&2
	usage
	exit 3
    fi
fi

# Parsing -c, -h and -i options
while getopts ":hic:" opt; do
    case $opt in
	c)
	    if [[ ! "${OPTARG}" == -* ]]
	    then
		COMMENT="${OPTARG}"
	    else
		echo "Invalid argument: $OPTARG" >&2
		usage
		exit 3
	    fi
	    
	    if [[ ${INIT_MODE} == "true" ]]
	    then
		echo "Invalid command line. Please, check your syntax and try again." >&2
		usage
		exit 3
	    fi
	    INIT_MODE=false
	    ;;
	h)
	    usage
	    exit 0
	    ;;
	i)
	    if [[ ${INIT_MODE} == "false" ]]
	    then
		echo "Invalid command line. Please, check your syntax and try again." >&2
		usage
		exit 3
	    fi
	    INIT_MODE=true
	    ;;
	\?)
	    echo "Invalid argument: $OPTARG" >&2
	    usage
	    exit 3
	    ;;
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    usage
	    exit 4
	    ;;
    esac
done
shift $((OPTIND-1))

#echo ${COMMENT}
#exit 0

# Get a value of the positional parameter (an image name)
if [ ! -z "${1}" ]
then
    IMAGE_NAME="${1}"
fi

# The block that checks all variables in the header of the script that need to be filled
if [ -z ${USER_NAME} ]
then
    echo "The script hasn't been setup properly. Please, fill a user name on the server in the variable USER_NAME in the head of the script" >&2
    exit 1
fi
if [ -z ${SERVER_ADDRESS} ]
then
    echo "The script hasn't been setup properly. Please, fill the server address in the variable SERVER_ADDRESS in the head of the script" >&2
    exit 1
fi
if [ -z "${SERVER_PATH}" ]
then
    echo "The script hasn't been setup properly. Please, fill a path to the JSON file on the server in the variable SERVER_PATH in the head of the script" >&2
    exit 1
fi
if [ ! -z "${IMAGE_NAME}" ] && [ -z "${SERVER_PATH}" ]
then
    echo "The script hasn't been setup properly. Please, fill a path to the image on the server in the variable SERVER_PATH in the head of the script" >&2
    exit 1
fi

# Does the server supports batch mode?
BATCH_MODE=$(check_ssh_type ${USER_NAME} "${SERVER_ADDRESS}")

if [ ${BATCH_MODE} == "false" ]
then
    echo -e "There is a problem with a connection to the server in a batch mode.\nIf you have not setup your server to use a public key for SSH connections, you can do this by using command 'ssh-copy-id'" >&2
fi

if [[ ${INIT_MODE} == "true" ]]
then  
    echo "Initialize your site"
    art
    init
else
    echo "Update your JSON and upload the image ${IMAGE_NAME}"
    update_remote_json
fi

echo "Done!"
