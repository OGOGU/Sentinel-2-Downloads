param (
[string]$start,
[string]$end,
[string]$option,
[string]$dwnld,
[string]$scr
)

#--------------
#Variables that must be modified if the user changes
#--------------
$usr="UserName" #your user name
$psw="Password" #your password

#--------------
#Variables that must be modified if we want to change the search area or the product
#--------------
$prod="S2MSI1C" #product ID
#$bbox="-10.80+35.80,4.79+35.80,4.79+44.02,-10.80+44.02,-10.80+35.80" #Península ibèrica
$bbox="0.704+42.794,0.437+40.542,0.678+40.731,0.865+41.082,2.052+41.371,3.087+41.957,3.016+42.479,1.463+42.460,0.704+42.794,0.704+42.794" #Bounding box


$temp="$scr\tmp"

# If the tmp folder does not exist, create it
if (-not (Test-Path $temp)) {
    New-Item -ItemType Directory -Path $temp | Out-Null
}


#This function returns the token using the user and password in order to perform the downloads
#The token expires every 600s, so it must be requested every time we want to perform new downloads (it cannot be reused from one day to the next)
function CreaToken() 
{
    $uri = "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token"

    $headers = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    $body = @{
        "username"    = $usr
        "password"    = $psw
        "grant_type"  = "password"
        "client_id"   = "cdse-public"
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tokenJson = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body | ConvertFrom-Json

    return $tokenJson
}

#This function returns the token from the refresh_token in order to perform the downloads
#The token expires every 600s, so it must be requested every time we want to perform new downloads (it cannot be reused from one day to the next).
#Since 600 seconds is a very short time and we always request many downloads, it makes no sense to track the time and wait for it to expire before requesting a new one. It is refreshed on each new download.
function RegeneraToken() 
{
    $uri = "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token"
    $token = $tokenJson.refresh_token

    $headers = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    $body = "grant_type=refresh_token&refresh_token=$token&client_id=cdse-public"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body

    $tokenJson = $response.Content | ConvertFrom-Json

    return $tokenJson
}

function CallDescarrega($taula)
{
    #Trigger the downloads
    $taulaDesc=Import-Csv -Path $taula -Delimiter ";" -Header "ID", "ZIPname"
    $total=$taulaDesc.ID.Count
    For ($s=0;$s -lt $total; $s++){
        $n=$s+1
        $status="$n"+"/"+"$total"
        if ($s -eq 0){
            $tokenJson=CreaToken
        }else{
            $tokenJson=RegeneraToken
        }
        DescarregaZIP $taulaDesc[$s].ID $taulaDesc[$s].ZIPname $dwnld $tokenJson.access_token $status
    }
}

function DescarregaZIP ($id, $ZIPname, $dwnld, $token, $status)
{
    # If the image we want to download already exists, do not download it.
	# This should never happen, but since it is not clear what curl does when asked to download the same file twice, this if statement is included just in case to avoid duplicates.
    if (Test-Path $dwnld\$ZIPname.zip -PathType Leaf){
        Write-Host "$status LA IMATGE JA EXISTEIX"
        return
    }
    else
    {
        #we receive the parameters and execute curl to download the image that has been received.
        $clau="Bearer $token"
        $url="https://catalogue.dataspace.copernicus.eu/odata/v1/Products("+$id+")/"+"$"+"value"
        $endle=$dwnld+'\'+$ZIPname+'.zip'

        $expression='curl.exe -H "Authorization: '+$clau+'" "'+$url+'" --location-trusted --output '+$endle
        $expression | Out-File -FilePath "$temp\curl.bat" -Encoding ASCII

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "$temp\curl.bat"
        $psi.WindowStyle = "Hidden"

        $proces = [System.Diagnostics.Process]::Start($psi)
        $proces.WaitForExit()

        $size = (Get-Item $endle).Length
        #we check that the download has completed correctly (correct exit code and file larger than 100 bytes) --> when the download fails, if we do nothing a ~25-byte zip file is saved, which is actually a JSON saying {"detail":"Unauthorized"}
		#otherwise, we delete the ZIP so that it can be downloaded again in the future
        if (($proces.ExitCode -ne 0) -or ((Test-Path $endle -PathType Leaf) -and ($size -le 100))) {
                Write-Host "$status $endle $size ERROR EN LA DESCÀRREGA!" 
                Remove-Item $endle -Force
        }else{
            if(Test-Path $endle -PathType Leaf){
                Write-Host "$status $endle $size FET!"
            }else{
                Write-Host "$status $endle $size ERROR: IMATGE NO DISPONIBLE?" #This has never happened and I do not know if it is possible. In theory, if something goes wrong with the download, we should detect it in the previous if statement and have an ExitCode different from 0.
            }
        }
    }
}

function RetornaJson ($url)
{
    $url= $url -replace '%24', '$' -replace '%2F', '/' -replace '%28', '(' -replace '%3A', ':' -replace '%27', "'" -replace '%29', ')' -replace '%3D', '=' -replace '%3B', ';' -replace '%2C', ','
    $exp='wget --output-document='+$temp+'\consulta.json "'+$url+'"'
    $exp | Out-File -FilePath "$temp\wget.bat" -Encoding ASCII
    $var = Start-Process -FilePath "$temp\wget.bat" -PassThru
    $var.WaitForExit()

    $Json=Get-Content -Raw -Path $temp\consulta.json | ConvertFrom-Json

    return $Json
}

if ($option -eq "N")
{
    #URL used for the query
    $url ="https://catalogue.dataspace.copernicus.eu/odata/v1/Products?"+"$"+"filter=Attributes/OData.CSC.StringAttribute/any(att:att/Name+eq+'productType'+and+att/OData.CSC.StringAttribute/Value+eq+'"+$prod+"')+and+OData.CSC.Intersects(area=geography'SRID=4326;POLYGON(("+$bbox+"))')+and+ContentDate/Start+gt+"+$start+"T00:00:00.000Z+and+ContentDate/End+lt+"+$end+"T23:59:59.999Z&"+"$"+"count=True&"+"$"+"orderby=ContentDate/Start asc"

    $Json=RetornaJson($url)
    #$Json | Format-List | Out-String | Write-Output

    #Since each query returns a maximum of only 20 results, $Json.'@odata.nextLink' provides the URL of the query that must be made to obtain the next 20 elements.
    $next=$Json.'@odata.nextLink'
    
    #We check that no identical query already exists. If it does, we delete it.
    $consulta="$temp\$start"+"_"+"$end.csv"
    if (Test-Path $consulta -PathType Leaf) {
        Remove-Item $consulta -Force
    }

    #As long as there is a URL to continue querying elements, we keep generating a list of image IDs and names
    while ($next -ne $null)
    {
	    $n=$Json.value.Length #Here it should always be 20, but I leave it this way to avoid problems if there are changes.
        for ($s=0; $s -lt $n; $s++) {
            $nomLlarg=$Json.value[$s].Name
            $nomZip=$nomLlarg.Substring(0, $nomLlarg.Length - 5)
		    $Json.value[$s].id+";"+$nomZip | Out-File -FilePath $consulta -Append
	    }
	    $Json=RetornaJson($next)
	    $next=$Json.'@odata.nextLink'
    } 
    #When it becomes null, the last page still needs to be printed
    $n=$Json.value.Length
    for ($s=0; $s -lt $n; $s++) {
        $nomLlarg=$Json.value[$s].Name
        $nomZip=$nomLlarg.Substring(0, $nomLlarg.Length - 5)
	    $Json.value[$s].id+";"+$nomZip | Out-File -FilePath $consulta -Append
    }

    #Trigger the downloads
    CallDescarrega($consulta)
 }

if ($option -eq "R")
{
    #1 Create the list of already downloaded images
    
    $llistaDescarregats = "$temp\ImatgesDescarregades.csv"
    $csvSortida = "$temp\Imatges_NO_Descarregades.csv"

    # Si ja existeixen llistes prèvies, les eliminem
    if (Test-Path $llistaDescarregats -PathType Leaf) {
        Remove-Item $llistaDescarregats -Force
    }
    if (Test-Path $csvSortida -PathType Leaf) {
        Remove-Item $csvSortida -Force
    }

    #We generate a variable that contains the list of ZIP files that have already been downloaded (without extension)
    $elementsDescarregats = Get-ChildItem -Path $dwnld -Filter "*.zip" | ForEach-Object { $_.BaseName }

    #We save the names of the downloaded files to the output file
    $elementsDescarregats | Out-File -FilePath $llistaDescarregats

    
    #2 We compare the images already downloaded with the initial query and save to a file those that have not yet been downloaded
    
    # Path to the CSV file that contains all images between the requested dates that should have been downloaded
    $csv1 = "$temp\$start"+"_"+"$end.csv"

    #We read the two CSV files and store them in variables
    $data1 = Import-Csv -Path $csv1 -Delimiter ";" -Header "ID", "ZIPname"
    $data2 = Import-Csv -Path $llistaDescarregats -Header "ZIPname"

    #We compare the columns and obtain the non-matching elements
    $noCoincidents = $data1 | Where-Object { $_.ZIPname -notin $data2.ZIPname }

    #We write the non-matching elements to a new CSV file
    $noCoincidents |Export-Csv -Path $csvSortida -Delimiter ";" -NoTypeInformation
    
    #We remove the header from the output CSV file
    (Get-Content -Path $csvSortida | Select-Object -Skip 1) | Set-Content -Path $csvSortida

    #Trigger the downloads
    CallDescarrega($csvSortida)
}
