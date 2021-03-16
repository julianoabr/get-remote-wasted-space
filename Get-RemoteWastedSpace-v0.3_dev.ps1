#Requires -RunAsAdministrator
#Requires -Version 3.0
<#
.Synopsis
   Get Free Space bigger than defined percentage on Remote Computers
.DESCRIPTION
   Get Free Space bigger than defined percentage on Remote Computers
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.AUTHOR
   Juliano Alves de Brito Ribeiro (Find me at: jaribeiro@uoldiveo.com or julianoalvesbr@live.com or https://github.com/julianoabr)
.VERSION
   0.3
.Next version
 1. Input in report file if the machine is physical or virtual
 2. If is virtual, bring type of disk. Thick, Thin or RDM
#>

Clear-Host

#FUNCTION TO PAUSE SCRIPT
function Pause-PSScript
{

   Read-Host 'Press [ENTER] to continue...' | Out-Null

}

#FUNCTION PING TO TEST CONNECTIVITY
function PSPing
([string]$hostname, [int]$timeout = 50) 
{
    $ping = new-object System.Net.NetworkInformation.Ping #creates a ping object
    
    try { $result = $ping.send($hostname, $timeout).Status.ToString() }
    catch { $result = "Failure" }
    return $result
}

#VALIDATE WMI CONNECTION
$rWmiOSBlock = {param($computer)
  try { $wmi=Get-WmiObject -class Win32_Bios -computer $computer -ErrorAction Stop }
  catch { $wmi = $null }
  return $wmi
}

#GET REMOTE WASTED SPACE
function Get-RemotedWastedSpace
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [System.String[]]$ServerList,

        # Param2 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [int]$PercentFreeSpace,

        [int]$MinDiskSpaceToConsider=10
        
    )


    foreach ($serverName in $ServerList){
    
      $localDrives = Get-WmiObject -Class win32_logicaldisk -ComputerName $ServerName | Where-Object -FilterScript {$psitem.DriveType -eq 3}  
    
      
      foreach ($drive in $localDrives){
      
      $computerName = $drive.PSComputerName
      $driveName = $drive.Name
      $driveFileSystem = $drive.FileSystem
      $driveSize = [math]::round(($drive.Size / 1GB),2)
      $driveFreeSpace = [math]::Round(($drive.FreeSpace / 1GB),2)
      $drivePercentFree = (100*($driveFreeSpace / $driveSize))
      
      if ($drivePercentFree -gt $PercentFreeSpace){
        if ($driveSize -le $minDiskSpaceToConsider){
            Write-Host "Drive: $driveName of Server: $computerName is $driveSize (GB) and not enter in the List" -ForegroundColor Black -BackgroundColor White

            }#if Drive Size
            else{
            
            $tempObj = New-Object -TypeName PsObject -Property @{
      
              ComputerName = $computerName
              DriveName = $driveName
              DriveFileSystem = $driveFileSystem
              DriveSizeGB = $driveSize
              DriveFreeSpaceGB = $driveFreeSpace
              DrivePercentFree = [math]::Round($drivePercentFree,2)
      
              } | Select-Object -Property ComputerName,DriveName,DriveFileSystem,DriveSizeGB,DriveFreeSpaceGB,DrivePercentFree | Export-Csv -NoTypeInformation -Path $csvfile -Append
            
            
            }#end of Else Drive Size
     
      
      
      }#end of IF
      else{
      
      $msgDrivePercentFree = [math]::Round($drivePercentFree,2)

      Write-Host "Drive: $driveName of Server: $computerName is less than $msgDrivePercentFree% and not enter in the List" -ForegroundColor Black -BackgroundColor White
      
      }
      

      }
        
    
    }#end of ForEach

}#end of Function Get-RemoteWastedSpace


Write-Warning 'Attention. You must create two folders inside the folder where you put this script' 

Write-Host 'Folder Names are: ' -NoNewline; Write-Host -NoNewline 'Report' -ForegroundColor Green; Write-Host -NoNewline ' and '; Write-Host -NoNewline 'Input' -ForegroundColor Green

Write-host ''

Pause-PSScript

#MAIN VARIABLES
$script_Parent = Split-Path -Parent $MyInvocation.MyCommand.Definition  

$currentDate = (Get-Date -Format "ddMMyyyy").ToString()

if (Test-Path "$script_Parent\Report"){
        
    Write-Host "Folder with Name Report Exists. I will continue"
                        
}#end IF
else{
        
    Write-Output "Folder with Name Report Does not Exists. I will try to Create it"

    New-Item -Path "$script_Parent\" -ItemType Directory -Name "Report" -Force -Verbose -ErrorAction Stop
            
}#end Else

if (Test-Path "$script_Parent\Input"){
        
    Write-Host "Folder with Name Input Exists. I will continue"
                        
}#end IF
else{
        
    Write-Output "Folder with Name Input Does not Exists. I will try to Create it"

    New-Item -Path "$script_Parent\" -ItemType Directory -Name "Input" -Force -Verbose -ErrorAction Stop
            
}#end Else



$csvfile = $Script_Parent + "\Report\WindowsMachines-WastedSpace-$currentDate.csv"


#SOURCE LIST FROM DOMAIN OR FILE
do
{
  $tmpReadChoice = ""

  Write-host "Do you want to get Wasted Space of Servers from a List (Manual) or (Auto) ?" -ForegroundColor Yellow 
    
    $tmpReadChoice = Read-Host "Type Only ( MANUAL / AUTO ). Any other value will not be accepted" 

    $ReadChoice = $tmpReadChoice.ToUpper()
    
    Switch -regex ($ReadChoice) 
     { 
       "\bMANUAL\b" {
         
         Write-Host "You choose manual. Put a file with name ServerList.txt inside Input Folder" -ForegroundColor Yellow -BackgroundColor DarkBlue

         $rServerList = @()
         
         $rServerList = (Get-Content -Path "$script_Parent\Input\ServerList.txt") | Sort-Object
                     
        }#End of Pre
       "\bAUTO\b" {
        
         Write-Host "You choose auto. I will get computers from your Domain Controller =D" -ForegroundColor DarkBlue -BackgroundColor Yellow
         
        #GET WINDOWS COMPUTERS
        $trimDate = (Get-date).AddDays(-30)

        $rServerList = @()

         #PLEASE, ADJUST ACCORDING TO YOUR DOMAIN
        $rServerList = Get-ADComputer -SearchBase 'dc=your,dc=domain,dc=net' -SearchScope Subtree -Filter {((ServicePrincipalName -notlike '*MSServerCluster*') -or 
        (ServicePrincipalName -notlike 'msclustervirtualserver*')) -and 
        (Modified -ge $trimdate) -and 
        ((OperatingSystem -Like 'Windows Server 2003*') -or (OperatingSystem -like 'Windows Server 201*') -or (OperatingSystem -like 'Windows Server 2008*')) -and 
        (DNSHostName -notlike 'NAME*') -and
        (DNSHostName -notlike 'NAME*') -and 
        (DNSHostName -notlike 'NAME3*') -and 
        (DNSHostName -notlike 'NAME4*')}  | Where-Object -FilterScript {$PSItem.DistinguishedName -notlike "*OU=CustomOU,OU=CustomOUPath*"} | Select-Object -ExpandProperty Name | Sort-Object         
            
       }#End of Pos 

   
}#End of Switch
 
    
}
until ($ReadChoice -notmatch "MANUAL" -xor $ReadChoice -notmatch "AUTO")

Write-Host 'This script will bring all the volumes in all Windows Servers where percentage of free space is bigger than you define' -ForegroundColor Green

$tmpPercentFree = Read-Host "Type the percentage of free space you want to check on the remove Windows Servers (Enter an Integer). Example: 70%. Type 70"

$percenteFree = ($tmpPercentFree / 1)


#Check to see if the file exists, if it does then overwrite it.
if (Test-Path $csvfile) {
    
    Write-Output "Overwriting $csvfile ..."
    
    Start-Sleep -Milliseconds 400

    Remove-Item $csvfile -Confirm -Verbose
}  



foreach ($rServerName in $rServerList){
    
    $result = PSPing -hostname $rServerName -timeout 20
	
    if ($result -ne "SUCCESS") { 

        Write-Output "ERROR Ping Server: $rServerName" | Out-file -FilePath "$script_Parent\Error-Validate-Ping-$currentDate.txt" -Append
    
    }#end of IF PING
	else { 
    
        Write-Output "SUCCESS PING $rServerName"

        $rJob = Start-Job -ScriptBlock $rWmiOSBlock -ArgumentList $rServerName
        
        $rWmi = Wait-job $rJob -Timeout 10 | Receive-Job
        
        if ($rWmi -ne $null){
            
            Get-RemotedWastedSpace -ServerList $rServerName -PercentFreeSpace $percenteFree
    
        }#end of IF validate WMI
        else{
        
            Write-Host "Failed to Connect to $rServerName" -ForegroundColor Red -BackgroundColor White

            $rJobID = $rJob.Id

            Get-Job -Id $rJobID | Remove-Job -Force
        
        }#end of Else Validate WMI
    }
    
}#end Foreach computer