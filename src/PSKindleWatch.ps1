$ErrorActionPreference = "Stop"

function Import-KindleDataFile {
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$DataFile
    )

    Write-Verbose "Importing Kindle Data file"

    try {
        $BookData = Get-Content -Path $DataFile | ConvertFrom-Json
        Write-Output $BookData
    }
    catch {
        Write-Host "Unable to load or parse data file ($DataFile). The exception message is below." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red 
    }
}

function Export-KindleDataFile {

    Param(
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ })]
        [string]$DataFile,

        [Parameter(Mandatory = $true)]
        [psobject]$BookData,

        [Parameter(Mandatory = $false)]
        [string]$Message = $null
    )

    Write-Verbose "Exporting Kindle Data file"

    try {
        $BookData | ConvertTo-Json -Depth 100 | Out-File $DataFile -Force -Encoding utf8
        if ($Message) {
            Write-Host $Message
        }
    }
    catch {
        Write-Host "Unable to write to data file ($DataFile). The exception message is below."  -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function Get-AmazonData {

    Param (
        [Parameter(Mandatory = $true)]
        [string]$ASIN
    )

    Write-Verbose "Querying Amazon API"

    $Body = @{
        method = "getBookData"
        asin   = $ASIN
    }

    try {
        $Result = Invoke-RestMethod -Method Post -ContentType "application/x-www-form-urlencoded" -Uri "https://www.amazon.com.au/gp/search-inside/service-data" -Body $Body -ErrorAction Stop
    }
    catch {
        Write-Host "API call was not successful. The exception message is below." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Verbose "---- Start API Lookup Result ---------------------"
    Write-Verbose $Result | Out-String
    Write-Verbose "---- End API Lookup Result -----------------------"

    Write-Output $Result

}

function Add-KindleBook {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_.HostNameType -eq "DNS" })]
        [System.Uri]$BookURL, 

        [Parameter(Mandatory = $false)]
        [string]$DataFile = [Environment]::GetFolderPath("MyDocuments") + "\KindleBooks.json"
    )

    if (!(Test-Path $DataFile)) {
        New-Item -Path $DataFile -ItemType File | Out-Null
        $BookData = @()
    }
    else {
        $BookData = Import-KindleDataFile -DataFile $DataFile

        # We need this because Write-Output in Import-KindleDataFile converts a single item array
        # into an object (essentially dropping the array). This causes issues when we attempt to 
        # add other objects to the array
        if ($BookData -is [PSCustomObject]) {
            [array]$BookData = @($BookData)
        }
    }

    $ASIN = $BookURL.ToString().Split("/")
    $ASINIndex = [array]::IndexOf($ASIN, "dp") + 1
    $ASIN = $ASIN[$ASINIndex]

    if ($ASIN.IndexOf("?") -ne -1) {
        $ASIN = $ASIN.Split("?")[0]
    }

    Write-Verbose "Extracted ASIN: $ASIN"  

    Write-Verbose "Checking if ASIN is already present in the data file"
    if ($ASIN -in $BookData.ASIN) {
        Write-Host "Book with ASIN $ASIN already exists in data file ($DataFile)" -ForegroundColor Gray
    }
    else {

        $Result = Get-AmazonData -ASIN $ASIN
        
        $Data = @{
            Title         = $Result.title
            Authors       = [array]$Result.authorNameList
            ASIN          = $Result.ASIN
            URL           = $BookURL
            ImageURL      = $Result.thumbnailImage.Replace("._SL75_", "")
            OriginalPrice = [decimal]$Result.buyingPrice.Replace("$", "")
            IsOnSale      = $false
            SalePrice     = 0
        }

        if ($Data.Title) {
            $obj = New-Object -TypeName PSCustomObject -Property $Data

            Write-Verbose "---- Start Object Dump ---------------------"
            Write-Verbose $obj | Out-String
            Write-Verbose "---- End Object Dump -----------------------"    
    
            $BookData += $obj            
            $Message = "Successfull added $($obj.Title)"
            
            #Write-Verbose $BookData | Out-String

            Export-KindleDataFile -BookData $BookData -DataFile $DataFile -Message $Message
        }
        else {
            Write-Error "API call did not return required data. Please ensure the URL is of the Kindle edition of the book."
        }
    }

}

