
## Command Library for Profile & Environment Administration

### 1\. Core Script Execution Commands

These are the primary commands for running the scripts you've developed.

  * **Run the Profile Generator**

    ```powershell
    pwsh -ExecutionPolicy Bypass -File .\profile-generator.ps1 -ValuesPath .\profile-values.yaml -Apply
    ```

      * **Purpose**: Executes the main generator script to create or update the profile files based on the YAML configuration.
      * **When to Use It**: After making changes to your `profile-values.yaml` or when setting up a new machine after the initial cleanup.

  * **Run the PATH Cleanup Script**

    ```powershell
    pwsh -ExecutionPolicy Bypass -File .\cleanup-path.ps1 -ValuesPath .\profile-values.yaml
    ```

      * **Purpose**: Programmatically removes old, conflicting paths from the user's permanent `PATH` environment variable.
      * **When to Use It**: Run **once as an Administrator** on any new or misconfigured machine to ensure a clean slate before generating a profile.

-----

### 2\. PowerShell Profile Management

These commands are for directly interacting with PowerShell's profile files.

  * **Edit Your Main Profile**

    ```powershell
    notepad $PROFILE
    ```

      * **Purpose**: Opens the current user's primary PowerShell profile script in Notepad for manual editing.
      * **When to Use It**: When you need to quickly check or modify the main loader script.

  * **Force-Overwrite the Main Profile (The "Final Reset")**

    ```powershell
    $CorrectContent = '. "E:\path\to\your\profile.generated.ps1"'
    Set-Content -Path $PROFILE -Value $CorrectContent -Force
    ```

      * **Purpose**: Programmatically replaces the entire content of the main profile with a single, correct line.
      * **When to Use It**: The definitive final step to fix a corrupted or misconfigured profile, ensuring it only contains the correct command.

  * **Discover All Active Profiles**

    ```powershell
    $PROFILE | Get-Member -MemberType NoteProperty | ForEach-Object {
        $profilePath = $PROFILE.$($_.Name)
        if (Test-Path $profilePath) {
            Write-Host "--- Checking Profile: $($_.Name) ---" -ForegroundColor Yellow
            Write-Host "Path: $profilePath"
            Get-Content $profilePath
        }
    }
    ```

      * **Purpose**: Lists all four possible PowerShell profile files for the current user and host, and prints the content of any that exist.
      * **When to Use It**: When you suspect a command is running from an unexpected profile file. This was a critical step in our debugging.

-----

### 3\. Environment Variable Management

These commands are for inspecting and changing environment variables.

  * **Set a Temporary (Session) Variable**

    ```powershell
    $env:VARIABLE_NAME = "value"
    ```

      * **Purpose**: Creates or modifies an environment variable for the **current PowerShell session only**. The change disappears when the terminal is closed.
      * **When to Use It**: Perfect for temporarily setting variables like `UV_CACHE_DIR` or adding a tool to the `PATH` for a specific task without making permanent changes.

  * **Set a Permanent User Variable**

    ```powershell
    [Environment]::SetEnvironmentVariable("VARIABLE_NAME", "value", "User")
    ```

      * **Purpose**: Creates or modifies an environment variable in the Windows Registry for the current user. This change is **permanent** and will be present in all future terminal sessions.
      * **When to Use It**: When a tool requires a permanent variable to be set (e.g., as performed by the `cleanup-path.ps1` script).

-----

### 4\. System & Environment Diagnostics

These are the investigation commands we used to find the root cause of problems.

  * **Inspect the `PATH` Variable**

    ```powershell
    $env:PATH -split ';'
    ```

      * **Purpose**: Displays the current session's `PATH` variable as a clean, one-entry-per-line list.
      * **When to Use It**: The first step in diagnosing any "command not found" error or when you suspect `PATH` conflicts.

  * **Find a Command's Location (PowerShell Way)**

    ```powershell
    Get-Command <command-name>
    ```

      * **Purpose**: The definitive PowerShell command to find any cmdlet, function, alias, or executable file that PowerShell can execute.
      * **When to Use It**: To confirm exactly which version of a tool (e.g., `python.exe`) your session is using. This was key to verifying our portable setup.

  * **Find an Executable's Location (External Tool)**

    ```powershell
    where.exe <executable-name>
    ```

      * **Purpose**: An external utility that searches the `PATH` for executable files (`.exe`, `.cmd`, etc.). It does **not** find PowerShell aliases or functions.
      * **When to Use It**: A quick alternative to `Get-Command` for finding executables, but less comprehensive within PowerShell.

  * **Inspect Windows Startup Locations**

    ```powershell
    # Opens the user's startup folder in File Explorer
    shell:startup
    ```

      * **Purpose**: Checks for shortcuts in the user's startup folder that may be launching rogue processes.
      * **When to Use It**: When you suspect a program or script is being launched automatically upon user login.

  * **Check Windows Terminal Settings**

    1.  Open Windows Terminal.
    2.  Go to **Settings** (`Ctrl + ,`).
    3.  Click **"Open JSON file"**.

    <!-- end list -->

      * **Purpose**: To inspect the `settings.json` file for custom `commandline` entries that may be overriding the default shell launch command. This was a critical diagnostic step for us.

-----

### 5\. Portable Tool Management (`uv` & Node.js)

These commands are specific to managing your portable toolchains.

  * **List Installed Python Versions (`uv`)**

    ```powershell
    uv python list
    ```

      * **Purpose**: Shows all Python interpreters that `uv` is aware of.
      * **When to Use It**: To verify if `uv` is using the correct portable cache. (Note: We found this command can be misleading, but it's still a primary diagnostic tool).

  * **Install Python with a Portable Cache (`uv`)**

    ```powershell
    uv python install <version> --cache-dir "E:\path\to\your\uv_cache"
    ```

      * **Purpose**: Installs a Python version into a specific, portable directory, overriding all other configurations.
      * **When to Use It**: The most reliable way to ensure your Python installations are fully portable.

  * **Verify Portable Node.js Installation**

    ```powershell
    node --version
    Get-Command node
    ```

      * **Purpose**: Confirms that the `node` command is working and that PowerShell is using the executable from your specified portable directory.
      * **When to Use It**: After setting up your portable Node.js directory and adding it to the `PATH`.

-----

### 6\. File & Directory Cleanup

This is the command used to reset parts of the environment.

  * **Forcefully Remove a Directory**
    ```powershell
    Remove-Item -Path "C:\path\to\directory" -Recurse -Force -ErrorAction SilentlyContinue
    ```
      * **Purpose**: Completely deletes a folder and all its contents without prompting for confirmation.
      * **When to Use It**: Essential for cleaning up old cache directories (like `$env:APPDATA\uv`) or removing temporary test folders to ensure a clean state.
