#README
#To download S2 images, two ps1 files are required, which must be stored together in the same folder. These files are named:

# 00_Call_DownloadSentinel2.ps1
    ## This script determines which images are downloaded and where they are stored.
    ## All variables must be checked to ensure they point to the intended directories.
# 01_DownloadSentinel2_v3.ps1
    ## This script manages the lists of images to be downloaded and performs the downloads.
    ## It is necessary to verify that the variables described between lines 8 and 19 are correctly defined.

#folder where the scripts are stored
$scripts="C:\Docs\Sentinel2Downloads"

Start and end dates of the search
$data_inici="2025-06-28"
$data_fi="2025-06-28"

#download options
$desc="N"
	#N means new downloads. -->New
	#R means to check that all files have been downloaded and, if not, download the missing ones. --> Retry

#directory where the downloads will be stored
$sortida="C:\Sentinel2"

& $scripts\01_DownloadSentinel2.ps1 -start $data_inici -end $data_fi -option $desc -dwnld $sortida -scr $scripts