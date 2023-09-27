# Production-grade Standalone Validator Guide

This guide presents a straightforward and focused guide to set up a production grade validator node.
It won't discuss all possible ways to set up a standalone node. The guide is tested and based on Ubuntu 22.04.

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
```
Disclaimer: the kernel live patching section was tested on Ubuntu 20.04 and might need to be slightly adapted.
```
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

# <a name="radixnode"></a>Radix Node
We install the Radix node based on the standalone instructions form the documentation
https://docs.radixdlt.com/main/node-and-gateway/systemd-install-node.html. 

## Dependencies
Install the necessary dependencies and initiate randomness to securely generate keys.
```
sudo apt install -y rng-tools openjdk-17-jdk unzip jq curl
sudo rngd -r /dev/random
```

## Create Radix User
Create a specific user for running the Radix node. The user is created with a locked password
and can only be switched to via `sudo su - radixdlt` (if you have already created this user you can skip this).
```
sudo useradd radixdlt -m -s /bin/bash
```

## Service Control
Allow radix user to control the radix node service.
```
sudo sh -c 'cat > /etc/sudoers.d/radix-babylon << EOF
radixdlt ALL= NOPASSWD: /bin/systemctl enable radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl restart radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl stop radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl start radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl reload radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl status radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl enable radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl restart radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl stop radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl start radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl reload radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl status radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl status radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl restart grafana-agent
radixdlt ALL= NOPASSWD: /bin/sed -i s/fullnode/validator/g /etc/grafana-agent.yaml
radixdlt ALL= NOPASSWD: /bin/sed -i s/validator/fullnode/g /etc/grafana-agent.yaml
EOF'
```


## Systemd Service
Create the radixdlt-node service:
```
sudo curl -Lo /etc/systemd/system/radix-babylon.service \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/radix-babylon.service
```

Also we enable the service at boot:
```
sudo systemctl enable radix-babylon
```

## Create config and data directories
We create the necessary directories and set the ownership:
```
sudo mkdir /etc/radix-babylon/
sudo chown radixdlt:radixdlt -R /etc/radix-babylon
sudo mkdir /babylon-ledger
sudo chown radixdlt:radixdlt /babylon-ledger
sudo mkdir -p /opt/radix-babylon/releases
sudo chown -R radixdlt:radixdlt /opt/radix-babylon
```

Add `/opt/radix-babylon` to `PATH`:
```
sudo sh -c 'cat > /etc/profile.d/radix-babylon.sh << EOF
PATH=$PATH:/opt/radix-babylon
EOF'
```

## Install Node
Switch to radixdlt user first
```
sudo su - radixdlt
```

I developed a seamless install and update script which downloads the last release
from `https://github.com/radixdlt/babylon-node/releases` and waits until one proposal was made to
restart the node to minimise the downtime.
If the interval between proposals is higher than around 5 seconds then there will be zero missed proposals:
```
curl -Lo /opt/radix-babylon/update-node \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/update-node && \
chmod +x /opt/radix-babylon/update-node
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
cd /etc/radix-babylon/node
```

## Secrets
Create secrets directories (one for validator and one for full node mode)
```
mkdir /etc/radix-babylon/node/secrets-validator
mkdir /etc/radix-babylon/node/secrets-fullnode
```

### Key Copy or Generation
The idea is to have two folders with configurations for a validator and a fullnode setting with different keys.
`/etc/radix-babylon/node/secrets-validator` contains the configuration for a validator.
`/etc/radix-babylon/node/secrets-fullnode` contains the configuration for a fullnode.
We will later to be able to switch between being a validator or fullnode.
This is useful for failover scenarios.

Either copy your already existing keyfiles `node-keystore.ks` to `/etc/radix-babylon/node/secrets-validator` or `/etc/radix-babylon/node/secrets-fullnode` or create a new keys.
Use a password generator of your choice to generate a secure password, don't use your regular one because
it will be written in plain text on disk and loaded as environment variable.
```
./bin/keygen --keystore=secrets-validator/node-keystore.ks --password=YOUR_VALIDATOR_PASSWORD
./bin/keygen --keystore=secrets-fullnode/node-keystore.ks --password=YOUR_FULLNODE_PASSWORD
```

