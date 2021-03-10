#!/usr/bin/env bash
set -e

COMPOSE_DOCKER_CLI_BUILD=0

MIN_DOCKER_VERSION='17.05.0'
MIN_COMPOSE_VERSION='1.19.0'
MIN_RAM=2400 # MB

DISPATCH_CONFIG_ENV='./.env'
DISPATCH_EXTRA_REQUIREMENTS='./requirements.txt'

DISPATCH_DB_SAMPLE_DATA_FILE='dispatch-sample-data.dump'
DISPATCH_DB_SAMPLE_DATA_URL="https://raw.githubusercontent.com/Netflix/dispatch/latest/data/${DISPATCH_DB_SAMPLE_DATA_FILE}"

DID_CLEAN_UP=0
# the cleanup function will be the exit point
cleanup () {
  if [ "$DID_CLEAN_UP" -eq 1 ]; then
    return 0;
  fi
  echo "Cleaning up..."
  docker-compose stop &> /dev/null
  DID_CLEAN_UP=1
}
trap cleanup ERR INT TERM

echo "Checking minimum requirements..."

DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
COMPOSE_VERSION=$(docker-compose --version | sed 's/docker-compose version \(.\{1,\}\),.*/\1/')
RAM_AVAILABLE_IN_DOCKER=$(docker run --rm busybox free -m 2>/dev/null | awk '/Mem/ {print $2}');

# Compare dot-separated strings - function below is inspired by https://stackoverflow.com/a/37939589/808368
function ver () { echo "$@" | awk -F. '{ printf("%d%03d%03d", $1,$2,$3); }'; }

function ensure_file_from_example {
  if [ -f "$1" ]; then
    echo "$1 already exists, skipped creation."
  else
    echo "Creating $1..."
    cp -n $(echo "$1".example) "$1"
  fi
}

if [ $(ver $DOCKER_VERSION) -lt $(ver $MIN_DOCKER_VERSION) ]; then
    echo "FAIL: Expected minimum Docker version to be $MIN_DOCKER_VERSION but found $DOCKER_VERSION"
    exit -1
fi

if [ $(ver $COMPOSE_VERSION) -lt $(ver $MIN_COMPOSE_VERSION) ]; then
    echo "FAIL: Expected minimum docker-compose version to be $MIN_COMPOSE_VERSION but found $COMPOSE_VERSION"
    exit -1
fi

if [ "$RAM_AVAILABLE_IN_DOCKER" -lt "$MIN_RAM" ]; then
    echo "FAIL: Expected minimum RAM available to Docker to be $MIN_RAM MB but found $RAM_AVAILABLE_IN_DOCKER MB"
    exit -1
fi

echo ""
ensure_file_from_example $DISPATCH_CONFIG_ENV
ensure_file_from_example $DISPATCH_EXTRA_REQUIREMENTS

# Clean up old stuff and ensure nothing is working while we install/update
docker-compose down --rmi local --remove-orphans

echo ""
echo "Creating volumes for persistent storage..."
echo "Created $(docker volume create --name=dispatch-postgres)."

echo ""
echo "Generating secret keys..."
# This is to escape the secret key to be used in sed below
SECRET_KEY=$(openssl rand -hex 30)
DISPATCH_JWT_SECRET=$(openssl rand -hex 30)
# We check the OS type and adjust the sed command accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^SECRET_KEY=.*/SECRET_KEY=${SECRET_KEY}/" $DISPATCH_CONFIG_ENV
    sed -i '' "s/^DISPATCH_JWT_SECRET=.*/DISPATCH_JWT_SECRET=${DISPATCH_JWT_SECRET}/" $DISPATCH_CONFIG_ENV
else
    sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${SECRET_KEY}/" $DISPATCH_CONFIG_ENV
    sed -i "s/^DISPATCH_JWT_SECRET=.*/DISPATCH_JWT_SECRET=${DISPATCH_JWT_SECRET}/" $DISPATCH_CONFIG_ENV
