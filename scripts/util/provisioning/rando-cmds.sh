terraform -chdir=terraform/digital_ocean/tfcloud/ apply --auto-approve -var org_name=test_tf_provision -var org_email=ariv3ra@gmail.com -var execution_mode=local

# Detroy TF_Cloud_Org and Workspaces
terraform -chdir=terraform/digital_ocean/tfcloud/ destroy --auto-approve -var org_name=test_tf_provision -var org_email=ariv3ra@gmail.com -var execution_mode=local


# Terraform Backend Config for do_create_k8s
echo -en "organization = \"${TF_CLOUD_ORGANIZATION}\"\nworkspaces{name =\"${TF_CLOUD_WORKSPACE}\"}" > ./terraform/digital_ocean/do_create_k8s/remote_backend_config

# Initialize terraform with unique org name
terraform -chdir=terraform/digital_ocean/do_create_k8s init \
  -backend-config=remote_backend_config
# Execute apply comand 
terraform -chdir=terraform/digital_ocean/do_create_k8s apply -auto-approve \
  -var do_token=$DIGITAL_OCEAN_TOKEN \
  -var cluster_name=$CLUSTER_NAME \
  -var do_k8s_slug_ver=$DO_K8S_SLUG_VER


# Terraform Backend Config for do_k8s_deploy_app
echo -en "organization = \"${TF_CLOUD_ORGANIZATION}\"\nworkspaces{name =\"${TF_CLOUD_WORKSPACE}-deploy\"}" > ./terraform/digital_ocean/do_k8s_deploy_app/remote_backend_config
# Initialize terraform with unique org name
terraform -chdir=terraform/digital_ocean/do_k8s_deploy_app init \
  -backend-config=remote_backend_config
# Execute apply comand 
terraform -chdir=./terraform/digital_ocean/do_k8s_deploy_app apply -auto-approve \
  -var do_token=$DIGITAL_OCEAN_TOKEN \
  -var cluster_name=$CLUSTER_NAME \
  -var docker_image=$DOCKER_IMAGE


  # Destroy prov

terraform -chdir=./terraform/digital_ocean/tfcloud destroy -auto-approve \
-var org_name=$TF_CLOUD_ORGANIZATION \
-var org_email=$TF_CLOUD_ORG_EMAIL \
-var workspace_name=$TF_CLOUD_WORKSPACE

# Provision container image 
cp ../../../requirements.txt . && docker build -t ariv3ra/cicd-ws-provision:latest -t ariv3ra/cicd-ws-provision:v0.0.1 .

