
update profile-values.yaml
```
toolchain:
  python:
    version: "3.9.18"  # Updated from 3.11
    wsl:
      path: "/mnt/e/users/gigster/workspace/.pyenv/shims/python"
      # Or if pyenv global works: "/usr/bin/python3"
```

# List installed versions
pyenv versions

# List available versions to install
pyenv install --list | grep "3\."

# Install specific version
pyenv install 3.12.2

# Set global default
pyenv global 3.9.18

# Set project-specific version (creates .python-version file)
pyenv local 3.9.18

# Show current version
pyenv version

# Uninstall version
pyenv uninstall 3.11.2
