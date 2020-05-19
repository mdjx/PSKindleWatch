# PSKindleWatch

PSKindleWatch is a PowerShell module that keeps a Kindle book watchlist and can alert you when a price drop occurs. 

## Installation

### Via Git

Clone the repository and run `.\build.ps1 deploy`. 

This will install several modules if you do not already have them, see `build.ps1` for details. These are only required for the build process and are not otherwise used by PSKindleWatch.

### Manually

Copy the files from `src` to `C:\Program Files\WindowsPowerShell\Modules\PSKindleWatch` and rename the `.ps1` file to `.psm1`. 

## Running

PSKindleWatch only has 4 cmdlets

```powershell
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Add-KindleBook                                     1.0        PSKindleWatch
Function        Get-KindleBooks                                    1.0        PSKindleWatch
Function        Remove-KindleBook                                  1.0        PSKindleWatch
Function        Update-KindleBookPrices                            1.0        PSKindleWatch
```

### Add-KindleBook

`Add-KindleBook -BookURL <String> [-DataFile <String>]`

Please ensure the URL is of the Kindle edition of the book, others may not work due to differences in Amazon's APIs. 

![Kindle edition](/docs/kindle_edition.gif)

The module stores book data in a JSON file, the `-DataFile` parameter specifies the path to this file. It is an optional parameter, by default it will be placed in the user's Documents folder and named KindleBooks.json. 

**Example**

```powershell
Add-KindleBook -BookURL "https://www.amazon.com.au/dp/B07YX3B5G9/"
```


### Get-KindleBooks

`Get-KindleBooks [-DataFile <String>]`

Returns a list of currently monitored books.

**Example**

```
PS C:\> Get-KindleBooks | Format-Table -AutoSize

Title                                                                                            Authors                               OriginalPrice
-----                                                                                            -------                               -------------
The Age of Surveillance Capitalism: The Fight for a Human Future at the New Frontier of Power    Shoshana Zuboff                                9.80
Superforecasting: The Art and Science of Prediction                                              Philip Tetlock,Dan Gardner                    14.99
Naked Economics: Undressing the Dismal Science (Fully Revised and Updated)                       Charles J. Wheelan, Burton G. Malkiel         23.06
```


### Remove-KindleBook

`Remove-KindleBook -BookTitle <String>`

The title lookup uses `-match`, a partial string match will suffice. 

**Example**

```powershell
PS C:\> Remove-KindleBook -BookTitle narco
Removing:
 -Narconomics: How To Run a Drug Cartel
 ```

### Update-KindleBookPrices

`Update-KindleBookPrices [-DataFile <String>] [-AlertScriptBlock <ScriptBlock>]`

Checks the current price of all books in the data file and prints any price drop to the console. 

It is recommended a wrapper be created to run this in a loop in a PowerShell window, or as a scheduled task, or as a Windows Service. I've written up a quick guide on how it can be made to run as a service to avoid needing to manually restart the process after reboots. Check it out [here](https://xkln.net/blog/running-a-powershell-script-as-a-service/). 

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
PS C:\> Update-KindleBookPrices
Checking price of Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell
+Found discount for Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell, new price is $41.98 (original: $67.91)
```

#### Alerting

As there are many options for alerting (email, SMS, push, API, ...) and each one with a myriad of providers this functionality has been left to the user to implement.

The `Update-KindleBookPrices` accepts a ScriptBlock parameter called `-AlertScriptBlock`. The ScriptBlock is executed if there is a change in price, and gets passed the `$Book` object (see JSON representation below) as the first parameter, and a descriptive message (a string, see example above in green) as the second parameter. 


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

    $Body = "<h1><a href=$($Book.URL)>Get it!</a></h1>"

    Send-MailMessage `
        -From "alerts@mydomain.com" `
        -To "me@mydomain.com" `
        -Subject $Msg `
        -Body $Body `
        -BodyAsHtml `
        -SmtpServer "mail.mydomain.com"

    Write-Host "Sending email!"
}

Update-KindleBookPrices -AlertScriptBlock $SendEmail
```

```diff
Checking price of Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell
Found discount for Windows PowerShell Cookbook: The Complete Guide to Scripting Microsoft's Command Shell, new price is $41.98 (original: $61.99)
Sending email!
```
