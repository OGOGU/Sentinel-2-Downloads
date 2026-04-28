# Sentinel‑2 Image Downloader (PowerShell)

## Prerequisites

The first thing you need to check is whether **wget** and **curl** are installed on your computer. Most current versions of Windows already include them.

The easiest way to verify this is to open **Command Prompt (CMD)** and run:

```cmd
wget
curl
```

You should receive a response indicating that the commands exist.

If they are not installed, download and install them first, and make sure the commands work correctly before continuing.

## Required Software

You will also need **PowerShell ISE**, which should be installed by default on Windows.

## Configuration

Inside the ZIP file, you will find **two PowerShell scripts (`.ps1`)**. Open both of them using **PowerShell ISE** and configure the following parameters.

### Script: `00_Call_DownloadSentinel2.ps1`

You must edit the following variables:

- **Scripts folder path**  
  Update the path to the folder where the `.ps1` scripts are stored (line 11):
  ```powershell
  $scripts=
  ```

- **Date range**  
  Set the start and end dates for the download (lines 15 and 16):
  ```powershell
  $data_inici=
  $data_fi=
  ```

- **Download option**  
  Set the `$desc` variable (line 19):
  - `N` → New download
  - `R` → Retry a previously attempted download that was interrupted

- **Output directory**  
  Set the path where the images will be saved (line 24):
  ```powershell
  $sortida=
  ```

### Script: `01_DownloadSentinel2.ps1`

You must edit the following parameters:

- **User credentials**  
  Set your Sentinel download credentials:
  - Line 12: user name
  - Line 13: password

- **Search area (bounding box)**  
  Update the `$bbox` variable (line 20) with the coordinates of the polygon defining the search area.

  Coordinates must be given in **degrees** and follow this format:

  ```text
  lon1+lat1,lon2+lat2,lon3+lat3,...,lon1+lat1
  ```

## Running the Script

Once all variables have been correctly set and the changes saved:

1. Press **F5** or click the **green arrow** in the PowerShell ISE toolbar.
2. If everything is correctly configured, the script will start downloading Sentinel‑2 images automatically.
