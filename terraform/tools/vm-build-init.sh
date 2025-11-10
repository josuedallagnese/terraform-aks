#!/bin/bash

sudo apt update -y 
sudo apt upgrade -y

# jq
sudo apt install jq -y

# unzip
sudo apt install unzip -y

# azure-cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# helm
curl -sL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo bash

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin
kubectl version --client

# Docker
sudo apt-get install docker.io -y

# k9s
sudo snap install k9s
sudo ln -s /snap/k9s/current/bin/k9s /snap/bin/
k9s version

# postgresql client
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
  sudo gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg
echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
  sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null
sudo apt update -y
sudo apt install -y postgresql-client-16
