#!/bin/bash

set -e

utility_name='archlinux-postgresql-upgrade'
os_user='postgres'

if [ "x$#" != "x0" ]
then
    echo "$utility_name: error: invalid args" 1>&2
    exit 1
fi

if [ "x$(id -u)" != "x0" ]
then
    echo "$utility_name: error: run the utility as root" 1>&2
    exit 1
fi

quote ()
{
    printf "'%s'" "${1//\'/\'\\\'\'}"
}

echo "$utility_name: removing pre-old data files..."

rm -rf -- /var/lib/postgres/old-data.removing

if [ -d /var/lib/postgres/old-data ] &&
        [ -f /var/lib/postgres/old-data/PG_VERSION ] &&
        [ ! -x "/opt/pgsql-$(cat -- /var/lib/postgres/old-data/PG_VERSION)/bin/pg_upgrade" ]
then
    mv -- /var/lib/postgres/old-data /var/lib/postgres/old-data.removing
fi

rm -rf -- /var/lib/postgres/old-data.removing

echo "$utility_name: removing pre-old data files: DONE!"

echo "$utility_name: preparing old data files..."

if [ ! -d /var/lib/postgres/old-data ] &&
        [ -d /var/lib/postgres/data ] &&
        [ -f /var/lib/postgres/data/PG_VERSION ] &&
        [ -x "/opt/pgsql-$(cat -- /var/lib/postgres/data/PG_VERSION)/bin/pg_upgrade" ]
then
    mv -- /var/lib/postgres/data /var/lib/postgres/old-data
fi

if [ ! -d /var/lib/postgres/old-data ]
then
    echo "$utility_name: error: unable to find old data files" 1>&2
    exit 1
fi

if [ ! -f /var/lib/postgres/old-data/pg_ident.conf.saved ]
then
    mv -- /var/lib/postgres/old-data/pg_ident.conf /var/lib/postgres/old-data/pg_ident.conf.saved
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
    chown -- "$os_user:$os_user" /var/lib/postgres/old-data/pg_hba.conf.new
    mv -- /var/lib/postgres/old-data/pg_hba.conf.new /var/lib/postgres/old-data/pg_hba.conf
fi

echo "$utility_name: preparing old data files: DONE!"

echo "$utility_name: preparing new data files..."

if [ -d /var/lib/postgres/data ]
then
    echo "$utility_name: error: new data files already exist" 1>&2
    exit 1
fi

rm -rf -- /var/lib/postgres/new-data
mkdir -m0700 -- /var/lib/postgres/new-data
chown -- "$os_user:$os_user" /var/lib/postgres/new-data

su -lc'/usr/bin/initdb -D/var/lib/postgres/new-data' -- "$os_user"

cp -p -- /var/lib/postgres/old-data/postgresql.auto.conf /var/lib/postgres/new-data/postgresql.auto.conf
cp -p -- /var/lib/postgres/old-data/pg_hba.conf.saved /var/lib/postgres/new-data/pg_hba.conf.saved
cp -p -- /var/lib/postgres/old-data/pg_ident.conf.saved /var/lib/postgres/new-data/pg_ident.conf.saved

echo "$utility_name: preparing new data files: DONE!"

echo "$utility_name: data migration..."

su -lc"cd -- /var/lib/postgres/new-data && /usr/bin/pg_upgrade -b"$(quote "/opt/pgsql-$(cat -- /var/lib/postgres/old-data/PG_VERSION)/bin")" -B/usr/bin -d/var/lib/postgres/old-data -D/var/lib/postgres/new-data" -- "$os_user"

mv -- /var/lib/postgres/new-data/pg_hba.conf /var/lib/postgres/new-data/pg_hba.conf.original
mv -- /var/lib/postgres/new-data/pg_hba.conf.saved /var/lib/postgres/new-data/pg_hba.conf
mv -- /var/lib/postgres/new-data/pg_ident.conf /var/lib/postgres/new-data/pg_ident.conf.original
mv -- /var/lib/postgres/new-data/pg_ident.conf.saved /var/lib/postgres/new-data/pg_ident.conf
mv -- /var/lib/postgres/new-data /var/lib/postgres/data

echo "$utility_name: data migration: DONE!"

# vi:ts=4:sw=4:et
