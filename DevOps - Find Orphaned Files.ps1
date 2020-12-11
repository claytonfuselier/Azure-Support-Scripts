# Intended use is to identify files/attachments not referenced on any CodeWiki pages in Azure DevOps (cloned locally)
#
# Optionally you can have the identified orphaned files moved to \.OrphanedFiles
# - Recommend running script at least once WITHOUT relocating files and reviewing the exported CSV for accuracy.
# - After reviewing/confirming the export, then change $relocate to "1" and rerun the script to relocate the files.
# - When ready, you can then remove or delete the \.OrphanedFiles folder as appropriate
#
# Assumptions
# - All "pages" have the file extension ".md"
# - All files without ".md" and not mentioned by filename in the body of a "page" are considered "orphaned"
# - Also ignores any files with ".git" in the name (e.g. ".gitignore")


### Variables
$relocate = 0    # 0=Leave Files, 1=Move Files to \.OrphanedFiles -> Read notes above for more info.
$gitroot = ""


### Enumertating files
$allfiles = Get-ChildItem -Path $gitroot -Recurse
Write-Host -ForegroundColor Yellow "Total number of files: $($allfiles.Count)"

# Filtering to ".md" extension and non-directories only
$pages = $allfiles | where {$_.Extension -eq ".md" -and $_.Attributes -ne "Directory" -and $_.Name -notmatch ".git"}
Write-Host -ForegroundColor Yellow "Number of Markdown Files: $($pages.Count)"

# Filtering to extensions other than ".md" and non-directories only
$nonpages = $allfiles | where {$_.Extension -ne ".md" -and $_.Attributes -ne "Directory" -and $_.Name -notmatch ".git"}
Write-Host -ForegroundColor Yellow "Number of Non-Markdown Files: $($nonpages.Count)"


### Declarations
$orphans = @()
$totalchks = $pages.Count * $nonpages.Count
$p = 0


### Searching for each nonpage filename inside each page
# Looping through nonpages
$nonpages | ForEach-Object {
    $curfile = $_
    $refcount = 0
    
    # Looping through each page to look for the nonpage's filename
    $pages | ForEach-Object{
        $pagecontent = Get-Content $_.PSPath
        if($pagecontent -match $curfile.Name) {
            $refcount++
        }

        # Progress bar
        $p++
        $pcomplete = ($p/$totalchks)*100
        Write-Progress -Activity "Checking for orphaned files" -Status "$p of $totalchks total searches" -PercentComplete $pcomplete
    }

    if($refcount -eq 0){
        $orphans += $curfile
    }
}


### Exporting orphaned files to CSV
Write-Host -ForegroundColor Cyan "Total number of Orphaned Files: $($orphans.Count)"
$orphans | select Directory, Name, Extension, FullName | Export-Csv .\OrphanedFiles.csv -NoTypeInformation


### Relocate orphaned files
# Checking optional variable defined at top of page
if($relocate -eq 1){
    
    # Testing for and creating home for orphaned files (if needed)
    $orphange = "$gitfolder\.OrphanedFiles"
    if (-not (Test-Path $orphange)){
        New-Item -Path $orphange -ItemType Directory | Out-Null
    }

    # Looping through $orphans array to relocate each one
    $p = 0
    $orphans | ForEach-Object {
        Move-Item -Path $_.FullName -Destination $orphange
        
        # Progress bar
        $p++
        $pcomplete = ($p/$orphans.Count)*100
        Write-Progress -Activity "Relocating orphaned files" -Status "$p of $($orphans.Count) total moves" -PercentComplete $pcomplete
    }
}
