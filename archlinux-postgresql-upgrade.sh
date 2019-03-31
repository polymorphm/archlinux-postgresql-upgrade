#!/bin/bash

set -e

utility_name='archlinux-postgresql-upgrade'
new_bin_path='/usr/bin'
old_bin_path_startswith='/opt/pgsql'
data_parent_dir='/var/lib/postgres'
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

rm -rf -- "$data_parent_dir/old-data.removing"

if [ -d "$data_parent_dir/old-data" ] &&
        [ -f "$data_parent_dir/old-data/PG_VERSION" ] &&
        [ ! -x "$old_bin_path_startswith-$(cat -- "$data_parent_dir/old-data/PG_VERSION")/bin/pg_upgrade" ]
then
    mv -- "$data_parent_dir/old-data" "$data_parent_dir/old-data.removing"
fi

rm -rf -- "$data_parent_dir/old-data.removing"

echo "$utility_name: removing pre-old data files: DONE!"

echo "$utility_name: preparing old data files..."

if [ ! -d "$data_parent_dir/old-data" ] &&
        [ -d "$data_parent_dir/data" ] &&
        [ -f "$data_parent_dir/data/PG_VERSION" ] &&
        [ -x "$old_bin_path_startswith-$(cat -- "$data_parent_dir/data/PG_VERSION")/bin/pg_upgrade" ]
then
    mv -- "$data_parent_dir/data" "$data_parent_dir/old-data"
fi

if [ ! -d "$data_parent_dir/old-data" ]
then
    echo "$utility_name: error: unable to find old data files" 1>&2
    exit 1
fi

if [ ! -f "$data_parent_dir/old-data/pg_ident.conf.saved" ]
then
    mv -- "$data_parent_dir/old-data/pg_ident.conf" "$data_parent_dir/old-data/pg_ident.conf.saved"
fi

if [ ! -f "$data_parent_dir/old-data/pg_hba.conf.saved" ]
then
    mv -- "$data_parent_dir/old-data/pg_hba.conf" "$data_parent_dir/old-data/pg_hba.conf.saved"
fi

if [ ! -f "$data_parent_dir/old-data/pg_hba.conf" ]
then
    rm -f -- "$data_parent_dir/old-data/pg_hba.conf.new"
    (umask 0077 && touch -- "$data_parent_dir/old-data/pg_hba.conf.new")
    echo 'local all all trust' >"$data_parent_dir/old-data/pg_hba.conf.new"
    chown -- "$os_user:$os_user" "$data_parent_dir/old-data/pg_hba.conf.new"
    mv -- "$data_parent_dir/old-data/pg_hba.conf.new" "$data_parent_dir/old-data/pg_hba.conf"
fi

echo "$utility_name: preparing old data files: DONE!"

echo "$utility_name: preparing new data files..."

if [ -d "$data_parent_dir/data" ]
then
    echo "$utility_name: error: new data files already exist" 1>&2
    exit 1
fi

rm -rf -- "$data_parent_dir/new-data"
mkdir -m0700 -- "$data_parent_dir/new-data"
chown -- "$os_user:$os_user" "$data_parent_dir/new-data"

su -lc"$(quote "$new_bin_path/initdb") -D$(quote "$data_parent_dir/new-data")" -- "$os_user"

cp -p -- "$data_parent_dir/old-data/postgresql.auto.conf" "$data_parent_dir/new-data/postgresql.auto.conf"
cp -p -- "$data_parent_dir/old-data/pg_hba.conf.saved" "$data_parent_dir/new-data/pg_hba.conf.saved"
cp -p -- "$data_parent_dir/old-data/pg_ident.conf.saved" "$data_parent_dir/new-data/pg_ident.conf.saved"

echo "$utility_name: preparing new data files: DONE!"

echo "$utility_name: data migration..."

su -lc"cd -- $(quote "$data_parent_dir/new-data") && $(quote "$new_bin_path/pg_upgrade") -b"$(quote "$old_bin_path_startswith-$(cat -- "$data_parent_dir/old-data/PG_VERSION")/bin")" -B$(quote "$new_bin_path") -d$(quote "$data_parent_dir/old-data") -D$(quote "$data_parent_dir/new-data")" -- "$os_user"

mv -- "$data_parent_dir/new-data/pg_hba.conf" "$data_parent_dir/new-data/pg_hba.conf.original"
mv -- "$data_parent_dir/new-data/pg_hba.conf.saved" "$data_parent_dir/new-data/pg_hba.conf"
mv -- "$data_parent_dir/new-data/pg_ident.conf" "$data_parent_dir/new-data/pg_ident.conf.original"
mv -- "$data_parent_dir/new-data/pg_ident.conf.saved" "$data_parent_dir/new-data/pg_ident.conf"
mv -- "$data_parent_dir/new-data" "$data_parent_dir/data"

echo "$utility_name: data migration: DONE!"

# vi:ts=4:sw=4:et
