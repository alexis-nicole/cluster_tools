ssh-keygen -t ed25519 # skip if you already have a key
# Replace node{1..5} with wathever name you are using for your computing nodes
for n in node{1..5}; do ssh-copy-id $n; done
# Replace <your_user> with your username
for n in node{1..5}; do
  ssh -t $n 'echo "<your_username> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/<your_username> && sudo chmod 0440 /etc/sudoers.d/<your_username>'
done
