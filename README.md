# Dispatch

Official bootstrap for running your own `Dispatch` with [Docker](https://www.docker.com/).

## Requirements

- Docker 17.05.0+
- Compose 1.19.0+

## Minimum Hardware Requirements:

- You need at least 2400MB RAM

## Setup

To get started with all the defaults, simply clone the repo and run `./install.sh` in your local check-out.

There may need to be modifications to the included example config files (`.env`) to accommodate your needs or your environment (such as adding Google credentials). If you want to perform these, do them before you run the install script and copy them without the `.example` extensions in the name before running the `install.sh` script.

## Data

By default Dispatch does not come with any data. If you're looking for some example data, please use the postgres dump file located [here](https://github.com/Netflix/dispatch/blob/develop/data/dispatch-sample-data.dump) to load example data.

## Securing Dispatch with SSL/TLS

If you'd like to protect your Dispatch install with SSL/TLS, there are
fantastic SSL/TLS proxies like [HAProxy](http://www.haproxy.org/)
and [Nginx](http://nginx.org/). You'll likely want to add this service to your `docker-compose.yml` file.

## Updating Dispatch

The included `install.sh` script is meant to be idempotent and to bring you to the latest version. What this means is you can and should run `install.sh` to upgrade to the latest version available.
