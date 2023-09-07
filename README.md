# Demo Tasks
Here are the results of the test using Terraform and Ansible.

## Demo gif (about 2 minutes)
![](https://s11.gifyu.com/images/SgPKF.gif)

# Environment
I chose to use AWS to run the machines, as AWS does not still supporting Ubuntu 21.04. Instead, I used 22.04.

# Prerequisites
You need to have Terraform and Ansible installed on your machine, as well as AWS credentials. If you don't have an AWS account, we've sent the credentials via email.

## Clone
```shell
git clone https://github.com/marcusgrenfell/DemoTasks
```

## Credentials
Edit the `terraform.tf` file and insert your access/private key.

## Terraform
Initialize and apply Terraform:
```shell
terraform init
terraform plan
terraform apply --auto-approve
```
After completing these steps, the machines will be ready. In the folder, you will find the inventory file, the nginx.conf file, and the machinekey.key.

## Ansible
Run the playbooks:
```shell
ansible-playbook -i inventory backend-playbook.yml
ansible-playbook -i inventory frontend-playbook.yml
```

## Test
Open your web browser and try accessing the frontend's public IP address.
