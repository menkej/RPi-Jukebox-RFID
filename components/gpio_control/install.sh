#!/bin/bash

if [[ $(id -u) != 0 ]]; then
   echo "This script should be run using sudo"
   exit 1
fi


echo 'disable old services: phoniebox-gpio-buttons and phoniebox-rotary-encoder'
systemctl stop phoniebox-rotary-encoder.service
systemctl disable phoniebox-rotary-encoder.service
systemctl stop phoniebox-gpio-buttons.service
systemctl disable phoniebox-gpio-buttons.service


echo 'Install all required python modules'
python3 -m pip install --upgrade --force-reinstall -r requirements.txt

echo 'Installing GPIO_Control service'
echo

USER_HOME=$(eval echo ~${SUDO_USER})
CONFIG_PATH=$USER_HOME/.config/phoniebox
FILE=$CONFIG_PATH/gpio_settings.ini
if [ ! -d $CONFIG_PATH ]; then
    mkdir -p $USER_HOME/.config/phoniebox/ ;
fi;

if test -f "$FILE"; then
    echo "$FILE exist"
    echo "Script will not install a configuration"
else
    unset options i
    while IFS= read -r -d $'\0' f; do
      options[i++]="$f"
    done < <(find ./example_configs/ -maxdepth 1 -type f -name "*.ini" -print0 )


    echo  'Please choose a default configuration'
    select opt in "${options[@]}" "Stop the script"; do
      case $opt in
        *.ini)
          echo "Configuration  file $opt selected"
          echo "Copy file to $FILE"
          echo cp -v $opt $FILE
          cp -v $opt $FILE
	  chown -R $(whoami) $FILE
          break
          ;;
        "Stop the script")
          echo "You chose to stop"
          break
          ;;
        *)
          echo "This is not a number"
          ;;
      esac
    done

fi
chown -R ${SUDO_USER}:${SUDO_USER} $USER_HOME/.config/phoniebox/

echo
echo 'Installing GPIO_Control service, this will require to enter your password up to 3 times to enable the service'
read -p "Press enter to continue " -n 1 -r
SERVICE_FILE=/etc/systemd/system/phoniebox_gpio_control.service
if test -f "$SERVICE_FILE"; then
   echo "$SERVICE_FILE exists.";
   echo 'systemctl daemon-reload'
   systemctl daemon-reload
   echo 'restarting service'
   systemctl restart phoniebox_gpio_control.service
   read -p "Press enter to continue " -n 1 -r;

    #echo "systemctl daemon-reload"
    #systemctl daemon-reload
else
    cp -v ./example_configs/phoniebox_gpio_control.service /etc/systemd/system/
    echo "systemctl start phoniebox_gpio_control.service"
    echo 'systemctl daemon-reload'
    systemctl start phoniebox_gpio_control.service
    echo "systemctl enable phoniebox_gpio_control.service"
    systemctl enable phoniebox_gpio_control.service
fi
SERVICE_STATUS="$(systemctl is-active phoniebox_gpio_control.service)"
if [ "${SERVICE_STATUS}" = "active" ]; then
    echo "Phoniebox GPIO Service started correctly ....."
else
    echo ""
    FRED="\033[31m"
    FBOLD='\033[1;31m'
    RS="\033[0m"
    echo -e "$FRED"$FBOLD"Problem during installation occured $RS"
    echo "   Service not running, please check functionallity by running gpio_control.py "
    echo "   in the directory ~/RPi-Jukebox-RFID/components/gpio_control: "
    echo "      $ cd ~/RPi-Jukebox-RFID/components/gpio_control"
    echo "      $ python gpio_control.py"
    echo "   or check output of journaclctl by:"
    echo "      $ journalctl -u phoniebox_gpio_control.service -f"
    exit 1
fi
#systemctl is-active --quiet phoniebox_gpio_control.service
#systemctl status phoniebox_gpio_control.service

