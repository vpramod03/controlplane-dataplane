export k3s_token = "SECRET"
export s3_config_file_path = "/usr/bin/s3cfg"
export bucket_name = "intelops_k3s"
echo " Installing K3s Master "
curl -sfL https://get.k3s.io | sh -s - server --token=$K3S_TOKEN
echo " K3s Installed "
export config_path=/etc/rancher/k3s/k3s.yaml
kubectl get pods --all-namespaces
yum install s3cmd
echo " access_key = "$s3_access_key"
host_base = "$s3_host_base"
host_bucket = "$s3_host_bucket"
secret_key = "$s3_secret_key" " >> "$s3_config_file_path"
echo "[INFO] Testing S3 connection"
s3cmd --no-check-certificate ls
if [ $? -eq 0 ]
then
echo "[INFO] S3 connection test success"
else
echo "[ERROR] S3 connection test failed"
exit 1
fi

echo "[INFO] Checking if s3://${BUCKET_NAME} bucket exists"
s3cmd --no-check-certificate ls ${BUCKET_NAME}
touch test-bucket.txt
s3cmd --no-check-certificate put test-bucket.txt s3://${BUCKET_NAME}/test-bucket.txt
if [ $? -eq 0 ]
then
echo "[INFO] s3://${BUCKET_NAME} bucket exists.No need to create"
else
echo "[INFO] s3://${BUCKET_NAME} bucket does not exists. Creating one..."
s3cmd --no-check-certificate mb s3://${BUCKET_NAME}
if [ $? -eq 0 ]
then
echo "[INFO] s3://${BUCKET_NAME} bucket created successfully"
else
echo "[ERROR] s3://${BUCKET_NAME} bucket creation failed"
exit 2
fi
fi
echo "[INFO] Uploading k3s config to s3"
s3cmd --no-check-certificate put ${config_path} s3://${BUCKET_NAME}/config/k3s.yaml
if [ $? -eq 0 ]
then
echo "[INFO] Upload success"
else
echo "[ERROR] Upload failed"
exit 3
fi
