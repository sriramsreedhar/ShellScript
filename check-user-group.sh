#!/bin/bash

if ! getent group web-track; then
  groupadd web-track
fi

if ! getent passwd sriram; then
  useradd -g examplegroup -G wheel sriram
fi

if ! id -nG sriram | grep -q 'examplegroup wheel'; then
  usermod -g examplegroup -G wheel sriram
fi

if ! test -d ~sriram/.ssh; then
  mkdir -p ~sriram/.ssh
fi

chown sriram.examplegroup ~sriram/.ssh

if ! grep -q alice@localhost ~alice/.ssh/authorized_keys; then
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAm3TAgMF/2RY+r7KIeUoNbQb1TP6ApOtg\
JPNV0TY6teCjbxm7fjzBxDrHXBS1vr+fe6xa67G5ef4sRLl0kkTZisnIguXqXOaeQTJ4Idy4LZEVVb\
ngkd2R9rA0vQ7Qx/XrZ0hgGpBA99AkxEnMSuFrD/E5TunvRHIczaI9Hy0IMXc= \
sriram@localhost" >> ~sriram/.ssh/authorized_keys
fi

chmod 600 ~sriram/.ssh/authorized_keys
