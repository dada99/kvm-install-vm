from jinja2 import Template
import ipaddress
group_count = input("How many groups to create this time? ")
k8s_group_template = """[k8s-lab-{{ groupnum }}]
ubuntu-lab-{{ groupnum }}-master	ansible_ssh_host={{ groupip }}	ansible_user=ubuntu
ubuntu-lab-{{ groupnum }}-worker-1	ansible_ssh_host={{ groupip+1 }}	ansible_user=ubuntu
ubuntu-lab-{{ groupnum }}-worker-2	ansible_ssh_host={{ groupip+2 }}	ansible_user=ubuntu"""
tm = Template(k8s_group_template)
first_ip = u'192.168.122.100'
first_ip_addr = ipaddress.IPv4Address(first_ip)
for i in range(int(group_count)):
  msg = tm.render(groupnum=i,groupip=(first_ip_addr+i*3))
  print(msg)