If you are migrating from Olympia you already have valid keyfiles here which you can copy:
```
cp /etc/radixdlt/node/secrets-validator/node-keystore.ks /etc/radix-babylon/node/secrets-validator/node-keystore.ks
cp /etc/radixdlt/node/secrets-fullnode/node-keystore.ks /etc/radix-babylon/node/secrets-fullnode/node-keystore.ks
```

Don't forget to set the ownership and permissions (and switch user again) - if you have used sudo to copy etc:
```
sudo chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-validator/
sudo chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-fullnode/
sudo su - radixdlt
cd /etc/radix-babylon/node
```

To achieve high uptime, it is important to also have a backup node for maintenance or failover.
Your main and backup node will have the same validator key (node-keystore.ks), but they both have different fullnode keys
(which leads to 3 different keys in total: 1 key used as validator, 2 keys used for the full nodes).
Please also checkout this article for further details: https://docs.radixdlt.com/main/node-and-gateway/maintaining-uptime.html.

### Environment file
Set java options, the previously used keystore password and the Rust JNI core lib.
```
cat > /etc/radix-babylon/node/secrets-validator/environment << EOF
JAVA_OPTS="--enable-preview -server -Xms12g -Xmx12g  -XX:MaxDirectMemorySize=2048m -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -Djava.library.path=/etc/radix-babylon/node/jni"
LD_PRELOAD=/etc/radix-babylon/node/jni/libcorerust.so
RADIX_NODE_KEYSTORE_PASSWORD=YOUR_VALIDATOR_PASSWORD
EOF

cat > /etc/radix-babylon/node/secrets-fullnode/environment << EOF
JAVA_OPTS="--enable-preview -server -Xms12g -Xmx12g  -XX:MaxDirectMemorySize=2048m -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -Djava.library.path=/etc/radix-babylon/node/jni"
LD_PRELOAD=/etc/radix-babylon/node/jni/libcorerust.so
RADIX_NODE_KEYSTORE_PASSWORD=YOUR_FULLNODE_PASSWORD
EOF
```

### Restrict Access To Secrets
```
chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-validator
chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-fullnode
chmod 500 /etc/radix-babylon/node/secrets-validator && chmod 400 /etc/radix-babylon/node/secrets-validator/*
chmod 500 /etc/radix-babylon/node/secrets-fullnode && chmod 400  /etc/radix-babylon/node/secrets-fullnode/*
```

## Node Configuration
Create and adapt the node configuration to your needs.
Especially, set the `network.host_ip` to your own IP (`curl ifconfig.me`) and
bind both apis to localhost `127.0.0.1`.

```
curl -Lo /etc/radix-babylon/node/default.config \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/default.config
nano /etc/radix-babylon/node/default.config
```

You also may want set a `seed_node` from another region instead of the one from the `EU` above.

If you want to run on stokenet (testnet) instead of mainnet, you can set `network.id=2` and use this seed nodes: 
```
radix://node_tdx_2_1qv89yg0la2jt429vqp8sxtpg95hj637gards67gpgqy2vuvwe4s5ss0va2y@13.126.248.88,radix://node_tdx_2_1qvtd9ffdhxyg7meqggr2ezsdfgjre5aqs6jwk5amdhjg86xhurgn5c79t9t@13.210.209.103,radix://node_tdx_2_1qwfh2nn0zx8cut5fqfz6n7pau2f7vdyl89mypldnn4fwlhaeg2tvunp8s8h@54.229.126.97,radix://node_tdx_2_1qwz237kqdpct5l3yjhmna66uxja2ymrf3x6hh528ng3gtvnwndtn5rsrad4@3.210.187.161
```

