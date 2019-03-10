README
======

``archlinux-postgresql-upgrade`` is wrapper-script for ``pg_upgrade`` for
full-automatically upgrading Postgresql data files on Archlinux distro.

Steps To Use
------------

::

    pacman -S postgresql-old-upgrade
    
    systemctl stop postgresql
    
    ./archlinux-postgresql-upgrade.sh
    
    systemctl start postgresql
