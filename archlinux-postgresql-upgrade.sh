#!/bin/bash

set -e

if [ "x$(id -u)" != "x0" ]
then
    echo 'archlinux-postgresql-upgrade: error: run the utility as root' 1>&2
    exit 1
fi

quote ()
{
    printf "'%s'" "${1//\'/\'\\\'\'}"
}

echo 'archlinux-postgresql-upgrade: removing pre-old data files...'

rm -rf -- /var/lib/postgres/old-data.removing

if [ -d /var/lib/postgres/old-data ] &&
        [ -f /var/lib/postgres/old-data/PG_VERSION ] &&
        [ ! -x "/opt/pgsql-$(cat -- /var/lib/postgres/old-data/PG_VERSION)/bin/pg_upgrade" ]
then
    mv -- /var/lib/postgres/old-data /var/lib/postgres/old-data.removing
fi

rm -rf -- /var/lib/postgres/old-data.removing

echo 'archlinux-postgresql-upgrade: removing pre-old data files: DONE!'

echo 'archlinux-postgresql-upgrade: preparing old data files...'

if [ ! -d /var/lib/postgres/old-data ] &&
        [ -d /var/lib/postgres/data ] &&
        [ -f /var/lib/postgres/data/PG_VERSION ] &&
        [ -x "/opt/pgsql-$(cat -- /var/lib/postgres/data/PG_VERSION)/bin/pg_upgrade" ]
then
    mv -- /var/lib/postgres/data /var/lib/postgres/old-data
fi

if [ ! -d /var/lib/postgres/old-data ]
then
    echo 'archlinux-postgresql-upgrade: error: unable to find old data files' 1>&2
    exit 1
fi

if [ ! -f /var/lib/postgres/old-data/pg_hba.conf.saved ]
then
    mv -- /var/lib/postgres/old-data/pg_hba.conf /var/lib/postgres/old-data/pg_hba.conf.saved
fi

if [ ! -f /var/lib/postgres/old-data/pg_hba.conf ]
then
    rm -f -- /var/lib/postgres/old-data/pg_hba.conf.new
    (umask 0077 && touch /var/lib/postgres/old-data/pg_hba.conf.new)
    echo 'local all all trust' >/var/lib/postgres/old-data/pg_hba.conf.new
    chown -- postgres:postgres /var/lib/postgres/old-data/pg_hba.conf.new
    mv -- /var/lib/postgres/old-data/pg_hba.conf.new /var/lib/postgres/old-data/pg_hba.conf
fi

echo 'archlinux-postgresql-upgrade: preparing old data files: DONE!'

echo 'archlinux-postgresql-upgrade: preparing new data files...'

if [ -d /var/lib/postgres/data ]
then
    echo 'error: new data files already exist' 1>&2
    exit 1
fi

rm -rf -- /var/lib/postgres/new-data
mkdir -m0700 -- /var/lib/postgres/new-data
chown -- postgres:postgres /var/lib/postgres/new-data

su -lc'/usr/bin/initdb -D/var/lib/postgres/new-data' -- postgres

cp -p -- /var/lib/postgres/old-data/postgresql.auto.conf /var/lib/postgres/new-data/postgresql.auto.conf
cp -p -- /var/lib/postgres/old-data/pg_hba.conf.saved /var/lib/postgres/new-data/pg_hba.conf.saved

echo 'archlinux-postgresql-upgrade: preparing new data files: DONE!'

echo 'archlinux-postgresql-upgrade: data migration...'

su -lc"cd /var/lib/postgres/new-data && /usr/bin/pg_upgrade -b"$(quote "/opt/pgsql-$(cat -- /var/lib/postgres/old-data/PG_VERSION)/bin")" -B/usr/bin -d/var/lib/postgres/old-data -D/var/lib/postgres/new-data" -- postgres

mv -- /var/lib/postgres/new-data/pg_hba.conf.saved /var/lib/postgres/new-data/pg_hba.conf
mv -- /var/lib/postgres/new-data /var/lib/postgres/data

echo 'archlinux-postgresql-upgrade: data migration: DONE!'
