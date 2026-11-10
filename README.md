# cci-report.sh
<p>Quickly lookup storage information on Hitachi VSP series arrays using CLI interface. This program does almost everything that Storage Navigator / Device Manager does, but much faster, and from a ssh terminal. This was created to capture state information to facilitate "roll back" in case of errors, and document steps to store in a Runbook for future reference.</p>

    $> cci-report.sh --help
    usage: cci-report.sh <serial_number> [hostgrp|ldev|logins|port|tier|pool|unalloc|used]
  
