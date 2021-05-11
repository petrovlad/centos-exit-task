#!/bin/bash

sudo -E -u mongo -H bash -c "export PATH=\"/apps/mongo${PATH:+:${PATH}}\"; echo $PATH"
sudo -E -u mongo -H bash -c "echo $PATH"
sudo -E -u mongo echo $PATH
echo $PATH

