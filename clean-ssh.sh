for IP in $(grep ansible_host inventory | cut -d'=' -f2); do  ssh-keygen     -f /home/rcampove/.ssh/known_hosts  -R $IP; done 
