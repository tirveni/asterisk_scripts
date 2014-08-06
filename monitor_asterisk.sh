#!/bin/sh
#
#    Copyright (C) 2014, Tirveni Yadav <tirveni@udyansh.org>
#
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Create CSV File of load ,memory,network usage and Asterisk Calls
#
# Required: asterisk, other things are from the standard linux utilities.
# This script has been run on Debian Wheezy, with Allo 2nd Gen 4 PRI Card
# pci:0000:05:00.0     allo4xxp+    1d21:1240 Allocard 2aCP4e (2nd Gen)
# Also tested on Redfone's bridge.
#
# Usage: ./monitor_asterisk.sh > /tmp/calls.log
#

while : ;
        
        do

                                time=`date +%F::%T`;
load=`w |grep average |awk -F 'average:' '{print $2}' |awk -F ','  '{print $1}' `;

#call Data
calls=`asterisk -rnx 'core show calls' `;
active_calls=`echo $calls | grep active  | awk -F ' ' '{print $1}' `;
total_calls=`echo $calls | grep processed  | awk -F ' ' '{print $1}' `;

#PRI data
prism=`asterisk -rnx 'pri show spans' |grep 'Up, Active' |wc -l ` ;


memory=`free -m |grep 'buffers/cache' |awk -F : '{print $2}' | awk -F ' ' '{print $1}' `;
traffic=`/sbin/ifconfig  eth0 |grep 'RX bytes'`
        echo $time,$load,$memory,$prism,$active_calls,$total_calls,$traffic ;

        sleep 10;


done;


