
C:\Users\Owner\AppData\Local\GitHub\PortableGit_69bd5e6f85e4842f07db71c9618a621154c52254\etc\ssh
C:\Users\Owner\AppData\Local\GitHub\PortableGit_69bd5e6f85e4842f07db71c9618a621154c52254\usr\lib\ssh

other sources

C:\ProgramData\ssh
ssh_host_dsa_key
ssh_host_dsa_key.pub
ssh_host_ecdsa_key
ssh_host_ecdsa_key.pub
ssh_host_ed25519_key
ssh_host_ed25519_key.pub
ssh_host_rsa_key
ssh_host_rsa_key.pub
sshd.pid
sshd_config

currently
C:\Users\Owner\.ssh

RecoveryKeyPair.ppk
config
config.txt
gigster99.ppk
gigster99.ppk.txt
github_rsa
github_rsa-name.txt
github_rsa.pub
id_rsa
id_rsa-name.txt
id_rsa.pub
known_hosts
known_hosts.txt

draft
```yaml
ssh_config:
  github:
    key_locations:
      windows: "C:\\Users\\Owner\\.ssh\\id_ed25519"
      macos: "$HOME/.ssh/id_ed25519" 
      wsl: "/home/gig/.ssh/id_ed25519"
    key_type: "ed25519"  # or "rsa"
    hosts:
      - "github.com"
      - "*.github.com"
```

targets
E:\users\gigster\workspace\.ssh



# Add GitHub key
pwsh ssh-build.ps1 add -Name "GitHub" -Service "github" `
  -PrivateKeyPath "~/.ssh/id_rsa_github" `
  -Host "github.com" -User "git"

# Add WinSCP key
pwsh ssh-build.ps1 add -Name "Production" -Service "winscp" `
  -PrivateKeyPath "~/.ssh/id_rsa_prod" `
  -Host "prod.example.com" -User "deploy"

# List all keys
pwsh ssh-build.ps1 list

# Validate keys exist
pwsh ssh-build.ps1 validate

# Test connections
pwsh ssh-build.ps1 test GitHub
pwsh ssh-build.ps1 test  # Test all

# Generate SSH config
pwsh ssh-build.ps1 configure