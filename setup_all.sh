#!/bin/bash

if [ $# -ne 2 ]; then
	echo "Usage: $0 ip_addr_self ip_addr_remote"
	echo "example: $0 10.0.0.1 10.0.0.2"
	exit
fi

if ! command -v slattach >/dev/null 2>&1 ; then
	echo "this program needs slattach (i.e. net-tools)."
	exit
fi

if ! command -v minimodem >/dev/null 2>&1 ; then
	echo "this program needs minimodem."
	exit
fi

baudrate=4800
ip_self=$1
ip_remote=$2

sudo modprobe slip
rm tmp 2> /dev/null
sudo slattach -v /dev/ptmx -s $baudrate > tmp &
slip_pid=$!
while ! [ -s tmp ]; do	#wait until tmp filled
    sleep 1
done
slip_dev=$(cat tmp | grep -oEi '\/dev\/pts\/[0-9]+')

echo "Slip dev is $slip_dev"
GROUP=$(stat -c '%G' $slip_dev)
if ! groups | grep -q $GROUP; then
  echo "Make sure you are member of the group $GROUP!"
  echo "E.g. sudo usermod -a -G $GROUP $(whoami)"
  echo "(re-login needed)"
  sudo kill $slip_pid
  exit
fi

sudo chmod g+rw $slip_dev

echo "starting Modems"
minimodem -t $baudrate < $slip_dev &
tx_pid=$!
minimodem -c 3 -r $baudrate > $slip_dev &
rx_pid=$!

sudo ip a a $ip_self peer ${ip_remote}/32 dev sl0
sudo ip link set up sl0

echo "Should be up and running. Press escape key to stop."
while read -r -n1 key
do
	if [[ $key == $'\e' ]];	then
		break;
	fi
done

echo "Stopping slip $slip_pid"
sudo kill $slip_pid
echo "Stopping tx modem $tx_pid"
kill $tx_pid
echo "Stopping rx modem $rx_pid"
kill $rx_pid
