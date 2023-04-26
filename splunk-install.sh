#!/bin/bash
splunkdir=0
splunk_install() {
splunklbl="$1"
password="$2"
splunkdir="/opt/$1"
if [ $splunklbl = "splunk" ];    then
        curl -O 'https://download.splunk.com/products/splunk/releases/8.2.6/linux/splunk-8.2.6-a6fe1ee8894b-Linux-x86_64.tgz'
    else
        curl -O 'https://download.splunk.com/products/universalforwarder/releases/8.2.6/linux/splunkforwarder-8.2.6-a6fe1ee8894b-Linux-x86_64.tgz'
fi
curl -Ok 'https://j4cknife.mimas.feralhosting.com/base_configs.tar'
tar xf $splunklbl-*tgz -C /opt
tar xf base_configs.tar -C /tmp
chown -R splunk.splunk /tmp/Base*
useradd splunk
chown -R splunk.splunk $splunkdir
printf "[user_info]\nUSERNAME = admin\nPASSWORD = $password" | tee $splunkdir/etc/system/local/user-seed.conf
$splunkdir/bin/splunk start --accept-license
$splunkdir/bin/splunk stop
$splunkdir/bin/splunk enable boot-start -systemd-managed 1 -user splunk
if [ $splunklbl = "splunk" ];    then
sed -i "s/LimitNOFILE=65536/LimitNOFILE=65536\nLimitNPROC=16000/" /etc/systemd/system/Splunkd.service | grep Limit
    else
        sed -i "s/LimitNOFILE=65536/LimitNOFILE=65536\nLimitNPROC=16000/" /etc/systemd/system/SplunkForwarder.service | grep Limit
fi
echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
cat > /etc/systemd/system/disable-thp.service << EOF
[Unit]
Description=Disable Transparent Huge Pages (THP)

[Service]
Type=simple
ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start disable-thp
systemctl enable disable-thp
cat > ./configs.sh << EOF
#!/bin/bash
lab=\$1
conf_path=\$2
if [ -z "\$1" ]; then
  printf "no ops, need syntax: configs.sh <lab> <conf_path>\nconfigs.sh cfrtl5 /opt/splunk/etc/apps"
  exit
elif [ -z "\$2" ]; then
  echo \$1 \$2
  echo "no path, using splunk apps"
  conf_path=$splunkdir/etc/apps
else
  for app in \$(cat list); do
  echo "\${app} \${path}\${lab}_\${app}/"
# cp -a /tmp/Configurations\ -\ Base/org_\${app}/ \${conf_path}\${lab}_\${app}/
# echo "\${conf_path}/\${lab}_\$(echo \${app} | sed -r 's/(org_)//')"
  cp -a /tmp/Configurations\ -\ Base/\${app} \${conf_path}/\${lab}_\$(echo \${app} | sed -r 's/(org_)//')
  done
fi
chown -R splunk.splunk \${conf_path}
exit
EOF
printf "org_all_forwarder_outputs\norg_all_indexes\norg_all_deploymentclient\norg_all_indexer_base\norg_all_search_base\norg_full_license_server\norg_indexer_volume_indexes" > list
chmod +x ./configs.sh
}
splunk_install $1 $2