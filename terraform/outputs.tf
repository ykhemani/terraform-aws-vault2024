output "a_hosts_file_entry" {
  value = "${aws_instance.instance.public_ip} vault.${var.domain} mysql.${var.domain} web.demo.${var.domain}"
}

output "b_connection_strings" {
  value = {
    ssh       = "ssh -i ./ssh_key ubuntu@${aws_instance.instance.public_ip}",
    vault_url = "https://vault.${var.domain}:8200/",
    web_url   = "https://web.demo.${var.domain}/",
  }
}

output "e_private_ip" {
  value = aws_instance.instance.private_ip
}

output "d_public_ip" {
  value = aws_instance.instance.public_ip
}

output "z_info" {
  value = "Your ssh key has been saved as ssh_key, with the corresponding public key saved as ssh_key.pub. The CA cert has been saved as ca.pem. To use this demo environment, please add the hosts_file_entry output to your /etc/hosts file. Please add the CA Cert to your trust store. You may then connect to the ssh environment."
}
