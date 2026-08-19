$vmUser = "prostoponchik"
$vmHost = "prostoponchik-matebox-9.ukwest.cloudapp.azure.com"

ssh "$vmUser@$vmHost" "sudo mkdir -p /app && sudo chown -R ${vmUser}:${vmUser} /app"

scp -r app/* "${vmUser}@${vmHost}:/app"

ssh "$vmUser@$vmHost" @'
sudo apt-get update
sudo apt install -y python3-pip
cd /app
sudo mv todoapp.service /etc/systemd/system/todoapp.service
sudo systemctl daemon-reload
sudo systemctl start todoapp
sudo systemctl enable todoapp
'@

ssh "$vmUser@$vmHost" "systemctl status todoapp --no-pager"