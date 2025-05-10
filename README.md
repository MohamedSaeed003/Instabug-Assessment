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

##  Implementation:

