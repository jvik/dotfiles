#!/bin/bash

ansible-playbook --ask-become-pass -i localhost, -c local ~/.bootstrap/test.yml -vvvv
