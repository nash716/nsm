#!/bin/sh

# ディレクトリ構造
# ~/.nsm/ ... Node Snapshot Managerのルートディレクトリ
#     ${HASH} ... スナップショット保存時にユーザが居るディレクトリのmd5ハッシュ値
#         ${TIMESTAMP} ... スナップショット保存時のタイムスタンプ
#             packages.zip ... `npm list`で1行目に表示される、"node_modules/"があるディレクトリの、"node_modules/"をzip圧縮したもの
#             comment.txt ... スナップショットに対するコメント
#             list.txt ... `npm list`で表示されるもの
# 英語間違ってたら教えてください
# 関数を1つで済ませたいので、同じような処理を何回も書いています。

nsm () {
	[ $# -lt 1 ] && nsm help && return

	if [ ! `which npm` ]; then
		echo "npm not found."
		return
	fi
	
	if [ ! -f ~/.nsm/nsm.sh ]; then
		echo "Please put nsm.sh to ~/.nsm"
		return
	fi
	
	local NSM_PATH="`dirname ~/.nsm`/.nsm"
	local CUR_PATH=`pwd`
	local CUR_PATH_HASH=`echo "${CUR_PATH}" | md5`
	
	case $1 in
		"create" )
			local i=0
			
			local TIMESTAMP=`date +'%Y-%m-%d_%H-%M-%S'`
			
			if [ -d "${NSM_PATH}/${CUR_PATH_HASH}" ]; then
				local CURLIST_HASH=`npm list | md5`
				
				for line in `ls -1 "${NSM_PATH}/${CUR_PATH_HASH}"`; do
					local SNAPSHOT_HASH=`cat "${NSM_PATH}/${CUR_PATH_HASH}/${line}/list.txt" | md5`
					[ ${CURLIST_HASH} = ${SNAPSHOT_HASH} ] && echo "Packages are same with ${line}." && return
				done
			fi
			
			npm list | while read line; do
				if [ $i -eq 0 ]; then
					local DIR="${line}/node_modules"
					
					[ ! -d ${DIR} ] && echo "No packages." && return
					
					mkdir "${NSM_PATH}/${CUR_PATH_HASH}"
					mkdir "${NSM_PATH}/${CUR_PATH_HASH}/${TIMESTAMP}"
					
					cp -r "${DIR}" "${NSM_PATH}/"
					cd ${NSM_PATH}
					zip -r "${NSM_PATH}/${CUR_PATH_HASH}/${TIMESTAMP}/packages.zip" "node_modules"
					cd ${CUR_PATH}
					rm -rf "${NSM_PATH}/node_modules"
				else
					return
				fi
				i=`expr $i + 1`
			done
			
			[ ! -e ${NSM_PATH}/${CUR_PATH_HASH}/${TIMESTAMP}/packages.zip ] && return
			
			npm list > "${NSM_PATH}/${CUR_PATH_HASH}/${TIMESTAMP}/list.txt"
			
			echo "Comment:"
			read comment
			echo ${comment} > "${NSM_PATH}/${CUR_PATH_HASH}/${TIMESTAMP}/comment.txt"
			
			echo "Snapshot was saved successfully."
		;;
		"list" )
			local n=0
			
			[ ! -d ${NSM_PATH}/${CUR_PATH_HASH} ] && echo "No snapshots related to this directory." && return
			
			ls -1 "${NSM_PATH}/${CUR_PATH_HASH}" | while read line; do
				n=`expr $n + 1`
			
				echo "[$n]"
			
				echo "Created at: ${line}"
				echo "ID: `echo ${line} | md5`"
			
				echo "Packages:"
				[ ! -r ${NSM_PATH}/${CUR_PATH_HASH}/${line}/list.txt ] && echo "No lists.txt in ${line}." && return
				cat ${NSM_PATH}/${CUR_PATH_HASH}/${line}/list.txt
			
				echo "Comment:"
				[ ! -r ${NSM_PATH}/${CUR_PATH_HASH}/${line}/comment.txt ] && echo "No comment.txt in ${line}." && return
				cat ${NSM_PATH}/${CUR_PATH_HASH}/${line}/comment.txt
				
				echo
			done
		;;
		"revert" )
			local i=0
			local timestamp
			
			if [ $# -lt 2 ]; then
				nsm list
			
				[ ! -d ${NSM_PATH}/${CUR_PATH_HASH} ] && return
			
				echo "Input the snapshot id to revert."
				read id
			fi
			
			for line in `ls -1 "${NSM_PATH}/${CUR_PATH_HASH}"`; do
				local HASH=`echo "${line}" | md5`
				if expr "${HASH}" : "^${id}" > /dev/null; then
					i=`expr $i + 1`
					timestamp="${line}"
				fi
			done
			
			[ $i -gt 1 ] && echo "There are too many snapshots which starts with ${id}." && return
			[ $i -eq 0 ] && echo "There are no snapshots which starts with ${id}." && return
			
			local CURLIST_HASH=`npm list | md5`
			local SNAPSHOT_HASH=`cat "${NSM_PATH}/${CUR_PATH_HASH}/${timestamp}/list.txt" | md5`
			
			[ ${CURLIST_HASH} = ${SNAPSHOT_HASH} ] && echo "Snapshot found, but its content was same with now." && return
			
			echo "Create the existing packages' snapshot before reverting?"
			read yn
			[ "${yn}" = "y" ] && nsm create
			
			echo "Snapshot found."
			echo "Revert?"
			read yn
			[ ! "${yn}" = "y" ] && return
			
			echo
			echo "Reverting..."
			unzip "${NSM_PATH}/${CUR_PATH_HASH}/${timestamp}/packages.zip" -d .
			echo "Reverted successfully."
		;;
		"help" )
			echo
			echo "Node Snapshot Manager"
			echo
			echo "Usage:"
			echo "    nsm help          Show this text."
			echo "    nsm create        Create a snapshot."
			echo "    nsm list          Show the snapshot list related to this directory."
			echo "    nsm revert <ID>   Revert to a former snapshot which starts with <ID>."
			echo
		;;
		* )
			nsm help
		;;
	esac
}