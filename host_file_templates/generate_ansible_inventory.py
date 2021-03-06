#! /usr/bin/python
from jinja2 import Template,Environment, FileSystemLoader
import os,sys
import ipaddress
from pathlib import Path
FIRST_IP = u'192.168.122.100'
FIRST_IP_ADDR = ipaddress.IPv4Address(FIRST_IP)
project_type = sys.argv[1] if len(sys.argv) > 1 else "k8s-1m-2w" # 
print('Using {} type to generate.'.format(project_type))
project_name = input("Give your project a name? ")
group_count = input("How many groups to create this time? ")
try:
  my_path = Path('{}/{}/'.format(os.path.dirname(os.path.abspath(__file__)),project_name)) #Create Path Object with project name
  while(my_path.exists()): 
    project_name = input("Your project is exist,plase give another name: ")
    my_path = Path('{}/{}/'.format(os.path.dirname(os.path.abspath(__file__)),project_name))
  my_path.mkdir()  
except:
  pass
#print(os.path.dirname(__file__)) # using python python_file_name will set os.path.dirname(__file__) to empty
template_path = '{}/templates/{}'.format(os.path.dirname(os.path.abspath(__file__)),project_type)
loader = FileSystemLoader(template_path)
env = Environment(loader=loader)

k8s_group_template = env.get_template('k8s-1m-2w.j2')
#f1 = open(my_path+'/inventory','w')
f1 = my_path / 'inventory'
for i in range(int(group_count)):
    msg = k8s_group_template.render(groupnum=i,groupip=(FIRST_IP_ADDR+i*3),p_name=project_name) # Output for Ansible inventory file
    print(msg)
    with f1.open('a') as f:
        f.write(msg)
        f.write('\n')

f2 = my_path / 'hosts'
k8s_cluster_hosts_template = env.get_template('k8s-1m-2w-hosts.j2')
print('\n')
for i in range(int(group_count)):
    msg = k8s_cluster_hosts_template.render(groupip=(FIRST_IP_ADDR+i*3),groupnum=i,p_name=project_name) # Output for /etc/hosts
    print(msg)
    with f2.open('a') as f:
        f.write(msg)
        f.write('\n')
