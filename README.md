# Dispatch

Official bootstrap for running your own `Dispatch` with [Docker](https://www.docker.com/).

## Requirements

- Docker 17.05.0+
- Compose 1.19.0+
- [PostgreSQL Client Applications](https://www.postgresql.org/docs/current/reference-client.html). They're included with PostgreSQL, which can be downloaded from [here](https://www.postgresql.org/download/).

## Minimum Hardware Requirements:

- You need at least 2400MB RAM

## Setup

To get started with all the defaults, simply clone the repo and run `./install.sh` in your local check-out.

There may need to be modifications to the included example config files (`.env`) to accommodate your needs or your environment (such as adding Google credentials). If you want to perform these, do them before you run the install script and copy them without the `.example` extensions in the name before running the `install.sh` script.

## Data

By default Dispatch does not come with any data. If you're looking for some example data, please use the postgres dump file located [here](https://github.com/Netflix/dispatch/blob/master/data/dispatch-sample-data.dump) to load example data.

### Starting with a clean database

If you decide to start with a clean database, you will need a user. To create a user, go to http://localhost:8000/register.

## Securing Dispatch with SSL/TLS

If you'd like to protect your Dispatch install with SSL/TLS, there are
fantastic SSL/TLS proxies like [HAProxy](http://www.haproxy.org/)
and [Nginx](http://nginx.org/). You'll likely want to add this service to your `docker-compose.yml` file.

## Updating Dispatch

The included `install.sh` script is meant to be idempotent and to bring you to the latest version. What this means is you can and should run `install.sh` to upgrade to the latest version available.

### Upgrading from an older version of postgres

If you are using an earlier version of `postgres` you may need to run manual steps to upgrade to the newest Postgres image.

This assumes that you have not changed the default Postgres data path (`/var/lib/postgresql/data`) in your `docker-compose.yml`.

If you have changed it, please replace all occurences of `/var/lib/postgresql/data` with your path.

1. Make a backup of your Dispatch Postgres data dir.
2. Stop all Dispatch containers, except the postgres one (e.g. use `docker stop` and not `docker-compose stop`).
3. Create a new Postgres container which uses a different data directory:
```
docker run -d \
      --name postgresnew \
      -e POSTGRES_DB=dispatch \
      -e POSTGRES_USER=dispatch \
      -e POSTGRES_PASSWORD=dispatch \
      -v /var/lib/postgresql/new:/var/lib/postgresql/data:rw \
      postgres:latest
```
4. Use `pg_dumpall` to dump all data from the existing Postgres container to the new Postgres container (replace `DISPATCH_DATABASE_CONTAINER_NAME` (default is `postgres`) with the name of the old Postgres container):
```
docker exec \
    DISPATCH_DATABASE_CONTAINER_NAME pg_dumpall -U postgres | \
    docker exec -i postgresnew psql -U postgres
```
5. Stop and remove both Postgres containers:
```
docker stop DISPATCH_DATABASE_CONTAINER_NAME postgresnew
docker rm DISPATCH_DATABASE_CONTAINER_NAME postgresnew
```
6. Edit your `docker-compose.yml` to use the `postgres:latest` image for the `database` container.
7. Replace old Postgres data directory with upgraded data directory:
```
mv /var/lib/postgresql/data /var/lib/postgresql/old
mv /var/lib/postgresql/new /var/lib/postgresql/data
```
8. Delete the old existing containers:
```
docker-compose rm
```
9. Start Dispatch up again:
```
docker-compose up
```

That should be it. Your Postgres data has now been updated to use the `postgres` image.