fi

echo "Secret keys written to $DISPATCH_CONFIG_ENV"

echo ""
echo "Pulling, building, and tagging Docker images..."
echo ""
docker-compose pull postgres
docker-compose build --force-rm
echo ""
echo "Docker images pulled and built."

docker-compose up -d postgres

# Very naively check whether there's an existing dispatch-postgres volume and the PG version in it
if [[ $(docker volume ls -q --filter name=dispatch-postgres) && $(docker run --rm -v dispatch-postgres:/db busybox cat /db/PG_VERSION 2>/dev/null) == "9.5" ]]; then
    docker volume rm dispatch-postgres-new || true
    # If this is Postgres 9.5 data, start upgrading it to 12 in a new volume
    docker run --rm \
    -v dispatch-postgres:/var/lib/postgresql/9.5/data \
    -v dispatch-postgres-new:/var/lib/postgresql/12/data \
    tianon/postgres-upgrade:9.5-to-12

    # Get rid of the old volume as we'll rename the new one to that
    docker volume rm dispatch-postgres
    docker volume create --name dispatch-postgres
    # There's no rename volume in Docker so copy the contents from old to new name
    # Also append the `host all all all trust` line as `tianon/postgres-upgrade:9.5-to-12`
    # doesn't do that automatically.
    docker run --rm -v dispatch-postgres-new:/from -v dispatch-postgres:/to alpine ash -c \
     "cd /from ; cp -av . /to ; echo 'host all all all trust' >> /to/pg_hba.conf"
    # Finally, remove the new old volume as we are all in dispatch-postgres now
    docker volume rm dispatch-postgres-new
fi

echo ""
echo "Setting up database..."
if [ $CI ]; then
  docker-compose run web database upgrade --no-input
else
  read -p "Do you want to load example data (WARNING: this will remove all existing database data) (y/N)?" CONT
  if [ "$CONT" = "y" ]; then
    source $DISPATCH_CONFIG_ENV
    echo "Downloading example data from Dispatch repository..."
    curl -o "./$DISPATCH_DB_SAMPLE_DATA_FILE" "$DISPATCH_DB_SAMPLE_DATA_URL"
    echo "Dropping database dispatch if it already exists..."
    docker-compose run -e "PGPASSWORD=$POSTGRES_PASSWORD" --rm postgres dropdb -h $DATABASE_HOSTNAME -p $DATABASE_PORT -U $POSTGRES_USER $DATABASE_NAME --if-exists
    echo "Creating dispatch database..."
    docker-compose run -e "PGPASSWORD=$POSTGRES_PASSWORD" --rm postgres createdb -h $DATABASE_HOSTNAME -p $DATABASE_PORT -U $POSTGRES_USER $DATABASE_NAME
    echo "Loading example data to the database..."
    docker-compose run -e "PGPASSWORD=$POSTGRES_PASSWORD" -v "$(pwd)/$DISPATCH_DB_SAMPLE_DATA_FILE:/$DISPATCH_DB_SAMPLE_DATA_FILE" --rm postgres psql -h $DATABASE_HOSTNAME -p $DATABASE_PORT -U $POSTGRES_USER -d $DATABASE_NAME -f "/$DISPATCH_DB_SAMPLE_DATA_FILE"
    echo "Example data loaded. Navigate to /register and create a new user."
  fi
  echo "Running standard database migrations..."
  docker-compose run --rm web database upgrade
fi

echo ""
echo "Installing plugins..."
docker-compose run --rm web plugins install

cleanup

echo ""
echo "----------------"
echo "You're all done! Run the following command to get Dispatch running:"
echo ""
echo "  docker-compose up -d"
echo ""
echo "Once running, access the Dispatch UI at:"
echo ""
echo "  http://localhost:8000/auth/register"
echo "----------------"
echo ""
