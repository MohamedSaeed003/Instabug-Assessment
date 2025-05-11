# Instabug-Assessment

## Why SealedSecrets?

### What problem do SealedSecrets solve?

Managing sensitive data like API keys, credentials, and tokens in Kubernetes can be risky if secrets are stored in plaintext or committed to version control. Kubernetes Secret objects are base64-encoded but not encrypted, making them vulnerable if not handled carefully.

**SealedSecrets**, provided by Bitnami, solve this problem by allowing secrets to be:

- **Encrypted using a controller's public key**
- **Safely stored in version control systems (like GitHub)**
- **Decrypted only inside the Kubernetes cluster using a private key**

---

## Understanding Public/Private Key Encryption

SealedSecrets relies on **asymmetric encryption**, which uses a **public key** and a **private key** pair:

- The **public key** is used to **encrypt** data.
- The **private key** is used to **decrypt** the data.

This means:

- Anyone (e.g., a developer or CI pipeline) can use the **public key** to encrypt a Kubernetes Secret into a `SealedSecret`.
- Only the **SealedSecrets controller**, which holds the private key, can decrypt it inside the Kubernetes cluster.

This ensures:
- Secrets can be **shared safely** (e.g., committed to Git).
- Only the controller in the target cluster can **unseal** and apply the secret.

### What Happens When You Run `kubeseal`?

When you run `kubeseal` to encrypt a Kubernetes Secret, the following steps occur:

1. A random **symmetric key** (e.g., an AES key) is generated.
2. The actual secret data  is encrypted using **AES** and that random key.
3. The **AES key** is then encrypted using the **public key** from the SealedSecrets controller.
4. Both the AES-encrypted secret and the encrypted AES key are stored in the resulting `SealedSecret` YAML file.

Only the **SealedSecrets controller**, which holds the corresponding **private key**, can:

- Decrypt the encrypted AES key.
- Use that AES key to decrypt the actual secret value.

This process ensures that secrets can be safely stored in Git and only decrypted by the target Kubernetes cluster.

---


## SealedSecrets Architecture: Key Components

To understand how SealedSecrets work, it's important to be familiar with the core components involved:

### 1. SealedSecrets Controller

- Runs as a Kubernetes controller inside your cluster.
- Holds the **private key** used to decrypt `SealedSecrets`.
- Watches for `SealedSecret` resources and converts them into standard Secret objects.
- Can optionally manage key rotation.

### 2. `kubeseal` CLI

- A command-line tool used to **seal** secrets before applying them to the cluster.
- Encrypts a standard Kubernetes Secret using the controller’s **public key**.
- The resulting `SealedSecret` can be safely stored in version control (e.g., GitHub).
- Does **not require cluster access** to seal secrets.

### 3. SealedSecret CRD (Custom Resource Definition)

- A Kubernetes **Custom Resource** named `SealedSecret`.
- Extends Kubernetes to understand and handle encrypted secrets.
- The controller watches this resource type and handles decryption + creation of Secret objects transparently.

---

## Why Automate Re-encryption?

Public and private keys in sealedsecret may be rotated for security:

- Existing SealedSecrets are still valid but encrypted with **outdated keys**
- New SealedSecrets use the **latest public key**
- Keeping secrets sealed with old keys could pose a **security risk**

Automating re-encryption ensures that:
- All SealedSecrets are consistently using the **latest public key**
- Manual resealing becomes unnecessary
- The cluster remains **secure and maintainable**

---

##  Steps for basic Example:
1. To run it in windows u have to work in WSL(Windows Subsystem for Linux)
  ```bash
  wsl --install
```

2. install [Docker Desktop](https://www.docker.com/products/docker-desktop) and check Settings, Resources,  WSL Integration
to verfiy Docker works 
```bash
dokcer version
```

3. we need to create K8s cluster, we choose to use [Minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download)
4. install [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets?tab=readme-ov-file#kubeseal)
5. Install kubeseal
```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.29.0/kubeseal-0.29.0-linux-amd64.tar.gz
```
and for verification
```bash
kubeseal --version
```
```bash
kubeseal --help
```
![image](https://github.com/user-attachments/assets/eb812501-e98e-4e88-bfd0-b876a5eb6b09)
--
6. Install the SealedSecret CRD and server-side controller into the kube-system namespace:
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.29.0/controller.yaml
```
for verification 
```bash
kubectl get pods -n kube-system
```
![image](https://github.com/user-attachments/assets/2e807654-882b-446e-b8c3-814bb78ca7b2)
--
7. Lets Generates a Kubernetes secret named mysecret
![image](https://github.com/user-attachments/assets/b698fce7-568e-4f89-9bf4-8b2c928658da)
secret_word not encrypted its base64-encoded
to encrypted we should pipe kubeseal
![image](https://github.com/user-attachments/assets/cb3fd78e-8842-43e0-9b15-ba2b6ba39153)

and here if we add the output file to our cluster the secret_word will be decrypted 
![image](https://github.com/user-attachments/assets/a5d3656f-a69f-4541-83d8-d80b68777870)
that happen because sealedSecret decrypts the secret for those who have access to K8s Cluster

---
## Steps for Automate Re-encryption:

1. Identify All Existing SealedSecrets in the Cluster
  to Retrieve all SealedSecrets that are currently present in the Kubernetes cluster.
  ```bash
  kubectl get sealedsecrets --all-namespaces
  ```
2. Fetch All Active Public Keys of the SealedSecrets Controller
  Fetch the latest public keys from the SealedSecrets controller.
  ```bash
  kubectl get secret -n kube-system sealed-secrets-key -o yaml
  ```
3. Decrypt Each SealedSecret Using the Existing Private Keys
  ```bash
  kubeseal --controller-namespace kube-system --decrypt --sealed-secret <sealed-secret-file>
  ```
4. Re-encrypt the Decrypted Secrets Using the Latest Public Key
   Once the SealedSecrets are decrypted, re-encrypt them with the latest public key.
  ```bash
  kubeseal --controller-namespace kube-system --format=yaml --cert <path-to-new-public-key> --re-encrypt <decrypted-secret>
  ```
5. Update the Existing SealedSecret Objects with the Re-encrypted Data
  to Replace the existing SealedSecret objects in the cluster with the newly re-encrypted data.
  ```bash
  kubectl apply -f <path-to-re-encrypted-sealedsecret.yaml>
  ```
6. Logging and Reporting Mechanism
to track the progress of the re-encryption process.
