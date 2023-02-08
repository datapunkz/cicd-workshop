# CI/CD Workshop with CircleCI

## Prerequisites

Knowledge of Git version control system
GitHub account - where the code is hosted
A code editor - you can use GitPod from the browser (preferred approach) which comes preloaded with all the dependencies.
Alternatively you can use locally installed editor. We are demoing this on VS Code.

## Chapter 0 - The Prologue and Prep

Fork this project! You will need a GitHub account.

This project can run on your machine if you have the correct dependencies installed (Git, Terraform, DigitalOcean CLI, Node.js), or it can also run in a cloud based environment using Gitpod (we recommend Gitpod for best experience).

To open this in Gitpod, copy your fork's GitHub URL, and combine it with this Gitpod prefix - `https://gitpod.io/#` and open it in a new tab.

The full URL should look something like this: `https://gitpod.io/#https://github.com/YOUR_GITHUB_USERNAME/THIS_REPO_NAME`.

This lets you spin up an environment with all the dependencies preinstalled, remotely connect to it, and work on it as it was on your machine. This is much faster, believe us, we measured it with science. 

### If NOT using Gitpod

If you are using Gitpod you're good, everything you need should have been installed already.

The commands used here are mostly using Bash, Git, and Python 3 - make sure they are installed and available. If using Windows, the commands might be different than the ones listed here.

Copy over the credentials source file. This is untracked in Git and will be used by a script to populate your CircleCI secret variables.

```
cp scripts/util/credentials.sample.toml credentials.toml
```

Install Python depedencies:

```
pip3 install -r requirements.txt
```

### IMPORTANT! Sign up for the required services and prepare credentials

If you don't do this, you'll have a bad time.

#### DigitalOcean

We will provision our resources on the DigitalOcean cloud platform. Create an account with DigitalOcean - https://cloud.digitalocean.com/ 
During the workshop we will provide you with a coupon code you can use to get free credits for the workshop.

- Go to API (left)
- Generate New Token with read and write access.
- Copy the token string to `credentials.toml` - `digital_ocean_token`
 
#### Terraform Cloud

We will use Terraform during the workshop to provision our infrastructure on Digital Ocean. 
Terraform Cloud is the SaaS backend for Terraform we will use to store our infrastructure as code.

- Create an account with Terraform Cloud - https://app.terraform.io/ 
- Go to your user settings by clicking on your avatar (top left), and select "User Settings"
- From there, click on "Tokens"
- Create an API token
- Copy the token string to `credentials.toml` - `tf_cloud_token`

#### Docker Hub

We will use Docker Hub as a repository to store our app images.

- Create an account with Docker Hub - https://hub.docker.com/ 
- Go to "Account Settings" (top right), and select Security
- Create New Access Token
- copy your username to `credentials.toml` - `docker_login`
- copy your token string to `credentials.toml` - `docker_token`

#### Snyk

We will use Snyk to run an automated security scan of our application an its dependencies. 

- Create an account with Snyk - https://app.snyk.io/
- Skip the integration step by clicking "Choose other integration" at the bottom of the options list.
- Click on your avatar in the bottom of the sidebar to show a dropdown
- Choose "Account Settings"
- Click to show your Auth Token
- Copy the auth token string to `credentials.toml` - `snyk_token`

### How this workshop works

We will go from a chapter to chapter - depending on people's background we might skip a chapter (Chapter 1 is for complete beginners to CI/CD and subsequent chapters build on top of that, for example).

To jump between chapters we have prepared a set of handy scripts you can run in your terminal, which will set up your environment so you can follow along.

The scripts to run are:

`./scripts/do_1_start.sh` - Beginning of first chapter
`./scripts/do_2.sh` - End of first chapter/Start of second chapter
`./scripts/do_3.sh` - End of second chapter/Start of third chapter
`./scripts/do_4_final.sh` - Final state

The chapters will copy and overwrite certain files in your workspace, so after running each script, commit the changes and push it, which will run it on CircleCI.

### Overview of the project

The project is a simple web application, that is packaged in a Docker container, and deployed to DigitalOcean hosted Kubernetes cluster, provisioned using Terraform.

### Workshop topics covered

#### Chapter 1 - Basics of CI/CD

