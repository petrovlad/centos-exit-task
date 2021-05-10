#!/bin/bash

#sudo -u mongo -H sh -c "export PATH="/apps/mongo${PATH:+:${PATH}}"; echo $PATH"
sudo env "PATH=/qwerty"
sudo -u mongo -H sh -c "echo $PATH"
echo $PATH

