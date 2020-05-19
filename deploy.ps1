Deploy 'PSKindleWatch - Module Deployment' {

    By Filesystem {
        FromSource "src"
        To "$Home\Documents\WindowsPowerShell\Modules\PSKindleWatch"
        WithOptions @{
            Mirror = $True
        }
    }

    By Task RenamePs1FilesToPsm1 {
        Get-ChildItem "$Home\Documents\WindowsPowerShell\Modules\PSKindleWatch" -Filter "*.ps1" | Rename-Item -NewName {$_.BaseName + ".psm1"}
    }
}