function Remove-KindleBook {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BookTitle, 

        [Parameter(Mandatory = $false)]
        [string]$DataFile = [Environment]::GetFolderPath("MyDocuments") + "\KindleBooks.json"
    )

    $BookData = Import-KindleDataFile -DataFile $DataFile
    $BooksToBeRemoved = ($BookData | ? { $_.Title -match $BookTitle }).Title -join "`n -"
    if ($BooksToBeRemoved) {
        Write-Host "Rmoving: `n -$BooksToBeRemoved"
        $BookData = $BookData | ? { $_.Title -notmatch $BookTitle }


        if ($BookData -eq $null) {
            Write-Host "Book list is empty!"
            $BookData = @()
        }

        Export-KindleDataFile -DataFile $DataFile -BookData $BookData
    }
    else {
        Write-Host "No matching book titles found"
    }
}


function Update-KindleBookPrices {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $false)]
        [scriptblock]$AlertScriptBlock = $null,

        [Parameter(Mandatory = $false)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$DataFile = [Environment]::GetFolderPath("MyDocuments") + "\KindleBooks.json"
    )

    $i = 0
    [array]$BookData = Import-KindleDataFile -DataFile $DataFile
    $BookCount = $BookData.count

    if ($?) {

        foreach ($Book in $BookData) {

            Write-Progress -Activity "Checking book prices" -Status "Progress:" -PercentComplete ($i / $BookCount * 100)
            $i++
            
            $Body = @{
                method = "getBookData"
                asin   = $Book.ASIN
            }
    
            Write-Host "Checking price of $($Book.Title)"

            $CurrentResult = Get-AmazonData -ASIN $Book.ASIN
            $CurrentPrice = [decimal]$CurrentResult.buyingPrice.Replace("$", "")
            $Message = $null

            # Condition for original price being discounted
            if (($CurrentPrice -lt $Book.OriginalPrice) -and ($Book.IsOnSale -eq $false)) {
                $Message = "Found discount for $($Book.Title), new price is `$$CurrentPrice (original: `$$($Book.OriginalPrice))"
                Write-Host $Message -ForegroundColor Green
                $Book.SalePrice = $CurrentPrice
                $Book.IsOnSale = $true
            }

            # Condition for further discount being applied to existing discount
            if (($CurrentPrice -lt $Book.SalePrice) -and ($Book.IsOnSale -eq $true)) {
                $Message = "Additional discount found for $($Book.Title), new price is `$$CurrentPrice (original: `$$($Book.OriginalPrice))"
                Write-Host $Message -ForegroundColor Green
                $Book.SalePrice = $CurrentPrice
            }

            # Condition for reduced discount being applied to existing discount
            if (($CurrentPrice -gt $Book.SalePrice) -and ($Book.IsOnSale -eq $true)) {
                $Message = "Discount reduced for $($Book.Title), new price is `$$CurrentPrice (up from previous discount of `$$($Book.SalePrice) and original: $($Book.OriginalPrice))"
                Write-Host $Message -ForegroundColor Yellow
                $Book.SalePrice = $CurrentPrice
            }

            # Condition for sale ending
            if (($CurrentPrice -ge $Book.OriginalPrice) -and ($Book.IsOnSale -eq $true)) {
                $Message = "Sale ended for $($Book.Title), current price is `$$CurrentPrice"
                Write-Host $Message -ForegroundColor Red
                $Book.OriginalPrice = $CurrentPrice
                $Book.SalePrice = 0
                $Book.IsOnSale = $false
            }

            # Condition for price increase
            if (($CurrentPrice -gt $Book.OriginalPrice) -and ($Book.IsOnSale -eq $false)) {
                $Message = "Price increased for $($Book.Title), new price is `$$CurrentPrice (original: `$$($Book.OriginalPrice))"
                Write-Host $Message -ForegroundColor Red
                $Book.OriginalPrice = $CurrentPrice
            }

            if ($AlertScriptBlock -and $Message) {
                Write-Verbose "Triggering configured alert"
                Invoke-Command -ScriptBlock $AlertScriptBlock -ArgumentList $Book, $Message
            }

            Start-Sleep -Seconds 1
        }
    }

    Export-KindleDataFile -BookData $BookData -DataFile $DataFile
    Write-Progress -Completed -Activity "Checking book prices"
}