For further detail and explanation check out the official documentation
https://docs-babylon.radixdlt.com/main/node-and-gateway/systemd-install-node.html


### Olympia Migration
Get the node address from your olympia node (needs to match the one you are connecting to):
```
curl -s localhost:4333/system/configuration | jq -r .networking.node_address
```

/etc/radix-babylon/node/default.config:
```
genesis.olympia.node_bech32_address=rn1q....
```

## Failover

Until now the service the Radix node does not find the secrets (environment and key).
Depending on whether we want to run the node in validator or full node mode we create a symbolic link 
to the corresponding directory. For example to run in validator mode:
```
/etc/radix-babylon/node/secrets -> /etc/radix-babylon/node/secrets-validator 
```

To streamline this process of promoting in case of a failover from our primary node, I wrote a small script:
```
curl -Lo /opt/radix-babylon/switch-mode \
    https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/switch-mode && \
chmod +x /opt/radix-babylon/switch-mode
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
1. Switch to fullnode mode on your validator: `/opt/radix-babylon/switch-mode.sh fullnode` 
2. Wait until switching mode was successful
3. Immediately switch to validator mode on your backup node: `/opt/radix-babylon/switch-mode.sh validator`

## Node-Runner CLI
```
This section is currently outdated and refers to the Olympia nodes.
```
The node-runner cli was already installed by the `update-node` script.
We only just need to fit the following environment variables to our setup: 
```
echo '
export NGINX_SUPERADMIN_PASSWORD=""
export NGINX_ADMIN_PASSWORD=""
export NGINX_METRICS_PASSWORD=""
export NODE_END_POINT="http://localhost:3333"' >> ~/.bashrc
```

Now you need to logout and login back into the shell to enable the environment variables.

The radix node-runner cli can afterwards be called with for example:
```
radixnode api system health
```

For further details checkout the official documentation https://github.com/radixdlt/node-runner.
Though only use the `api` feature of the cli to interact with the node endpoints in 
an easier way and not the `setup`/`update`/`nginx`/`monitoring` commands, since these
conflict with the minimal setup approach in this guide.


## Registering as a validator
First of all we make sure that our node is running in `validator mode` to register the correct node key.
```
switch-mode validator
```

To register as validator please refer to the official documentation https://docs-babylon.radixdlt.com/main/node-and-gateway/register-as-validator.html Keep in mind to adapt the local port in `curl` commands if necessary.

# Monitoring with Grafana Cloud
```
This section is currently outdated and refers to the Olympia nodes.
```
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
          metrics_path: /prometheus/metrics
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
sudo journalctl -f -u radix-babylon --output=cat
```

Shows node health (`BOOTING`, `SYNCING`, `UP`, `STALLED`, `OUT_OF_SYNC`, `BOOTING_PRE_GENESIS`)
```
curl -s localhost:3334/system/health | jq
```

Shows current validator information:
```
curl -s localhost:3334/system/identity | jq
```

Get network peers:
```
curl -s localhost:3334/system/peers | jq
```

Get node configuration:
```
curl -s localhost:3334/system/configuration | jq
```


# Babylon Migration
To simplify the upgrade process we are going to run the migration in parallel to your current Olympia nodes.
This requires however to have enough memory (32GB should be enough, 4 CPU cores should work (untested) but would recommend 8 to be on the safe side).

