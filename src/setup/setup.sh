################### [server] 

#install cherrypi
pip3 install cherrypy

# install postgres 
sudo apt update
sudo apt install postgresql
pip3 install psycopg2-binary

# enable remote access to postgres 
sudo vi /etc/postgresql/11/main/postgresql.conf
    listen_addresses = '*'
sudo service postgresql restart

# connect to template database
sudo su - postgres
psql template1

# create user
CREATE USER nyu WITH PASSWORD 'pa0l1n0';

# create database
CREATE DATABASE mobile_testbed;

# grant required privileges
GRANT ALL PRIVILEGES ON DATABASE mobile_testbed to nyu;

# connect to database with created user
psql nyu -h 127.0.0.1 -d mobile_testbed

# create tables # FIXME 
create table status_update(tester_id text, location text, timestamp integer, data jsonb);

################### [client]
# aioquic support (H3 client)
sudo apt install libssl-dev python3-dev
git clone git@github.com:aiortc/aioquic.git
cd aioquic/
pip3 install -e .
pip3 install wsproto