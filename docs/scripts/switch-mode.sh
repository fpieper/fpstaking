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

check_return_code () {
    if [[ $? -eq 0 ]]
    then
        echo "Successfully switched radix mode and restarted."
    else
        echo "Error: Failed to switch radix mode and restart."
    fi
}

switch_grafana () {
    if [[ ! -f /etc/grafana-agent.yaml ]]
    then
        return
    fi
    if
        sudo sed -i "s/$1/$2/g" /etc/grafana-agent.yaml && \
        sudo systemctl restart grafana-agent
    then
        echo "Successfully switched grafana agent to $2 mode."
    else
        echo "Error: Failed to switch grafana agent to $2 mode."
    fi
}

if [[ "$1" == "validator" ]]
then
    echo "Restarting Radix Node in validator mode ..."
    sudo systemctl stop radixdlt-node && \
    rm -f /etc/radixdlt/node/secrets && \
    ln -s /etc/radixdlt/node/secrets-validator /etc/radixdlt/node/secrets && \
    sudo systemctl start radixdlt-node
    check_return_code
    switch_grafana "fullnode" $1
elif [[ "$1" == "fullnode" ]]
then
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
    echo "Restarting Radix Node in fullnode mode ..."
    sudo systemctl stop radixdlt-node && \
    rm -f /etc/radixdlt/node/secrets && \
    ln -s /etc/radixdlt/node/secrets-fullnode /etc/radixdlt/node/secrets && \
    sudo systemctl start radixdlt-node
    check_return_code
    switch_grafana "validator" $1
else
    echo "Radix Node Switch Mode"
    echo ""
    echo "Usage:"
    echo "  switch-mode fullnode      Switch radix node to fullnode mode."
    echo "  switch-mode validator     Switch radix node to validator mode."
fi
