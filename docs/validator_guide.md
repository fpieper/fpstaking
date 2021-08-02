# Production-grade Standalone Validator Guide

This guide presents a straightforward and focused guide to set up a production grade validator node.
It won't discuss all possible ways to set up a standalone node. The guide is tested and based on Ubuntu 20.04.

This is work in progress and some parts may change with the upcoming node releases.

# Basic Setup

## Create User
Create a user which you use instead of root (pick your own username). 
```
adduser john
```

Add user to sudo group
```
adduser john sudo
```

Change user and go to home directory
```
su - john
```

Lock root password to disable root login via password
(don't confuse with `-d` it removes the password and allows to login without a password)
```
sudo passwd -l root
```

## Hostname

You may want to set a different hostname to make distinguishing between your different nodes easier e.g.:
```
sudo hostnamectl set-hostname mainnet-1
```

## SSH
Based on https://withblue.ink/2016/07/15/stop-ssh-brute-force-attempts.html

### Public Key Authentication
It is recommended to use ED25519 keys for SSH (same like Radix is using itself for signing transactions).
Generate a key with a strong passphrase to protect it on your CLIENT system.

On Linux:
```
ssh-keygen -t ed25519
```
On Windows PuTTYgen can be used to generate an ED25519 key.

On the `SERVER` paste your generated public key (in OpenSSH format) into `authorized_keys`:
```
mkdir -p ~/.ssh && nano ~/.ssh/authorized_keys
```

Remove all "group" and "other" permissions and ensure ownership of `.ssh` is correct:
```
chmod -R go= ~/.ssh
chown -R john:john ~/.ssh
```

Further details:
- https://medium.com/risan/upgrade-your-ssh-key-to-ed25519-c6e8d60d3c54
- https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys-on-ubuntu-20-04

### Secure Configuration
To secure SSH we:
 - Change the port (use your own custom port instead of `1234`).
   Though this doesn't really make your node more secure, but stops a lot of low effort 'attacks' appearing in your log files.
 - Disable password authentication
 - Disable root login
 - Only allow our own user `john` to connect

Modify or add the following settings to `/etc/ssh/sshd_config`.
```
sudo nano /etc/ssh/sshd_config
```
```
Port 1234
PasswordAuthentication no
PermitRootLogin no
AllowUsers john
```


### Restart SSH
To activate the changes restart the SSH service
```
sudo systemctl restart sshd
```

## Firewall (using UFW)
First, we ensure that safe defaults are set (they should be in a clean installation) 
```
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Second, we will only allow the custom SSH port and Radix network gossip on port 30000/tcp.
```
sudo ufw allow 1234/tcp
sudo ufw allow 30000/tcp
```

Afterwards we enable the firewall and check the status.
```
sudo ufw enable
sudo ufw status
```

Be careful and verify whether you can successfully open a new SSH connection before
closing your existing session. Now after you ensured you didn't lock yourself out of your
server we can continue with setting up the Radix node itself.

## Update System
Update package repository and update system:
```
sudo apt update -y
sudo apt-get dist-upgrade
```

## Automatic system updates
We want automatic unattended security updates (based on https://help.ubuntu.com/community/AutomaticSecurityUpdates)
```
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

You can check whether it created the `/etc/apt/apt.conf.d/20auto-upgrades` file with the following content:
```
cat /etc/apt/apt.conf.d/20auto-upgrades
```
```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

If you want to configure optional email notifications you can check out this article 
https://linoxide.com/enable-automatic-updates-on-ubuntu-20-04/.


## Kernel live patching
We will use `canonical-livepatch` for kernel live patching.
First we need to check whether you are running the `linux-generic` kernel
(or any of these `generic, lowlatency, aws, azure, oem, gcp, gke, gkeop`
https://wiki.ubuntu.com/Kernel/Livepatch - then you can skip installing a different kernel
and move to enabling `livepatch` directly).
```
uname -a
```

If you are not running linux-generic, you need to uninstall your current kernel
(replace `linux-image-5.4.0-1040-kvm` with your kernel version) and then install linux-generic:
https://www.reddit.com/r/Ubuntu/comments/7pujtv/difference_between_linuxgeneric_and_linuxkvm/
```
dpkg --list | grep linux-image
sudo apt-get remove --purge linux-image-5.4.0-1040-kvm
sudo apt install linux-generic
sudo update-grub
sudo reboot
```

Attach the machine to your Ubuntu account and activate livepatch (register for a token on https://ubuntu.com/security/livepatch)
```
sudo ua attach <your token>
sudo snap install canonical-livepatch
sudo ua enable livepatch
```

To reinstall your old kernel (if linux-kvm was previously used) - uninstall linux-generic kernel like above and then:
```
sudo apt install linux-kvm
```

Check for status
```
sudo canonical-livepatch status --verbose
```

Troubleshooting: maybe reinstalling the kernel if necessary
```
sudo apt-get install --reinstall linux-generic
```

## Shared Memory Read Only
Based on https://www.techrepublic.com/article/how-to-enable-secure-shared-memory-on-ubuntu-server/

Add the following line `/etc/fstab`:
```
none /run/shm tmpfs defaults,ro 0 0
```

Enable changes
```
sudo mount -a
sudo reboot
```


# Radix Node
We install the Radix node based on the standalone instructions form the documentation
https://docs.radixdlt.com/main/node/systemd-install-node.html. 

## Dependencies
Install the necessary dependencies and initiate randomness to securely generate keys.
```
sudo apt install -y rng-tools openjdk-11-jdk unzip wget jq
sudo rngd -r /dev/random
```

## Create Radix User
Create a specific user for running the Radix node. The user is created with a locked password
and can only be switched to via `sudo su - radixdlt`.
```
sudo useradd radixdlt -m -s /bin/bash
```

## Service Control
Allow radix user to control the radix node service.
```
sudo sh -c 'cat > /etc/sudoers.d/radixdlt << EOF
radixdlt ALL= NOPASSWD: /bin/systemctl enable radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl restart radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl stop radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl start radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl reload radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl status radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl enable radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl restart radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl stop radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl start radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl reload radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl status radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl status radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl restart grafana-agent
radixdlt ALL= NOPASSWD: /bin/sed -i s/fullnode/validator/g /etc/grafana-agent.yaml
radixdlt ALL= NOPASSWD: /bin/sed -i s/validator/fullnode/g /etc/grafana-agent.yaml
EOF'
```


## Create System Service file and directories
We create the systemd service and set the correct ownership
(we do that now because the radixdlt user does not have the permissions):
```
sudo touch /etc/systemd/system/radixdlt-node.service
sudo chown radixdlt:radixdlt /etc/systemd/system/radixdlt-node.service
````

Also we create the necessary directories and set the ownership:
```
sudo mkdir /etc/radixdlt/
sudo chown radixdlt:radixdlt -R /etc/radixdlt
sudo mkdir /data
sudo chown radixdlt:radixdlt /data
sudo mkdir -p /opt/radixdlt/releases
sudo chown -R radixdlt:radixdlt /opt/radixdlt
```

Add `/opt/radixdlt` to `PATH`:
```
sudo sh -c 'cat > /etc/profile.d/radixdlt.sh << EOF
PATH=$PATH:/opt/radixdlt
EOF'
```

## Install Node
Switch to radixdlt user first
```
sudo su - radixdlt
```

I developed a seamless install and update script which downloads the last release
from `https://github.com/radixdlt/radixdlt/releases` and waits until one proposal was made to
restart the node to minimise the downtime.
If the interval between proposals is higher than around 5 seconds then there will be zero missed proposals:
```
curl -Lo /opt/radixdlt/update-node \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/update-node && \
chmod +x /opt/radixdlt/update-node
```

Installs or updates the radix node with the latest available version.
```
update-node
```

The argument `force` bypasses the check of the current installed version (mostly useful for testing). 
```
update-node force
```

Change directory for following steps.
```
cd /etc/radixdlt/node
```

## Secrets
Create secrets directories (one for validator and one for full node mode)
```
mkdir /etc/radixdlt/node/secrets-validator
mkdir /etc/radixdlt/node/secrets-fullnode
```

### Key Copy or Generation
The idea is to have two folders with configurations for a validator and a fullnode setting with different keys.
`/etc/radixdlt/node/secrets-validator` contains the configuration for a validator.
`/etc/radixdlt/node/secrets-fullnode` contains the configuration for a fullnode.
We will later to be able to switch between being a validator or fullnode.
This is useful for failover scenarios.

Either copy your already existing keyfiles `validator.ks` to `/etc/radixdlt/node/secrets-validator` or `/etc/radixdlt/node/secrets-fullnode` or create a new keys.
Use a password generator of your choice to generate a secure password, don't use your regular one because
it will be written in plain text on disk and loaded as environment variable.
```
./bin/keygen --keystore=secrets-validator/node-keystore.ks --password=YOUR_VALIDATOR_PASSWORD
./bin/keygen --keystore=secrets-fullnode/node-keystore.ks --password=YOUR_FULLNODE_PASSWORD
```

Don't forget to set the ownership and permissions (and switch user again):
```
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-validator/
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-fullnode/
sudo su - radixdlt
cd /etc/radixdlt/node
```

To achieve high uptime, it is important to also have a backup node for maintenance or failover.
Your main and backup node will have the same validator key (node-keystore.ks), but they both have different fullnode keys
(which leads to 3 different keys in total: 1 key used as validator, 2 keys used for the full nodes).
Please also checkout this article for further details: https://docs.radixdlt.com/main/node/maintaining-uptime.html.

### Environment file
Set java options and the previously used keystore password.
```
cat > /etc/radixdlt/node/secrets-validator/environment << EOF
JAVA_OPTS="-server -Xms8g -Xmx8g -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
RADIX_NODE_KEYSTORE_PASSWORD=YOUR_VALIDATOR_PASSWORD
EOF

cat > /etc/radixdlt/node/secrets-fullnode/environment << EOF
JAVA_OPTS="-server -Xms8g -Xmx8g -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
RADIX_NODE_KEYSTORE_PASSWORD=YOUR_FULLNODE_PASSWORD
EOF
```

### Restrict Access To Secrets
```
chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-validator
chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-fullnode
chmod 500 /etc/radixdlt/node/secrets-validator && chmod 400 /etc/radixdlt/node/secrets-validator/*
chmod 500 /etc/radixdlt/node/secrets-fullnode && chmod 400  /etc/radixdlt/node/secrets-fullnode/*
```

## Node Configuration
Create and adapt the node configuration to your needs.
Especially, set the `network.host_ip` to your own IP (`curl ifconfig.me`) and
bind both apis to localhost `127.0.0.1`.

```
curl -Lo /etc/radixdlt/node/default.config \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/default.config
nano /etc/radixdlt/node/default.config
```

Setting `api.archive.enable=true` enables archive mode otherwise the node is running as full node.
Then you may also want to enable the construction endpoint with `api.construction.enable=true`.

You also may want set a `seed_node` from another region instead of the one from the `EU` above.

If you want to run on stokenet (testnet) instead of mainnet, you can set `network.id=2` and use this seed node: 
```
radix://tn1qt9kqzzqyj27zv4n67f2jrzgd24hsxfwe8d4kw9j4msze7rpdg3guvk07jy@54.76.86.46:30000
```

For further detail and explanation check out the official documentation
https://docs.radixdlt.com/main/node/systemd-install-node.html#_configuration

## Systemd Service
Create the radixdlt-node service with the following config.
```
curl -Lo /etc/systemd/system/radixdlt-node.service \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/radixdlt-node.service
```

Also we enable the service at boot:
```
sudo systemctl enable radixdlt-node
```

## Failover

Until now the service the Radix node does not find the secrets (environment and key).
Depending on whether we want to run the node in validator or full node mode we create a symbolic link 
to the corresponding directory. For example to run in validator mode:
```
/etc/radixdlt/node/secrets -> /etc/radixdlt/node/secrets-validator 
```

To streamline this process of promoting in case of a failover from our primary node, I wrote a small script:
```
curl -Lo /opt/radixdlt/switch-mode \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/switch-mode && \
chmod +x /opt/radixdlt/switch-mode
```

To switch the mode simply pass the mode as first argument. Possible modes are: `validator` and `fullnode`
```
switch-mode <mode>
```

For example:
```
switch-mode validator
switch-mode fullnode
```

It also supports `force` in case you need to switch, but your validator isn't fully working or making proposals:
```
switch-mode fullnode force
```

For bootstrapping a new validator it is a good idea to start as a `fullnode` and then after full sync
switch to `validator` mode because this also directly tests failover or promoting to validator works fine.

Switching to fullnode waits for the next made proposal still in validator mode
and stops immediately afterwards to minimise downtime (or specifically the missed proposals)  

For maintenance failover just open SSH connections to both of your servers side-by-side.
1. Switch to fullnode mode on your validator: `/opt/radixdlt/switch-mode.sh fullnode` 
2. Wait until switching mode was successful
3. Immediately switch to validator mode on your backup node: `/opt/radixdlt/switch-mode.sh validator`

## Node-Runner CLI

The node-runner cli was already installed by the `update-node` script.
We only just need to fit the following environment variables to our setup: 
```
echo '
export NGINX_SUPERADMIN_PASSWORD=""
export NGINX_ADMIN_PASSWORD=""
export NGINX_METRICS_PASSWORD=""
export NODE_END_POINT="http://localhost:3333"' >> ~/.bashrc
```

The radix node-runner cli can now be called with for example:
```
radixnode api health
```

For further details checkout the official documentation https://github.com/radixdlt/node-runner.
Though only use the `api` feature of the cli to interact with the node endpoints in 
an easier way and not the `setup`/`update`/`nginx`/`monitoring` commands, since these
conflict with the minimal setup approach in this guide.


## Registering as a validator
This is based on the official documentation https://docs.radixdlt.com/main/node/systemd-register-as-validator.html.
Please take a look for further details, I mainly added it here because our endpoints are slightly different.

We first get the node's wallet address (`address`) with:
```
curl -s -d '{ "jsonrpc": "2.0", "method": "account.get_info", "params": [], "id":1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/account" | jq
```

We can also get both the node's wallet address (`owner` - prefixed with `rv` (mainnet) and `tv` (stokenet))
and the validator address (`address`)
```
curl -s -d '{"jsonrpc": "2.0", "method": "validation.get_node_info", "params": [], "id": 1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/validation" | jq
```

Then send at least 30 XRD to `wallet address` via your Radix Desktop Wallet.

Register your node (or more specifically your key as validator).
Think about and adapt every parameter, especially:
- `validator` - the validator address prefixed with `rv` (mainnet) or `tv` (stokenet)
- `name`
- `url`
- `validatorFee` - specified to up to two decimals of precision. e.g. 1 or 1.75
- `allowDelegation` - if false, only stake from owner below will be accepted
- `owner` - the owner receives all validator fees
  
Please check the official documentation for further details https://docs.radixdlt.com/main/node/systemd-register-as-validator.html#call-endpoint-to-register-validator
```
curl -s -X POST 'http://localhost:3333/account' -H 'Content-Type: application/json' \
-d '{"jsonrpc": "2.0","method": "account.submit_transaction_single_step",
"params":
{"actions": [
{"type": "RegisterValidator",
"validator": "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm"},
{"type": "UpdateValidatorMetadata",
"name": "🚀Florian Pieper Staking",
"url": "https://florianpieperstaking.com",
"validator": "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm"},
{"type": "UpdateValidatorFee",
"validator": "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm",
"validatorFee": 3.4},
{"type": "UpdateAllowDelegationFlag",
"validator": "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm",
"allowDelegation": true},
{"type": "UpdateValidatorOwnerAddress",
"validator": "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm",
"owner": "rdx1qsp5tf0ykd3dd6l84dgpgrs0fgt9slwnkfc0r39wqa98tc579nns73chn9fzm" }
]}, "id": 1}' | jq
```

You can then check if everything worked:
```
curl -s -d '{"jsonrpc": "2.0", "method": "validation.get_node_info", "params": [], "id": 1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/validation" | jq
```

Hint: the above request can be also used to update the values.
Just use one update action instead of all like above.

For example to update the validator metadata you can use this request.
```
curl -s -X POST 'http://localhost:3333/account' -H 'Content-Type: application/json' \
-d '{"jsonrpc": "2.0","method": "account.submit_transaction_single_step",
"params":
{"actions": [
{"type": "UpdateValidatorFee",
"validator": "rv1qfxktwkq9amdh678cxfynzt4zeua2tkh8nnrtcjpt7fyl0lmu8r3urllukm",
"validatorFee": 3.4}
]}, "id": 1}' | jq
```


# Monitoring with Grafana Cloud
I can recommend watching this comprehensive introduction to Grafana Cloud
https://grafana.com/go/webinar/intro-to-prometheus-and-grafana/.
First, sign up for a Grafana Cloud free account and follow their quickstart introductions to install
Grafana Agent on your node (via the automatic setup script). This basic setup is out of the scope of this guide.
You can find the quickstart introductions to install the Grafana Agent under
`Onboarding (lightning icon) / Walkthrough / Linux Server` and click on `Next: Configure Service`.
The Grafana Agent is basically a stripped down Promotheus which is directly writing to Grafana Cloud instead of storing metrics locally
(Grafana Agent behaves like having a built-in Promotheus). 
You should now have a working monitoring of your system load pushed to Grafana Cloud.

## Extending Grafana Agent Config
Add the `scrape_configs` configuration to `etc/grafana-agent.yaml`: 
```
sudo nano /etc/grafana-agent.yaml
```
```
prometheus:
configs:
- name: integrations
  scrape_configs:
    - job_name: radix-mainnet-fullnode
      static_configs:
        - targets: ['localhost:3333']
  remote_write:
    - basic_auth:
      password: secret
      username: 123456
      url: https://prometheus-blocks-prod-us-central1.grafana.net/api/prom/push
```

The prefixes like `radix-mainnet` before `fullnode` or `validator` are arbitrary and can be used
to have two dashboards (one for mainnet and one for stokenet) in the same Grafana Cloud account.

Just set the template variable `job` to `radix-mainnet-validator` in your mainnet dashboard
and `radix-stokenet-validator` in your stokenet dashboard.

The switch-mode script replaces `fullnode` with `validator` and vice versa.
Set `job_name` in the config above to e.g. `radix-mainnet-fullnode` if you are running in fullnode mode and
`radix-mainnet-validator` if you are running as validator.

And restart to activate the new settings:
```
sudo systemctl restart grafana-agent
```

## Radix Dashboard

I adapted the official `Radix Node Dashboard`
https://github.com/radixdlt/node-runner/blob/main/monitoring/grafana/provisioning/dashboards/sample-node-dashboard.json
and modified it a bit for usage in Grafana Cloud (including specific job names for `radix-validator` and `radix-fullnode` for failover).
You can get the `dashboard.json` from https://github.com/fpieper/fpstaking/blob/main/docs/config/dashboard.json.
You only need to replace `<your grafana cloud name>` with your own cloud name
(three times, since it seems the alerts have problems to process a datasource template variable).
It is a good idea to replace the values and variables in your JSON and then import the JSON as dashboard into Grafana Cloud.

## Alerts

### Spike.sh for phone calls
To get phone proper notifications via phone calls in case of Grafana Alerts I am using Spike.sh.
It only costs 7$/month and is working great.
How you can configure Spike.sh as `Notification Channel` is described here:
https://docs.spike.sh/integrations-guideline/integrate-spike-with-grafana.
Afterwards you can select `Spike.sh` in your alert configurations.

### Grafana Alerts
You can find the alerts by clicking on the panel title / Edit / Alert.

I set an alert on the proposals made panel, which fires an alert if no proposal was made in the last 2 minutes.
However, this needs a bit tuning for real world condition (worked fine in betanet conditions).

You also need to set `Notifications` to `Spike.sh` (if you configured the `Notification Channel` above).
Or any other notification channel if you prefer `PagerDuty` or `Telegram`.

# More Hardening
## SSH
- https://serverfault.com/questions/275669/ssh-sshd-how-do-i-set-max-login-attempts  
- Restrict access to the port:
    - use a VPN
    - only allow connections from a fix IP address
      ```
      sudo ufw allow from 1.2.3.4 to any port ssh
      ```

## Restrict Local Access (TTY1, etc)
We can additionally restrict local access.
However, this obviously leads results in that you won't be able to login without SSH in emergencies.
(booting into recovery mode works with most virtual servers, but causes downtime).
But since we have multiple backup servers this can be a fair trade-off.

Uncomment or add in this file
```
sudo nano /etc/pam.d/login
```
the following line:
```
account required pam_access.so
```

Then uncomment or add in this file
```
sudo nano /etc/security/access.conf
```
the following line:
```
-:ALL:ALL
```

For further details:
- https://linuxconfig.org/how-to-restrict-users-access-on-a-linux-machine

# Logs & Status

Shows radix node logs with colours:
```
sudo journalctl -f -u radixdlt-node --output=cat
```

Shows node health (`BOOTING`, `SYNCING`, `UP`, `STALLED`, `OUT_OF_SYNC`)
```
curl -s localhost:3333/health | jq
```

Show account information:
```
curl -s -d '{ "jsonrpc": "2.0", "method": "account.get_info", "params": [], "id":1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/account" | jq
```

Show node information:
```
curl -s -d '{"jsonrpc": "2.0", "method": "validation.get_node_info", "params": [], "id": 1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/validation" | jq
```

Shows `targetStateVersion` (versions are kind of Radix's blocks in Olympia - how many blocks are synced):
```
curl -s -X POST 'http://localhost:3333/system' -d '{"jsonrpc": "2.0", "method": "sync.get_data", "params": [], "id": 1}' | jq ".result.targetStateVersion"
```

Shows the difference sync difference to the network.
Should be `0` if the node is fully synced (if `targetCurrentDiff` isn't `0`)
```
curl -s -X POST 'http://localhost:3333/system' -d '{"jsonrpc": "2.0", "method": "sync.get_data", "params": [], "id": 1}' | jq
```

Shows current validator information:
```
curl -s -d '{"jsonrpc": "2.0", "method": "validation.get_node_info", "params": [], "id": 1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/validation" | jq
```

Get network peers:
```
curl -s -d '{"jsonrpc": "2.0", "method": "networking.get_peers", "params": [], "id": 1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/system" | jq
```

Get network configuration:
```
curl -s -d '{"jsonrpc": "2.0", "method": "networking.get_configuration", "params": [], "id": 1}' -H "Content-Type: application/json" -X POST "http://localhost:3333/system" | jq
```
