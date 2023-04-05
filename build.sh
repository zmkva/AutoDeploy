#!/bin/bash

VERSION="0.1.4.02550"

duser="/home"
RUNPATH=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)
INSTALL_CMD=""
REMOVE_CMD=""
PACKAGE=""
LOG="$RUNPATH/run.log"
SU="sudo su"
TARGET_TABLE_PATH="${RUNPATH}/target.txt"

install()
{  
    cat /dev/null > ${RUNPATH}/cache/install
    cat /dev/null > ${RUNPATH}/target_pub.txt

    cat "${TARGET_TABLE_PATH}" | while read user pass isroot ip port type system
    do
        if test "x$user" = "x#" || test "x$user" = "x"; then
            continue
        fi
		
        if test "x$isroot" = "xY"; then
            SWITCH_USER=
            TARGET_DIR="/$user"
        else
            SWITCH_USER=$SU
            TARGET_DIR="$duser/$user"
        fi

        case $system in
            ubuntu)
                PACKAGE="your-packet-${VERSION}.amd64.deb"
                INSTALL_CMD="dpkg -i $TARGET_DIR/$PACKAGE"
                REMOVE_CMD="dpkg -r your packet"
                ;;
            centos)
                PACKAGE="your-packet-${VERSION}.x86_64.rpm"
                INSTALL_CMD="rpm -ivh $TARGET_DIR/$PACKAGE"
                REMOVE_CMD="rpm -e your packet"
                ;;
            *)
                echo "not support this system, ip:$ip"
                continue
        esac
	
        if [ ! -f "$RUNPATH/package/$PACKAGE" ]; then
            echo "packet: $PACKAGE not exist!"
            echo "packet: $PACKAGE not exist!" >> $LOG
            exit
        fi

	expect << EOF > $RUNPATH/cache/install
        spawn scp $RUNPATH/package/$PACKAGE $user@$ip:$TARGET_DIR
        expect {
               "yes/no"   { send \"yes\r\"; exp_continue }
               "password" { send \"$pass\r\"; }
        }

        spawn ssh -t -p $port $user@$ip $SWITCH_USER
        expect {
               "yes/no"   { send "yes\r"; exp_continue }
               "password" { send "$pass\r"; exp_continue }
	       "for"	  { send "$pass\r" }
        }

        expect "*#"
	
	# execute a cmd
	send "$REMOVE_CMD; $INSTALL_CMD; rm -r $TARGET_DIR/$PACKAGE; \r"
        expect eof
EOF
	# operate result wirte to install file
        cat ${RUNPATH}/cache/install >> $LOG

	unset pkey
    done
}


nodestop()
{
    if [ ! -f "${TARGET_TABLE_PATH}" ]; then
        echo "${TARGET_TABLE_PATH} not exist!"
	echo "${TARGET_TABLE_PATH} not exist!" >> $LOG
	exit
    else
        cat "${TARGET_TABLE_PATH}" | while read user pass isroot ip port type system
        do
        if test "x$user" = "x#" || test "x$user" = "x"; then
            continue
        fi
		
        if test "x$isroot" = "xY"; then
            SWITCH_USER=
            TARGET_DIR="/$user"
        else
            SWITCH_USER=$SU
            TARGET_DIR="$duser/$user"
        fi

	expect << EOF >> $LOG
        spawn ssh -t -p $port $user@$ip $SWITCH_USER
        expect {
               "yes/no"   {send "yes\r"; exp_continue}
               "password" {send "$pass\r"; exp_continue}
               "$user:"   {send "$pass\r"}
        }

        expect "*#"

        send "systemctl stop your-app; exit;\r"

        expect eof
EOF

        echo "node $ip stop finish!"
        done
    fi
}
if ! [ -x "$(command -v expect)" ];then
    echo "The system is not install expect"
    os=`cat /proc/version`
    if [[ $os =~ "buntu" && "`arch`" = "x86_64" ]];then
        echo "OS: Ubuntu, About to install the expect, please input passwd"
	# sudo apt install expect
        sudo dpkg -i $RUNPATH/expect/ubuntu/libtcl8.6_8.6.8+dfsg-3_amd64.deb
        sudo dpkg -i $RUNPATH/expect/ubuntu/tcl-expect_5.45.4-1_amd64.deb
        sudo dpkg -i $RUNPATH/expect/ubuntu/expect_5.45.4-1_amd64.deb
        sudo dpkg -i $RUNPATH/expect/ubuntu/tcl8.6_8.6.8+dfsg-3_amd64.deb
	clear
	echo "expect install finish!"
    elif [[ $os =~ "entos" && "`arch`" = "x86_64" ]]; then
	echo "OS: CentOS, About to install the expect, please input passwd"
	# yum -y install expect
	sudo rpm -ivh --force $RUNPATH/expect/centos/tcl-8.5.13-8.el7.x86_64.rpm
	sudo rpm -ivh --force $RUNPATH/expect/centos/expect-5.45-14.el7_1.x86_64.rpm
	clear
	echo "expect install finish!"
    else
        echo "please install expect!"
        exit
    fi
fi

echo "target file path:  $TARGET_TABLE_PATH"


stime=`date +%Y%m%d-%H:%M:%S`
stime_s=`date +%s`
echo "#############################################################-[Start Date:$stime] CMD:$1" >> $LOG

case $1 in
    install)
	install
	;;
    update)
	update
	;;
    restart)
	noderestart
	;;
    stop)
	nodestop
	;;
    *)
	Usage
	;;
esac

etime=`date +%Y%m%d-%H:%M:%S`
etime_s=`date +%s`
sumtime=$[ $etime_s - $stime_s ]
echo "########################### End #############################-[End Date:$etime] CMD:$1, 用时：$sumtime" >> $LOG
