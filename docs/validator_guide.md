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
https://docs.radixdlt.com/main/node/standalone-install-node.html. 

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
sudo sh -c ' cat > /etc/sudoers.d/radixdlt << EOF
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
```


## Install Node
Switch to radixdlt user first
```
sudo su - radixdlt
```

Go to `https://github.com/radixdlt/radixdlt/releases` and check for the latest updates, download and extract them:
```
wget https://github.com/radixdlt/radixdlt/releases/download/1.0-beta.35.1/radixdlt-dist-1.0-beta.35.1.zip
unzip radixdlt-dist-1.0-beta.35.1.zip
mv radixdlt-1.0-beta.35.1/ /etc/radixdlt/node
cd /etc/radixdlt/node
```

## Secrets
Create secrets directories (one for validator and one for full node mode)
```
mkdir /etc/radixdlt/node/secrets-validator
mkdir /etc/radixdlt/node/secrets-fullnode
```

### Key Copy or Generation
The idea is to have two folders with configuration for a validator and a fullnode setting with different keys.
`/etc/radixdlt/node/secrets-validator` contains the configuration for a validator.
`/etc/radixdlt/node/secrets-fullnode` contains the configuration for a fullnode.
We will later to be able to switch between being a validator or fullnode.
This is useful for failover scenarios.

Either copy your already existing keyfiles `validator.ks` to `/etc/radixdlt/node/secrets-validator` or `/etc/radixdlt/node/secrets-fullnode` or create a new keys.
Use a password generator of your choice to generate a secure password, don't use your regular one because
it will be written in plain text on disk and loaded as environment variable.
```
./bin/keygen --keystore=secrets-validator/validator.ks --password=SET_YOUR_VALIDATOR_PASSWORD
./bin/keygen --keystore=secrets-fullnode/validator.ks --password=SET_YOUR_FULLNODE_PASSWORD
```

Remove password from Bash history afterwards, would be better to be able to set the password via a prompt.

Don't forget to set the ownership and permissions (and switch user again):
```
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-validator/
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-fullnode/
sudo su - radixdlt
cd /etc/radixdlt/node
```

### Environment file
Set java options and the previously used keystore password. I increased the Java heap from 3 GB to 4 GB.
```
cat > /etc/radixdlt/node/secrets-validator/environment << EOF
JAVA_OPTS="-server -Xms4g -Xmx4g -XX:+HeapDumpOnOutOfMemoryError -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
RADIX_NODE_KEYSTORE_PASSWORD=SET_YOUR_VALIDATOR_PASSWORD
EOF

cat > /etc/radixdlt/node/secrets-fullnode/environment << EOF
JAVA_OPTS="-server -Xms4g -Xmx4g -XX:+HeapDumpOnOutOfMemoryError -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
RADIX_NODE_KEYSTORE_PASSWORD=SET_YOUR_FULLNODE_PASSWORD
EOF
```

### Restrict Access To Secrets
```
chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-validator
chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-fullnode
chmod 500 /etc/radixdlt/node/secrets-validator && chmod 400 /etc/radixdlt/node/secrets-validator/*
chmod 500 /etc/radixdlt/node/secrets-fullnode && chmod 400  /etc/radixdlt/node/secrets-fullnode/*
```

## Universe.json
We get the `universe.json` which is necessary for bootstrapping our node.
```
curl -k https://52.48.95.182/universe.json > /etc/radixdlt/node/universe.json
```

## Node Configuration
Create and adapt the node configuration to your needs.
Especially, set the host IP to your own IP (`curl ifconfig.me`) and
binding both apis to localhost `127.0.0.1`.

```
nano /etc/radixdlt/node/default.config
```
```
ntp=false
ntp.pool=pool.ntp.org

universe.location=/etc/radixdlt/node/universe.json
node.key.path=/etc/radixdlt/node/secrets/validator.ks
network.tcp.listen_port=30000
network.tcp.broadcast_port=30000
network.seeds=52.48.95.182:30000
host.ip=1.2.3.4
db.location=/data

node_api.port=3333
client_api.enable=false
client_api.port=8080
log.level=debug

api.node.bind.address=127.0.0.1
api.archive.bind.address=127.0.0.1
```

