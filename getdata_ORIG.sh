#!/bin/bash

# bhupendra.hirani@youview.com
# Shell script to extract 1-minute data from AWS Cloudwatch using the AWS CLI
# Needs to have 5 parameters passed in to run the API calls to get the data and carries out some inline editing post processing on the data
# 05-11-14 Initial version

if [ "$#" != 7 ]
then
  echo "usage: getdata.sh metric-name daysback  namespace statistics dimensions period"
  echo "  metric-name:  CPUUtilization|HTTPCode_ELB_4XX|HTTPCode_Backend_2XX|.."
  echo "  daysback:   number of days worth of data required. Must be between 1 and 14"
  echo "  namespace:    AutoScaling|EC2|ELB|RDS|..."
  echo "  statistics:   average|sum|max"
  echo "  dimensions:     Name=LoadBalancerName,Value=cc4pro01-B2cFeeds-YU7BSCH7OHWR"
  echo "  period:     60|300|900|3600|21600|86400"
  echo "  profile:     ProfileName"
  echo ""
  echo "example: $ ./getdata.sh HTTPCode_ELB_5XX 14 AWS/ELB Sum Name=LoadBalancerName,Value=cc4pro01-B2cFeeds-YU7BSCH7OHWR 60"
  exit 0
fi

daysback="$2"
time="T00:00:00"

#Validate that the daysback is less than 13
if [ "$daysback" -gt 14 ]
then
  daysback=14
  echo "AWS only has 14 days data. Changing daysback value to to $daysback"
elif [ "$daysback" -lt 1 ]
then
  daysback=1
  echo "Changing daysback value to $daysback"
fi

# exit script if filename already exists
filename=$1_`date -d "-$daysback days" +%Y-%m-%d`
if [ -f $filename.csv ];
then
   echo "file named $filename.csv already exists. Please delete/rename the file and retry."
   exit 0
fi

while [ $daysback -gt 0 ]; do
  startdate=`date -d "-$daysback days" +%Y-%m-%d`
  startdatetime=$startdate$time
  let daysback=daysback-1
  enddate=`date -d "-$daysback day" +%Y-%m-%d`
  enddatetime=$enddate$time
  `aws cloudwatch get-metric-statistics --metric-name $1 --start-time $startdatetime --end-time $enddatetime --namespace $3 --statistics $4 --dimensions $5 --period $6 --profile $7 >> $filename.txt`
done
`perl -p -i -e 's/\t/,/g' $filename.txt`
`perl -p -i -e 's/Z,.*$//g' $filename.txt`
`perl -p -i -e 's/^[A-Z]+,//g' $filename.txt`
`perl -p -i -e 's/T/ /g' $filename.txt`

while IFS=, read x1 x2 rest
  do
    echo ${x2},${x1},$rest
  done < $filename.txt > $filename.tmp

`sort -o $filename.csv < $filename.tmp`
`sort -k1 -n $filename.tmp > tmp.txt`
`sed -n "/$1/!p" tmp.txt > $filename.csv`
`cp $filename.csv /YouView/CloudFormation/`
`rm $filename.txt $filename.tmp tmp.txt`

