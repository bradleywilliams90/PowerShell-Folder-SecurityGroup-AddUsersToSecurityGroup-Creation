function Sync-Check-Option ($shareLocation, $SGGroup)
{
    switch($shareLocation)
    {
	    1{
	    $regonalDCs = "server2019.sysadmin.local"
	    }
	    
    }
    ForEach ($regonalDC in $regonalDCs)
    {
        $loopCount = 0
        DO
        {
            Write-Host ""
            Write-Host "Checking $regonalDC for $SGGroup-RW/-RO"
            try
            {
                $checkADGroupRW = Get-ADGroup -server $regonalDC -Identity $SGGroup-RW
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
            {
                Write-host “AD $SGGroup-RW security group object was not found on server $regonalDC”    
            }
            try
            {
                $checkADGroupRO = Get-ADGroup -server $regonalDC -Identity $SGGroup-RO
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
            {
                Write-host “AD $SGGroup-RO security group object was not found on server $regonalDC”    
            }
            if (($checkADGroupRW -eq $NULL) -OR ($checkADGroupRO -eq $NULL))
            {
                $doneDT = (Get-Date).AddSeconds(30)
                while($doneDT -gt (Get-Date)) 
                {
                    $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
                    $percent = (30 - $secondsLeft) / 30 * 100
                    Write-Progress -Activity "Sleeping" -Status "Sleeping for 30 sec to let new security group info sync to all DC's, then checking replication" -SecondsRemaining $secondsLeft -PercentComplete $percent
                    [System.Threading.Thread]::Sleep(500)
                }
            }
            if ($checkADGroupRW -ne $null)
            {
                Write-host “AD $SGGroup-RW security group object found on server $regonalDC”
                $checkADGroupRW = 1
            }
            if ($checkADGroupRO -ne $null)
            {
                Write-host “AD $SGGroup-RO security group object found on server $regonalDC”
                $checkADGroupRO = 1
            }
            Write-Host ""
            $loopCount = $loopCount +1
            if ($loopCount -gt 30)
            {
                write-host "this process has looped $loopCount times, which is about 15 min. Breaking out of the loop"
                return $checkADGroupRW, $checkADGroupRO
            }

        }while (($checkADGroupRW -eq $NULL) -AND ($checkADGroupRO -eq $NULL))      
    }
    return $checkADGroupRW, $checkADGroupRO
}

function Set-ShareLocation ($shareLocation)
{
    Write-host "This folder will be created in \\server2019\test"
    Write-host "1) \\server2019\test"
    
    $location = Read-Host "Please press 1 to continue"
	write-host ""
    
    #making sure people pick 1-3
    While ($location -notin 1)
    {
        Write-host "ERROR! Invalid entry."
        Write-host " \\server2019\test"
        
        $location = Read-Host "Please press 1 to continue"
		write-host ""
    }
    
    #Sets the share location to the main file share location
    switch($location)
    {
	    1{
	    $shareLocation = "\\server2019\test"
	    }
	    
    }
    return $shareLocation, $location
}

function Set-FolderName ($shareLocationUPN)
{
    #Sets the folder name
    $folderName = Read-Host "What should the new folder be called"
	write-host ""
    $nameCorrect = Read-Host "You typed: $folderName. Is that right? (y/n)"
	write-host ""
    #Check to make sure people spelled the folder name correctly. Gives them the chance to try again
    while ($nameCorrect -notin "y","Y","yes","Yes","YES","n","N","no","No","NO")
    {
        Write-host "Invalid choice"
        $nameCorrect = Read-Host "You typed: $folderName. Is that right? (y/n)"
		write-host ""
    }
    while ( $nameCorrect -in "n","N","no","NO","No","nO" )
    {
        $folderName = Read-Host "What should the new folder be called"
		write-host ""
        $nameCorrect = Read-Host "You typed: $folderName. Is that right? (y/n)"
		write-host ""
    }
    #Creates the full UPN path
    Write-Host "Replacing spaces with _, if there are any"
    $folderName = $folderName.replace(" ","_")
    Write-Host "Updated folder name: $folderName"
    $folderpath = $shareLocationUPN+ "\" +$foldername
    Write-Host "Attempting to create new folder in this directory: $folderpath"
	write-host ""
    
    #Check to see if 
    if (Test-Path -Path $folderpath) 
    {
        write-host "This folder already exists"
		write-host ""
    } 
    else 
    {
        new-item -Path $folderpath -ItemType Directory
        write-host "Folder created"
		write-host ""
    }
    return $folderName
}

function CreateSecurityGroups ($foldername, $folderpath, $shareLocation)
{
    If ($shareLocation -eq "1")
    {
        $SGLocation = "sysadmin.local/SGGroups"
        $OULocation = "OU=SGGroups,DC=sysadmin,DC=local"
        $SGPrefix = "Security-Group-"
        $regonalDC = "server2019.sysadmin.local"
    }
    
  
    write-host "Attempting to create new RW & RO security groups in $SGLocation"
	write-host ""
    try
    {
        $checkADGroupRW = Get-ADGroup -Identity $SGPrefix$foldername-RW
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        Write-host “AD $SGPrefix$foldername-RW security group object not found”
    }
    if ($checkADGroup -eq $null) 
    {
        #New-ADGroup -server $regonalDC $SGPrefix$foldername-RW -GroupCategory Security -groupscope global -Path $OULocation -Description "provides read-write access to $folderpath"
        New-ADGroup $SGPrefix$foldername-RW -GroupCategory Security -groupscope universal -Path $OULocation -Description "provides read-write access to $folderpath"
        write-host "AD $SGPrefix$foldername-RW Security Group Created" 
		write-host ""		
    }
    Else
    {
        write-host "AD $SGPrefix$foldername-RW security group already exists"
		write-host ""
    }
    try
    {
        $checkADGroupRO = Get-ADGroup -Identity $SGPrefix$foldername-RO
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        Write-host “AD $SGPrefix$foldername-RO security group object not found”
    }
    if ($checkADGroup -eq $null) 
    {
        #New-ADGroup -server $regonalDC $SGPrefix$foldername-RO -GroupCategory Security -groupscope global -Path $OULocation -Description "provides read-only access to $folderpath"
        New-ADGroup $SGPrefix$foldername-RO -GroupCategory Security -groupscope universal -Path $OULocation -Description "provides read-only access to $folderpath"
        write-host "AD $SGPrefix$foldername-RO Security Group Created"
    }
    Else
    {
        write-host "AD $SGPrefix$foldername-RO security group already exists"
		write-host ""
    }
    

    return $SGPrefix, $foldername
}

function SetFolderPermissions ($folderpath, $SGGroup)
{
    $RO = $SGGroup+"-RO"
    $RW = $SGGroup+"-RW"
    $doneDT = (Get-Date).AddSeconds(15)
    while($doneDT -gt (Get-Date)) 
    {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = (15 - $secondsLeft) / 15 * 100
        Write-Progress -Activity "Sleeping" -Status "Sleeping for 15 sec to let new security group info sync to local DC" -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    write-host ""
    write-host "Adding security groups to $folderpath"
    $Acl = Get-Acl $folderpath
    $ACLRO = New-Object System.Security.AccessControl.FileSystemAccessRule("$RO", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $ACLRW = New-Object System.Security.AccessControl.FileSystemAccessRule("$RW", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($ACLRO)
    Set-Acl $folderpath $Acl
    $Acl.SetAccessRule($ACLRW)
    Set-Acl $folderpath $Acl
    write-host "Security groups added to $folderpath"    
}

function addMembersToSecurityGroups ($folderpath, $SGGroup)
{
    write-host ""
    #defining security groups
    $RO = $SGGroup+"-RO"
    $RW = $SGGroup+"-RW"
    #Get User Input to Define AS user lookup Variable
    Do
    {
        write-host "What kind of permission do you want to give someone over folder '$folderpath'?"
        write-host "1) Read/Write"
        write-host "2) Read Only"
        $addPerms = Read-Host "Please enter 1 or 2"
        write-host ""
        while ($addPerms -notin 1,2)
        {
            Write-host "ERROR! Invalid choice"
            write-host "What kind of permission do you want to give to '$folderpath'?"            
            write-host "1) Read/Write"
            write-host "2) Read Only"
            $addPerms = Read-Host "Please enter 1 or 2"
            write-host ""
        }
        if ( $addPerms -eq 1)
        {
            $addPerms = $RW
        }
        if ( $addPerms -eq 2)
        {
            $addPerms = $RO
        }
        Do 
        {
            Write-Host "You will look the user up by their username"            
            Write-Host "1) Username"
            
            $adLookup = Read-Host "Please press 1 to continue"
            write-host ""

            While ($adLookup -notin 1)
            {
                Write-Host "Invalid choice. Please press 1 to continue"
                Write-Host "1) Username"
                
                $adLookup = Read-Host "Please press 1"
                write-host ""
            }
            If ($adLookup -eq 1)
            {
                $lookupType = "Username"
                adLookup $addPerms $lookupType
            }
           

            $adLookup = Read-Host "Do you want to add anyone else to '$addPerms'? (y/n)"
			write-host ""
			
            while ($adLookup -notin "y","Y","yes","Yes","YES","n","N","no","No","nO","NO")
            {
                Write-host "Invalid choice"
                $adLookup = Read-Host "Do you want to add anyone else to '$addPerms'? (y/n)"
				write-host ""
            }
            If ($adLookup -in "y","Y","yes","Yes","YES")
            {
                $adLookup = 1
            }
            Else
            {
                $adLookup = 0
            } 
        } While ($adLookup -in 1)

        $addMorePermissions = Read-Host "Do you want to add any other permissions to '$folderpath'? (y/n)"

        while ($addMorePermissions -notin "y","Y","yes","Yes","YES","n","N","no","No","nO","NO")
        {
            Write-host "Invalid choice"
            $addMorePermissions = Read-Host "Do you want to add any other permissions to '$folderpath'? (y/n)"
			write-host ""
        }
        If ($addMorePermissions -in "y","Y","yes","Yes","YES")
        {
            $addMorePermissions = 1
        }
        If ($addMorePermissions -in "n","N","no","No","nO","NO")
        {
            $addMorePermissions = 0
        } 
    }while($addMorePermissions -eq 1)
}


function adLookup ($addPerms, $lookupType)
{
    $addPermsLocal = $addPerms
    $lookupTypeLocal = $lookupType
    $checkADuser = $null
    if ($lookupType -eq "Username")
    {
        $adSearchType = "SamAccountName"
    }
   
    $RWmembers = Read-Host "Please put in the person's $lookupType"
    write-host "Attempting user lookup: $RWmembers"
	write-host ""
    While ($checkADuser -eq $null)
    {
        Try
        {
            $checkADuser = Get-ADuser -Filter "$adSearchType -like '*$RWmembers*'"
        }
        catch [Microsoft.ActiveDirectory.Management.ADException]
        {
            Write-host “Error! It looks like the $lookupType was left blank”
        }
        if ($checkADuser -eq $null)
        {
            Write-host “AD user object not found”
            $tryAgain = Read-Host "Do you want to try again with a different '$lookupType'? (y/n)"
			write-host ""
            while ($tryAgain -notin "y","Y","yes","Yes","n","N","no","No")
            {
                Write-host "Invalid choice"
                $tryAgain = Read-Host "Do you want to try again with a different '$lookupType'? (y/n)" 
				write-host ""
            }
            If ($tryAgain -in "y","Y","yes","Yes")
            {
                $RWmembers = Read-Host "Please put in the person's $lookupType"
                write-host "Attempting user lookup: $RWmembers"
				write-host ""
            }
            If ($tryAgain -in "n","N","no","No")
            {
                write-host "User lookup by $lookupType stopped/failed. Going back"
				write-host ""
                return
            }
        }
    }
    if ($checkADuser -ne $null)
    {
        $checkmultipleUsers = ((($checkADuser).GetType() | Select-Object BaseType).BaseType).Name
    }
    while ($checkmultipleUsers -eq "Array")
    {
        #$checkmultipleUsers
        $checkADuser | sort | Format-Table Name,SamAccountName -A
        $RWmembers = Read-Host "Error! Multiple Users found. Please enter the SamAccountName (username) of the correct user"
        $checkADuser = Get-ADUser -Filter 'SamAccountName -like $RWmembers'
        $checkmultipleUsers = ((($checkADuser).GetType() | Select-Object BaseType).BaseType).Name
    }
    if ($checkADuser -ne $null) 
    {
        Get-ADUser -Filter 'SamAccountName -like $RWmembers' | Format-Table Name,SamAccountName -A
        $nameCorrect = Read-Host "Is this the correct user (y/n)"
        write-host ""
		
        if ($nameCorrect -in "y","Y","yes","Yes")
        {
            Add-ADGroupMember($RWmembers) -Identity($addPerms)
            write-host "User added to '$addPerms'"
			write-host ""			
        }
        elseif ($nameCorrect -in "n","N","no","No")  
        {
            write-host "User lookup by $lookupType stopped/failed. Going back"
			write-host ""
            return
        }
    }
}
cls            
$shareLocationArray = Set-ShareLocation
$shareLocationUPN = $shareLocationArray[0]
$shareLocation = $shareLocationArray[1]
$foldername = Set-FolderName $shareLocationUPN
$checkmultiplFolderNames = ((($foldername).GetType() | Select-Object BaseType).BaseType).Name
if ($checkmultiplFolderNames -eq "Array")
{
    $foldername = $foldername[1]
}
$folderpath = $shareLocationUPN+ "\" +$foldername
$SGGroupArray = CreateSecurityGroups $foldername $folderpath $shareLocation
$SGGroup = $SGGroupArray[0]+$SGGroupArray[1]
SetFolderPermissions $folderpath $SGGroup
addMembersToSecurityGroups $folderpath $SGGroup 
   
cls
write-host "Summary:"
write-host "New folder created: '$folderpath'"
write-host "Current folder permissions"
Get-Acl -Path $folderpath | Format-Table -Wrap
write-host "New security group created: $SGGroup-RW"
write-host "$SGGroup-RW members"
Get-ADGroupMember -Identity $SGGroup-RW | Format-Table Name,SamAccountName -A
write-host "New security group created: $SGGroup-RO"
write-host "$SGGroup-RO members"
Get-ADGroupMember -Identity $SGGroup-RO | Format-Table Name,SamAccountName -A

read-host "Press CTRL + C to quit"
write-host ""