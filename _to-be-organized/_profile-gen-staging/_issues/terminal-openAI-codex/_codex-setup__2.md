## Secrets

This project requires environment variables for authentication and configuration.  
Values are managed **outside of the repository** and must never be committed.  

### Environment Setup
- **Windows (PowerShell 7)**: environment variables are loaded from `profile.generated.ps1`.  
- **WSL/Debian (Bash)**: environment variables are loaded from `.bashrc.generated`.  
- **Local secrets** (such as API keys) are stored in `.env.secrets` and referenced by those profile scripts.  

Both shells source these files on startup, so variables are automatically available when running commands or tests.  

### Required Variables
- `API_KEY`: stored in `.env.secrets`; exported by both profile scripts.  
- `AWS_PROFILE`: developer’s AWS named profile; set locally, not in code.  
- `DB_PASSWORD`: stored in `.env.secrets`; exported to environment.  
- `OPENAI_API_KEY`: configured in `.env.secrets`; loaded by profiles.  

### Usage in Code
Codex and developers should assume these variables are already available at runtime:
- **Node.js** → `process.env.VAR`  
- **Python** → `os.environ["VAR"]`  
- **PowerShell** → `$env:VAR`  
- **Bash** → `$VAR`  

### Guidelines
- Never hardcode or inline secret values.  
- Never commit `.env.secrets`, `profile.generated.ps1`, or `.bashrc.generated`.  
- If a new secret is introduced, add it here with a note on where it is set.  
- Codex dialogues may reference environment variables symbolically, but the real values are supplied by the developer’s shell environment.  