## Preparations
Upgrade both nodes to Ubuntu 22.04 and node version 1.5.0 (if you didn't do that already). For details to upgrade the operating system see e.g.: https://jumpcloud.com/blog/how-to-upgrade-ubuntu-20-04-to-ubuntu-22-04

1. first upgrade your backup node (you can either update Ubuntu or the node first). The node can be updated as always using:
  `update-node`
2. switch your validator to the backup
3. upgrade your other node (currently the full node - also Ubuntu and Radix node)

## Olympia Node Configuration Change
These changes need to be applied to both nodes - your fullnode and validator.

### Bind Olympia End State endpoint to localhost

In your `/etc/radixdlt/node/default.config` add this line (if you are using an Olympia node on another server do not add this line or set `0.0.0.0`):
```
api.end-state.bind.address=127.0.0.1
```

### Change network listen port
To be able to run both nodes in parallel we set the Olympia listen port to `30001`:
```
sudo ufw allow 30001/tcp
sudo ufw reload
sudo ufw status
sudo nano /etc/radixdlt/node/default.config
```

/etc/radixdlt/node/default.config:
```
api.port=4333
network.p2p.listen_port=30001
network.p2p.broadcast_port=30001
```

As fallback in case needed also update the port in the `/opt/radixdlt/switch-mode` script.
```
HOST="http://localhost:4333"
```

After successful Babylon migration you can remove this firewall rule again with:
```
sudo ufw delete allow 30001/tcp
sudo ufw reload
sudo ufw status
```

### Increase assigned memory
In `/etc/radixdlt/node/secrets-validator/environment` and `/etc/radixdlt/node/secrets-fullnode/environment` (both nodes) change the memory settings:
```
JAVA_OPTS="... -Xms12g -Xmx12g ..."
```

You probably need to also adjust the permissions:
```
sudo chmod +w /etc/radixdlt/node/secrets-validator/environment
sudo chmod +w /etc/radixdlt/node/secrets-fullnode/environment

sudo nano /etc/radixdlt/node/secrets-validator/environment
sudo nano /etc/radixdlt/node/secrets-fullnode/environment

sudo su radixdlt
chmod 500 /etc/radixdlt/node/secrets-validator && chmod 400 /etc/radixdlt/node/secrets-validator/*
chmod 500 /etc/radixdlt/node/secrets-fullnode && chmod 400 /etc/radixdlt/node/secrets-fullnode/*

exit
```

### Olympia PATH variables
We need to remove the old PATH for Olympia by doing:
```
sudo rm /etc/profile.d/radixdlt.sh
```
This will take effect after logout / reboot. Until then better to use the explicit paths for the `switch-mode` and `update-node` script.

### Apply & verify new config
Afterwards restart your validator/fullnode with (if you want to be safe against proposal misses use the switch-mode script which waits for an propsal and then safely restarts):
```
sudo systemctl restart radixdlt-node
```

Verify afterwards that the endpoint is working with (it is a ):
```
john@radixnode:~$ curl localhost:3400/olympia-end-state
Invalid method, path exists for GET /olympia-end-state
```

## Install Babylon
The [Radix Node](#radix-node) section is updated to Babylon and will install the Babylon node in parallel to the Olympia node.
Best to install it first on your backup node to see if everything works fine and then on your current validator.
If you feel more comfortable you can also switch validators for that process (and always installing on the backup node).

Besides that, you want to run the Olympia and Babylon node on one machine in the same mode. On one server you are running both in validator mode and on one machine both in fullnode mode.

## Verify Babylon node setup
Finally we need to verify that the Babylon nodes are configured correctly and can connect to your (local) Olympia nodes.
For that check the logs on both nodes with:
```
sudo journalctl -f -u radix-babylon --output=cat
```

This should give you log messages like these:
```
2023-09-27T00:29:26,854 [INFO/OlympiaGenesisService/OlympiaGenesisService] - Querying the Olympia node http://127.0.0.1:3400 for genesis data (this may take a few minutes)
2023-09-27T00:29:26,899 [INFO/OlympiaGenesisService/OlympiaGenesisService] - Successfully connected to the Olympia mainnet node, but the end state hasn't yet been generated (will keep polling)...
2023-09-27T00:29:27,901 [INFO/OlympiaGenesisService/OlympiaGenesisService] - Querying the Olympia node http://127.0.0.1:3400 for genesis data (with test payload) (this may take a few minutes)
```

In this case everything is fine and you are ready for the Babylon migration.

## Take your front seats
Babylon is a huge milestone for Radix - take a seat and enjoy your front seats in the migration ;)
