README
======

``archlinux-postgresql-upgrade`` is a simple wrapper-script over ``pg_upgrade``
for full-automatically upgrading Postgresql data files on Archlinux distro.

Steps To Use
------------

::

    pacman -S postgresql-old-upgrade
    
    systemctl stop postgresql
    
    ./archlinux-postgresql-upgrade.sh
    
    systemctl start postgresql
