#!/bin/bash
# the script takes one directory as an argument
# explantion of exactly what the script does please see at the end

input=$1
ARGS=1         # Script requires 1 arguments.
#E_BADARGS=85   # Wrong number of arguments passed to script.
ERR_CODE=0     #defaulting to success return to the OS

echo -e "\n Supplied directory is:  $input \n";

  if [ $# -ne "$ARGS" ];
    then
      echo -e "\n USAGE: `basename $0` the script requires one argument - directory."
      echo -e "\n Please supply a directory containing pcap file that has a corresponding rule."
      exit 1;
  fi
#above check if valid number of arguments are passed to the script - should be 1 (directory location)

 if [ ! -d "$input" ]; then
     # Control will enter here if DIRECTORY doesn't exist
     echo "The supplied directory does not exist or the name is wrong !"
     exit 1;
 fi


#below we check if the configurational file exists and load the $SURICATA and $CONFIG values from there
if [ -f regression_config ];then
	. regression_config
else
  echo " \"regression_config \" not found !"
  exit 1;
fi


SUCCESS="0"
FAILURE="0"
SKIPPED="0"

for pcap_file in  $( dir $input -1 |grep .pcap$ ); do
    pcap_name="$(echo "$pcap_file" |awk -F "." ' { print $1 } ')"

    TMP_LOG=`mktemp -d /tmp/suriqa.XXXXXXXX` #creating a tmp log name
    `mkdir $TMP_LOG/files` # making a "files" directory, just in case if magic files are enabled in yaml, so that we do not stop suri from execution.

    rule_id=${pcap_name}

    if [ ! -f "$input/$rule_id.rules" ];
    then
        #echo "File \"$rule_id.rules\" corresponding to $pcap_file not found! "
        let ERR_CODE=$ERR_CODE+1;
        #exit $ERR_CODE ;

        let SKIPPED=$SKIPPED+1;
        continue
    fi
    # the above if statement checks for a corresponding rules file to the pcap supplied

    MYCONFIG="${input}/${rule_id}.yaml"
    if [ ! -f ${MYCONFIG} ]; then
        MYCONFIG=${CONFIG}
    fi

    CMD="$SURICATA -c ${MYCONFIG} --runmode=single -S $input/$rule_id.rules -r $input/$pcap_file -l $TMP_LOG/"
    $CMD &> "$TMP_LOG/output"
    #run Suricata

    number_of_alerts="$(cat $TMP_LOG/fast.log |grep \:$rule_id\: |wc -l)"
    #count the number of alerts with that particular rules files SID

    if [ "$number_of_alerts" -eq "0" ]; then
        echo $CMD > $TMP_LOG/command.log
        echo $rule_id ": FAILED, see $TMP_LOG, rulefile: $rule_id.rules, pcap file $pcap_file, Expected alerts, got $number_of_alerts."
        let FAILURE=$FAILURE+1 ;
    else
        echo $rule_id ": OK"
        let SUCCESS=$SUCCESS+1;
        ` rm -r $TMP_LOG `
        #above removing the temp log directory ONLY if the test has SUCCEEDED
    fi
done

echo; echo "SUMMARY:"
echo "-----------"
echo "SUCCESS: " $SUCCESS;
echo "FAILURE: " $FAILURE;
echo "SKIPPED: " $SKIPPED;

 [[ $FAILURE -eq "0" ]] && exit 0 || exit 1
#the upper line - if failures are 0 it returns success, otherwise error to the  OS




# THIS IS WHAT THE SCRIPT DOES !!!!!!!!!!!!
# If you have time, can you write me a regression testing script? I'd like
# the script to be simple.
#
# It takes in 2 arguments: a pcap and a rule file. The name of the pcap
# will be in this format:
#
# 2002031-001-sandnet-public-tp-01.pcap
#
# meaning:
#
# 2002031 - rule id (sid)
# 001 - pcap id (for having multiple pcaps for a sid)
# sandnet - pcap source
# public - whether or not the pcap can be shared
# tp - true positive (fp for false positive)
# 01 - number of alerts we should see for the sid
#
# The rule file should be in the this format:
#
# 2002031.rules
#
# The goal is simple. The script should run the pcap against the rules and
# check if the number of alerts is correct. If it isn't, display an
# error/warning.