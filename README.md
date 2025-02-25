# SharePoint Site Information Extractor (No Modules Required)

A lightweight PowerShell script to extract information about SharePoint sites without requiring admin privileges or additional PowerShell modules.

## Features

- **No Additional Modules Required**: Uses built-in PowerShell commands only
- **Minimal Permissions**: Works with standard user access permissions
- **Comprehensive Information**: Collects site names, URLs, creation dates, last modified dates, and more
- **Subsite Discovery**: Optionally discovers and documents all subsites recursively
- **CSV Export**: Exports all collected information to a CSV file for easy analysis

## Requirements

- PowerShell 5.1 or higher
- Basic read access to SharePoint sites
- No admin privileges required
- No additional PowerShell modules needed

## Usage

1. Download the `SharePointSiteInfo.ps1` script
2. Open PowerShell
3. Run the script with your SharePoint site URL:

```powershell
.\SharePointSiteInfo.ps1 -SiteUrl "https://yourcompany.sharepoint.com/sites/YourSite"
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| -SiteUrl | Yes | Base SharePoint URL (e.g., https://contoso.sharepoint.com/sites/YourSite) |
| -OutputFile | No | Custom output filename (default: SharePointSitesInfo_[timestamp].csv) |
| -IncludeSubsites | No | Set to $false to exclude subsites (default: $true) |
| -Credential | No | Provide credentials directly (default: will prompt or use default) |

### Examples

**Basic usage:**
```powershell
.\SharePointSiteInfo.ps1 -SiteUrl "https://yourcompany.sharepoint.com/sites/YourSite"
```

**Custom output file:**
```powershell
.\SharePointSiteInfo.ps1 -SiteUrl "https://yourcompany.sharepoint.com/sites/YourSite" -OutputFile "MySiteInfo.csv"
```

**Exclude subsites:**
```powershell
.\SharePointSiteInfo.ps1 -SiteUrl "https://yourcompany.sharepoint.com/sites/YourSite" -IncludeSubsites:$false
```

**Provide credentials:**
```powershell
$cred = Get-Credential
.\SharePointSiteInfo.ps1 -SiteUrl "https://yourcompany.sharepoint.com/sites/YourSite" -Credential $cred
```

## Information Collected

The script attempts to collect the following information for each site:

| Information | Description | Permission Required |
|-------------|-------------|---------------------|
| Title | Site title | Basic read |
| URL | Site URL | Basic read |
| Created | Creation date | Basic read |
| LastModified | Last modification date | Basic read |
| TimeZone | Site time zone | Basic read |
| StorageUsed | Storage usage in MB | Higher permissions* |
| StorageQuota | Storage quota in MB | Higher permissions* |
| Owners | Site owners/admins | Higher permissions* |
| CurrentUser | Current user accessing the site | Basic read |
| ParentSiteUrl | URL of parent site (for subsites) | Basic read |
| IsSubSite | Whether this is a subsite | Basic read |

\* *The script will attempt to retrieve this information but will continue if unsuccessful due to permission limitations*

## Permissions

This script is designed to work with minimal permissions:

- **Basic Site Access**: Required to access the site and its basic properties
- **Higher Permissions**: Optional for certain information (storage data, owner details)

If you have limited permissions, the script will still work but some fields may show as "Not available with current permissions".

## Limitations

- Cannot access sites where you don't have at least read permissions
- Some information requires higher permissions and may not be available
- For large SharePoint environments with many sites, the script may take time to complete
- Cannot retrieve detailed permission information without admin access
- Storage information may be limited depending on your access level

## Troubleshooting

**The script doesn't find any sites:**
- Verify you have the correct URL
- Check that you have at least read permissions to the site
- Try using explicit credentials with the -Credential parameter

**Missing information in the output:**
- Some information requires higher permissions
- The script gracefully handles permission limitations by marking those fields as "Not available"

**Script running slowly:**
- For large environments with many subsites, the script may take time
- Consider using -IncludeSubsites:$false to only scan the main site

## Disclaimer

This script is provided as-is without warranty. Always test in a non-production environment first.
