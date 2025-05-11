CONTROLLER_NAMESPACE="kube-system"
SECRET_NAMESPACE="default"
SEAL_NAME="sealed-secrets"
LOG_FILE="re-encryption.log"

echo "Fetching the latest public key..."
kubeseal --fetch-cert --controller-namespace $CONTROLLER_NAMESPACE --output /tmp/sealed-secrets-cert.pem

if [ ! -f /tmp/sealed-secrets-cert.pem ]; then
  echo "Error: Failed to fetch the public certificate!" | tee -a $LOG_FILE
  exit 1
fi
echo "Public key fetched successfully." | tee -a $LOG_FILE

echo "Fetching all SealedSecrets in the cluster..."
kubectl get sealedsecrets --all-namespaces -o json | jq -r '.items[].metadata.name' > sealedsecrets_list.txt

if [ ! -s sealedsecrets_list.txt ]; then
  echo "No SealedSecrets found in the cluster." | tee -a $LOG_FILE
  exit 1
fi

echo "Starting re-encryption process for SealedSecrets..." | tee -a $LOG_FILE
while IFS= read -r secret_name; do
  echo "Processing SealedSecret: $secret_name" | tee -a $LOG_FILE

  # Step 1: Fetch the SealedSecret YAML and decrypt it
  kubectl get sealedsecret -n $SECRET_NAMESPACE $secret_name -o yaml > /tmp/$secret_name.yaml

  # Decrypt the SealedSecret using the current private key
  kubeseal --controller-namespace $CONTROLLER_NAMESPACE --decrypt --input /tmp/$secret_name.yaml --output /tmp/$secret_name-decrypted.yaml

  if [ $? -ne 0 ]; then
    echo "Failed to decrypt SealedSecret: $secret_name" | tee -a $LOG_FILE
    continue
  fi
  echo "Decrypted SealedSecret: $secret_name" | tee -a $LOG_FILE

  # Step 2: Re-encrypt using the latest public key
  kubeseal --controller-namespace $CONTROLLER_NAMESPACE --cert /tmp/sealed-secrets-cert.pem --format=yaml --input /tmp/$secret_name-decrypted.yaml --output /tmp/$secret_name-sealed.yaml

  if [ $? -ne 0 ]; then
    echo "Failed to re-encrypt SealedSecret: $secret_name" | tee -a $LOG_FILE
    continue
  fi
  echo "Re-encrypted SealedSecret: $secret_name" | tee -a $LOG_FILE

  # Step 3: Apply the re-encrypted SealedSecret back to the cluster
  kubectl apply -f /tmp/$secret_name-sealed.yaml

  if [ $? -eq 0 ]; then
    echo "Successfully updated SealedSecret: $secret_name" | tee -a $LOG_FILE
  else
    echo "Failed to update SealedSecret: $secret_name" | tee -a $LOG_FILE
  fi

echo "Re-encryption process completed." | tee -a $LOG_FILE
