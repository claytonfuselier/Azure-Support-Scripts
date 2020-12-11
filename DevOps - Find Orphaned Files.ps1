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



####################### Begin Script #######################
### Simple Error Checking
if(-not $gitroot){
    Write-Host -ForegroundColor Red -BackgroundColor Black "The variable 'gitroot' is not defined.`nScript execution will now stop."
    exit
}
if(-not (Test-Path $gitroot)){
    Write-Host -ForegroundColor Red -BackgroundColor Black "The path '$gitroot' is not valid.`nScript execution will now stop."
    exit
}


### Enumertating files
Write-Host -ForegroundColor Cyan "Scanning folder root $gitroot"
$allfiles = Get-ChildItem -Path $gitroot -Recurse
Write-Host -ForegroundColor Yellow "Total number of files/folders: $($allfiles.Count)"

# Filtering to ".md" extension and non-directories only
$pages = $allfiles | where {$_.Extension -eq ".md" -and $_.Attributes -ne "Directory" -and $_.Name -notmatch ".git"}
Write-Host -ForegroundColor Yellow "Number of pages: $($pages.Count)"

# Filtering to extensions other than ".md" and non-directories only
$nonpages = $allfiles | where {$_.Extension -ne ".md" -and $_.Attributes -ne "Directory" -and $_.Name -notmatch ".git"}
Write-Host -ForegroundColor Yellow "Number of non-page files: $($nonpages.Count)"


### Declarations
$orphans = @()
$cnt = 0
$est = ""
$totalchks = $pages.Count * $nonpages.Count
$starttime = Get-Date 


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

        # Estimated Time Left Calculation
        if ($cnt -gt 0){
            $now = Get-Date
            $avg = ($now – $starttime).TotalMilliseconds/$cnt
            $msleft = (($totalchks–$cnt)*$avg)
            $time = New-TimeSpan –Seconds ($msleft/1000)
        }

        # Progress bar
        $cnt++
        $percent = [MATH]::Round(($cnt/$totalchks)*100,2)
        Write-Progress -Activity "Checking for Orphaned Files ($percent %)" -Status "$cnt of $totalchks total searches - $time" -PercentComplete $percent
    }

    if($refcount -eq 0){
        $orphans += $curfile
    }
}


### Exporting orphaned files to CSV
Write-Host -ForegroundColor Yellow "Total number of Orphaned Files: $($orphans.Count)"
if($orphans.Count -ge 1){
    $shellpath = (Get-Location).Path
    Write-Host -ForegroundColor Cyan "Exported list to $shellpath\OrphanedFiles.csv"
    $orphans | select Directory, Name, Extension, FullName | Export-Csv .\OrphanedFiles.csv -NoTypeInformation
}


### Relocate orphaned files
# Checking optional variable defined at top of page
if($relocate -eq 1){
    
    # Testing for and creating home for orphaned files (if needed)
    $orphange = "$gitroot\.OrphanedFiles"
    if (-not (Test-Path $orphange)){
        New-Item -Path $orphange -ItemType Directory | Out-Null
    }

    # Looping through $orphans array to relocate each one
    $cnt = 0
    $orphans | ForEach-Object {
        Move-Item -Path $_.FullName -Destination $orphange
        
        # Progress bar
        $cnt++
        $percent = ($cnt/$orphans.Count)*100
        Write-Progress -Activity "Relocating Orphaned Files" -Status "$cnt of $($orphans.Count) total moves" -PercentComplete $percent
    }
    Write-Host -ForegroundColor Cyan "Relocated orphaned files to $orphange"
}
