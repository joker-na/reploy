#!/bin/bash

sudo -i
wget --no-check-certificate -qO InstallNET.sh "https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"
chmod a+x InstallNET.sh
bash InstallNET.sh -debian 12 -pwd hp6#dT0#s4t5t
sleep 10
(reboot && exit 0) &
