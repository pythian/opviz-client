# Installing via Ansible


## Dependencies

1. Download and install Ansible http://docs.ansible.com/intro_installation.html

1. Create ansible.cfg in your working directory. There's an example in the 'ansible' directory.

1. Create inventory file or use dynamic inventory such as ec2.py in the ansible root directory


## Installing client

1. Either duplicate the ansible/playbooks/opsviz_agents.yml and modify the 'vars', create a 'group_vars/$group.yml' file based on your inventory groups to modify vars.

```yaml
---
sensu:
  rabbitmq:
    host: (rabbitmq server)
    port: 5671
    user: sensu
    ssl: true
    password: XXXX # TODO: encrypt with ansible vault
  subscriptions: ["all", "mysql"]
  mysql:
    user: sensu
    password: XXXX
```

1. Run playbook, specifying the targets you want to install upon, something like this:

```bash
$ ansible-playbook -i ansible/ec2.py ansible/playbooks/opsviz_agents.yml -e "targets=tag_Role_MySQL"
```

## Caveats
### Ansible dict merging
By default, ansible does not merge dictionaries (hashes). Therefore, if you provide a dictionary, it will overwrite the entire default dictionary. This behavior can be modified by updating the ansible.cfg 'hash_behaviour':

```
hash_behaviour=merge
```

Source: http://docs.ansible.com/intro_configuration.html#hash-behaviour