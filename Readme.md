# Readme
The script `deploy_install_deps.sh` deploys and run install_deps.sh as root on the compute nodes, from  the controller node.

The full terminal output for each node is saved to ~/install_logs/<node>_<timestamp>.log

The node also keeps its own copy in /var/log/install_deps.log.

## Current limitation
The script will ask the password before connecting to each node. The following (***untested!***) should generate a key for your current user and deploy it to each node as well:
```shell
ssh-keygen -t ed25519 # skip if you already have a key
# Replace node{1..5} with wathever name you are using for your computing nodes
for n in node{1..5}; do ssh-copy-id $n; done
# Replace <your_user> with your username
for n in node{1..5}; do
  ssh -t $n 'echo "<your_user> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/<your_user> && sudo chmod 0440 /etc/sudoers.d/<your_user>'
done
```
