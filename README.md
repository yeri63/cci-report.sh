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
    10:01  Prod-App1_0                   250 GB     75%   Enable      30          150 GB       38 GB        0 GB    M    Full
    ...

    $ cci-report.sh 350101 pool
    350101 - Data Center 1

    Pool  Name          Total Capacity  Used Capacity  Used  Threshold  Status   Threshold Limit
    ----  ------------  --------------  -------------  ----  ---------  -------  ---------------
    0     Pool0               1,024 TB         512 TB   50%    100%     Normal            819 TB

    
    
