# SharePoint Site Information Extraction Script (No Modules Required)
# This script uses the SharePoint REST API with standard authentication
# Requires only basic read permissions to sites

param (
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,  # Base SharePoint URL (e.g., https://contoso.sharepoint.com)
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "SharePointSitesInfo_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeSubsites = $true,
    
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential
)

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
}

function Get-SharePointSiteInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    try {
        # Build the REST API URL to get site information
        $apiUrl = "$Url/_api/web?$select=Title,Url,Created,LastItemModifiedDate,CurrentUser,RegionalSettings/TimeZone/Description"
        
        # Make the REST API call
        if ($Credential) {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Credential $Credential -ContentType "application/json;odata=verbose" -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -UseDefaultCredentials -ContentType "application/json;odata=verbose" -ErrorAction Stop
        }
        
        # Get storage info if possible (requires higher permissions but will try)
        $storageInfo = @{
            "StorageUsed" = "Not available with current permissions"
            "StorageQuota" = "Not available with current permissions"
        }
        
        try {
            $storageUrl = "$Url/_api/site/usage"
            if ($Credential) {
                $storageResponse = Invoke-RestMethod -Uri $storageUrl -Method Get -Credential $Credential -ContentType "application/json;odata=verbose" -ErrorAction Stop
            } else {
                $storageResponse = Invoke-RestMethod -Uri $storageUrl -Method Get -UseDefaultCredentials -ContentType "application/json;odata=verbose" -ErrorAction Stop
            }
            
            $storageInfo = @{
                "StorageUsed" = "$([math]::Round($storageResponse.d.Usage.Storage / 1MB, 2)) MB"
                "StorageQuota" = "$([math]::Round($storageResponse.d.StorageMaximumLevel / 1MB, 2)) MB"
            }
        }
        catch {
            Write-Log "Cannot retrieve storage information for $Url (requires higher permissions)" -Level "WARNING"
        }
        
        # Try to get site owners (requires higher permissions but will try)
        $ownersInfo = "Not available with current permissions"
        try {
            $ownersUrl = "$Url/_api/web/siteusers?$filter=IsSiteAdmin eq true"
            if ($Credential) {
                $ownersResponse = Invoke-RestMethod -Uri $ownersUrl -Method Get -Credential $Credential -ContentType "application/json;odata=verbose" -ErrorAction Stop
            } else {
                $ownersResponse = Invoke-RestMethod -Uri $ownersUrl -Method Get -UseDefaultCredentials -ContentType "application/json;odata=verbose" -ErrorAction Stop
            }
            
            $ownersInfo = ($ownersResponse.d.results | ForEach-Object { "$($_.Title) <$($_.Email)>" }) -join "; "
            if ([string]::IsNullOrEmpty($ownersInfo)) {
                $ownersInfo = "No site admins found"
            }
        }
        catch {
            Write-Log "Cannot retrieve owner information for $Url (requires higher permissions)" -Level "WARNING"
        }
        
        # Create site info object
        $siteInfo = [PSCustomObject]@{
            Title = $response.d.Title
            Url = $response.d.Url
            Created = $response.d.Created
            LastModified = $response.d.LastItemModifiedDate
            TimeZone = $response.d.RegionalSettings.TimeZone.Description
            StorageUsed = $storageInfo.StorageUsed
            StorageQuota = $storageInfo.StorageQuota
            Owners = $ownersInfo
            CurrentUser = $response.d.CurrentUser.Title
        }
        
        return $siteInfo
    }
    catch {
        Write-Log "Error retrieving site information for $Url`: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-SharePointSubsites {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SiteUrl,
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    try {
        # Build the REST API URL to get subsites
        $apiUrl = "$SiteUrl/_api/web/webs"
        
        # Make the REST API call
        if ($Credential) {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Credential $Credential -ContentType "application/json;odata=verbose" -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -UseDefaultCredentials -ContentType "application/json;odata=verbose" -ErrorAction Stop
        }
        
        return $response.d.results
    }
    catch {
        Write-Log "Error retrieving subsites for $SiteUrl`: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

# Start script
Write-Log "Script started - retrieving SharePoint site information with minimal permissions"

# Get credentials if not provided
if (-not $Credential) {
    Write-Log "No credentials provided. You'll be prompted to enter them, or the script will use default credentials."
    $useDefaultCreds = Read-Host "Use default credentials? (Y/N)"
    
    if ($useDefaultCreds.ToUpper() -ne "Y") {
        $Credential = Get-Credential -Message "Enter your SharePoint credentials"
    }
}

# Sites collection to store all site info
$allSites = @()

# Get main site info
Write-Log "Retrieving information for main site: $SiteUrl"
$mainSite = Get-SharePointSiteInfo -Url $SiteUrl -Credential $Credential
if ($mainSite) {
    $allSites += $mainSite
}

# Process accessible subsite URLs (if requested)
if ($IncludeSubsites) {
    Write-Log "Retrieving subsites information..."
    
    # Queue of sites to process
    $sitesToProcess = New-Object System.Collections.Queue
    $sitesToProcess.Enqueue($SiteUrl)
    $processedUrls = @{}
    
    while ($sitesToProcess.Count -gt 0) {
        $currentSiteUrl = $sitesToProcess.Dequeue()
        
        # Skip if already processed
        if ($processedUrls.ContainsKey($currentSiteUrl)) {
            continue
        }
        
        $processedUrls[$currentSiteUrl] = $true
        
        # Get subsites of the current site
        $subsites = Get-SharePointSubsites -SiteUrl $currentSiteUrl -Credential $Credential
        
        foreach ($subsite in $subsites) {
            Write-Log "Found subsite: $($subsite.Url)"
            
            # Get detailed info about this subsite
            $subsiteInfo = Get-SharePointSiteInfo -Url $subsite.Url -Credential $Credential
            if ($subsiteInfo) {
                $subsiteInfo | Add-Member -MemberType NoteProperty -Name "ParentSiteUrl" -Value $currentSiteUrl
                $subsiteInfo | Add-Member -MemberType NoteProperty -Name "IsSubSite" -Value $true
                $allSites += $subsiteInfo
            }
            
            # Add this subsite to the processing queue
            $sitesToProcess.Enqueue($subsite.Url)
        }
    }
}

# Export to CSV
if ($allSites.Count -gt 0) {
    Write-Log "Exporting $($allSites.Count) sites to $OutputFile"
    $allSites | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Log "Output file: $((Get-Item $OutputFile).FullName)"
} else {
    Write-Log "No site information retrieved. Check your permissions and site URL." -Level "WARNING"
}

Write-Log "Script completed"
