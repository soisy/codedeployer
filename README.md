## Description
Codedeployer is a small library that helps deploying any application or codebase to groups of ec2 instances through AWS Codedeploy.
The deploy process needs pre-configuration on the AWS side, so ask your nearest ops.

The deployment works like this:
- an archive is created containing the codebase and a special `appspec.yml` file needed by Codedeploy
- this archive is uploaded to S3
- a series of calls is made to the Codedeploy API to initiate deployments
- an agent installed on all supported instances polls Codedeploy waiting for deployment instructions
- when the agent receives a deployment instruction, it downloads the archive from S3 and executes the steps defined in the `appspec.yml` file

This process shifts the deployment from a push system like Idephix or Deployer that requires ssh access to machines in order to rsync the code, to a poll system where the instances are notified of a new deployment request by the agent and download the application archive, running all the configured scripts to complete the deployment.

## Components
Things that run on the deployer machine (dev or CI):
- `bin/deploy` script: sets up autoload and executes the main PHP script
- `Codedeployer` PHP class: executed on the dev or CI machine, sets up the archive, pushes it to S3 and calls Codedeploy APIs to initiate deployments
- `config/config.php`: configuration file containing the name of the application and the instance groups target of the deployment, used by the `Codedeployer` class

Things that run on the target machine (ec2 instance where the code is deployed)
- `config/appspec.yml`: configuration file required by AWS Codedeploy, is included in the archive and describes what to do during the deployment on the target machines
- `config/hook-scripts/hook-wrapper.sh`: wrapper script called by `appspec.yml`, is executed on the destination ec2 machines, calls deployments scripts and provides logging; requires the `ts` tool for timestamping
- `config/hook-scripts/instance-template`: template directory containing premade scripts 
- `config/hook-scripts/strategies`: scripts that execute predefined deploy strategies: rotating releases and simple copy
- `config/hook-scripts/rsync_exclude`: list of files and directories excluded from the final copy

## Installation and usage
1. Run `composer require soisy/codedeployer`
2. Run `./vendor/bin/deploy --setup`
3. Create directories named as deployment groups
4. Add scripts inside deployment groups directories
5. Compile `config.php`
6. Run `./vendor/bin/deploy`

**Point 1** and **2** are self explanatory.

**Point 3** requires you to create a directory under `deploy/hook-script` for each instance group you want to deploy to. You should duplicate the `instance-template` directory, change its name to the match the deployment group and adjust its content.

For example, if you wish to deploy to `ec2-alfa` and `ec2-beta` instance groups, the tree will look like this:

```
deploy/
└── hook-scripts/
    ├── ec2-alfa/
    └── ec2-beta/
```

**Point 4** requires you to populate the directories from point 3.
AWS Codedeploy offers various hooks during the process, for simplicity the default setup only uses `AfterInstall` but other hooks can be easily added to `appspec.yml` if needed.

`AfterInstall` is the first hook available and is run after the agent has downloaded and extracted the revision archive to a temporary directory;
it is used to actually copy all the code to the real target directory and execute any post-install script that might be needed (ie. clearing cache, recreating snapshots, etc).

For more information on AWS Codedeploy hooks see: https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html#appspec-hooks-server

Now add scripts in those directories named after these hooks, so assuming you go for the easy version with just `AfterInstall`, your tree should look like this:

```
deploy/
└── hook-scripts/
    ├── ec2-alfa/
    │   └── AfterInstall.sh
    └── ec2-beta/
        └── AfterInstall.sh

```

these scripts will be run by the wrapper script `hook-wrapper.sh` which is defined as the main hook in `appspec.yml`

**Point 5** only requires you to compile a few application related options, the file should be self explanatory.

## TODO
- refactor config.php with some other form of configuration
- write Codedeploy new activation (app + groups) through CLI skipping web console
- sanity checks
