Moving your Google Cloud operations to the Debian/WSL terminal is a great step for robustness and scripting ease.

Here are the steps to install and initialize the **Google Cloud CLI** using the official APT repository method inside your **Debian (WSL) terminal**:

-----

## 🛠️ Step 1: Install Dependencies and GPG Key

First, open your **Debian (WSL) terminal** from Windows Terminal and run the following two commands to ensure your system can securely download packages from Google's repository.

1.  **Install Required Utilities:**
    ```bash
    sudo apt update && sudo apt install -y apt-transport-https ca-certificates gnupg curl
    ```
2.  **Import the Google Cloud public key:**
    (This is the secure way to add the key for modern Debian versions.)
    ```bash
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    ```

-----

## 📦 Step 2: Add the Cloud SDK Repository

Next, you need to tell Debian where to find the Google Cloud SDK packages by adding the repository to your system's source list.

1.  **Add the repository source file:**
    ```bash
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    ```

-----

## ⬇️ Step 3: Update and Install the Google Cloud CLI

Now that the source is configured, update your local package list and install the main package.

1.  **Update and Install the gcloud CLI:**
    ```bash
    sudo apt update && sudo apt install google-cloud-cli
    ```

-----

## ⚙️ Step 4: Initialize the gcloud CLI

Once the installation completes, run the `gcloud init` command to authenticate your account and set your default project configuration.

1.  **Start Initialization:**

    ```bash
    gcloud init
    ```

2.  **Follow the Prompts:**

      * It will ask you to log in. Since you are in a WSL terminal, it will provide a link you can copy and paste into your Windows browser.
      * In the browser, log in with your Google account and grant permissions.
      * The browser will give you a **verification code** to copy. Paste this code back into your Debian terminal.
      * You will then be prompted to select a **Google Cloud Project** from a list and optionally configure a **default Compute Engine region/zone**.

After completing these steps, your Debian terminal is fully configured and authenticated to use `gcloud` with maximum reliability.

Would you like the full `gcloud storage cp` command to use from your new Debian terminal, including how to reference files on your Windows C: drive?