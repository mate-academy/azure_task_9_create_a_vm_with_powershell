#! /bin/bash 

pip install --break-system-packages -r requirements.txt # did not work without --break-system-packages flag on Ubuntu 22.04 and Python 3.11+
python3 manage.py migrate
python3 manage.py runserver 0.0.0.0:8080