#!/bin/bash

HOST="http://localhost:3333"

VALIDATOR_ADDRESS=$(curl -s -d '{"jsonrpc": "2.0", "method": "validation.get_node_info", "params": [], "id": 1}' \
                    -H "Content-Type: application/json" -X POST "$HOST/validation" | jq -r ".result.address")
IS_VALIDATING=$(curl -s -X POST "$HOST/validation" -H "Content-Type: application/json" \
                -d '{"jsonrpc": "2.0", "method": "validation.get_current_epoch_data", "params": [], "id": 1}' \
                | jq ".result.validators | any(.address == \"$VALIDATOR_ADDRESS\")")

get_completed_proposals () {
   curl -s -X POST "$HOST/validation" -H "Content-Type: application/json" \
   -d '{"jsonrpc": "2.0", "method": "validation.get_current_epoch_data", "params": [], "id": 1}' \
   | jq ".result.validators[] | select(.address == \"$VALIDATOR_ADDRESS\") | .proposalsCompleted"
}

echo "Checking for latest radix node version ..."
NODE_URL=$(curl -s https://api.github.com/repos/radixdlt/radixdlt/releases/latest | \
           jq -r '.assets[] | select(.browser_download_url|split("/")|last|test("^radixdlt-dist-1.0-beta.[0-9.]*zip")) | .browser_download_url')
echo "Found url:" "$NODE_URL"
NODE_ARCHIVE=$(basename "$NODE_URL")

echo "Latest node version:" "$NODE_ARCHIVE"

cd /opt/radixdlt/releases || exit

if [[ ! -f $NODE_ARCHIVE ]]
then
    echo "Downloading new version ..."
    curl -OL "$NODE_URL" && \
    unzip "$NODE_ARCHIVE"
fi

NODE_EXTRACTED=$(unzip -Z1 "$NODE_ARCHIVE" | head -n 1)
if [[ ${#NODE_EXTRACTED} == 0 ]]
then
    echo "Error: Failed to read downloaded archive."
    exit
fi

if [[ $(find "$NODE_EXTRACTED" -type f | wc -l) == 0 ]]
then
    echo "Error: no files extracted."
    exit
fi

DIR_BIN=/opt/radixdlt/releases/${NODE_EXTRACTED}bin
DIR_LIB=/opt/radixdlt/releases/${NODE_EXTRACTED}lib

if [[ $DIR_BIN = $(readlink /etc/radixdlt/node/bin) && \
      $DIR_LIB = $(readlink /etc/radixdlt/node/lib) && \
      "$1" != "force" ]]
then
    echo "Already up to date with version"
    exit
fi

mkdir -p /etc/radixdlt/node

echo "Installing new node version" "$NODE_ARCHIVE" "..."

## INSTALL - node not running

if [[ $VALIDATOR_ADDRESS == "" ]]
then
    if
        rm -f /etc/radixdlt/node/bin && \
        rm -f /etc/radixdlt/node/lib && \
        ln -s "$DIR_BIN" /etc/radixdlt/node/bin && \
        ln -s "$DIR_LIB" /etc/radixdlt/node/lib
    then
        echo "Successfully installed node files."
    else
        echo "Error: Failed to install node files."
    fi
    exit
fi

## UPDATE

if [[ $IS_VALIDATING == true ]]
then
  PROPOSALS_COMPLETED=$(get_completed_proposals)
  echo "Wait until node completed proposal to minimise risk of a missed proposal ..."
  while (( $(get_completed_proposals) == PROPOSALS_COMPLETED)) || (( $(get_completed_proposals) == 0))
  do
      echo "Waiting ..."
      sleep 1
  done
  echo "Validator completed proposal - updating now."
fi

if
    sudo systemctl stop radixdlt-node && \
    rm -f /etc/radixdlt/node/bin && \
    rm -f /etc/radixdlt/node/lib && \
    ln -s "$DIR_BIN" /etc/radixdlt/node/bin && \
    ln -s "$DIR_LIB" /etc/radixdlt/node/lib && \
    sudo systemctl start radixdlt-node
then
    echo "Successfully installed node and restarted."
else
    echo "Error: Failed to install and restart node."
fi
