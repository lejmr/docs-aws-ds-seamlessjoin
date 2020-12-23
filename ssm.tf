

resource "aws_ssm_document" "join" {
  name          = "${var.short_name}-JoinDirectoryServiceDomain"
  document_type = "Command"

  content = <<DOC
  {
    "schemaVersion": "1.2",
    "description": "Check ip configuration of a Linux instance.",
    "parameters": {
      "directoryId": {
        "type": "String",
        "description": "(Required) The ID of the AWS Directory Service directory."
      },
      "directoryName": {
        "type": "String",
        "description": "(Required) The name of the directory; for example, test.example.com"
      },
      "directoryOU": {
        "type": "String",
        "default": "",
        "description": "(Optional) The Organizational Unit (OU) and Directory Components (DC) for the directory; for example, OU=test,DC=example,DC=com"
      },
      "dnsIpAddresses": {
        "type": "String",
        "default": "",
        "description": "(Optional) The IP addresses of the DNS servers in the directory. Required when DHCP is not configured. Learn more at https://docs.aws.amazon.com/directoryservice/latest/admin-guide/simple_ad_dns.html"
      }
    },
    "runtimeConfig": {
      "aws:runShellScript": {
        "properties": [
          {
            "id": "0.aws:runShellScript",
            "runCommand": [
              "set -e",
              "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 15; done",
              "echo '[libdefaults]' > /etc/krb5.conf",
              "echo 'rdns=false' >> /etc/krb5.conf",
              "if [ 'x{{ dnsIpAddresses }}' != 'x' ]; then",
                "echo '* Modify DNS to resolve {{ directoryName }} from {{ dnsIpAddresses }}'",
                "sed -i 's/^.DNS=.*/DNS={{ dnsIpAddresses }}/g' /etc/systemd/resolved.conf",
                "sed -i 's/^.Domains=.*/Domains={{ directoryName }}/g' /etc/systemd/resolved.conf",
                "sed -i 's/^.Cache=.*/Cache=yes/g' /etc/systemd/resolved.conf",
                "systemctl restart systemd-resolved.service",
              "fi",
              "apt update && apt install -y awscli jq realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit",
              "instanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
              "computerName=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 | sed 's/\\./-/g')",
              "region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r)",
              "password=$(date +%s | sha256sum | base64 | head -c 32 ; echo)",
              "if [ 'x{{ directoryOU }}' = 'x' ]; then",
                "aws --region $region ds create-computer --directory-id {{ directoryId }} --computer-name $computerName --password $password --computer-attributes Name=description,Value=$instanceId",
              "else",
                "aws --region $region ds create-computer --directory-id {{ directoryId }} --organizational-unit-distinguished-name {{ directoryOU }} --computer-name $computerName --password $password --computer-attributes Name=description,Value=$instanceId",
              "fi",
              "realm join -v {{ directoryName }} --computer-name $computerName --one-time-password $password",
              "sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config",
              "systemctl restart sshd.service",
              "echo session required pam_mkhomedir.so skel=/etc/skel/ umask=0077 >> /etc/pam.d/common-session"

            ]
          }
        ]
      }
    }
  }
DOC
}



# For short name logins
#              ,
#              "sed -i 's/^use_fully_qualified_names.*/use_fully_qualified_names = False/g' /etc/sssd/sssd.conf",
#              "sed -i 's|^fallback_homedir.*|fallback_homedir = /home/%u|g' /etc/sssd/sssd.conf",
#              "sed -i 's/^sudoers:.*/sudoers:        files/g' /etc/nsswitch.conf",
#              "systemctl restart sssd.service",