- Review of a basic CI/CD pipeline
- Reporting test results
- Caching dependencies
- Using the orb to install and cache dependencies
- Setting up secrets and contexts
- Building and pushing a Docker image
- Scanning for vulnerabilities

#### Chapter 2 - Infrastructure provisioning and deployments with Terraform

- Cloud native principles
- Introduction to Terraform
- Provisioning a K8s cluster with Terraform on DigitalOcean
- Destroying the provisioned infrastructure
- Deployment to the new cluster with Terraform
- Running a smoke test on the deployed app
- Manual approval step before destroying infrastructure

## Chapter 1 - Basics of CI/CD

Most of our work will be in `./circleci/config.yml` - the CircleCI configuration file. This is where we will be describing our CI/CD pipelines.

This workshop is written in chapters, so you can jump between them by running scripts in `scripts/` dir, if you get lost and want to catch up with something.
To begin, prepare your environment for the initial state by running the start script: `./scripts/do_1_start.sh`

Go to app.circleci.com, and if you haven't yet, log in with your GitHub account (or create a new one).
Navigate to the `Projects` tab, and find this workshop project there - `cicd-workshop`.

We will start off with a basic continuous integration pipeline, which will run your tests each time you commit some code. Run a commit for each instruction. The first pipeline is already configured, if it's not you can run: `./scripts/do_0_start.sh` to create the environment.

Now review the `.circleci/config.yaml` find the `jobs` section, and a job called `build`, and workflow called `build_test_deploy`:

```yaml
version: 2.1

jobs:
  build_and_test:
    docker:
      - image: cimg/node:16.16.0
    steps:
      - checkout
      - run:
          command: |
            npm install
      - run:
          command: |
            npm run test

workflows:
  test_scan_deploy:
    jobs:
      - build_and_test

```


Original configuration has a single job to test our code. 
Let's change the `build_and_test` job by reporting the results it to CircleCI:

```yaml
build_and_test:
    docker:
      - image: cimg/node:16.16.0
    steps:
      - checkout
      - run:
          name: Run tests
          command: npm run test-ci
      - run:
          name: Copy tests results for storing
          command: |
            mkdir test-results
            cp test-results.xml test-results/
          when: always
      - store_test_results:
          path: test-results
      - store_artifacts:
          path: test-results

```

Now, let's look at dependencies. At the moment everything is always downloaded from scratch. We can instead store dependencies to cache to skip the download. Change the `build` job accordingly:

```yaml
build_and_test:
    docker:
      - image: cimg/node:16.16.0
    steps:
      - checkout
      - restore_cache:
          keys:
            - v1-npm-deps-{{ arch }}-{{ checksum "package-lock.json" }}
            - v1-npm-deps-{{ arch }}-
            - v1-npm-deps-
      - run:
          command: |
            npm install
      - save_cache:
          paths:
            - node_modules
          key: v1-npm-deps-{{ arch }}-{{ checksum "package-lock.json" }}
      - run:
          command: |
            npm run test-ci
```