Setting `client_api.enable=true` enables archive mode otherwise the node is running as full node.
`api.node.bind.address` and `api.archive.bind.address` is not read in the current beta,
but this will work in one of the next updates.

For further detail and explanation check out the official documentation
https://docs.radixdlt.com/main/node/standalone-install-node.html#create-node-configuration-file-for-standalone-install

## Systemd Service
Create the radixdlt-node service with the following config.
```
nano /etc/systemd/system/radixdlt-node.service
```
```
[Unit]
Description=Radix DLT Validator
After=local-fs.target
After=network-online.target
After=nss-lookup.target
After=time-sync.target
After=systemd-journald-dev-log.socket
Wants=network-online.target

[Service]
EnvironmentFile=/etc/radixdlt/node/secrets/environment

User=radixdlt
WorkingDirectory=/etc/radixdlt/node
ExecStart=/etc/radixdlt/node/bin/radixdlt
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure

[Install]
WantedBy=multi-user.target
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

To streamline this process of promoting in case of a failover from our primary node, I wrote a small script.
Create the file `/etc/radixdlt/node/switch-mode.sh` (and set permissions) 
```
nano /etc/radixdlt/node/switch-mode.sh
chmod +x /etc/radixdlt/node/switch-mode.sh
```
with the following content:
```
#!/bin/bash

