#!/bin/bash 
# 
# Download country IP blocks to ban
# 
# Specify countries (2-letter codes) in 'blocks'
#
# Requires
# * curl
# * ipset

prog=$(basename $0)
blocks="cn ru ar ua"
myfifo=$(mktemp)

trap "/bin/rm -f $myfifo" EXIT

if [ -x "`which curl`" -a -x "`which ipset`" ]; then
   for block in $blocks ; do 
   SETNAME="evil_ips_${block}"
       curl -s "http://www.ipdeny.com/ipblocks/data/aggregated/${block}-aggregated.zone" 2>/dev/null > $myfifo 
   done 

   evil_ips=$(wc -l $myfifo)
   if [ $evil_ips -gt 0 ]
   then # only proceed if new IPs are obtained
      logger -t $prog "Adding IPs to be blocked."
      ipset list $SETNAME &>/dev/null # check if the IP set exists

      if [ $? -ne 0 ]
      then
         ipset create $SETNAME nethash # create new IP set
         iptables -I INPUT 2 -m set --match-set $SETNAME src -j DROP
      else
         ipset flush $SETNAME # clear existing IP set
      fi

      # populate the new or existing empty IP set
      while read ip_range 
      do
          ipset add $SETNAME $ip_range
      done < $myfifo
   else
      logger -t $prog "No IPs to add."
   fi
else
   logger -t $prog "Needed command not found."
fi