We have cached dependencies manually, but there is a cleaner approach - by using an orb. Orbs are a CircleCI concept for reusing configuration code. We will introduce the new [orb for Node.JS](https://circleci.com/developer/orbs/orb/circleci/node)

```yaml
version: 2.1

orbs:
  node: circleci/node@5.1.0
```

We can use the orb to install packages, which will handle caching of our dependencies for us. Change the `build` job accordingly:

```yaml
jobs:
  build_and_test:
    docker:
      - image: cimg/node:16.16.0
    steps:
      - checkout
      - node/install-packages
      - run:
          name: Run tests
          command: npm run test-ci
```

### Secrets and Contexts

CircleCI lets you store secrets on the platform where they will only made available to the executors as environment variables. The first secrets you will need are credentials for Docker Hub which you'll use to deploy your image to Docker Hub.

We have prepared a script for you to create a context and set it up with all the secrets you will need in CircleCI. This will use the CircleCI API.
You should have all the required accounts for third party services already, and are just missing the CircleCI API token and the organization ID:

- In app.circleci.com click on your user image (bottom left)
- Go to Personal API Tokens 
- Generate new API token and insert it to `credentials.toml` under `docker_token`
- Insert your Docker Hub username to `credentials.toml` under `docker_login`
- In app.circleci.com click on the Organization settings. 
- Copy the Organization ID value and insert it in `credentials.toml` under `circleci_org_id`. 

Make sure that you have all the required service variables set in `credentials.toml`, and then run the script:

```bash
python3 scripts/util/provisioning/provision_workshop.py
```

Most of the things you do in CircleCI web interface can also be done with the API. You can inspect the newly created context and secrets by going to your organization settings. Now we can create a new job to build and deploy a Docker image.

### Building and deploying a Docker image

- First introduce the Docker orb:

```yaml
orbs:
  node: circleci/node@5.0.2
  docker: circleci/docker@2.1.1
```

- Add a new job:

```yaml
jobs:
...
  build_docker_image:
      docker:
        - image: cimg/base:stable
      steps:
        - checkout
        - setup_remote_docker:
            docker_layer_caching: false
        - docker/check
        - docker/build:
            image: $DOCKER_LOGIN/$CIRCLE_PROJECT_REPONAME
            tag: 0.1.<< pipeline.number >>
        - docker/push:
            image: $DOCKER_LOGIN/$CIRCLE_PROJECT_REPONAME
            tag: 0.1.<< pipeline.number >>
```

In the workflow, add the deployment job:

```yaml
workflows:
  test_scan_deploy:
    jobs:
      - build_and_test
      - build_docker_image

```

This doesn't run unfortunately - our `build_docker_image` doesn't have the required credentials. 
Add the context we created earlier:

```yaml
workflows:
  test_scan_deploy:
      jobs:
        - build_and_test
        - build_docker_image:
            context:
              - CICD_WORKSHOP_DOCKER
```

This runs both jobs in parallel. We might want to run them sequentially instead, so Docker deployment only happens when the tests have passed. Do this by adding a `requires` stanza to the `build_docker_image` job:

```yaml
workflows:
  test_scan_deploy:
      jobs:
        - build_and_test
        - build_docker_image:
            context:
              - CICD_WORKSHOP_DOCKER
            requires:
              - build_and_test
```

- Now, let's integrate a dependency scanning tool in our process. We will use Snyk, for which you should already have the account created and environment variable set.

- Add Snyk orb: 

```yaml
orbs: 
  node: circleci/node@5.0.2
  docker: circleci/docker@2.1.1
  snyk: snyk/snyk@1.2.3
```

Note: if you push this, you are likely to see the pipeline fail. This is because the Snyk orb comes from a third-party, developed by Snyk themselves. This is a security feature that you can overcome by opting in to partner and community orbs in your organisation settings - security.

- Add dependency vulnerability scan job:

```yaml
jobs:
...
  dependency_vulnerability_scan:
    docker:
      - image: cimg/node:16.16.0
    steps:
      - checkout
      - node/install-packages
      - snyk/scan:
          fail-on-issues: true
          monitor-on-build: false
```

- Add the job to workflow. Don't forget to give it the context - this time we used `CICD_WORKSHOP_SNYK`:

```yaml
workflows:
  test_scan_deploy:
      jobs:
        - build_and_test
        - dependency_vulnerability_scan:
            context:
              - CICD_WORKSHOP_SNYK
        - build_docker_image:
            context:
              - CICD_WORKSHOP_DOCKER
```

- This will now run the automated security scan for your dependencies and fail your job if any of them have known vulnerabilities. Now let's add the security scan to our Docker image build job as well:

```yaml
  build_docker_image:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - setup_remote_docker:
          docker_layer_caching: false
      - docker/check
      - docker/build:
          image: $DOCKER_LOGIN/$CIRCLE_PROJECT_REPONAME
          tag: 0.1.<< pipeline.number >>
      - snyk/scan:
          fail-on-issues: false
          monitor-on-build: false
          target-file: "Dockerfile"
          docker-image-name: $DOCKER_LOGIN/$CIRCLE_PROJECT_REPONAME:0.1.<< pipeline.number >>
          project: ${CIRCLE_PROJECT_REPONAME}/${CIRCLE_BRANCH}-app
      - docker/push:
          image: $DOCKER_LOGIN/$CIRCLE_PROJECT_REPONAME
          tag: 0.1.<< pipeline.number >>
```

🎉 Congratulations, you've completed the first part of the exercise!

## Chapter 2 - Cloud Native Deployments

We often use CI/CD pipelines to create our infrastructure, not just run our applications. In the following steps we will be doing just that.

First make sure you have all the credentials created and set in your contexts - as set in your `credentials.toml`.

This tells a cloud provider - in our case Digitalocean - what to create for us, so we can deploy our application. We will use a tool called Terraform for it.

- Add the orb for Terraform

```yaml
orbs:
  node: circleci/node@5.1.0
  docker: circleci/docker@2.2.0
  snyk: snyk/snyk@1.4.0
  terraform: circleci/terraform@3.2.0
```

- Add a command to install the Digitalocean CLI - `doctl`. This will be reusable in all jobs across the entire pipeline:

```yaml
commands:
  install_doctl:
    parameters:
      version:
        default: "1.92.0"
        type: string
    steps:
      - run:
          name: Install doctl client
          command: |
            cd ~
            wget https://github.com/digitalocean/doctl/releases/download/v<<parameters.version>>/doctl-<<parameters.version>>-linux-amd64.tar.gz
            tar xf ~/doctl-<<parameters.version>>-linux-amd64.tar.gz
            sudo mv ~/doctl /usr/local/bin
```

Add a job to create a DigitalOcean cluster using Terraform

```yaml
create_do_k8s_cluster:
    docker:
      - image: cimg/node:16.16.0
    steps:
      - checkout
      - install_doctl:
          version: "1.78.0"
      - run:
          name: Create .terraformrc file locally
          command: |
          echo -en "credentials \"app.terraform.io\" {token = \"$TF_CLOUD_TOKEN\"}" > $HOME/.terraformrc
            # Create backend file for terraform init with unique TF Cloud org
            echo -en "organization = \"${TF_CLOUD_ORGANIZATION}\"\nworkspaces{name =\"${TF_CLOUD_WORKSPACE}\"}" > ./terraform/digital_ocean/do_create_k8s/remote_backend_config
      - terraform/install:
          terraform_version: "1.2.0"
          arch: "amd64"
          os: "linux"
      - terraform/init:
          path: ./terraform/digital_ocean/do_create_k8s
      - run:
          name: Create K8s Cluster on DigitalOcean
          command: |
            export CLUSTER_NAME=${CIRCLE_PROJECT_USERNAME}-${CIRCLE_PROJECT_REPONAME}
            export DO_K8S_SLUG_VER="$(doctl kubernetes options versions \
              -o json -t $DIGITAL_OCEAN_TOKEN | jq -r '.[0] | .slug')"

            terraform -chdir=./terraform/digital_ocean/do_create_k8s apply \
              -var do_token=$DIGITAL_OCEAN_TOKEN \
              -var cluster_name=$CLUSTER_NAME \
              -var do_k8s_slug_ver=$DO_K8S_SLUG_VER \
              -auto-approve

```

Add a job deploy_to_k8s which will perform the deployment:

```yaml
deploy_to_k8s:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - install_doctl
      - run:
          name: Create .terraformrc file locally
          command: |
            echo "credentials \"app.terraform.io\" {token = \"$TF_CLOUD_TOKEN\"}" > $HOME/.terraformrc
            # Create backend file for terraform init with unique TF Cloud org
            echo -en "organization = \"${TF_CLOUD_ORGANIZATION}\"\nworkspaces{name =\"${TF_CLOUD_WORKSPACE}-deployment\"}" > ./terraform/digital_ocean/do_k8s_deploy_app/remote_backend_config
      - terraform/install:
          terraform_version: "1.2.0"
          arch: "amd64"
          os: "linux"
      - run:
          name: Deploy Application to K8s on DigitalOcean
          command: |
            export CLUSTER_NAME=${CIRCLE_PROJECT_USERNAME}-${CIRCLE_PROJECT_REPONAME}
            export TAG=0.1.<< pipeline.number >>
            export DOCKER_IMAGE="${DOCKER_LOGIN}/${CIRCLE_PROJECT_REPONAME}:$TAG"
            doctl auth init -t $DIGITAL_OCEAN_TOKEN
            doctl kubernetes cluster kubeconfig save $CLUSTER_NAME

            # Initialize terraform with unique org name
            terraform -chdir=terraform/digital_ocean/do_k8s_deploy_app init \
              -backend-config=remote_backend_config

            # Execute apply comand 
            terraform -chdir=./terraform/digital_ocean/do_k8s_deploy_app apply -auto-approve \
              -var do_token=$DIGITAL_OCEAN_TOKEN \
              -var cluster_name=$CLUSTER_NAME \
              -var docker_image=$DOCKER_IMAGE

            # Save the Load Balancer Public IP Address
            export ENDPOINT="$(terraform -chdir=./terraform/digital_ocean/do_k8s_deploy_app output lb_public_ip)"
            mkdir -p /tmp/do_k8s/
            echo 'export ENDPOINT='${ENDPOINT} > /tmp/do_k8s/dok8s-endpoint
      - persist_to_workspace:
          root: /tmp/do_k8s/
          paths:
            - "*"

```

Add the new job to the workflow. Add `requires` statements to only start cluster  when all prior steps have completed

```yaml
workflows:
  test_scan_deploy:
      jobs:
        - build_and_test
        - dependency_vulnerability_scan:
            context:
              - cicd-workshop
        - build_docker_image:
            context:
              - cicd-workshop
        - create_do_k8s_cluster:
            requires:
              - dependency_vulnerability_scan
              - build_docker_image
              - build_and_test
            context: 
              - cicd-workshop
        - deploy_to_k8s:
            requires:
              - create_do_k8s_cluster
              - CICD_WORKSHOP_DOCKER
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD
```

- Now that our application has been deployed it should be running on our brand new Kubernetes cluster! Yay us, but it's not yet time to call it a day. We need to verify that the app is actually running, and for that we need to test in production. Let's introduce something called a Smoke test!


- Add a new job - `smoketest_k8s_deployment`. This uses a bash script to make HTTP requests to the deployed app and verifies the responses are what we expect. We also use a CircleCI Workspace to pass the endpoint of the deployed application to our test. 

```yaml
  smoketest_k8s_deployment:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - attach_workspace:
          at: /tmp/do_k8s/
      - run:
          name: Smoke Test K8s App Deployment
          command: |
            source /tmp/do_k8s/dok8s-endpoint
            ./test/smoke_test $ENDPOINT

```

- Add the smoke test job to the workflow, so it's dependent on `deploy_to_k8s`:

```yaml

workflows:
  test_scan_deploy:
      jobs:
        - build_and_test
        - dependency_vulnerability_scan:
            context:
              - cicd-workshop
        - build_docker_image:
            context:
              - cicd-workshop
        - create_do_k8s_cluster:
            requires:
              - dependency_vulnerability_scan
              - build_docker_image
              - build_and_test
            context:
              - cicd-workshop
        - deploy_to_k8s:
            requires:
              - create_do_k8s_cluster
              - CICD_WORKSHOP_DOCKER
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD
        - smoketest_k8s_deployment:
            requires:
              - deploy_to_k8s
```

### Tear down the infrastructure

The last step of this chapter is to tear down the infrastructure we provisioned, and "undeploy" the application. This will ensure you're not charged for keeping these resources up and running. We will combine it with an approval step that only triggers when we manually click approve (who said CI/CD was all about automation?)

- Create a new job - `destroy_k8s_cluster`:

```yaml
destroy_k8s_cluster:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - install_doctl
      - run:
          name: Create .terraformrc file locally
          command: |
            # Create TF Cli config file
            echo "credentials \"app.terraform.io\" {token = \"$TF_CLOUD_TOKEN\"}" > $HOME/.terraformrc && cat $HOME/.terraformrc
            # Create backend file for terraform init with unique TF Cloud org for K8s cluster
            echo -en "organization = \"${TF_CLOUD_ORGANIZATION}\"\nworkspaces{name =\"${TF_CLOUD_WORKSPACE}\"}" > ./terraform/digital_ocean/do_create_k8s/remote_backend_config
            # Create backend file for terraform init with unique TF Cloud org K8s App Deploy
            echo -en "organization = \"${TF_CLOUD_ORGANIZATION}\"\nworkspaces{name =\"${TF_CLOUD_WORKSPACE}-deployment\"}" > ./terraform/digital_ocean/do_k8s_deploy_app/remote_backend_config                        
      - terraform/install:
          terraform_version: "1.2.0"
          arch: "amd64"
          os: "linux"
      - run:
          name: Destroy App Deployment
          command: |
            export CLUSTER_NAME=${CIRCLE_PROJECT_USERNAME}-${CIRCLE_PROJECT_REPONAME}
            export TAG=0.1.<< pipeline.number >>
            export DOCKER_IMAGE="${DOCKER_LOGIN}/${CIRCLE_PROJECT_REPONAME}:$TAG"          
            doctl auth init -t $DIGITAL_OCEAN_TOKEN
            doctl kubernetes cluster kubeconfig save $CLUSTER_NAME
            
            # Initialize terraform with unique org name
            terraform -chdir=terraform/digital_ocean/do_k8s_deploy_app init \
              -backend-config=remote_backend_config

            terraform -chdir=./terraform/digital_ocean/do_k8s_deploy_app/ apply -destroy -auto-approve \
              -var do_token=$DIGITAL_OCEAN_TOKEN \
              -var cluster_name=$CLUSTER_NAME \
              -var docker_image=$DOCKER_IMAGE
      - run:
          name: Destroy K8s Cluster
          command: |
            export CLUSTER_NAME=${CIRCLE_PROJECT_USERNAME}-${CIRCLE_PROJECT_REPONAME}
            export DO_K8S_SLUG_VER="$(doctl kubernetes options versions \
              -o json -t $DIGITAL_OCEAN_TOKEN | jq -r '.[0] | .slug')"

            # Initialize terraform with unique org name
            terraform -chdir=terraform/digital_ocean/do_create_k8s init \
              -backend-config=remote_backend_config

            terraform -chdir=./terraform/digital_ocean/do_create_k8s apply -destroy -auto-approve \
              -var do_token=$DIGITAL_OCEAN_TOKEN \
              -var cluster_name=$CLUSTER_NAME \
              -var do_k8s_slug_ver=$DO_K8S_SLUG_VER
```

This runs two Terraform steps - with the, running `apply -destroy` which basically undoes them. First the deployment, and then the underlying infrastructure.

- Now add the destroy job to the workflow.

```yaml
workflows:
  test_scan_deploy:
      jobs:
        - build_and_test
        - dependency_vulnerability_scan:
            context:
              - CICD_WORKSHOP_SNYK
        - build_docker_image:
            context:
              - CICD_WORKSHOP_DOCKER
        - create_do_k8s_cluster:
            requires:
              - build_docker_image
            context:
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD
        - deploy_to_k8s:
            requires:
              - create_do_k8s_cluster
            context:
              - CICD_WORKSHOP_DOCKER
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD
        - smoketest_k8s_deployment:
            requires:
              - deploy_to_k8s
        - destroy_k8s_cluster:
            requires:
              - smoketest_k8s_deployment
            context:
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD
```

Finally, add a special `approve_destroy` job to the workflow before `destroy_k8s_cluster`:

```yaml
workflows:
  test_scan_deploy:
      jobs:
        - build_and_test
        - dependency_vulnerability_scan:
            context:
              - CICD_WORKSHOP_SNYK
        - build_docker_image:
            context:
              - CICD_WORKSHOP_DOCKER
        - create_do_k8s_cluster:
            requires:
              - build_docker_image
            context:
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD
        - deploy_to_k8s:
            requires:
              - create_do_k8s_cluster
            context:
              - CICD_WORKSHOP_DOCKER
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD
        - smoketest_k8s_deployment:
            requires:
              - deploy_to_k8s
        - approve_destroy:
            type: approval
            requires:
              - smoketest_k8s_deployment
        - destroy_k8s_cluster:
            requires:
              - approve_destroy
            context:
              - CICD_WORKSHOP_DIGITAL_OCEAN
              - CICD_WORKSHOP_TERRAFORM_CLOUD

```

The `approve_destroy` had a special type set - `approval` which means we don't have to define it and it will give us the option to manually confirm we want to continue executing the workflow.

🎉 Congratulations! You have completed the workshop!