check_return_code () {
    if [[ $? -eq 0 ]]
    then
        echo "Successfully switched mode and restarted."
    else
        echo "Error: Failed to switch mode and restart."
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
elif [[ "$1" == "fullnode" ]]
then
    echo "Restarting Radix Node in fullnode mode ..."
    sudo systemctl stop radixdlt-node && \
    rm -f /etc/radixdlt/node/secrets && \
    ln -s /etc/radixdlt/node/secrets-fullnode /etc/radixdlt/node/secrets && \
    sudo systemctl start radixdlt-node
    check_return_code
fi
```

To switch the mode simply pass the mode as first argument. Possible modes are: `validator` and `fullnode`
```
/etc/radixdlt/node/switch-mode.sh <mode>
```

For example:
```
/etc/radixdlt/node/switch-mode.sh validator
/etc/radixdlt/node/switch-mode.sh fullnode
```

For bootstrapping a new validator it is a good idea to start as a `fullnode` and then after full sync
switch to `validator` mode because this also directly tests failover or promoting to validator works fine.

Keep in mind to restart the `metrics-exporter` after switching to validator mode (it is later described how).
However, the metrics will be included into the `radixnode` and the separate `metrics-exporter` will not be needed
anymore.

## Registering as a validator
This is based on the official documentation https://docs.radixdlt.com/main/node/standalone-register-as-validator.html.
Please take a look for further details, I mainly added it here because our endpoints are slightly different.

We first get your `address` with:
```
curl -s -X  GET 'http://localhost:3333/node'
```

Then send some XRD to this address via your Radix Desktop Wallet.

Register your node (or more specifically your key as validator). Adapt the parameters as you like,
especially your `name` and `url`
```
curl -s -X POST 'http://localhost:3333/node/execute' -H 'Content-Type: application/json' \
  --data-raw '{"actions":[{"action":"RegisterValidator","params":{"name": "My Validator", "url": "https://my-validator.com" }}]}'
```

You can then check if everything worked:
```
curl -s -X POST http://localhost:3333/node/validator
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

Hint: the monitoring section is work in progress, because the new metrics API will change things a bit.

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
    - job_name: radixnode
      static_configs:
        - targets: ['localhost:8099']
  remote_write:
    - basic_auth:
      password: secret
      username: 123456
      url: https://prometheus-blocks-prod-us-central1.grafana.net/api/prom/push
```

And restart to activate the new settings:
```
sudo systemctl restart grafana-agent
```

## Metrics Exporter
This is only needed temporarily until the `/metrics` endpoint is directly offered
by the radix node (probably next version).


First extract the `app.jar` from the metrics exporter image (better do this on a different machine):
```
docker run -d radixdlt/metrics-exporter:1.0-beta.35
docker ps (to get the container name)
docker cp <containername>:/app.jar .
```

The metrics exporter does not find the `application.xml` if we run it as `radixdlt`.
Therefore we will run it as our own user `john`.
Create a directory `metrics-exporter` and copy the `app.jar` to there
(from your client system with your preferred method):
```
sudo mkdir ~/metrics-exporter
cd ~/metrics-exporter
```

Create `application.yml` in the same directory
```
nano application.yml
```
with:
```
metrics-exporter:
  root-api-url: http://localhost:3333
  collect-json-rpc-metrics: true
  root-json-rpc-url: http://localhost:8080
  rmi-host: #core:9010 # used to collect JMX metrics, will be placed in a URL like so: service:jmx:rmi:///jndi/rmi://{rmi-host}/jmxrmi
  ledger-folder: #./RADIXDB # will measure the size of this folder
  container-name:
```

Start the metrics exporter (in a tmux session):
```
tmux
java -jar app.jar
```
Now your metrics are pushed to Grafana Cloud.


## Radix Dashboard Template

### Prepared Dashboard
I did the steps I described below under "build yourself" and created a ready to use template called
`dashboard-with-proposals.json` https://github.com/fpieper/fpstaking/blob/main/docs/dashboard-with-proposals.json.
You only need to replace `<your grafana cloud name>` with your own cloud name
(two times, since it seems the alerts have problems to process a datasource template variable).
It is a good idea to replace the values and variables in your JSON and then import the complete JSON into Grafana Cloud.

### Build Yourself
Or you can start with the official `Radix Node Dashboard`
https://github.com/radixdlt/node-runner/blob/main/monitoring/grafana/provisioning/dashboards/sample-node-dashboard.json
and modify it a bit for usage in Grafana Cloud:

Replace all `"datasource": null` and `"datasource": "-- Grafana --"` with `"datasource":  "$datasource"`.

Then modify and extends the variables in `templating`. Change the `instance` variable to `localhost:8099` and
add the variable `datasource` (you need to lookup the correct datasource name in Grafana Cloud):
```
"templating": {
  "list": [
    {
      "description": "If case you are running many nodes, use this var to target a single on",
      "error": null,
      "hide": 2,
      "label": null,
      "name": "instance",
      "query": "localhost:8099",
      "skipUrlSync": false,
      "type": "constant"
    },
    {
      "description": "Set your datasource",
      "error": null,
      "hide": 2,
      "label": "Data Source",
      "name": "datasource",
      "query": "grafanacloud-<your grafana cloud name>-prom",
      "skipUrlSync": false,
      "type": "constant"
    }
  ]
},
```

Checkout `dashboard-with-proposals.json` to see how I added `proposals_made`. 

Afterwards, you can now import your dashboard into Grafana Cloud, and the correct values should show up.

### Limitation
The dashboard currently does not distinguish between multiple nodes like a validator or full node.
Therefore, without further modifications only run the `metrics-exporter` on your node which is validating
(after you switched to `validator` mode).

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


# Logs & Status

Shows radix node logs with colours:
```
sudo journalctl -f -u radixdlt-node --output=cat
```

Shows `target_state_version` (versions are kind of Radix's blocks in Olympia - how many blocks are synced):
```
curl -s localhost:3333/system/info | jq ".info.counters.sync.target_state_version"
```

Shows the difference sync difference to the network.
Should be `0` if the node is fully synced (if `target_state_version` isn't `0`)
```
curl -s localhost:3333/system/info | jq ".info.counters.sync.target_current_diff"
```

Shows current validator information:
```
curl -s -X POST 'http://localhost:3333/node/validator' | jq
```
