## restart the services on the pi

sudo systemctl restart kahrabaiq-agent
sudo systemctl restart kahrabaiq-command-runner
sudo systemctl restart kahrabaiq-summary-sync
sudo systemctl restart kahrabaiq-iot-live-publisher
sudo systemctl restart kahrabaiq-sensor-receiver

## services details 
systemctl list-units 'kahrabaiq-*' --type=service --all

## access pi env file 
sudo nano /etc/kahrabaiq/pi.env

## status of the pi services 
sudo systemctl status \
  kahrabaiq-agent \
  kahrabaiq-command-runner \
  kahrabaiq-iot-live-publisher \
  kahrabaiq-sensor-receiver \
  kahrabaiq-summary-sync \
  --no-pager