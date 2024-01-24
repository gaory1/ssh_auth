#!/bin/bash

if test $# -lt 3
then
    echo "usage: $0 <host> <user> <passwd>"
    echo "return: 0 - ok; 100 - bad passwd; other - unreachable, timeout etc"
    exit 2
fi

host=$1
user=$2
passwd=$3
key=~/.ssh/id_rsa
pubkey=$key.pub

hostname=$(ssh -G $host | awk '/^hostname / {print $2}')
port=$(ssh -G $host | awk '/^port / {print $2}')

ssh-keygen -f ~/.ssh/known_hosts -R $hostname:$port >/dev/null 2>&1

ssh-keyscan -p $port $hostname >> ~/.ssh/known_hosts

# test first
expect << EOF
set timeout 30

spawn ssh -o PasswordAuthentication=no $user@$host true
expect {
	"(yes/no)?" { exp_send "yes\n" ; exp_continue }
	"*'s password:" { exit 100 }
	"No route to host" { exit 2 }
	"Permission denied" { exit 100 }
	eof { 
	}
}
EOF

if [ $? = 0 ]; then
    if ssh -o PasswordAuthentication=no $user@$host true; then
        exit 0
    fi
fi

if [ ! -r $key ]; then
	ssh-keygen -q -f $key -N '' -t rsa
fi

expect << EOF
set timeout 30

spawn ssh-copy-id -i $pubkey $user@$host 
expect {
	"(yes/no)?" { exp_send "yes\n" ; exp_continue }
	"Permission denied" { exit 100 }
	"*'s password:" { exp_send "$passwd\n" ; exp_continue }
	"No route to host" { exit 2 }
}
EOF

ssh -o PasswordAuthentication=no $user@$host true

