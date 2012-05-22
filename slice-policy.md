# Policy Slice

The *policy* slice is used to create policy rules to bind nodes to specific models based on tags. Multiple policies are filter top down in the same way as firewall rules where the first suitable applicable policy will be applied. Generic policy should be specified last, while specific policy should be specified first.


## Managing Policy

razor policy by default will provide a list of active policy:

    $ razor policy
    Policies
    #      Label         Template               Tags        Model Label   Broker Target  Count           UUID
    1  install_ubuntu  linux_deploy      [vmware_vm, cpu1]  linux_deploy  none           1      4ikCC2fXO75swJW9NP9qdG
    2  install_linux   linux_deploy      [vmware_vm, cpu4]  linux_deploy  puppet         1      4ikCC2fXO75swJW9NP9qdG
    3  install_esxi    vmware_hypervisor [phsical]          vmware        none           1      4ikCC2fXO75swJW9NP9qdG

The active policy above describes ubuntu deployed on vm with a single cpu, linux on vm with four cpu with puppet broker handoff, and esx deployed on hardware.  Support for reordering rules will be coming in a future release.

### Adding Policy

Razor policy are associated with policy template and a list of available policy templates can be obtained via the following command:

    $ razor policy get template
    
    Policy Templates:
        Template                                                  Description
    linux_deploy       Policy for deploying a Linux-based operating system. Compatible with Linux operating system Models
    vmware_hypervisor  Policy for deploying a VMware hypervisor. Compatible with VMware hypervisor Model Configs

Additional policy templates can be loaded into the system to extend Razor's functionality.

    $ razor policy add
    [Policy] [add] <-Must Provide Policy Template [template]
    
    Command help:  razor policy add (policy templates) (Name) (Model Config UUID) [none|(Broker Target UUID)] (tag{,tag,tag})

In additional to policy template, a model uuid must be provided to which model to bind to the applicable nodes. In this case razor will provide a list of suitable policy if a specific uuid isn't provided:

    $razor policy add linux_deploy install_linux
    [Policy] [add] <-Must Provide Model Config UUID [model_config]
    
    Command help:  razor policy add (policy templates) (Name) (Model Config UUID) [none|(Broker Target UUID)] (tag{,tag,tag})
    Valid Models for (linux_deploy)
     Label =>  ubuntu
     Template =>  linux_deploy
     Description =>  Ubuntu Oneiric 11.10 Minimal
     UUID =>  5SL6gy6V1OXzFKWOfgsqxG

Optional brokers can be specified to trigger node handoff to external systems after the active model is applied. For example a puppet broker plugin will install puppet on the target system and connect the node to an appropriate puppet master. If none is selected, razor will not initiate any handoff process after binding an active model to the node.

    $ razor policy add linux_deploy install_ubuntu 5SL6gy6V1OXzFKWOfgsqxG
    [Policy] [add] <-Must Provide Broker Target UUID or String:'none' [broker_target]
    
    Command help:  razor policy add (policy templates) (Name) (Model Config UUID) [none|(Broker Target UUID)] (tag{,tag,tag})
    All Broker Target
    < none >

The list of comma seperated tags, is the criteria which razor identifies nodes that should have the specified policy applied to the node. In the example below a vmware node with 1 cpu will apply the install_ubuntu policy, and the policy order will determine the priority which the rue will be applied to the node. Tags for identifying nodes can be created via tag rules and tag matches:

    $ razor policy add linux_deploy install_ubuntu 5SL6gy6V1OXzFKWOfgsqxG none vmware_vm
     UUID =>  4ikCC2fXO75swJW9NP9qdG
     Line Number =>  1
     Label =>  install_ubuntu
     Template =>  linux_deploy
     Description =>  Policy for deploying a Linux-based operating system. Compatible with Linux operating system Models
     Tags =>  [vmware_vm]
     Model Label =>  ubuntu
     Broker Target =>  none
     Bound Count =>  0

To find out the current state of active models bound to nodes, check the policy active state:

    razor policy active
    Active Models:
         Label          State           Node UUID            System      Bind #           UUID           
    centos_install   init         6ifxsUY43FZWuykB0tlrA2  none           1       6ph1ArWrUa2RPbBlXDRNtq  
    centos_install   init         49ZAUZJmQLDyQxLd6ZhEE6  none           2       4GZwgJ4xaVvGHUW0qHjIhW  
    install_precise  postinstall  7l4hBeHQOEioBMzglVrnFi  none           1       5LR9QOvX0wj47oKlt29UJm  
    esx_install      postinstall  YDLLKKJ9u3RS3QEcqdwx0   puppet_master  2       fvIBp22fNXlAoeMQdyilO   
    esx_install      init         2AiYujFMynjiLS4URaeoKw  puppet_master  1       2HPrdJ0ctz7A8Z5NLvzYwU  

The active model can be reviewed to find out what action the node is currently in and what state it has transitioned through to get to the current state:

    razor policy active log fvIBp22fNXlAoeMQdyilO
          State            Action      Result    Time     Last     Total           Node           
    init               mk_call         n/a     14:49:32  0 sec    0 sec    YDLLKKJ9u3RS3QEcqdwx0  
    init               boot_call       n/a     14:50:02  30 sec   30 sec   YDLLKKJ9u3RS3QEcqdwx0  
    init               kickstart_file  n/a     14:51:59  1.9 min  2.5 min  YDLLKKJ9u3RS3QEcqdwx0  
    init=>postinstall  kickstart_end   n/a     14:52:00  1 sec    2.5 min  YDLLKKJ9u3RS3QEcqdwx0  