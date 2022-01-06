# variables that can be overriden
#variable "hostname" { default = "simple" }
variable "domain" { default = "example.com" }
#variable "memoryMB" { default = 1024*1 }
#variable "cpu" { default = 1 }

variable "vm_names" {
  type = list(string)
  default = ["alpha","bravo", "charlie", "tanque"]
}


###########
terraform {
 required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
     version = "0.6.3"
    }
  }
}
###########

# instance the provider
provider "libvirt" {
#  uri = "qemu:///system"
  uri = "qemu+ssh://rcampove@172.16.12.135/system"
}

# fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "os_image" {
  count = length(var.vm_names)
  name = "${var.vm_names[count.index]}-bionic.qcow2"
#  name = "${var.hostname}-os_image"
  pool = "default"
  source = "/home/rcampove/terraform/test/img/bionic-server-cloudimg-amd64.img"
  format = "qcow2"
}

# Use CloudInit ISO to add ssh-key to the instance
resource "libvirt_cloudinit_disk" "commoninit" {
          count = length(var.vm_names)
          name = "${var.vm_names[count.index]}-cloudinit.iso"
          pool = "default"
          user_data = data.template_file.user_data[count.index].rendered
          network_config = data.template_file.network_config[count.index].rendered
}


data "template_file" "user_data" {
  count = length(var.vm_names)
  template = file("${path.module}/user_cloud_init.cfg")
  vars = {
    Hostname = var.vm_names[count.index]
    #fqdn = "${var.hostname}.${var.domain}"
  }
}

data "template_file" "network_config" {
  count = length(var.vm_names)
  template = file("${path.module}/network_config_dhcp.cfg")
  vars = {
       IPv4Address = "192.168.0.${240 + count.index}"
  }
}


# Create the machine
resource "libvirt_domain" "domain-ubuntu" {
  count = length(var.vm_names)
  name = var.vm_names[count.index]
  memory = "16384"
  vcpu = 2

#  name = var.hostname
#  memory = var.memoryMB
#  vcpu = var.cpu

  disk {
       volume_id = libvirt_volume.os_image[count.index].id
  }
  network_interface {
       wait_for_lease = false
#       network_name = "default"
      network_name = "bridge-br0"
      #bridge = "br0"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit[count.index].id

  # IMPORTANT
  # Ubuntu can hang is a isa-serial is not present at boot time.
  # If you find your CPU 100% and never is available this is why
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = "true"
  }
}

terraform { 
  required_version = ">= 0.12"
}
#output "ips" {
#  # show IP, run 'terraform refresh' if not populated
#  value = libvirt_domain.domain-ubuntu.*.network_interface.0.addresses
#}

resource "null_resource" "clean-ssh" {
  provisioner "local-exec" {
     when = "destroy"
     command = "/home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/clean-ssh.sh | tee -a /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/clean-ssh.log "
     }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [libvirt_domain.domain-ubuntu]
  create_duration = "60s"
}

resource "null_resource" "ansible-ping" {
 depends_on = [time_sleep.wait_30_seconds]       
 provisioner "local-exec" {
    command = "/usr/bin/ansible -i /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/inventory nodes -b -m shell -a 'uptime' | tee -a /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/ejecucion.ansible"
  }
}

resource "null_resource" "ansible-install-k8s" {
 depends_on = [null_resource.ansible-ping]       
 provisioner "local-exec" {
    command = "/usr/bin/ansible-playbook -i /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/inventory /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/install-k8s.yml | tee -a /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/ejecucion.ansible"
  }
}


resource "null_resource" "ansible-install-master" {
 depends_on = [null_resource.ansible-install-k8s]       
 provisioner "local-exec" {
    command = "/usr/bin/ansible-playbook -i /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/inventory /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/master.yml | tee -a /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/ejecucion.ansible"
  }
}

resource "null_resource" "ansible-install-workers" {
 depends_on = [null_resource.ansible-install-master]       
 provisioner "local-exec" {
    command = "/usr/bin/ansible-playbook -i /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/inventory /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/workers.yml | tee -a /home/rcampove/terraform/test/terraform-libvirt-ubuntu-examples/simple/ejecucion.ansible"
  }
}

