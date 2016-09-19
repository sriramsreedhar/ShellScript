#/bin/bash
for i in `grep neutronapi /etc/hosts | awk '{print$1}'`; do ssh $i 'diff /etc/neutron/neutron.conf /etc/neutron/neutron.conf.2016*'; done
