#Requires -RunAsAdministrator

Deploy 'PSKindleWatch - Module Deployment' {

    By Filesystem {
        FromSource "src"
        To "C:\Program Files\WindowsPowerShell\Modules\PSKindleWatch"
        WithOptions @{
            Mirror = $True
        }
    }

    By Task RenamePs1FilesToPsm1 {
        Get-ChildItem "C:\Program Files\WindowsPowerShell\Modules\PSKindleWatch" -Filter "*.ps1" | Rename-Item -NewName {$_.BaseName + ".psm1"}
    }
}