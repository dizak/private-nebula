# This repo stores instructions and info about the Nebula network overlay private use

## What is Nebula?

As the [Nebula repo](https://github.com/slackhq/nebula) states:

*Nebula is a scalable overlay networking tool with a focus on performance,
simplicity and security.  It lets you seamlessly connect computers anywhere in
the world. Nebula is portable, and runs on Linux, OSX, and Windows.  (Also:
keep this quiet, but we have an early prototype running on iOS).  It can be
used to connect a small number of computers, but is also able to connect tens
of thousands of computers.

Nebula incorporates a number of existing concepts like encryption, security
groups, certificates, and tunneling, and each of those individual pieces
existed before Nebula in various forms.  What makes Nebula different to
existing offerings is that it brings all of these ideas together, resulting in
a sum that is greater than its individual parts.

You can read more about Nebula [here](https://medium.com/p/884110a5579)*

## Brief instructions overview

1. The nebula nodes communicate with each other over ```UDP``` tunnel.

1. The identity is established using the certificates. 

1. The initial communication is established via special node called lighthouse.
   Only the lighthouse should have public IP - so it can be reached before any
   tunnel gets created.

1. The certificates can be generated anywhere and then copied to the future
   nodes. Can also be generated in-place. Nevertheless, the certificate of the
   organization-level is required for issuing the certificates for the idividual
   nodes so it is better to issue the certificates in one place

## Conventions

1. The nebula binaries are located in ```/opt/nebula/``` 

1. The certificates/config files are located in ```/etc/nebula```

1. The organization name is ```izak-nebula```

1. The project @DigitalOcean for the lighthouse node is called ```nebula```

1. The lighthouse node VPS @DigitalOcean is called nebula-lighthouse

## Issuing the certificates

The IPs are set at the moment of creating the certificates

1. Create the certificate-key files for the organization. **These files must be
   present in the CWD when the certificates for the individual nodes get created
   in the subsequent steps**. The oganization level key file **is
   NOT required on ANY node for the nebula to operate**. This file should stay
   safe in a single place, ideally offline.

```console
/opt/nebula/nebula-cert ca -name 'izak-nebula'
```

1. Create the certificates for the individual nodes. This information is not
   really that sensitive, and can kept here:

```console
/opt/nebula/nebula-cert sign -name "lighthouse" -ip "192.168.101.1/24"
/opt/nebula/nebula-cert sign -name "raspberrypi_0" -groups "pck,raspberrypi" -ip "192.168.101.3/24"
/opt/nebula/nebula-cert sign -name "raspberrypi_1" -groups "kabaty,raspberrypi" -ip "192.168.101.2/24"
/opt/nebula/nebula-cert sign -name "120s" -groups "kabaty,laptop" -ip "192.168.101.4/24"
/opt/nebula/nebula-cert sign -name "raspberrypi_2" -ca-crt ./nebula-certificates/ca.crt -ca-key ./nebula-certificates/ca.key -out-crt ./nebula-certificates/raspberrypi_2.crt -out-key ./nebula-certificates/raspberrypi_2.key  -groups "twarda,raspberrypi" -ip "192.168.101.5/24"

```
## Creating the lighthouse node with droplet instance @DigitalOcean

### Requirements

- ```doctl``` (CLI DigitalOcean interface)

1. Create ssh-keys specifically for connecting with the droplet. *Skip this step
   if the keys were created previously

```console
 ssh-keygen -f .ssh/id_rsa_nebula_lighthouse
```

1. Import the ssh keys into the DigitalOcean account

```compute
 doctl compute ssh-key import nebula-lighthouse --public-key-file ~/.ssh/id_rsa_nebula_lighthouse.pub
```

1. Create a minimalist droplet with the ssh key added:

```console
doctl compute droplet create nebula-lighthouse --image debian-10-x64 --size s-1vcpu-1gb --region lon1 --ssh-keys $(doctl compute ssh-key list | grep nebula | awk '{print $3}')
```

1. Make sure you can connect to the droplet:

```console
ssh -i ~/.ssh/id_rsa_nebula_lighthouse root@$(doctl compute droplet list | grep nebula | awk '{print $3}')
```

1. Download the ```nebula``` binaries

```console
ssh -i ~/.ssh/id_rsa_nebula_lighthouse root@$(doctl compute droplet list | grep nebula | awk '{print $3}') mkdir /opt/nebula/

ssh -i ~/.ssh/id_rsa_nebula_lighthouse root@$(doctl compute droplet list | grep nebula | awk '{print $3}') wget https://github.com/slackhq/nebula/releases/download/v1.2.0/nebula-linux-amd64.tar.gz -O /tmp/nebula-linux-amd64.tar.gz

ssh -i ~/.ssh/id_rsa_nebula_lighthouse root@$(doctl compute droplet list | grep nebula | awk '{print $3}') tar -xf /tmp/nebula-linux-amd64.tar.gz -C /opt/nebula/
```

1. Edit the ```lighthouse-config.yml``` by putting the desired internal nebula
   network ip as a key and the droplet's public IP inside the list for
   ```static_host_map```.


1. Copy the certificate files to the nodes. *Do not copy ```ca.key``` to any node*.

For the lighthouse it should be:

```console
ssh -i ~/.ssh/id_rsa_nebula_lighthouse root@$(doctl compute droplet list | grep nebula | awk '{print $3}') mkdir /etc/nebula/

scp -i ~/.ssh/id_rsa_nebula_lighthouse ca.crt lighthouse.crt lighthouse.key lighthouse-config.yml root@$(doctl compute droplet list | grep nebula | awk '{print $3}'):/etc/nebula/
```

For the regular nodes the nebula installation (linux-amd64, linux-armv6, linux-armv7), generating the config file, generating the ```systemd``` service file, enabling and starting the service is automated with the script ```install-nebula-node.sh```. Still, the certificate files must be copied to the node **manually**
