A broker instance may be included as part of any policy that is defined within Razor.  If a broker instance is included when creating a policy (see the description of the policy slice, below, for more information), that broker instance will be used to manage the process of handing off a node to an underlying DevOps system once the OS provisioning process defined by that policy is complete.

It should be noted here that once the node handoff process is complete, Razor assumes that any further management of the system will be done directly through the DevOps system.  Once a node has been placed into that state, Razor will only intervene during the initial phases of the network boot process for that node (to supply the appropriate 'local boot' iPXE boot script).

At some later time, the DevOps system may remove the active_model that was bound to that node when a matching policy was found (via Razor’s RESTful API) and force a reboot of that node.  This will, effectively, hand the node back over to Razor for management (and, perhaps, reprovisioning of a new OS instance), but until such a handoff from the DevOps system (back to Razor) occurs, that node is will remain under the exclusive control of the DevOps system.

## The broker CLI

The broker CLI provides users with the ability to view a summary of all of the broker targets currently available in the system, the details for a specific broker target, or a list of the broker plugins that are defined within Razor.  Broker plugins are used when creating a new broker target (just as model templates are used when creating new model instances and policy templates are used when creating new policy instances).  Currently, there are broker plugins defined in Razor for both Puppet and Chef (the 'puppet' and 'chef' plugins, respectively).  Broker plugins for other brokers may be added to Razor by the community over time.

In addition to viewing the details of the broker targets or plugins in the system, the broker CLI provides users with the ability to create new broker targets, update existing broker targets, and remove specific broker targets (or even to remove all existing broker targets).  Help is also available for the CLI commands that make up the broker slice; providing user’s with usage assistance for the broker slice itself and for the sub-commands that are supported by that slice.  Here is a high-level summary of the commands that are available via the broker CLI:
```bash
razor broker [get] [all]                   View all broker targets
razor broker [get] (UUID)                  View specific broker target
razor broker [get] plugin|plugins|t        View list of broker plugins
razor broker add (options...)              Create a new broker target
razor broker update (UUID) (options...)    Update a specific broker
razor broker remove (UUID)|all             Remove existing broker(s)
```
It should be noted here that there are a set of options that must be specified when adding a new broker target to the system using the 'broker add' command.  Those options are shown below:
```bash
razor broker add (options...)
    -p, --plugin BROKER_PLUGIN       The broker plugin to use. 
    -n, --name BROKER_NAME           The name for the broker target. 
    -d, --description DESCRIPTION    A description for the broker target. 
    -h, --help                       Display this screen.
```
The value for the 'plugin' argument (above) must be the name of one of the available broker plugins defined in the system.  The names of the currently defined broker plugins can be easily obtained using the `razor broker plugins` command.

It should also be noted here that when this functionality is accessed using the CLI, Razor will walk through an interactive script (much like is done in the case of the model slice) in order to gather additional (broker-plugin-specific) meta-data. For the 'puppet' broker plugin, the following parameters are defined using that interactive script:

* **server** -- used to define the location of the Puppet master for a given node. It should be noted here that a hostname should be used for the value of this parameter (rather than an IP address) because this server value is also assumed to be the value of the 'ca_server', which will be embedded in the certificates used for authentication between puppet and the node). If the default value (an empty string) is used for this parameter, then the default hostname used by Puppet will be assumed for this hostname parameter.
* **broker_version** -- used to define the version of Puppet that should be installed locally on the node (using a 'gem install' command) during the node handoff process. If the default value (an empty string) is used for the value of this parameter, then the latest version of Puppet will be installed locally (whatever version that may be).

For the 'chef' broker plugin, the following parameters are defined using a similar interactive script:

* **chef_server_url** -- the URL of where the Chef server can be found
* **chef_version** -- the Chef version to install locally on the node (used in the 'gem install' command to constrain the version of Chef that is installed)
* **validation_key** -- the contents of the validation.pem file, followed by a blank line
* **validation_client_name** -- the validation client name
* **bootstrap_environment** -- the Chef environment in which the chef-client will run
* **install_sh_url** -- the Omnibus installer script URL
* **chef_client_path** -- an alternate path to the chef-client binary
* **base_run_list** -- an optional run_list of common base roles.

Like the 'broker add' command, there are a set of options to the 'broker update' command, and the user must also supply one or more of those options when updating a broker instance (each option that is supplied corresponds to a meta-data value that will be updated in the specific broker target instance).  Those options are shown here:
```bash
razor broker update (UUID) (options...)
    -n, --name BROKER_NAME           New name for the broker target. 
    -d, --description DESCRIPTION    New description for the broker target. 
    -c, --change-metadata            Used to trigger a change in the broker's meta-data 
    -h, --help                       Display this screen.
```
As you can see, except for the broker plugin, any of the meta-data values associated with a broker target can be changed via this 'broker update' command.  Changes to the underlying (broker-plugin-specific) meta-data can be made interactively by including the '-c' or '--change-metadata' flag in the 'broker update' command.  Changes to the broker plugin type are not possible using a 'broker update' command.  Instead, the user must create a new broker target of the correct type (and, possibly, the remove the old broker target).

## The broker RESTful API

The broker RESTful API is provided via two resources ('/broker' and '/broker/{UUID}').  There is also a third, associated resource provided through the RESTful API ('/broker/plugins') that can be used to obtain a list of available broker plugins.  The operations that are supported for each of these resources are as follows:

* **GET /broker** -- used to get a summary view of all of the broker instances that are registered with the system
* **GET /broker/{UUID}** -- used to get the details of a specific broker instance (by UUID); the details returned are the same as those returned in the previous operation, but the values returned are only those for the specified broker instance.
* **GET /broker/plugins** -- used to obtain a list of the broker plugins that are available in the system; a broker plugin is used to define a template for a specific DevOps system (eg. Puppet or Chef), and one of these plugins must be specified when creating a new broker instance.
* **POST /broker?json_hash=(JSON_STR)** -- used to create a new broker instance; the 'name', 'description',  'plugin', and 'servers' that are necessary for this operation are included in the (JSON_STR), a URL-encoded JSON hash value that must be included as part of the broker creation request.  An example of such a json_hash value would be something like the following string:
```html
%7B%22name%22%3A%22puppet_broker%22%2C%22plugin%22%3A%22puppet%22%2C%22description%22%3A%22Puppet%20Broker%22%2C%22req_metadata_hash%22%3A%7B%22server%22%3A%22puppet.localdomain.com%22%2C%22broker_version%22%3A%223.0.1%22%7D%7D
```
which is the URL-encoded version of the following JSON string representation of a hash map containing values for these four parameters:
```json
{"name":"puppet_broker","plugin":"puppet","description":"Puppet Broker","req_metadata_hash":{"server":"puppet.localdomain.com","broker_version":"3.0.1"}}
```
*Note; the req_metatdata_hash value is itself a hash, and it contains the same meta-data values that are gathered interactively whenever a broker plugin instance of the specified type (based on the 'plugin' value in the request) is created via the CLI.*
* **PUT /broker/{UUID}?json_hash=(JSON_STR)** -- used to update an existing broker instance with new meta-data values.  One or more of the 'name', 'description', or 'req-metadata_hash' values must be included in the json_hash argument that is part of this request.  It should be noted here that the 'plugin' value for a broker instance cannot be updated in this manner.
* **DELETE /broker/{UUID}** -- used to remove a specific broker instance; there is no 'remove all' operation supported via the broker RESTful API (it was felt that such an operation was too destructive to make available via REST).