# Counter API application

## Setup local development environment

> Docker must be installed on the development server (with docker compose that is embedded in recent versions)

Code is supposed to be located into `app/` folder (currently `app.py` file only), as well as the `requirements.txt` file containing the dependencies.

At the root of the project, we also find the `Dockerfile` which will build the docker image that will run the application, and
`docker-compose.yml` file which will launch a local test environment with a database.

To test the changes made on `app/app.py` and the requirements, you just have to launch the docker compose environment that will build the corresponding
docker image :
```
docker compose up --build -d
```

Then, the Flask application will run on `localhost:5000` host,relying on the database service launched by docker compose.

```
$ curl -X GET http://localhost:5000/counter
{
  "value": 0
}

$ curl -X PUT http://localhost:5000/counter/increment
{
  "value": 1
}
```

You can also launch **Playwright** tests with docker compose. These tests are defined into `playwright/tests/api.test.js` file.

```
$ docker compose run --rm playwright

[+] Creating 2/0
 ✔ Container db   Running                                                                                                                                                                    0.0s 
 ✔ Container api  Running                                                                                                                                                                    0.0s 
Dependencies already installed.
Playwright browsers already installed.

Running 4 tests using 1 worker

  ✓  1 tests/api.test.js:9:5 › API Counter Tests › GET /counter should return the current value (153ms)
Initial value: 0
  ✓  2 tests/api.test.js:19:5 › API Counter Tests › PUT /increment should increase the counter (58ms)
Incremented value: 1
  ✓  3 tests/api.test.js:29:5 › API Counter Tests › PUT /decrement should decrease the counter (81ms)
Decremented value: 0
  ✓  4 tests/api.test.js:40:5 › API Counter Tests › PUT /decrement should not decrease the counter under 0 after a reset (116ms)
Reset value: 0
Decremented value: 0

  4 passed (2.1s)
```

## Provision the AWS infrastrucure

AWS infrastructure is managed by **Terraform** that needs to be installed on the development server.

Here is the structure of the `terraform/` folder from the project :

```
terraform
├── live
│   └── prod
│       ├── infrastructure
│       │   ├── main.tf
│       │   ├── prod.tfvars
│       │   └── variables.tf
│       └── secrets
│           ├── main.tf
│           ├── prod.tfvars
│           └── variables.tf
├── modules
│   ├── api_gateway
│   │   ├── main.tf
│   │   ├── output.tf
│   │   └── variables.tf
│   ├── bastion
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── ecs
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── lambda
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── network
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── rds
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── secrets
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
└── scripts
    └── get_public_ip.sh
```

We can see **modules** that defines the configuration of each main element from the infrastructure.

Then, the Terraform infrastructure is applied from `terraform/live/prod` folders :
- `secrets` manages the secrets (required by the database) and must be applied **first** and **once**.
- `infrastructure` handles the infrastructure relying on a Lambda to execute the application (default case) or an ECS instance (fallback)

For each case, all variables are defined into `variables.tf` (that might provide default values too) and `prod.tfvars` which gives values to the variables used by the Terraform plan.

As mentionned, `secrets` configuration needs to be applied **first** and has **already been done**. Two secrets are managed :
- `db_master_user_secret` : the database master user password (`postgres` user)
- `db_user_secret` : the common database user used by the counter API application (`db_user` user)

Then, Terraform `infrastructure` configuration rely on a [Gitlab backend](https://docs.gitlab.com/ee/user/infrastructure/iac/terraform_state.html#migrate-to-a-gitlab-managed-opentofu-state) to manage the initialization state.

In `infrastructure` Terraform environment, we need to execute the following command to create/update the infrastructure :

```
# We assume we are into terraform/live/prod/infrastructure folder
# Init Terraform with Gitlab backend
PROJECT_ID="<gitlab-project-id>"
TF_USERNAME="<gitlab-username>"
TF_ADDRESS="https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/old-state-name"
terraform init \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=${TF_USERNAME} \
  -backend-config=password=${GITLAB_ACCESS_TOKEN} \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5

# Define Terraform plan with variables
terraform plan -var-file="prod.tfvars"

# Apply Terraform plan with variables
terraform apply -var-file="prod.tfvars"
```

> AWS needs the following environment variables to be defined: **AWS_ACCESS_KEY_ID** and **AWS_SECRET_ACCESS_KEY**, linked to an account that has enough rights to perform the deployment tasks.

`scripts/` folder at the root of the Terraform configuration only contains bash scripts that can be called during Terraform plan execution.

Below are the environment variables required to run the Terraform plans :
- `AWS_ACCESS_KEY_ID`: AWS account key identifier
- `AWS_SECRET_ACCESS_KEY`: AWS account key password
- `GITLAB_ACCESS_TOKEN`: a Gitlab access token to the project that contains the Terraform backend

## Fallback strategy

The Terraform infrastructure plan that can be modified to set the **API gateway integration** to a container running with **ECS**.

To do so, you have to set `integration_target` Terraform variable value to `ecs`. Thus, an ECS instance will be created and will
run the API counter application; the API gateway integration will be set to the ECS instance endpoint to provide the API.

The easiest way, in order not to modify the configuration file, is to set the variable value in the **command line**.

```
# We assume we are into terraform/live/prod/infrastructure folder
terraform plan -var-file="prod.tfvars" -var "integration_target=ecs"
```

Then, to come back to the **primary** setup, you just let `integration_target` variable be set by default configuration.

```
terraform plan -var-file="prod.tfvars"
```

This way, the API integration will be set back to the **Lambda** running the application, and the ECS instance is destroyed.