param(
    [string]$location = (Get-Location).Path
)

# If you can't run scripts, use Unblock-File cmdlet on this file. See https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file?view=powershell-7.3
# Also see https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.3

# Determine the operating system
$os = [System.Environment]::OSVersion.Platform
Write-Host "Your OS is: $os"


# --------- BEGIN Folder Structure ---------

# Create the location directory if it doesn't exist
if (-not (Test-Path -Path $location -PathType Container)) {
    New-Item -Path $location -ItemType Directory
}

# Create folders inside the project directory
$srcPath = Join-Path -Path $location -ChildPath "src"
$dataPath = Join-Path -Path $location -ChildPath "data"
$notebooksPath = Join-Path -Path $location -ChildPath "notebooks"

New-Item -Path $srcPath -ItemType Directory
Write-Host "Created directory: $srcPath"

New-Item -Path $dataPath -ItemType Directory
Write-Host "Created directory: $dataPath"

New-Item -Path $notebooksPath -ItemType Directory
Write-Host "Created directory: $notebooksPath"

Set-Location -Path $location

# --------- END Folder Structure ---------


# --------- BEGIN .gitignore ---------

# Check if the .git folder does not exist, then initialize a Git repository
$gitFolder = Join-Path -Path $location -ChildPath ".git"
if (-not (Test-Path -Path $gitFolder -PathType Container)) {
    git init $location
}

# Create the .gitignore file
$gitignorePath = Join-Path -Path $location -ChildPath ".gitignore"
# Add to .gitignore file
# Add data folder
Add-Content -Path $gitignorePath -Value "data/"
# Add environment(s)
Add-Content -Path $gitignorePath -Value ".env/"
# Add Jupyter Notebook
Add-Content -Path $gitignorePath -Value ".ipynb_checkpoints"
# Byte-compiled / optimized / DLL files
Add-Content -Path $gitignorePath -Value "__pycache__/"
Add-Content -Path $gitignorePath -Value "*.py[cod]"
Add-Content -Path $gitignorePath -Value "*$py.class"
# For more content, see also https://github.com/github/gitignore/blob/main/Python.gitignore


# --------- END .gitignore ---------


# --------- BEGIN Requirements File ---------

# Helps install Python packages. Can use pip or conda.
# Create a requirements file
$requirementsPath = Join-Path -Path $location -ChildPath "requirements.txt"
#
# This fixes ModuleNotFoundError: No module named 'notebook.base' when installing nbextensions
Add-Content -Path $requirementsPath -Value "notebook==6.4.12"
Add-Content -Path $requirementsPath -Value "traitlets==5.9.0"

Add-Content -Path $requirementsPath -Value "jupyterlab"
Add-Content -Path $requirementsPath -Value "pandas"
# # Add package to help clear jupyter cell outputs pre-commit
# Add-Content -Path $requirementsPath -Value "jupyter_contrib_nbextensions"

# --------- END Requirements File ---------

git add .
git commit -m 'initial setup'

# --------- BEGIN Proxy Server ---------

# Input proxy credentials to install any requirements
# Load the System.Web assembly if it's not already loaded
if (-not ([System.Management.Automation.PSTypeName]'System.Web.HttpUtility').Type)
{
    [System.Reflection.Assembly]::LoadWithPartialName('System.Web')
}

$userName = Read-Host "Enter your user name"
$passWord = Read-Host "Enter your password" -AsSecureString
$passWord = [System.Web.HttpUtility]::UrlEncode($passWord)
$httpProxy = "HTTP_PROXY=http://${userName}:${passWord}@bcpxy.nycnet:8080"
$httpsProxy = "HTTPS_PROXY=http://${userName}:${passWord}@bcpxy.nycnet:8080"
$argumentsProxy = @("/C set $httpProxy", "/C set $httpsProxy")
Start-Process cmd.exe -ArgumentList $argumentsProxy
Write-Host "Set proxies using $userName's password."

# --------- END Proxy Server ---------


# --------- BEGIN Virtual Environment ---------

# Create a Python virtual environment in the location directory
$venvPath = Join-Path -Path $location -ChildPath ".env"

if ($os -eq "Win32NT") {
    py -m venv $venvPath
    $activateScript = Join-Path -Path $venvPath -ChildPath "Scripts\Activate.ps1"
    if (Test-Path -Path $activateScript -PathType Leaf) { & $activateScript }
    py -m ensurepip --upgrade
    py -m pip install -r requirements.txt
}
else {
    python3 -m venv $venvPath
    $activateScript = Join-Path -Path $venvPath -ChildPath "bin/Activate.ps1"
    if (Test-Path -Path $activateScript -PathType Leaf) { & $activateScript }
    python -m ensurepip --upgrade
    python3 -m pip install -r requirements.txt
}

if ($env:VIRTUAL_ENV) {
    Write-Host "Virtual environment is active: $($env:VIRTUAL_ENV)"
} else {
    Write-Host "No virtual environment is currently active."
}
python.exe -m pip install --upgrade pip
# --------- END Virtual Environment ---------


# --------- BEGIN Git Hooks ---------

# Add git hook that clears the output of Jupyter notebooks before committing

# Define the source and target file paths
$precommitSamplePath = Join-Path -Path $location -ChildPath ".git\hooks\pre-commit.sample"
$precommitPath = Join-Path -Path $location -ChildPath ".git\hooks\pre-commit"

# Check if the source file exists
if (Test-Path -Path $precommitSamplePath -PathType Leaf) {
    # Rename the file to remove the .sample extension
    Rename-Item -Path $precommitSamplePath -NewName $precommitPath -Force
    Write-Host "File renamed: $precommitSamplePath -> $precommitPath"
} else {
    Write-Host "Source file $precommitSamplePath does not exist."
}

# Edit pre-commmit file to clear output of Jupyter Notebook before committing
Set-Content -Path $precommitPath -Value "" -NoNewline
Add-Content -Path $preCommitPath -Value "#!/bin/sh"
Add-Content -Path $preCommitPath -Value "jupyter nbconvert --clear-output notebooks\\*.ipynb"

# --------- END Git Hooks ---------
