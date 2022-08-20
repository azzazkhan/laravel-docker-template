#!/bin/bash

service php8.1-fpm start
apache2ctl -D FOREGROUND
