# PSKindleWatch

PSKindleWatch is a PowerShell module that keeps a Kindle book watchlist and can alert you when a price drop occurs. 

## Installation

### Via Git

Clone the repository and run `.\build.ps1 deploy`. 

This will install several modules if you do not already have them, see `build.ps1` for details. These are only required for the build process and are not otherwise used by PSKindleWatch.

### Manually

Copy the files from `src` to `C:\Program Files\WindowsPowerShell\Modules\PSKindleWatch` and rename the `.ps1` file to `.psm1`. 

## Running

PSKindleWatch only has 3 cmdlets

```powershell
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Add-KindleBook                                     1.0        PSKindleWatch
Function        Remove-KindleBook                                  1.0        PSKindleWatch
Function        Update-KindleBookPrices                            1.0        PSKindleWatch
```

### Add-KindleBook

`Add-KindleBook -BookURL <String> [-DataFile <String>]`

Please ensure the URL is of the Kindle edition of the book, others may not work due to differences in Amazon's APIs. 

![Kindle edition](docs/kindle_edition.png)

The module stores book data in a JSON file, the `-DataFile` parameter specifies the path to this file. It is an optional parameter, by default it will be placed in the user's Documents folder and named KindleBooks.json. 

**Example**

```powershell
Add-KindleBook -BookURL "https://www.amazon.com.au/dp/B07YX3B5G9/"
```

### Remove-KindleBook

`Remove-KindleBook -BookTitle <String>`

The title lookup uses `-match`, a partial string match will suffice. 

**Example**

```powershell
PS C:\> Remove-KindleBook -BookTitle narco
Rmoving:
 -Narconomics: How To Run a Drug Cartel
 ```

### Update-KindleBookPrices

`Update-KindleBookPrices [-DataFile] <String>] [-AlertScriptBlock <ScriptBlock>]`

Checks the current price of all books in the data file and prints any price drop to the console. 

It is recommended a wrapper be created to run this either on a loop in a PowerShell window, or as a scheduled task. 

**Example**

```powershell
while($true) {
    Get-Date
    Update-KindleBookPrices
    Start-Sleep -Seconds 43200
}
```

**Example Output**

```diff
PS C:\md\dev\PSKindleWatch> Update-KindleBookPrices
Checking price of Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell, original price: 67.91
+Found discount for Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell, new price is $41.98 (original: $67.91)
```

#### Alerting

As there are many options for alerting (email, SMS, push, API, ...) and each one with a myriad of providers this functionality has been left to the user to implement.

The `Update-KindleBookPrices` accepts a ScriptBlock parameter called `-AlertScriptBlock`. The ScriptBlock is executed if there is a change in price, and gets passed the `$Book` object (see JSON representation below), and a descriptive message (see example above in green). 


```json
{
    "ASIN":  "B00ARN9MEK",
    "Title":  "Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell",
    "Authors":  [
                    "Lee Holmes"
                ],
    "URL":  "https://www.amazon.com.au/Windows-PowerShel...<truncated>",
    "ImageURL":  "https://images-na.ssl-images-amazon.com/images/I/51MtlVpXnvL.jpg",
    "IsOnSale":  true,
    "OriginalPrice":  67.91,
    "SalePrice":  41.98
}
```

**Example**

```powershell
[ScriptBlock]$SendEmail = { 
    Param(
        $Book,
        $Msg
    )

    $Body = "<h1><a href=$($Book.URL)>Get it!</a><h1>"

    Send-MailMessage `
        -From "alerts@mydomain.com" `
        -To "me@mydomain.com" `
        -Subject $Msg `
        -Body $Body `
        -BodyAsHtml `
        -SmtpServer "mail.mydomain.com"
}
```

```
PS C:\> Update-KindleBookPrices -AlertScriptBlock $SendEmail
Checking price of Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell, original price: 61.99
Found discount for Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell, new price is $41.98 (original: $61.99)
Sending email!
```