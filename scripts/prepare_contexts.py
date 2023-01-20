#!/usr/bin/env python3
import toml
import json
import requests

creds = toml.load('credentials.toml').get('keys')
CIRCLE_TOKEN = creds.get('circleci_token')
CIRCLECI_ORG_SLUG = creds.get('circleci_org_slug')
CIRCLECI_ORG_ID = creds.get('circleci_org_id')
CIRCLECI_BASE_URL = "http://circleci.com/api/v2/"
CIRCLECI_CONTEXT_NAME = "demo"
CIRCLECI_CONTEXT_NAME_PREFIX = "CICD_WORKSHOP_"

SNYK_TOKEN = creds.get('snyk_token')
DOCKER_LOGIN = creds.get('docker_login')
DOCKER_TOKEN = creds.get('docker_token')
TF_CLOUD_KEY = creds.get('tf_cloud_key')
DIGITALOCEAN_TOKEN = creds.get('digitalocean_token')
REQUEST_HEADER = {
    'content-type': "application/json",
    'Circle-Token': CIRCLE_TOKEN
  }

def get_circleci_api_request(endpoint, payload_dict): 
  conn = requests.get(CIRCLECI_BASE_URL + endpoint, headers=REQUEST_HEADER)
  return conn.json()

def post_circleci_api_request(endpoint, payload_dict):
  conn = requests.post(CIRCLECI_BASE_URL + endpoint, headers=REQUEST_HEADER,json=payload_dict)
  return conn.json()

def put_circleci_api_request(endpoint, payload_dict):
  conn = requests.put(CIRCLECI_BASE_URL + endpoint, headers=REQUEST_HEADER,json=payload_dict)
  return conn.json()

def delete_circleci_api_request(endpoint, context_id):
  conn = requests.delete(CIRCLECI_BASE_URL + endpoint + context_id, headers=REQUEST_HEADER)
  return conn.json()

def add_circle_token_to_context_with_name(context_name, env_var_name, env_var_value):
  context_id = find_or_create_context_by_name(context_name)
  add_circle_token_to_context(context_id=context_id, env_var_name=env_var_name, env_var_value=env_var_value)
  
  #Mask the secret values 
  masked_env_value = env_var_value[-4:] if len(env_var_value) > 4 else "***********"
  return {'Context Name':CIRCLECI_CONTEXT_NAME_PREFIX + context_name,
          'Environment Variable': env_var_name, 
          'Environment Value' : f'****{masked_env_value}'}

def add_circle_token_to_context(context_id, env_var_name, env_var_value):
  return put_circleci_api_request(f'context/{context_id}/environment-variable/{env_var_name}', { "value": env_var_value })

# Get the context id to which we'll store env vars
def find_or_create_context_by_name(context_name):   # context name - CICD_WORKSHOP_docker etc...
  full_context_name = CIRCLECI_CONTEXT_NAME_PREFIX + context_name
  contexts = get_circleci_api_request(f'context?owner-id={CIRCLECI_ORG_ID}&owner-type=organization', None).get('items')
  context = next((ctx for ctx in contexts if ctx.get('name') == full_context_name), None)
  # print(f'Full Context Name: {context}')
  if context == None:
  # Context doesn't exist so we create it   
    context_payload = {
      "name": full_context_name,
        "owner": {
          "id": CIRCLECI_ORG_ID,
          "type": "organization"
        }
    }
    context = post_circleci_api_request('context', context_payload) 
  circleci_context_id = context.get('id')
  return circleci_context_id

# Add Env vars to context
print(add_circle_token_to_context_with_name('SNYK', 'SNYK_TOKEN', SNYK_TOKEN))
print(add_circle_token_to_context_with_name('DOCKER', 'DOCKER_LOGIN', DOCKER_LOGIN))
print(add_circle_token_to_context_with_name('DOCKER', 'DOCKER_PASSWORD', DOCKER_TOKEN))
print(add_circle_token_to_context_with_name('TERRAFORM_CLOUD', 'TF_CLOUD_KEY', TF_CLOUD_KEY))
print(add_circle_token_to_context_with_name('DIGITAL_OCEAN', 'DIGITALOCEAN_TOKEN', DIGITALOCEAN_TOKEN))

# # Warning uncommenting the code block below will delete all the contexts created above
# # To delete the values from CircleCI contexts uncomment the lines below
#
# def delete_contexts():
#   context_ids = get_circleci_api_request(F'context?owner-id={CIRCLECI_ORG_ID}&owner-type=organization', None).get('items')
#   for ctx in context_ids:
#     if ctx == None:
#       #Do nothing
#       print('-----\n')
#     else:
#       #delete the context
#       message = delete_circleci_api_request(f'context/', ctx.get('id')).get('message')
#       print(f"Context ID: {ctx.get('id')} Name: {ctx.get('name')} {message}") 
#
# # execute the delete context call
# delete_contexts()