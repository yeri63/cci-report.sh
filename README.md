# cci-report.sh
<p>Quickly lookup storage information on Hitachi VSP series arrays using CLI interface. This program does almost everything that Storage Navigator / Device Manager does, but much faster, and from a ssh terminal. This was created to speed up collection of storage array information to document changes, and quickly "roll back" in case of errors. This became a source for creating Runbook of standard procedures, ie. storage allocation, decommission, volume expansion, volume replication, host migration, etc.</p>

    $ cci-report.sh --help
    usage: cci-report.sh <serial_number> [hostgrp|ldev|logins|port|tier|pool|unalloc|used]

    $ cci-report.sh   
    350101 - Data Center 1
    350102 - Data Center 2

    $ cci-report.sh 350101 hostgrp Prod
    350101 - Data Center 1

    Port       Host Group                    Host Name                  HBA WWN                  Host Mode   Bits
    ---------  ----------------------------  -------------------------  -----------------------  ----------  ----
    CL1-A-1    Prod-App1                     App1                       10:00:00:00:00:00:00:a0  LINUX/IRIX  40
    CL1-A-2    Prod-App2                     App2                       10:00:00:00:00:00:00:a1  LINUX/IRIX  40

    Port       Host Group                    Host Name                  HBA WWN                  Host Mode   Bits
    ---------  ----------------------------  -------------------------  -----------------------  ----------  ----
    CL2-A-1    Prod-App1                     App1                       10:00:00:00:00:00:00:b0  LINUX/IRIX  40
    CL2-A-2    Prod-App2                     App2                       10:00:00:00:00:00:00:b1  LINUX/IRIX  40

    $ cci-report.sh 350101 ldev App3
    350101 - Data Center 1

    Vol    Label                                     Size        LUN   Dec   Port
    -----  ----------------------------------------  ----------  ----  ---  -----------------------------------
    10:20  Test-App3_0                               50 GB       0x00  000  CL3-A-2, CL4-A-2
    10:21  Test_App3_1                               100 GB      0x01  001  CL3-A-2, CL4-A-2
    ...

    $ cci-report.sh 350101 logins CL2-A
    350101 - Data Center 1
    
    Port   Login WWN
    -----  -----------------------
    CL2-A  10:00:00:00:00:00:00:b0
    CL2-A  10:00:00:00:00:00:00:b1
    CL2-A  10:00:00:00:00:00:00:b2

    $ cci-report.sh 350101 port CL2-A
    350101 - Data Center 1
    
    Port   Array Port WWN           Port Attribute
    -----  -----------------------  ------------------
    CL2-A  50:06:00:00:00:00:00:50  target port

    $ cci-report.sh 350101 tier App1
    350101 - Data Center 1

    Vol    Label                         Size       Used  Relocation  Policy       Tier1       Tier2       Tier3  Level  Alloc
    -----  ----------------------------  ---------  ----  ----------  ------  ----------  ----------  ----------  -----  -----
    10:00  Prod-App1_0                   100 GB     35%   Enable      30           20 GB        0 GB        0 GB    M    Full
    10:01  Prod-App1_1                   250 GB     75%   Enable      30          150 GB       38 GB        0 GB    M    Full
    ...

    $ cci-report.sh 350101 pool
    350101 - Data Center 1

    Pool  Name          Total Capacity  Used Capacity  Used  Threshold  Status   Threshold Limit
    ----  ------------  --------------  -------------  ----  ---------  -------  ---------------
    0     Pool0               1,024 TB         512 TB   50%    100%     Normal            819 TB

    $ cci-report.sh 350101 unalloc
    350101 - Data Center 1

    Vol    Label                                     Size
    -----  ----------------------------------------  ----------
    20:00  Test-App5-0                               10 GB
    20:01  Test-App5-1                               200 GB
    ...
    
    $ cci-report.sh 350101 used
    350101 - Data Center 1

    00:00  00:01  00:02  00:03  00:04  00:05  00:06  00:07  00:08  00:09  00:0A  00:0B  00:0C  00:0D  00:0E  00:0F
    00:10  00:11  00:12  00:13  00:14  00:15  00:16  00:17  00:18  00:19  00:1A  00:1B  00:1C  00:1D  00:1E  00:1F
    00:20  00:21  00:22  00:23  00:24  00:25  00:26  00:27  00:28  00:29  00:2A  00:2B  00:2C  00:2D  00:2E  00:2F
    00:30  00:31  00:32  00:33  00:34  00:35  00:36  00:37  00:38  00:39  00:3A  00:3B  00:3C  00:3D  00:3E  00:3F
    00:40  00:41  00:42  00:43  00:44  00:45  00:46  00:47  00:48  00:49  00:4A  00:4B  00:4C  00:4D  00:4E  00:4F
    00:50  00:51  00:52  00:53  00:54  00:55  --:--  --:--  00:58  00:59  --:--  --:--  --:--  --:--  --:--  00:0F
    ...
