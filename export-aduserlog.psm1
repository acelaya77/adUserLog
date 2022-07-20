
Function export-aduserlog {
    [CmdletBinding(DefaultParameterSetName = 'Default')]

    Param(
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true,
            Mandatory = $true
        )]
        [string[]]$SamAccountName,

        [Parameter()]
        [ValidateScript({ $(Get-Item $_) -is [System.IO.DirectoryInfo] })]
        [System.IO.DirectoryInfo]$OutputPath,
        <#
                Switch ($_) {
                    { !(Test-Path $_) } { Throw ("Directory does not exist: '{0}'" -f $_) }
                    { ( (Get-Item $_) -isnot [System.IO.DirectoryInfo]) } { Throw ("Parameter must be a path, not a file: '{0}'" -f $_) }
                    Default { $true }
                }#>

        [Parameter()]
        [string]$Notes

    )

    Begin {

        $script:stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:funcName = 'export-aduserlog'
        $script:date = Get-Date
        $script:properties = @(
            'samAccountName'
            'givenName'
            'surname'
            'memberOf'
            'name'
            'SamAccountName'
            'ObjectGUID'
            'UserPrincipalName'
            'EmployeeID'
            'ExtensionAttribute1'
            'GivenName'
            'Surname'
            'DisplayName'
            'CanonicalName'
            'Company'
            'Department'
            'Title'
            'Description'
            'HomeDrive'
            'HomeDirectory'
            'ScriptPath'
            'msNPAllowDialin'
            'msExchRemoteRecipientType'
            'msExchHideFromAddressLists'
            'msExchDelegateListBL'
            'msExchCoManagedObjectsBL'
            'publicDelegatesBL'
            'msExchUMCallingLineIDs'
            'msExchUCVoiceMailSettings'
            'msExchModeratedObjectsBL'
            'Mail'
            'HomePage'
            'StreetAddress'
            'City'
            'PostalCode'
            'State'
            'Country'
            'whenCreated'
            'whenChanged'
            'LastLogonDate'
            'PasswordLastSet'
            'PasswordExpired'
            'Enabled'
            'UserAccountControl'
            'ExtensionAttribute2'
            'ExtensionAttribute3'
            'ExtensionAttribute4'
            'ExtensionAttribute5'
            'ExtensionAttribute6'
            'ExtensionAttribute7'
            'ExtensionAttribute8'
            'ExtensionAttribute9'
            'ExtensionAttribute10'
            'ExtensionAttribute11'
            'ExtensionAttribute12'
            'ExtensionAttribute13'
            'ExtensionAttribute14'
            'ExtensionAttribute15'
        )
        $script:ldapFilter = '(samAccountName={0})' -f $SamAccountName
        $script:users = foreach ( $user in $samAccountName ) { Get-ADUser -LDAPFilter $script:ldapFilter -Properties $script:properties }
    } #end begin{}

    Process {

        foreach ( $user in $script:users ) {

            #region :: [FILENAME] If file already exists, we want to increment the filename. This does that.
            $script:count = 0
            do {
                $script:count++
                if ($script:count -gt 1) { Write-Verbose $("File in use: `"{0}`"" -f $script:strFileName) }
                $script:splatFileName = @{
                    Date           = $(Get-Date -f 'yyyyMMdd')
                    samAccountName = $($user.SAMACCOUNTNAME)
                    givenName      = $(Switch ( $user.Givenname ) { { [string]::IsNullOrEmpty($_) } { $null }; Default { $_.ToLower().replace(' ', '-') }; })
                    surname        = $(Switch ( $user.Surname ) { { [string]::IsNullOrEmpty($_) } { $null }; Default { $_.ToLower().replace(' ', '-') }; })
                    count          = $(Switch ( $script:count ) { { $_ -eq 1 } { '' }; { $_ -gt 1 } { '_v{0:00}' -f $script:count }; })
                }
                $script:strFileName = '{0}_{1}_{2}_{3}_aduser_export{4}.log' -f $script:splatFileName.date, $script:splatFileName.samAccountName, $script:splatFileName.givenName, $script:splatFileName.surname, $script:splatFileName.count
                $script:file = (Join-Path $OutputPath $script:strFileName)
                Write-Verbose $("Attempting file: `"{0}`"" -f $script:file.FullName)
            } While ( (Test-Path($script:file)) )

            Write-Verbose $("Using file: `"{0}`"" -f $script:file) #$file
            #endregion :: [FILENAME]

            #region :: [GROUPS] using memberOf attribute to collate the array groups, prepending a tag for the parent domain ([   SCCCD]) or child ([STUDENTS])
            [string[]]$script:strGroups = $user.memberOf | ForEach-Object {
                $script:cn = $_.split(',')[0].where( { $_ -match 'CN=' }).replace('CN=', '')
                $script:ouPath = $($_.split(',').where( { $_ -match 'DC=' }).replace('DC=', '')[0] -join ',')
                '[{1,8}] {0}' -f $script:cn, $script:ouPath
            }
            #endregion :: [GROUPS]

            #region :: [EXTENSIONATTRIBUTES] We only want to show the ones that have values, not them all, and put them in order.
            $script:strExtensionAttributes = ''
            $($user.PSObject.Properties.Where( { (![string]::IsNullOrEmpty($PSItem.Value)) -and ($PSItem.Name -match 'extensionAttribute') }).Name) | ForEach-Object {
                $script:strName = $_
                $script:strValue = $user.$($_)
                if ( $_ -match 'extensionAttribute[1-9]$') {
                    $script:strExtensionAttributes += $('{0}..........: {1}' -f $script:strName.Trim(), $script:strValue.Trim()) | Out-String
                }
                else {
                    $script:strExtensionAttributes += $('{0}.........: {1}' -f $script:strName.Trim(), $script:strValue.Trim()) | Out-String
                }
            }
            $script:colExtensionAttributes = $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e1\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e2\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e3\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e4\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e5\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e6\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e7\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e8\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e9\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e10\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e11\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e12\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e13\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e14\.\.' }) | Out-String
            $script:colExtensionAttributes += $($script:strExtensionAttributes -split "`r`n").Where({ $PSItem -match 'e15\.\.' }) | Out-String
            #endregion :: [EXTENSIONATTRIBUTES]

            #region :: [PROXYADDRESSES] We want to only show the email, nit SIP or X400, X500
            if ( ![String]::IsNullOrEmpty($user.ProxyAddresses) ) {
                $script:ProxyAddresses = [string]::Join("`r`n                             : ", $($user.ProxyAddresses).where( { !($PSItem -match $($user.Mail)) -and !($PSItem -match $($user.UserPrincipalName)) -and ($PSItem -cmatch 'smtp:') }).replace('smtp:', ''))
            }
            Else {
                $script:ProxyAddresses = [string]::("`n                 ")
            }
            #endregion :: [PROXYADDRESSES]

            #region :: [LOGONSCRIPT] We're going to show the script path and the contents
            if ( ![string]::IsNullOrEmpty($user.ScriptPath) ) {
                $script:scriptPath = (Join-Path '\\scccd.net\NETLOGON' $user.ScriptPath)
                if ( !(Test-Path $script:scriptPath) ) {
                    $script:dirs = Get-ChildItem -Recurse -Directory -Path:$(Join-Path '\\SCCCD.NET' 'NETLOGON')
                    $script:files = foreach ( $d in $script:dirs ) { Get-ChildItem -Path:$d.FullName -File }
                    $script:scriptPath = $script:files.where({ $Psitem.Name -match $(Split-Path -Leaf $script:scriptPath).Split('.')[0] })
                    if ( ![string]::IsNullOrEmpty($script:scriptPath) ) {
                        $script:logonScript = [PSCustomObject]@{
                            Path    = (Join-Path (Split-Path $script:scriptPath) (Split-Path $script:scriptPath -Leaf))
                            Content = $(Get-Content (Join-Path (Split-Path $script:scriptPath) (Split-Path $script:scriptPath -Leaf)) ).Split("`r`n") | ForEach-Object { $('{1}{0}' -f $_, '    ' ) } | Out-String
                        }
                    }
                }
                If ( [string]::IsNullOrEmpty($script:scriptPath) ) {
                    $script:logonScript = [PSCustomObject]@{
                        Path    = $null
                        Content = $null
                    }
                }
                else {
                    $script:logonScript = [PSCustomObject]@{
                        Path    = $(Get-Item $script:scriptPath).FullName
                        Content = $( Get-Content $(Get-Item $script:scriptPath).FullName ).Split("`r`n") | ForEach-Object { $('{1}{0}' -f $_, '    ' ) } | Out-String
                    }
                    $script:additionalScripts = $($script:logonScript.Content.Split("`r`n") | Select-String -Pattern:'\\\\SCCCD\.NET.*\.(cmd|bat|vbs)' ).Matches.Value | ForEach-Object {
                        if ( ![string]::IsNullOrEmpty($_) ) {
                            Get-Item $_ -ErrorAction:Ignore 
                        }
                        else { $null }
                    }
                }

                $script:logonScripts = @()
                $script:logonScripts += $logonScript
                if ( ![string]::IsNullOrEmpty($script:additionalScripts.FullName) ) {
                    $script:logonScripts += [PSCustomObject]@{
                        Path    = $($script:additionalScripts.FullName)
                        Content = $(Get-Content $($script:additionalScripts.FullName)).Split("`r`n") | ForEach-Object { $('{1}{0}' -f $_, '    ' ) } | Out-String
                    }
                }

                Write-Verbose $($script:logonScripts.Path | Out-String) -Verbose
                if ( $($script:logonScripts | Measure-Object).Count -ge 1 ) {
                    $script:scripts = foreach ( $s in $script:logonScripts ) {
                        Write-Verbose -Verbose $s.path
                        $script:padString = if ( [string]::IsNullOrEmpty($s.Path) ) {
                            '-' * 80
                        }
                        else {
                            ('-' * ([int]((80 - $s.Path.length) / 2) + (80 - ($s.Path).length) % 2) )
                        }
                        Write-Verbose $script:padString
                        @"

$( $( $( '{1}{0}{1}' -f $s.Path, $script:padString ) ).Substring(0,80) )
$($s.Content)
--------------------------------------------------------------------------------

"@
                    }
                }
                else {
                    $script:scripts = ''
                }

            }
            else {
                Write-Warning 'No script'
                $script:logonScript = [PSCustomObject]@{
                    Path    = $null
                    Content = $null
                }
            }
            #endregion :: [LOGONSCRIPT]


            #region :: [BUILD OUTPUT]
            $script:header = @"


================================================================================
FILEPATH.................: '$(Split-Path $script:file)'
FILENAME.................: '$(Split-Path -Leaf $script:file)'
TITLE....................: AD Account Information Log, $($SamAccountName)
DATETIME.................: $(Get-Date $script:date -Format 's')
NOTES....................: $Notes
================================================================================


"@

            $script:Body = @"
Name.........................: $($User.Name)
SamAccountName...............: $($User.SamAccountName)
GUID.........................: $($user.ObjectGUID)
UserPrincipalName............: $($User.UserPrincipalName)
EmployeeID...................: $($User.EmployeeID)
ExtensionAttribute1..........: $($User.ExtensionAttribute1)
GivenName....................: $($User.GivenName)
Surname......................: $($User.Surname)
DisplayName..................: $($User.DisplayName)
CanonicalName................: $($User.CanonicalName)
Company......................: $($User.Company)
Department...................: $($User.Department)
Title........................: $($User.Title)
Description..................: $($User.Description)
HomeDrive....................: $($User.HomeDrive)
HomeDirectory................: $($User.HomeDirectory)
ScriptPath...................: $($User.ScriptPath)
msNPAllowDialin..............: $($User.msNPAllowDialin)
msExchRemoteRecipientType....: $($User.msExchRemoteRecipientType)
msExchHideFromAddressLists...: $($User.msExchHideFromAddressLists)
Mail.........................: $($User.Mail)
SMTP_Addresses...............: $($script:ProxyAddresses)
HomePage.....................: $($User.HomePage)
StreetAddress................: $($User.StreetAddress)
City.........................: $($User.City)
PostalCode...................: $($User.PostalCode)
State........................: $($User.State)
Country......................: $($User.Country)
whenCreated..................: $($User.whenCreated)
whenChanged..................: $($User.whenChanged)
LastLogonDate................: $($User.LastLogonDate)
PasswordLastSet..............: $($($User.PasswordLastSet) )
PasswordExpired..............: $($User.PasswordExpired)
Enabled......................: $($User.Enabled)
msExchDelegateListBL.........: $($User.msExchDelegateListBL)
msExchCoManagedObjectsBL.....: $($User.msExchCoManagedObjectsBL)
publicDelegatesBL............: $($User.publicDelegatesBL)
msExchModeratedObjectsBL.....: $($User.msExchModeratedObjectsBL)
UserAccountControl...........: $(Convert-UserAccountControl $user.UserAccountControl)
X400.........................: $(try{[string]::join("`r`n    .............................: ",$($User.ProxyAddresses | Where-Object{($_ -match 'X400:*')}))}catch{''})
EUM..........................: $(try{[string]::join("`r`n    .............................: ",$($User.ProxyAddresses | Where-Object{($_ -match 'EUM:*')}))}catch{''})
$($script:colExtensionAttributes)

================================================================================
Groups:
================================================================================

`r`n    $([string]::Join("`r`n    ",$($script:strGroups | Sort-Object)))

================================================================================
LoginScripts:
================================================================================
$($script:scripts)

"@

            $script:output = $script:header
            $script:output += $script:Body
            $script:output += "`r`n"
            #endregion :: [BUILD OUTPUT]

            #region :: [SAVE OUTPUT]
            $script:stream = [System.IO.StreamWriter]::new($script:file)
            Try {
                $script:file | Write-Verbose
                $script:output | Out-String -Stream | ForEach-Object {
                    $script:stream.WriteLine($_.Trim())
                }
            }
            Finally {
                $script:stream.Close()
            }

            Write-Verbose $("File saved: '{0}'`r`n" -f (Join-Path $(Split-Path $script:file -Parent) $(Split-Path $script:file -Leaf)) ) -Verbose

            if ( $PSBoundParameters.ContainsKey('FilePathToClipboard') ) {
                $('Invoke-Item $(Join-Path "{0}" "{1}")' -f $(Split-Path $script:file -Parent) , $(Split-Path $script:file -Leaf)) | Set-Clipboard
                Write-Verbose 'Paste to terminal to Invoke output file, [Ctrl]+[V]'
            }

            if ( $PSBoundParameters.ContainsKey('InvokeItem') ) {
                Invoke-Item $script:file
            }

            if ( $PSBoundParameters.ContainsKey('OutputToClipboard') ) {
                $script:output | Set-Clipboard
            }
            #endregion :: [SAVE OUTPUT]

        }

    } #end process{}

    End {
        $stopWatch.Stop()
        '{0,-32} :: Runtime: {1}' -f $funcName, $stopWatch.Elapsed.ToString('mm\:ss\.fff') | Write-Verbose
    }

}

Export-ModuleMember -Function:'export-aduserlog'
