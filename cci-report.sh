#!/bin/bash

# Program: cci-report.sh
#    Date: 02-Dec-2025
# Version: 5.9

# Script uses CMD-DEV to communicate with storage systems, providing faster results.

# Global Constants

filename=cci-report.sh                      # Script name showin in messages.
horcm_files=/etc/horcm?.conf                # HORCM config path.
logout=false                                # Logout option on md-hcs and st-hcs.
array_qty=2                                 # Number of arrays.

# Array name and serial number, with HORCM instance index.

array[10]="Primary VSP G1000"
serial[10]="123456"

array[20]="Secondary VSP G1000"
serial[20]="234567"

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

horcm_login ()
{
    # horcmstart.sh $instance > /dev/null

    # HORCMINST=$instance
    # export HORCMINST

    return                                  # Skip login, since this is not necessary.

    # Different password used on the VSP G1000 and HUS-VM arrays.

    if [[ "${array[$instance]}" == *HUSVM* ]]; then
        raidcom -login maintenance raid-mainte -I$instance > /dev/null
    else
        raidcom -login maintenance raid-maintenance -I$instance > /dev/null
    fi
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

horcm_logout ()
{
    if [ "$logout" == "true" ]; then  	 			# Avoid disconnecting other sessions.
        raidcom -logout -I$instance > /dev/null
        # horcmshutdown.sh $instance > /dev/null
    fi

    # HORCMINST=
    # export HORCMINST
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

list_arrays ()
{
    echo

    for instance in "${!array[@]}"; do
        printf "%6s - " ${serial[$instance]}
        echo ${array[$instance]}
    done 

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

report_header ()
{
    echo
    printf "%s - " ${serial[$instance]}
    echo ${array[$instance]}
    echo
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_validate ()
{
    for instance in "${!array[@]}"; do					# Validate storage system serial.
        if [ "$1" == "${serial[$instance]}" ]; then
            return 
        fi
    done

    param_error "non-existent array"					# Invalid array serial provided.
    exit 1
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_port ()
{
    report_header
    horcm_login

    raidcom get port -I$instance | awk -v key="$filter1" -v key2="$filter2" '
        !/PORT/ { if ( $3 == "TAR" )
                      attrib = "target port"

                  else if ( $3 == "MCU" )
                      attrib = "MCU initiator port"

                  else if ( $3 == "RCU" )
                      attrib = "RCU target port"

                  else if ( $3 == "ELUN" )
                      attrib = "ELUN external port";

                  w1 = substr($11,1,2);
                  w2 = substr($11,3,2);
                  w3 = substr($11,5,2);
                  w4 = substr($11,7,2);
                  w5 = substr($11,9,2);
                  w6 = substr($11,11,2);
                  w7 = substr($11,13,2);
                  w8 = substr($11,15,2);

                  wwn = sprintf("%s:%s:%s:%s:%s:%s:%s:%s", w1, w2, w3, w4, w5, w6, w7, w8);

                  out = sprintf("%s  %s  %s", $1, wwn, attrib);
                  
                  if (!match(tolower(out), tolower(key)) || !match(tolower(out), tolower(key2)) ) 
                      next;
                  
                  if ( substr($1,1,3) != last_cntlr ) {
                      if ( count > 0 )
                          printf("\n");

                      printf("Port   Array Port WWN           Port Attribute\n");
                      printf("-----  -----------------------  ------------------\n");
                      last_cntlr = substr($1,1,3); }
                      
                  print out;
                  count++; }'

    horcm_logout

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_hostgrp ()
{
    report_header
    horcm_login

    # Check if filters were provided to narrow down the results.

    filter="$filter1$filter2"

    if [ ${#filter} -eq 0 ]; then
        ports=`raidcom get port -I$instance | awk '/TAR/ { print $1 }'`

    else
        # Use the -allports option to quickly extract hostgroup names to apply filter.

        ports=`raidcom get host_grp -allports -I$instance | awk -v key1="$filter1" -v key2="$filter2" '

            /PORT/ { next }
            
            /G00/  { next }

                   { if (!match(tolower($0), tolower(key1)) || !match(tolower($0), tolower(key2)) )
                         next;
                     else
                         printf("%s ", $1) }'`
    fi


    # Collect HostGroup data...
    # PORT   GID  GROUP_NAME                       Serial# HMD          HMO_BITs

    for i in $ports; do
        raidcom get host_grp -port $i -I$instance | awk -v key1="$filter1" -v key2="$filter2" '

            /PORT/ { next }
            
            /G00/  { next }

                   { if (!match(tolower($0), tolower(key1)) || !match(tolower($0), tolower(key2)) )
                         next;
                     else
                         print; }'

    done | sort -u -k1,1 -k2,2n > /var/tmp/hostgrp.dat


    # Collect HostGroup data...
    # PORT   GID GROUP_NAME                    HWWN  Serial# NICK_NAME

    ports=`cat /var/tmp/hostgrp.dat | awk '{ print $1"-"$2 }'`

    for i in $ports; do
        raidcom get hba_wwn -port $i -I$instance
    done | sed '/PORT/d' > /var/tmp/hostmode.dat 


    # Generate report.

    { cat /var/tmp/hostmode.dat;
      echo;
      cat /var/tmp/hostgrp.dat; } | awk '
      
        BEGIN { getline;

                # Build arrays for the hostgrp, host, and hba wwn.

                while (length($0) > 0) {
                    port = sprintf("%s-%s", $1, $2);
                    group[port] = $3;

                    wwn = $4;
                    w01 = substr(wwn,1,2);
                    w02 = substr(wwn,3,2);
                    w03 = substr(wwn,5,2);
                    w04 = substr(wwn,7,2);
                    w05 = substr(wwn,9,2);
                    w06 = substr(wwn,11,2);
                    w07 = substr(wwn,13,2);
                    w08 = substr(wwn,15,2);

                    if (lastPort == port)
                        ndx++
                    else
                        ndx = 0;

                    portndx = sprintf("%s-%s", port, ndx);
                    lastPort = port;
                    
                    hba[portndx] = sprintf("%s:%s:%s:%s:%s:%s:%s:%s", w01, w02, w03, w04, w05, w06, w07, w08);
                    host[portndx] = $6;

                    getline; }

                line = 1; }
                 
             {  # Collect host mode and bits for each HostGrp port and print.

                port = sprintf("%s-%s", $1, $2);
                group[port] = $3;
                mode[port] = $5;

                if (NF == 6)
                    bits[port] = $6; 

                if (NF == 7)
                    bits[port] = sprintf("%s,%s", $6, $7);

                if (NF == 8)
                    bits[port] = sprintf("%s,%s,%s", $6, $7, $8);

                if (NF == 9)
                    bits[port] = sprintf("%s,%s,%s,%s", $6, $7, $8, $9);


                # Generate heading break for each new port.

                if (last != $1) {
                    # Print headings for the report.

                    if (line > 1)
                        printf("\n");

                    printf "Port       Host Group                    Host Name                  ";
                    printf "HBA WWN                  Host Mode   Bits\n";
                    printf "---------  ----------------------------  -------------------------  ";
                    printf "-----------------------  ----------  ----\n"; }

                ndx = 0;
                while (1) {
                    portndx = sprintf("%s-%s", port, ndx++);
                    if (length(hba[portndx]) == 0)
                        break;

                    printf("%-9s  %-28s  %-25s  %-23s  %-10s  %s\n", 
                           port, group[port], host[portndx], hba[portndx], mode[port], bits[port]); } 
                    
                last = $1;
                line++; }'

    echo

    horcm_logout

    # Cleanup temporary files used to generate report.

#    rm /var/tmp/hostgrp.dat
#    rm /var/tmp/hostmode.dat

    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_unalloc ()
{
    report_header
    horcm_login                                                         # Login to array for CCI.

    raidcom get ldev -ldev_list unmapped -I$instance 2> /dev/null | awk -v key="$filter1" -v key2="$filter2" '

        BEGIN { printf("Vol    Label                                           ");
                printf("Size\n");   

                printf("-----  ----------------------------------------  ");
                printf("----------\n"); } 

        # Process LDEV data, adding up the storage for each host.

        /LDEV / { split($0,a," : ");
                  volume = sprintf("%02X:%02X", int(a[2]/256), a[2] % 256); }

        /VOL_Capacity/ { split($0,a,":");                               # Host volume capacity.
                         blocks = a[2];
                         size = blocks / 2; }                           # Covert to KB.

        /LDEV_NAMING/ { split($0,a," : ");
                        label = a[2];

                        if (label == "")
                            label = "-";

                        out = sprintf("%5s  %-40s %8.0f GB", volume, label, size / 1024 / 1024); 
                        if ((volume != "00:01") && match(tolower(out), tolower(key)) && match(tolower(out), tolower(key2)) )
                            print out; }

        END { printf("-----  ----------------------------------------  ");
              printf("----------\n"); }' | \

        sed ':a;s/ \b\([0-9]\+\)\([0-9]\{3\}\)\b/\1,\2/;ta'         # Add commas for thousands formatting.


    horcm_logout                                                        # Logout out of CCI session.

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_used ()
{
    report_header
    horcm_login                                                         # Login to array for CCI.

        raidcom get ldev -ldev_list defined -I$instance 2> /dev/null | awk '
            BEGIN { digit="0123456789ABCDEF0"; prev=""; free="--:--  "; i = 17; }

	    /^LDEV / { ldev = sprintf("%02X:%02X", int($3/256), $3 % 256); 
                       dev = substr(ldev,1,4);                         # XX:Xn
    
                       if (dev != prev) {    # Is this in a different group of disks?

                        # Fill in missing LDEVs with placeholders to make report easier to read.

                        while (i < 17) {
                            printf(free);
                            i++; }

                        if (prev != "")
                            print "";

                        i = 1; }

                    # Fill in unused LDEVs with placeholders to help keep disks aligned.

                    while (substr(digit,i,1) != substr(ldev,5,1)) {
                        printf(free);
                        i++; }

                    printf("%5s  ", ldev);
                    prev = dev; i++; }

           END { while (substr(digit,i,1) != substr($1,5,1) && i < 17) {
                     printf(free);
                     i++; }

                printf("\n\n") }'
 
    exit;
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_ldev ()
{
    report_header
    horcm_login								# Login to array for CCI.

    echo | awk '
        BEGIN { printf("Vol    Label                                           ");
                printf("Size  LUN   Dec  Port\n"); 

                printf("-----  ----------------------------------------  ");
                printf("----------  ----  ---  -----------------------------------\n"); }'

    raidcom get ldev -ldev_list defined -I$instance 2> /dev/null | awk -v key="$filter1" -v key2="$filter2" ' 

        # Process LDEV data, adding up the storage for each host.

        /LDEV / { split($0,a," : ");                    # Logical Device ID.
                  volume = sprintf("%02X:%02X", int(a[2]/256), a[2] % 256); }

        /VOL_Capacity/ { split($0,a,":");               # Host volume capacity.
                         blocks = a[2];
                         size = blocks / 2; }           # Covert to KB.

        /PORTs/ { n = split($0,a," : ");                # HostGroup ports.

                  # This assumes that the same LUN was mapped to every port.

                  for (i=2; i <= n; i++) {              # Determine ports used.
                      split(a[i],b," ");
                      lun = b[2];
                      
                      if (i == 2)                       # Show HostGroup index.
                          paths = b[1];
                      else
                          paths = paths ", " b[1]; } }
                          
        /VOL_ATTR/ { if (index($0,"POOL")) {            # Volume attributes.
                         attrib = "POOL";
                         next; }

                     split($0,a," : ");
                     attrib = a[2]; }

        /LDEV_NAMING/ { split($0,a," : ");              # Volume name.
                        label = a[2];

                        if (label == "")
                            label = "-";

                        capacity = size / 1024 / 1024;

                        out = sprintf("%5s  %-40s %8.0f GB  0x%02X  %03d  %s", volume, label, capacity, lun, lun, paths);

                        if (match(tolower(out), tolower(key)) && match(tolower(out), tolower(key2)) && (attrib != "POOL") ) {
                            print out; 
                            total += capacity; }

                        lun = 0;
                        paths = ""; }
                        
        END           { printf("%10.0f\n", total); }' | sort -k7,7 -k6,6 | awk '

        NR == 1 { total = $0; }

        NR > 1  { print; }

        END { printf("-----  ----------------------------------------  ");
              printf("----------  ----  ---  -----------------------------------\n");
              printf("Total                                         ");
              printf("%10.0f GB \n", total); }' | \

        sed ':a;s/ \b\([0-9]\+\)\([0-9]\{3\}\)\b/\1,\2/;ta'         # Add commas for thousands formatting.

    horcm_logout							# Logout out of CCI session.

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_tier ()
{
    report_header
    horcm_login

    echo | awk '

        BEGIN { printf("Vol    Label                               Size  Used  ");
                printf("Relocation  Policy       Tier1       Tier2       Tier3  Level  Alloc\n"); 

                printf("-----  ----------------------------  ----------  ----  ");
                printf("----------  ------  ----------  ----------  ----------  -----  -----\n"); }'

    raidcom get ldev -ldev_list mapped -I$instance 2> /dev/null | awk -v key1="$filter1" -v key2="$filter2" ' 

        # Process LDEV data, extracting up the storage for each host.

        /LDEV /            { split($0,a," : ");
                             policy = "Disable";                # Reset policy for non-tiered volumes.
                             tier=0;                            # Reset tier flag for arrays without tiers.
                             volume = sprintf("%02X:%02X", int(a[2]/256), a[2] % 256); }

        /VOL_Capacity/     { split($0,a,":");                   # Host volume capacity.
                             blocks = a[2];
                             size = blocks / 2;                 # Covert to KB.
                             capacity = size / 1024 / 1024; }

        /LDEV_NAMING/      { split($0,a," : ");                 # LDEV volume name.
                             label = a[2]; 

                             if (label == "")
                                 label = "-"; }

        /Used_Block/       { split($0,a," : ");                 # Blocks Used.
                             blocks = a[2];
                             used = blocks / 2 / 1024 / 1024; }           # Convert to GB.

        /TIER_Relocation/  { split($0,a,":");                   # Tier relocation.
                             tier = 1;                          # Tier flag showing array uses tiers.
                             relocation = a[2]; }

        /TIER_level/       { split($0,a,":");                   # Tier policy.
                             policy = a[2]; }

        /TIER#1/           { split($0,a,":");                   # Tier 1 capacity.
                             mb = a[2];
                             tier1 = mb / 1024; }

        /TIER#2/           { split($0,a,":");                   # Tier 2 capacity.
                             mb = a[2];
                             tier2 = mb / 1024; }

        /TIER#3/           { split($0,a,":");                   # Tier 3 capacity.
                             mb = a[2];
                             tier3 = mb / 1024; }

        /TIER_Alloc_level/ { split($0,a," : ");                 # Allocation Level.
                             alloc_level = a[2]; }

        /FLA/              { split($0,a," : ");                 # Full Allocation.
                             full_alloc = a[2];

                             if (full_alloc == "Disable")
                                 alloc = "Thin";
                             else
                                 alloc = "Full";

                             # Used tier storage relative to capacity.

                             if (int(capacity + 0.5) == 0)
                                 used_pct = 0;
                             else
                                 if (tier == 1)
                                     used_pct = (int(tier1 + 0.5) + int(tier2 + 0.5) + int(tier3 + 0.5)) / int(capacity + 0.5) * 100;
                                 else
                                     used_pct = (int(used + 0.5)) / int(capacity + 0.5) * 100;

                             # Make sure used never exceeds 100%.

                             if (used_pct > 100)
                                 used_pct = 100;

                             out = sprintf("%s %s %f %f %d %s %s %f %f %f %s %s %d",
                                           volume, label, capacity, used, used_pct, 
                                           relocation, policy, tier1, tier2, tier3, alloc_level, alloc, tier); 

                             if (match(tolower(out), tolower(key1)) && match(tolower(out), tolower(key2)) ) 
                                 print volume, label, capacity, used, used_pct, relocation, policy, tier1, tier2, tier3, alloc_level, alloc, tier;

                           # Use sed to temporarily move the SI/TC suffix to the left of the index for sorting, then move back.

                           }' | sed 's/\(_*.[0-9]\)_\(si\|tc\)/_\2\1/;' \
                              | sort -k2,2V \
                              | sed 's/_\(si\|tc\)\(_*.[0-9]\)/\2_\1/;' | awk '

        /:/                { volume = $1; 
                             label = $2;
                             capacity = $3;
                             used = $4
                             used_pct = $5;
                             relocation = $6;
                             policy = $7;
                             tier1 = $8;
                             tier2 = $9;
                             tier3 = $10;
                             alloc_level = $11;
                             alloc = $12;
                             tier = $13;

                             out = sprintf("%5s  %-28s %8.0f GB  %3d%%  %-10s  %-6s %8.0f GB %8.0f GB %8.0f GB    %-3s  %s",
                                           volume, label, capacity, used_pct, relocation, policy, tier1, tier2, tier3, alloc_level, alloc); 
                             print out;

                             total_cap += capacity;
                             total_used += used;
                             total_tier1 += tier1;
                             total_tier2 += tier2;
                             total_tier3 += tier3;
                             }

        END { printf("-----  ----------------------------  ----------  ----  ");
              printf("----------  ------  ----------  ----------  ----------  -----  -----\n"); 

              # Prevent division by zero if no records were found.

              if (total_cap == 0)
                  exit;

              if (tier == 1)
                  total_used_pct = (total_tier1 + total_tier2 + total_tier3) / total_cap * 100;
              else
                  total_used_pct = total_used / total_cap * 100;

              out = sprintf("%5s %-28s %9.0f GB  %3d%%  %-10s  %-6s %8.0f GB %8.0f GB %8.0f GB   %s",
                             "Total", " ", total_cap, total_used_pct, " ", " ", total_tier1, total_tier2, total_tier3, " "); 
              print out; }' | \

        sed ':a;s/ \b\([0-9]\+\)\([0-9]\{3\}\)\b/\1,\2/;ta'     # Add commas for thousands formatting.

    horcm_logout                                                # Logout out of CCI session.

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_total ()
{
    report_header
    horcm_login								# Login to array for CCI.

    { raidcom get host_grp -allports -I$instance | sed '/G00/d;1d';
      echo;
      raidcom get ldev -ldev_list defined -I$instance; } | awk -v key="$filter1" -v key2="$filter2" ' 

        BEGIN          { sum = 0; 

                         getline;

                         # Build array of all hosts by port, since the hostname from
                         # raidcom get ldev is truncated.

                         while ( length($0) > 0 ) {
                             port = sprintf("%s-%s", $1, $2);
                             host = $3; 
                             hosts[port] = host;

                             getline; }} 

        /LDEV /        { split($0,a," : ");
                         volume = sprintf("%02X:%02X", int(a[2]/256), a[2] % 256); 
                         attrib = ""; }                 # Reset volume attributes.

        /VOL_Capacity/ { split($0,a,":");               # Host volume capacity.
                         blocks = a[2];
                         size = blocks / 2; }          	# Convert to KB.

        /NUM_PORT/     { split($0,a," : ");				# Ports LDev is mapped to.
                         ports = a[2]; }                # Mapped to a host when > 0.

        /PORTs/        { n = split($0,a," : ");         # Identify the hostname.
                         split(a[2],b," ");
                                                   
                         port = b[1];
                         host = hosts[port]; 

                         if (length(host) == 0)         # Account for Commvault Intellisnap disks.
                             host = "Commvault_Intellisnap"; }
                                                                   
        /VOL_ATTR/     { if (index($0,"POOL")) {        # Volume attributes.
                             attrib = "POOL"
                             total += size; } 

                         if (index($0,"ELUN"))          # Add ELUNs volumes to raw capacity.
                             raw += size;
                       }

        /RAID_TYPE/    { split($0,a," : ");				# RAID Type (nD+yP)
                         raid = a[2]; }

        /RAID_GROUP/   { split($0,a," : ");				# Parity Group or PG.
                         pg = a[2]; 

                         split(raid,a,"+");				# Extract RAID info.
                         data[pg] = a[1];				# Number of data disks.
                         parity[pg] = a[2]; }			# Number of parity disks.

        /DRIVE_TYPE/   { split($0,a," : ");				# Drive Type or Model.
                         model[pg] = a[2]; }

        /DRIVE_Capa/   { split($0,a," : ");				# Physical Drive Capacity.
                         blocks = a[2];
                         capacity[pg] = blocks / 2; }   # Convert to KB.

        /LDEV_NAMING/  { split($0,a," : ");				# LDEV alias name.
                         name = a[2];

                         if (name == "")
                             name = "-"; }

        /Used_Block/   { split($0,a," : ");				# Blocks Used.
                         blocks = a[2];
                         used = blocks / 2 / 1024 / 1024; }           # Convert to GB.

        /TIER_Reloc/    { tier = 1; }                   # Tier enabled array.

        /TIER#1/        { split($0,a,":");              # Tier 1 capacity.
                         mb = a[2];
                         tier1 = mb / 1024; }

        /TIER#2/        { split($0,a,":");              # Tier 2 capacity.
                         mb = a[2];
                         tier2 = mb / 1024; }

        /TIER#3/        { split($0,a,":");              # Tier 3 capacity.
                         mb = a[2];
                         tier3 = mb / 1024; }

        /ALUA/         { # Since this is the last fieled selected from the record, begin processing data.
        
                         if (attrib == "POOL")          # Skip volumes used to create the Pool.
                             next;

                         if (tier == 1)
                             used = tier1 + tier2 + tier3;          # Add up the tier usage.

                         totals[host] += size / 1024 / 1024;        # Record all host totals in GB.
                         all_used[host] += used;                    # Record all host used in GB.

                         all_tier1[host] += tier1;
                         all_tier2[host] += tier2;
                         all_tier3[host] += tier3; }

        END            { alloc = 0;
                         used = 0;
      
                         # Add up the total and used storage for all of the hosts.

                         for (host in totals) {
                             out = sprintf("%-30s    %9d GB  %9d GB  %9d GB  %9d GB  %9d GB", 
                                           host, totals[host], all_used[host], 
                                           all_tier1[host], all_tier2[host], all_tier3[host]);

                             if (match(tolower(out), tolower(key1)) && match(tolower(out), tolower(key2)) ) {
                                 print out;
                                 key_alloc += totals[host]; 
                                 key_used += all_used[host]; 
                                 tier1 += all_tier1[host];
                                 tier2 += all_tier2[host];
                                 tier3 += all_tier3[host]; }

                             alloc += totals[host]; }

                         # Add up all the disk raw storage in the PGs.

                         for (pg in data) 
                             raw += (data[pg] + parity[pg]) * capacity[pg];
                            
                         total = total / 1024 / 1024 + 10.24;
                         free = total - alloc;
                         raw = raw / 1024 / 1024;

                         if (key_alloc > 0) {
                             alloc = key_alloc;
                             used = key_used; }

                         printf("%d %d %d %d %d %d %d %d %d\n", key_alloc, used, tier1, tier2, tier3, 
                                 total, alloc, free, raw); }' | sort | awk '

        # Extra code to automatically place the total at the end of the list after sorting. The
        # sort is necessary to group similar host volumes together since over time they will be 
        # out of sequence as new volumes are added.

        NR == 1        { key_alloc = $1;
                         used = $2;
                         tier1 = $3;
                         tier2 = $4;
                         tier3 = $5;

                         total = $6;
                         alloc = $7;
                         free = $8;
                         raw = $9;

                         printf("Host                                 Allocated          Used         Tier1         Tier2         Tier3\n");
                         printf("--------------------------------  ------------  ------------  ------------  ------------  ------------\n") }

        NR > 1         { print } 

        END            { printf("--------------------------------  ------------  ------------  ------------  ------------  ------------\n");
                         printf("Host Total                        %9.0f GB  %9.0f GB  %9.0f GB  %9.0f GB  %9.0f GB\n\n",
                                 key_alloc, used, tier1, tier2, tier3);

                         printf("Total Capacity                   ");
                         printf("%10.0f GB -> %8.2f TB\n", total, int(total/10.24)/100); 
                         printf("Total Allocated                  ");
                         printf("%10.0f GB -> %8.2f TB\n", alloc, int(alloc/10.24)/100); 
                         printf("Free Capacity                    ");
                         printf("%10.0f GB -> %8.2f TB\n", free, int(free/10.24)/100); 
                         printf("Raw Capacity                     ");
                         printf("%10.0f GB -> %8.2f TB\n", raw, int(raw/10.24)/100); }' | \

        sed ':a;s/ \b\([0-9]\+\)\([0-9]\{3\}\)\b/\1,\2/;ta'         # Add commas for thousands formatting.

    horcm_logout							# Logout out of CCI session.

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_pool ()
{
    report_header
    horcm_login								# Login to array for CCI.

    { raidcom get pool -I$instance;
      echo;
      raidcom get pool -key opt -I$instance;
      echo; } | awk -v key="$filter1" -v key2="$filter2" ' 

          BEGIN { # Collect the Available, Capacity and Subscribed Percentage for every Pool.

                  getline;  # discard the heading.

                  while ( length($0) > 0 ) {
                      id = $1 + 0;

                      if ($2 == "POLN")
                          status[id] = "Normal";
                      else if ($2 == "POLF")
                          status[id] = "Full";
                      else if ($2 == "POLS")
                          status[id] = "Suspend";
                      else if ($2 == "POLE")
                          status[id] = "Failure";

                      usage[id] = $3;
                      avail = $5 / 1024 / 1024;
                      total[id] = $6 / 1024 / 1024;
                      used[id] = total[id] - avail;
                      threshold[id] = $10;

                      limit[id] = avail - (total[id] * 0.2);

                      getline; }
                      
                  # Get the pool names and print the report.

                  printf("Pool  Name          Total Capacity  Used Capacity  ");
                  printf("Used  Threshold  Status   Threshold Limit\n");
                  printf("----  ------------  --------------  -------------  ");
                  printf("----  ---------  -------  ---------------\n");

                  getline;  # discard the heading.

                  while ( length($0) > 0 ) {
                      id = $1 + 0;

                      printf("%-4s  %-12s  %11.0f TB  %10.0f TB  ", id, $4, total[id], used[id]);
                      printf("%3.0f%%    %3.0f%%     %-7s  %12.0f TB\n", usage[id], threshold[id], status[id], limit[id]);

                      getline; getline; } 
                }' | \

          sed ':a;s/ \b\([0-9]\+\)\([0-9]\{3\}\)\b/\1,\2/;ta'         # Add commas for thousands formatting.

    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

array_logins ()
{
    report_header
    horcm_login								# Login to array for CCI.

    # Check if filters were provided to narrow down the results.

    filter="$filter1$filter2"

    if [ ${#filter} -eq 0 ]; then
        ports=`raidcom get port -I$instance | awk '/CL/ { print $1 }' | uniq`

    else
        ports=`raidcom get port -I$instance | awk -v key1="$filter1" -v key2="$filter2" '

              /CL/ { if (!match(tolower($0), tolower(key1)) || !match(tolower($0), tolower(key2)) )
                         next;
                     else
                         print $1 }' | uniq`
    fi

    # Collect Port Login data...
    # PORT           LOGIN_WWN      Serial#   -

    for i in $ports; do
	(( n++ ))
        raidcom get port -port $i -I$instance | awk -v key1="$filter1" -v key2="$filter2" -v n=$n '

	 /PORT/ { if ( n > 1 )
	             print " ";

    		  print "PORT   LOGIN WWN";
                  print "-----  -----------------------";
	          next; }

                { if (!match(tolower($0), tolower(key1)) || !match(tolower($0), tolower(key2)) )
                      next;
                  else
                      wwn = $2;
                      w01 = substr(wwn,1,2);
                      w02 = substr(wwn,3,2);
                      w03 = substr(wwn,5,2);
                      w04 = substr(wwn,7,2);
                      w05 = substr(wwn,9,2);
                      w06 = substr(wwn,11,2);
                      w07 = substr(wwn,13,2);
                      w08 = substr(wwn,15,2);
 
                      printf("%5s  %2s:%2s:%2s:%2s:%2s:%2s:%2s:%2s\n", $1, 
                             w01, w02, w03, w04, w05, w06, w07, w08 ); }' 
    done
    
    echo
    exit 0
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

param_error ()
{
    echo "error: "$1"."
    echo
    exit 1
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

help_syntax ()
{
    if [[ $array_qty > 1 ]]; then
        echo "usage: $filename <serial_number> [hostgrp|ldev|logins|port|tier|pool|unalloc|used] [<filter1> <filter2>]"
    else
        echo "usage: $filename [totals|hostgrp|ldev|logins|port|tier|pool|unalloc|used] [<filter1> <filter2>]"
    fi
    echo
    exit 1
}

# ------- --------- --------- --------- --------- --------- --------- --------- --------- ---------

# Start main program execution here.

if [[ $# == 0 ]]; then                            # Show usage if required.
    list_arrays
fi

if [[ ( $1 == "--help" ) || ( $# > 4 ) ]]; then	  # Show usage if required.
    help_syntax
fi

if [ $array_qty -gt 1 ]; then
    array_serial=$1
    option=$2
    filter1=$3
    filter2=$4

    array_validate $array_serial                 # Validate array S/N.
else
    option=$1
    filter1=$2
    filter2=$3
fi

# Allow filter to select only replicated volumes.

case "$filter1" in
    [Ss][Ii] ) filter1="_si ";;
    [Tt][Cc] ) filter1="_tc ";;
esac

case "$filter2" in
    SI ) filter1="_si ";;
    TC ) filter1="_tc ";;
esac

case "$option" in
    port    ) array_port;;           # List array Port WWN.

    hostgrp ) array_hostgrp;;        # Show HostGroup(s) by Port.

    ldev    ) array_ldev;;           # Show host storage by LDEV.

    totals  ) array_total;;          # Show array storage by host.

    tier    ) array_tier;;           # Show host storage by Tier.

    pool    ) array_pool;;           # Show array pool totals.

    unalloc ) array_unalloc;;        # Show unlloc host storage by LDEV.

    used    ) array_used;;           # Show used array storage by LDEV.

    logins  ) array_logins;;         # Show hosts logged into port.

esac
                                                                                                                                                           
if [[ ( "$option" == "" ) && ( $array_qty > 1 ) ]]; then		# Show array storage by host.
    array_total
fi

param_error "invalid option"			# Invalid option entered.


