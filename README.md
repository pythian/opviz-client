# OpsVis Clients
## The first step in DevOps transformation is knowing where change is needed

### Overview

This repository includes the cloudformation json and opsworks cookbooks to stand up a complete ELK stack in AWS.

Out of the box, it is Highly Available within one availability zone and automatically scales on load and usage.

It also builds everything with private-only ip addresses and restricts all external access to two endpoints:

1. Logs and metrics flow in through HA RabbitMQ with SSL terminated at the ELB
1. All dashboards and elasticsearch requests are protected by doorman and hosted together on a “dashboard” host

### Components
- Sensu
- Logstash

### Setup
1. Upload an SSL Certificate to AWS for the RabbitMQ ELB - and note the generated ARN [Instructions](http://docs.aws.amazon.com/ElasticLoadBalancing/latest/DeveloperGuide/ssl-server-cert.html#upload-cert)
2. Create a new cloud formation stack on the [Cloud Formation Dashboard](https://console.aws.amazon.com/cloudformation/home) [image](screenshots/create_stack.png)
3. Choose "Upload a template to Amazon S3" on upload cloudformation.json
4. See Cloudformation Paramaters section on specifics for paramaters [image](screenshots/cloudformation_parameters.png)
5. *During options I recommend disabling rollback on failture so you can see logs on opsworks boxes when recipes fail* [image](screenshots/rollback_on_failure.png)



### Access Into Operational Visibility Stack
RabbitMQ has a public facing ELB in front of it with SSL termination.
The dashboard instance has an ELB in front of it so the dasbhoards for grafana, kibana, graphite, and sensu are publicly accessible (Authentication is still required)

## Clients

### External Logstash Clients
To setup an external logstash client.

1. Install logstash according to [documentation](http://logstash.net/docs/1.4.2/tutorials/getting-started-with-logstash)
2. Update the config to push logs to the rabbitmq ELB

### External Sensu Clients
We use the public facing RabbitMQ as the transport layer for external sensu clients.

1. Install sensu client according to [documentation](http://sensuapp.org/docs/0.16/guide)
2. Update client config `/etc/sensu/conf.d/client.json`
3. Update rabbitmq config `/etc/sensu/conf.d/rabbitmq.json`

        {
          "rabbitmq": {
            "host": "<RabbitMQ ELB>",
            "port": 5671,
            "user": "sensu",
            "password": "<sensu RabbitMQ password>",
            "vhost": "/sensu",
            "ssl" : true
          }
        }

### Updating Sensu Checks and Metrics
*Todo: At this time we don't have a way to drive sensu checks or metrics directly from CloudFormation paramaters or any other external definitions.
This would make it easier to update sensu without needing to worry about making changes directly to the sensu config without configuration management or making standalone checks on each client*

- Option 1: SSH into the sensu box and make changes according to sensu [documentation](http://sensuapp.org/docs/0.11/checks)
- Option 2: Setup standalone checks on each external client according to [documentation](http://sensuapp.org/docs/0.11/adding_a_standalone_check)

- Handlers

  When adding a check as [type metric](http://sensuapp.org/docs/0.11/adding_a_metric) set the handlers to "graphite".
  *This will forward any metrics onto graphite for us automatically*

***

### Custom JSON
[This Custom Json](custom_json.example.json) is the Custom Json block that is set as the OpsWorks custom json. It drives a lot of the custom configuration
that chef uses to customize the boxes. Its currently embedded in the Cloud Formation script so that we can inject paramaters into the custom json.

If changes need to be made to the custom json you can do it from the OpsWorks stack's stack settings page. If you make changes make sure that you
don't update the Cloud Formation stack as it will overwrite the custom OpsWork's settings you made.

*Todo: At some point it would be nice to allow a user to inject their own custom json into the cloud formation processes without having to manually make changes
to the monolithic cloudromation.json file*

