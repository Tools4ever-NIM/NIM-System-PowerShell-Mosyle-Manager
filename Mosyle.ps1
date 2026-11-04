#
# Mosyle.ps1 - Mosyle Manager NIM PowerShell connector.
# Requires Windows PowerShell 5.1 or later.
#
$Log_MaskableKeys = @(
    'password',
    'accessToken',
    'Authorization',
    'proxy_password',
    'pincode'
)

# Shared class snapshot, populated only after a complete successful import.
$script:MosyleClassesCache = $null
$script:MosyleAuthorizationCache = $null
$script:MosyleDevicesCache = $null

# Endpoint definitions follow the supplied Mosyle Manager API documentation.
$script:MosyleTables = @{
    Devices = @{
        Path = '/v2/listdevices'
        Collection = 'devices'
        Paged = $true
        Columns = 'deviceudid,serial_number,device_name,os,osversion,userid,useremail,username,usertype,asset_tag,tags,location'
        Settings = @('os','tags','osversions','serial_numbers')
    }
    Classes = @{
        Path = '/v2/listclasses'
        Collection = 'classes'
        Paged = $true
        Columns = 'id,class_name,course_name,location,account'
        Settings = @()
    }
    ClassTeachers = @{
        Path = '/v2/listclasses'
        Collection = 'classes'
        Paged = $true
        Columns = 'Key,ClassID,UserID'
        Settings = @()
        ClassRole = 'teacher'
    }
    ClassStudents = @{
        Path = '/v2/listclasses'
        Collection = 'classes'
        Paged = $true
        Columns = 'Key,ClassID,UserID'
        Settings = @()
        ClassRole = 'students'
    }
    ClassCoordinators = @{
        Path = '/v2/listclasses'
        Collection = 'classes'
        Paged = $true
        Columns = 'Key,ClassID,UserID'
        Settings = @()
        ClassRole = 'coordinators'
    }
    DynamicDeviceGroups = @{
        Path = '/v2/listdevicegroups'
        Collection = 'groups'
        Paged = $true
        Columns = 'id,name,device_numbers'
        Settings = @('os','is_security_group')
    }
    DeviceGroupDevices = @{
        Path = '/v2/listdevicegroupsdevices'
        Collection = 'groups'
        Paged = $true
        Columns = 'id,name,deviceudid'
        Settings = @('os','is_security_group','security_compliance_status')
        Membership = $true
    }
    DynamicGroupDevices = @{
        Path = '/v2/listdevicesbygroup'
        Collection = 'udids'
        Paged = $false
        Columns = 'iddevicegroup,group_name,deviceudid'
        Settings = @('iddevicegroup','is_security_group','security_compliance_status')
    }
    SharedDeviceGroups = @{
        Path = '/v2/listshareddevicegroups'
        Collection = 'groups'
        Paged = $true
        Columns = 'idshareddevicegroup,name,idaccount,number_of_devices,assigned_devices'
        Settings = @('os','idshareddevicegroup','idaccount')
    }
    IOSSecurityCompliance = @{
        Path = '/v2/iossecuritycontrolscompliance'
        Collection = 'devices'
        Paged = $true
        Columns = 'UDID,ComplianceStatus,rule_name'
        Settings = @('rule_name','security_compliance_status')
    }
    Accounts = @{
        Path = '/v2/accounts'
        Collection = 'accounts'
        Paged = $false
        Columns = 'idaccount,name,address,date_created'
        Settings = @()
    }
    CustomDeviceAttributes = @{
        Path = '/v2/customdeviceattribute'
        Collection = 'info'
        Paged = $false
        Columns = 'Name,UniqueID,Value,LastUpdate,Source,OS,IsDeleted'
        Settings = @('os')
    }
}

$script:MosyleActions = @{
    UserCreate = @{
        Path = '/v2/users'
        Operation = 'save'
        Semantics = 'create'
        Envelope = $true
        Required = @('id','name','type','locations','welcome_email')
        Optional = @('email','managed_appleid','idaccount')
        Arrays = @('locations')
    }
    UserUpdate = @{
        Path = '/v2/users'
        Operation = 'update'
        Semantics = 'update'
        Envelope = $true
        Required = @('id')
        Optional = @('name','type','email','managed_appleid','locations','idaccount')
        Arrays = @('locations')
    }
    UserDelete = @{
        Path = '/v2/users'
        Operation = 'delete'
        Semantics = 'delete'
        Envelope = $true
        Required = @('id')
        Optional = @()
        Arrays = @()
    }
    UserAssignDevice = @{
        Path = '/v2/users'
        Operation = 'assign_device'
        Semantics = 'update'
        Envelope = $true
        Required = @('id','serial_number')
        Optional = @()
        Arrays = @()
    }
    DeviceUpdate = @{
        Path = '/v2/devices'
        Semantics = 'update'
        Envelope = $true
        Required = @('serialnumber')
        Optional = @('asset_tag','tags','name','lock')
        Arrays = @()
    }
    DeviceUnassign = @{
        Path = '/v2/bulkops'
        Operation = 'change_to_limbo'
        Semantics = 'update'
        Envelope = $true
        Required = @()
        Optional = @('devices','groups')
        Arrays = @('devices','groups')
    }
    DeviceUpdateLimboLocation = @{
        Path = '/v2/bulkops'
        Operation = 'update_limbo_location'
        Semantics = 'update'
        Envelope = $true
        Required = @('devices','location')
        Optional = @('groups')
        Arrays = @('devices','groups')
    }
    DeviceLock = @{
        Path = '/v2/bulkops'
        Operation = 'lock_device'
        Semantics = 'update'
        Envelope = $true
        Required = @('devices')
        Optional = @('pincode','phonenumber','lockmessage')
        Arrays = @('devices')
    }
    DynamicDeviceGroupAdd = @{
        Path = '/v2/devicegroups'
        Operation = 'update_devices'
        Semantics = 'update'
        Envelope = $false
        Required = @('idgroup','add')
        Optional = @()
        Arrays = @('add')
    }
    DynamicDeviceGroupRemove = @{
        Path = '/v2/devicegroups'
        Operation = 'update_devices'
        Semantics = 'update'
        Envelope = $false
        Required = @('idgroup','remove')
        Optional = @()
        Arrays = @('remove')
    }
    SharedDeviceGroupAdd = @{
        Path = '/v2/shareddevicegroups'
        Operation = 'assign_device'
        Semantics = 'update'
        Envelope = $false
        Required = @('idshareddevicegroup','add')
        Optional = @()
        Arrays = @('add')
    }
    SharedDeviceGroupRemove = @{
        Path = '/v2/shareddevicegroups'
        Operation = 'assign_device'
        Semantics = 'update'
        Envelope = $false
        Required = @('idshareddevicegroup','remove')
        Optional = @()
        Arrays = @('remove')
    }
    CustomDeviceAttributeUpdate = @{
        Path = '/v2/customdeviceattribute'
        Operation = 'update_custom_device_attributes'
        Semantics = 'update'
        Envelope = $true
        Required = @('os','old_unique_id','unique_id','name','value')
        Optional = @()
        Arrays = @()
    }
}

#
# System functions
#

function Idm-SystemInfo {
    param (
        # Operations
        [switch] $Connection,
        [switch] $TestConnection,
        [switch] $Configuration,
        # Parameters
        [string] $ConnectionParams
    )

    Log info "-Connection=$Connection -TestConnection=$TestConnection -Configuration=$Configuration"

    if ($Connection) {
        @(
            @{
                name = 'username'
                type = 'textbox'
                label = 'Username (email)'
                value = ''
            }
            @{
                name = 'password'
                type = 'textbox'
                label = 'Password'
                password = $true
                value = ''
            }
            @{
                name = 'accessToken'
                type = 'textbox'
                label = 'Access Token'
                password = $true
                value = ''
            }
            @{
                name = 'use_proxy'
                type = 'checkbox'
                label = 'Use Proxy'
                value = $false
            }
            @{
                name = 'proxy_address'
                type = 'textbox'
                label = 'Proxy Address'
                value = 'http://127.0.0.1:8888'
                disabled = '!use_proxy'
                hidden = '!use_proxy'
            }
            @{
                name = 'use_proxy_credentials'
                type = 'checkbox'
                label = 'Use Proxy Credentials'
                value = $false
                disabled = '!use_proxy'
                hidden = '!use_proxy'
            }
            @{
                name = 'proxy_username'
                type = 'textbox'
                label = 'Proxy Username'
                label_indent = $true
                value = ''
                disabled = '!use_proxy_credentials'
                hidden = '!use_proxy_credentials'
            }
            @{
                name = 'proxy_password'
                type = 'textbox'
                label = 'Proxy Password'
                label_indent = $true
                password = $true
                value = ''
                disabled = '!use_proxy_credentials'
                hidden = '!use_proxy_credentials'
            }
            @{
                name = 'page_size'
                type = 'textbox'
                label = 'Page Size'
                tooltip = 'Requested page size for all data endpoints. Endpoints may ignore this option.'
                value = 100
            }
            @{
                name = 'nr_of_retries'
                type = 'textbox'
                label = 'Max. number of retry attempts'
                tooltip = 'Total request attempts, including the initial request (1-20).'
                value = 10
            }
            @{
                name = 'retryDelay'
                type = 'textbox'
                label = 'Seconds to wait for retry'
                tooltip = 'Initial delay before exponential backoff (1-60 seconds). Retry-After takes precedence when longer.'
                value = 15
            }
        )
    }

    if ($Configuration) {
        @()
    }

    if ($TestConnection) {
        $settings = ConvertFrom-Json2 $ConnectionParams
        $token = Get-MosyleAuthorization $settings
        $null = Get-MosyleUsersPage -Settings $settings -Authorization $token -Page 1 -Columns @('id','name','managedappleid','type','email')
        Log info 'Connection test succeeded'
    }

    Log info 'Done'
}

#
# Object CRUD functions
#

function Idm-UsersRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Log verbose "-GetMeta=$GetMeta [Users]"

    if ($GetMeta) {
        @{
            name = 'specific_columns'
            type = 'textbox'
            label = 'Specific columns'
            tooltip = 'Comma-separated Mosyle user column names. These columns also define the output schema.'
            value = 'id,name,managedappleid,type,email'
        }
        Log verbose 'Done [Users metadata]'
        return
    }

    # Read the selected columns using a stable output schema across pages.
    $settings = ConvertFrom-Json2 $SystemParams
    $table = @{}
    if (-not [string]::IsNullOrWhiteSpace($FunctionParams)) {
        $table = ConvertFrom-Json2 $FunctionParams
    }
    $columnText = [string] $table.specific_columns
    if ([string]::IsNullOrWhiteSpace($columnText)) {
        $columnText = 'id,name,managedappleid,type,email'
    }
    $columns = @($columnText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    if ($columns.Count -eq 0) {
        throw 'At least one specific column is required.'
    }
    foreach ($column in $columns) {
        if ($column -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "Invalid Mosyle column name '$column'. Use comma-separated names."
        }
    }
    $token = Get-MosyleAuthorization $settings
    $page = 1
    $rowCount = 0
    do {
        $result = Get-MosyleUsersPage -Settings $settings -Authorization $token -Page $page -Columns $columns
        $users = @($result.users)
        if ($users.Count -eq 0 -and ([long]($page - 1) * [long]$result.page_size) -lt [long]$result.total) {
            throw "Mosyle returned an empty page $page before the reported total was reached."
        }
        Log verbose "Retrieved page ${page}: $($users.Count) users (reported total: $($result.total))"
        $rowCount += $users.Count

        foreach ($user in $users) {
            $row = [ordered]@{}
            foreach ($column in $columns) {
                $value = $user.$column
                if ($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]) {
                    $value = ConvertTo-Json -InputObject $value -Depth 32 -Compress
                }
                $row[$column] = $value
            }
            [PSCustomObject] $row
        }
        if (([long]$page * [long]$result.page_size) -ge [long]$result.total) {
            break
        }
        $page++
    } while ($true)

    Log info "Done [Users]: $rowCount users retrieved"
}


function Idm-DevicesRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'Devices'
}


function Idm-DeviceCustomAttributeValuesRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    if ($GetMeta) {
        Get-MosyleTableMetaData -Class 'Devices' | Where-Object { $_.name -ne 'specific_columns' }
        return
    }
    Log verbose '-GetMeta=False [DeviceCustomAttributeValues]'
    $devices = @(Get-MosyleDevices -SystemParams $SystemParams -FunctionParams $FunctionParams)
    $count = 0
    foreach ($device in $devices) {
        $attributes = $device.CustomDeviceAttributes
        if ($null -eq $attributes -or ($attributes -is [string] -and [string]::IsNullOrWhiteSpace($attributes))) { continue }
        if ($attributes -is [string]) {
            try { $attributes = ConvertFrom-Json -InputObject $attributes -ErrorAction Stop }
            catch { throw 'Device CustomDeviceAttributes contains invalid JSON.' }
        }
        foreach ($attribute in @($attributes)) {
            if ($null -eq $attribute) { continue }
            $id = [string]$attribute.CustomAttributeUniqueID
            if ([string]::IsNullOrWhiteSpace($id)) { $id = [string]$attribute.UniqueID }
            if ([string]::IsNullOrWhiteSpace($id)) { $id = [string]$attribute.unique_id }
            if ([string]::IsNullOrWhiteSpace($id)) { throw 'Device custom attribute is missing CustomAttributeUniqueID.' }
            if ([string]::IsNullOrWhiteSpace([string]$device.deviceudid)) { throw 'Device custom attribute response is missing deviceudid.' }
            $value = $attribute.Value
            if ($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]) {
                $value = ConvertTo-Json -InputObject $value -Depth 32 -Compress
            }
            [PSCustomObject][ordered]@{
                DeviceID = $device.deviceudid
                Name = $attribute.Name
                CustomAttributeUniqueID = $id
                Value = $value
            }
            $count++
        }
    }
    Log info "Done [DeviceCustomAttributeValues]: $count rows retrieved"
}


function Idm-ClassesRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'Classes'
}


function Idm-ClassTeachersRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'ClassTeachers'
}


function Idm-ClassStudentsRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'ClassStudents'
}


function Idm-ClassCoordinatorsRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'ClassCoordinators'
}


function Idm-DynamicDeviceGroupsRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'DynamicDeviceGroups'
}


function Idm-DeviceGroupDevicesRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'DeviceGroupDevices'
}


function Idm-DynamicGroupDevicesRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    if ($GetMeta) {
        Get-MosyleTableMetaData -Class 'DynamicGroupDevices'
        @{
            name = 'os'
            type = 'textbox'
            label = 'OS for group discovery'
            tooltip = 'Used to discover groups when iddevicegroup is blank: ios, mac, tvos, visionos.'
            value = 'mac'
        }
        return
    }

    $function_params = @{}
    if (-not [string]::IsNullOrWhiteSpace($FunctionParams)) {
        $function_params = ConvertFrom-Json2 $FunctionParams
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$function_params.iddevicegroup)) {
        Read-MosyleTable -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'DynamicGroupDevices'
        return
    }

    # No group filter: discover groups, then collect each group's memberships.
    $discovery = @{}
    foreach ($name in @('os','is_security_group')) {
        if ($function_params.ContainsKey($name)) { $discovery[$name] = $function_params[$name] }
    }
    $groups = @(Read-MosyleTable -SystemParams $SystemParams -FunctionParams ($discovery | ConvertTo-Json -Compress) -Class 'DynamicDeviceGroups')
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($group in $groups) {
        $id = [string]$group.id
        if ([string]::IsNullOrWhiteSpace($id)) { throw 'Dynamic device group response is missing its id.' }
        if (-not $seen.Add($id)) { continue }
        $options = $function_params.Clone()
        $options.iddevicegroup = $id
        Read-MosyleTable -SystemParams $SystemParams -FunctionParams ($options | ConvertTo-Json -Compress) -Class 'DynamicGroupDevices'
    }
}


function Idm-SharedDeviceGroupsRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'SharedDeviceGroups'
}


function Idm-IOSSecurityComplianceRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    if ($GetMeta) {
        Get-MosyleTableMetaData -Class 'IOSSecurityCompliance'
        return
    }
    $function_params = @{}
    if (-not [string]::IsNullOrWhiteSpace($FunctionParams)) {
        $function_params = ConvertFrom-Json2 $FunctionParams
    }
    if ([string]::IsNullOrWhiteSpace([string]$function_params.rule_name)) {
        Log warning 'IOSSecurityCompliance skipped: configure rule_name to collect compliance data. Mosyle requires a rule name and provides no documented rule discovery endpoint.'
        return
    }
    Read-MosyleTable -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'IOSSecurityCompliance'
}


function Idm-AccountsRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'Accounts'
}


function Idm-CustomDeviceAttributesRead {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Read-MosyleTable -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Class 'CustomDeviceAttributes'
}


function Idm-UserCreate {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'UserCreate'
}


function Idm-UserUpdate {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'UserUpdate'
}


function Idm-UserDelete {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'UserDelete'
}


function Idm-UserAssignDevice {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'UserAssignDevice'
}


function Idm-DeviceUpdate {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'DeviceUpdate'
}


function Idm-DeviceUnassign {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'DeviceUnassign'
}


function Idm-DeviceUpdateLimboLocation {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'DeviceUpdateLimboLocation'
}


function Idm-DeviceLock {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'DeviceLock'
}


function Idm-DynamicDeviceGroupAdd {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'DynamicDeviceGroupAdd'
}


function Idm-DynamicDeviceGroupRemove {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'DynamicDeviceGroupRemove'
}


function Idm-SharedDeviceGroupAdd {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'SharedDeviceGroupAdd'
}


function Idm-SharedDeviceGroupRemove {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'SharedDeviceGroupRemove'
}


function Idm-CustomDeviceAttributeUpdate {
    param (
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Invoke-MosyleAction -GetMeta:$GetMeta -SystemParams $SystemParams -FunctionParams $FunctionParams -Action 'CustomDeviceAttributeUpdate'
}


#
# Internal functions
#

function Invoke-MosyleRequest {
    param (
        [hashtable] $Settings,
        [string] $Path,
        [hashtable] $Body,
        [string] $Authorization,
        [string] $Class,
        [string] $LogMessage,
        [switch] $Mutation,
        [switch] $AuthorizationRetried
    )
    # Callers may hold an older token after another request refreshed the session.
    if ($Path -ne '/v2/login' -and $Authorization) {
        $Authorization = Get-MosyleAuthorization -Settings $Settings
    }
    $headers = @{
        Accept = 'application/json'
    }
    if ($Authorization) {
        $headers.Authorization = $Authorization
    }

    # Build request parameters. Do not log bodies, credentials, or authorization headers.
    $splat = @{
        Uri                = 'https://managerapi.mosyle.com' + $Path
        Method             = 'POST'
        Headers            = $headers
        ContentType        = 'application/json; charset=utf-8'
        Body               = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10 -Compress))
        UseBasicParsing    = $true
        TimeoutSec         = 120
        MaximumRedirection = 0
    }

    # Configure proxy if enabled.
    if ($Settings.use_proxy) {
        $proxyUri = $null
        if (-not [Uri]::TryCreate([string] $Settings.proxy_address, [UriKind]::Absolute, [ref] $proxyUri) -or
            $proxyUri.Scheme -notin @('http','https')) {
            throw 'A valid HTTP or HTTPS Proxy Address is required when Use Proxy is enabled.'
        }
        $splat.Proxy = $proxyUri
        if ($Settings.use_proxy_credentials) {
            if ([string]::IsNullOrWhiteSpace([string] $Settings.proxy_username) -or
                [string]::IsNullOrEmpty([string] $Settings.proxy_password)) {
                throw 'Proxy Username and Proxy Password are required when Use Proxy Credentials is enabled.'
            }
            $splat.ProxyCredential = New-Object System.Management.Automation.PSCredential (
                $Settings.proxy_username,
                (ConvertTo-SecureString $Settings.proxy_password -AsPlainText -Force)
            )
        }
    }

    # Defaults also apply to connection settings saved before retry options were added.
    $maxAttempts = 5
    $retryDelay = 2
    if ($null -ne $Settings.nr_of_retries) {
        if (-not [int]::TryParse([string] $Settings.nr_of_retries, [ref] $maxAttempts) -or
            $maxAttempts -lt 1 -or $maxAttempts -gt 20) {
            throw 'Max. number of retry attempts must be an integer from 1 to 20.'
        }
    }
    if ($null -ne $Settings.retryDelay) {
        if (-not [int]::TryParse([string] $Settings.retryDelay, [ref] $retryDelay) -or
            $retryDelay -lt 1 -or $retryDelay -gt 60) {
            throw 'Seconds to wait for retry must be an integer from 1 to 60.'
        }
    }

    # Mutations only retry explicit throttling. A timeout or 5xx may follow a committed write.
    for ($attempt = 0; $attempt -lt $maxAttempts; $attempt++) {
        try {
            $attemptSuffix = if ($attempt -gt 0) { " (Attempt $($attempt + 1))" } else { '' }
            $requestContext = "$($splat.Method) Call: $($splat.Uri)$($attemptSuffix) [$($Class)] $($LogMessage)"
            Log verbose $requestContext
            $response = Invoke-WebRequest @splat -ErrorAction Stop
            Add-Member -InputObject $response -NotePropertyName MosyleRequestContext -NotePropertyValue $requestContext -Force
            break
        }
        catch {
            $response = $_.Exception.Response
            $status = 0
            if ($null -ne $response) {
                $status = [int] $response.StatusCode
            }
            if ($status -eq 401 -and $Path -ne '/v2/login' -and $Authorization) {
                $script:MosyleAuthorizationCache = $null
                if (-not $AuthorizationRetried) {
                    Log warning "$requestContext - HTTP 401; refreshing token once."
                    $newToken = Get-MosyleAuthorization -Settings $Settings -ForceRefresh
                    return Invoke-MosyleRequest -Settings $Settings -Path $Path -Body $Body -Authorization $newToken -Class $Class -LogMessage $LogMessage -Mutation:$Mutation -AuthorizationRetried
                }
            }
            $retryable = ($status -eq 0 -or $status -in @(408,429,500,502,503,504))
            if (-not $retryable -or $attempt -eq ($maxAttempts - 1) -or ($Mutation -and $status -ne 429)) {
                Log error "$requestContext - HTTP $status"
                throw "$requestContext - HTTP $status (request failed)"
            }
            $delay = [double][Math]::Min(60, ($retryDelay * [Math]::Pow(2, $attempt)))
            if ($null -ne $response) {
                $retryAfter = [string] $response.Headers['Retry-After']
                $seconds = 0
                $date = [DateTimeOffset]::MinValue
                if ([int]::TryParse($retryAfter, [ref] $seconds)) {
                    $delay = [Math]::Max($delay, $seconds)
                }
                elseif ([DateTimeOffset]::TryParse($retryAfter, [ref] $date)) {
                    $delay = [Math]::Max($delay, [Math]::Ceiling(($date - [DateTimeOffset]::UtcNow).TotalSeconds))
                }
            }
            Log warning "$requestContext - HTTP $status. Retrying in $delay seconds."
            Start-Sleep -Seconds ([int][Math]::Min(2147483, $delay))
        }
    }
    # Some API versions report token rejection in a successful HTTP response.
    if ($Path -ne '/v2/login' -and $Authorization) {
        $apiStatus = $null
        try { $apiStatus = (ConvertFrom-Json -InputObject $response.Content -ErrorAction Stop).status }
        catch { } # Endpoint readers report malformed JSON with their request context.
        if ($apiStatus -in @('INVALID_TOKEN','TOKEN_EXPIRED','INVALID_AUTHORIZATION','UNAUTHORIZED')) {
            $script:MosyleAuthorizationCache = $null
            if ($AuthorizationRetried) { throw "$requestContext - API error: $apiStatus" }
            Log warning "$requestContext - Authorization rejected; refreshing token once."
            $newToken = Get-MosyleAuthorization -Settings $Settings -ForceRefresh
            return Invoke-MosyleRequest -Settings $Settings -Path $Path -Body $Body -Authorization $newToken -Class $Class -LogMessage $LogMessage -Mutation:$Mutation -AuthorizationRetried
        }
    }
    return $response

}

function Get-MosyleAuthorization {
    param (
        [hashtable] $Settings,
        [switch] $ForceRefresh
    )

    foreach ($key in @('username','password','accessToken')) {
        if ([string]::IsNullOrWhiteSpace([string] $Settings[$key])) {
            throw "Mosyle connection setting '$key' is required."
        }
    }
    $identity = [ordered]@{}
    foreach ($key in @('username','password','accessToken','use_proxy','proxy_address','use_proxy_credentials','proxy_username','proxy_password')) {
        $identity[$key] = $Settings[$key]
    }
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $cacheKey = [Convert]::ToBase64String($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes(($identity | ConvertTo-Json -Compress))))
    }
    finally {
        $hasher.Dispose()
    }
    if (-not $ForceRefresh -and $null -ne $script:MosyleAuthorizationCache -and
        $script:MosyleAuthorizationCache.Key -eq $cacheKey -and
        -not [string]::IsNullOrWhiteSpace($script:MosyleAuthorizationCache.Token)) {
        return $script:MosyleAuthorizationCache.Token
    }

    $script:MosyleAuthorizationCache = $null
    $response = Invoke-MosyleRequest -Settings $Settings -Path '/v2/login' -Class 'Authentication' -Body @{
        accessToken = $Settings.accessToken
        email = $Settings.username
        password = $Settings.password
    }
    $token = [string] ($response.Headers['Authorization'] | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'Mosyle login did not return an Authorization header.'
    }
    $script:MosyleAuthorizationCache = @{ Key = $cacheKey; Token = $token }
    return $token
}


function Get-MosyleUsersPage {
    param (
        [hashtable] $Settings,
        [string] $Authorization,
        [int] $Page,
        [string[]] $Columns
    )
    $response = Invoke-MosyleRequest -Settings $Settings -Path '/v2/listusers' -Class 'Users' -LogMessage "[Page: $Page]" -Authorization $Authorization -Body @{
        accessToken = $Settings.accessToken
        options = @{
            page = $Page
            page_size = Get-MosylePageSize -Settings $Settings
            specific_columns = @($Columns)
        }
    }
    try {
        $data = ConvertFrom-Json -InputObject $response.Content -ErrorAction Stop
    }
    catch {
        throw 'Mosyle listusers returned invalid JSON.'
    }
    if ($data.status -ne 'OK' -or $data.response.status -ne 'OK') {
        $status = if ($data.status -ne 'OK') { $data.status } else { $data.response.status }
        throw "$($response.MosyleRequestContext) - API error: $status"
    }
    $result = $data.response
    if ($null -eq $result.users -or $null -eq $result.page -or $null -eq $result.page_size -or $null -eq $result.total) {
        throw 'Mosyle listusers response is missing users or pagination metadata.'
    }
    $actualPage = 0L
    $pageSize = 0L
    $total = 0L
    if (-not [long]::TryParse([string] $result.page, [ref] $actualPage) -or $actualPage -ne $Page -or
        -not [long]::TryParse([string] $result.page_size, [ref] $pageSize) -or $pageSize -le 0 -or
        -not [long]::TryParse([string] $result.total, [ref] $total) -or $total -lt 0) {
        throw 'Mosyle listusers returned invalid or unexpected pagination metadata.'
    }
    return $result
}

function ConvertTo-MosyleArray {
    param (
        $Value,
        [switch] $Objects
    )

    if ($Value -is [string]) {
        if ($Value.Trim().StartsWith('[')) {
            try {
                $Value = ConvertFrom-Json -InputObject $Value -ErrorAction Stop
            }
            catch {
                throw 'Invalid JSON array parameter.'
            }
        }
        elseif ($Objects) {
            throw 'Locations must be a JSON array of objects with name and, for students, grade_level.'
        }
        else { $Value = @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    }
    foreach ($item in @($Value)) {
        if ($null -ne $item) {
            $item
        }
    }
}

function Invoke-MosyleApi {
    param (
        [hashtable] $Settings,
        [string] $Authorization,
        [string] $Path,
        [hashtable] $Body,
        [string] $Class,
        [string] $LogMessage,
        [switch] $Mutation
    )

    $splat = @{
        Settings = $Settings
        Authorization = $Authorization
        Path = $Path
        Body = $Body
        Class = $Class
        LogMessage = $LogMessage
        Mutation = $Mutation
    }
    $response = Invoke-MosyleRequest @splat
    try {
        $data = ConvertFrom-Json -InputObject $response.Content -ErrorAction Stop
    }
    catch {
        throw "$($response.MosyleRequestContext) - Invalid JSON response."
    }
    if ($data.status -and $data.status -notin @('OK','success')) {
        throw "$($response.MosyleRequestContext) - API error: $($data.status)"
    }
    if (-not $data.status -and $Path -ne '/v2/iossecuritycontrolscompliance') {
        throw "$($response.MosyleRequestContext) - No API status returned."
    }
    foreach ($item in @($data.response) + @($data.elements)) {
        if ($null -eq $item) {
            continue
        }
        if ($item.status -and $item.status -notin @('OK','success','COMMAND_SENT')) {
            throw "$($response.MosyleRequestContext) - Unsuccessful item status: $($item.status)"
        }
        if ($null -ne $item.devices_notfound -and @($item.devices_notfound).Count -gt 0) {
            throw "$($response.MosyleRequestContext) - Could not find one or more requested devices."
        }
    }
    return $data
}

function Get-MosyleTableMetaData {
    param (
        [string] $Class
    )

    $definition = $script:MosyleTables[$Class]
    foreach ($name in $definition.Settings) {
        $value = ''
        $tooltip = 'Optional API filter.'
        if ($name -eq 'os') {
            $value = 'mac'
            $tooltip = 'Required OS: ios, mac, tvos, visionos (subject to endpoint support).'
        }
        if ($name -eq 'is_security_group') {
            $value = '0'
        }
        if ($name -eq 'security_compliance_status') {
            $value = 'compliant'
        }

        if ($name -in @('tags','osversions','serial_numbers')) {
            $tooltip = 'Comma-separated values or a JSON array of strings.'
        }
        if ($name -eq 'iddevicegroup') {
            $tooltip = 'Optional group ID. Leave blank to collect memberships for all dynamic groups in the selected OS.'
        }
        if ($name -eq 'rule_name') {
            $tooltip = 'Mosyle requires a rule name. Leave blank to skip this table with a warning.'
        }
        @{
            name = $name
            type = 'textbox'
            label = $name
            tooltip = $tooltip
            value = $value
        }
    }
    if ($Class -in @('Devices','Classes','SharedDeviceGroups')) {
        @{
            name = 'specific_columns'
            type = 'textbox'
            label = 'Specific columns'
            tooltip = 'Comma-separated API column names. Nested values are returned as compact JSON.'
            value = $definition.Columns
        }
    }
}

function Read-MosyleTable {
    param (
        [switch] $GetMeta,
        [string] $SystemParams,
        [string] $FunctionParams,
        [string] $Class,
        [switch] $RawClassData,
        [switch] $RawDeviceData
    )

    Log verbose "-GetMeta=$GetMeta [$Class]"
    if ($GetMeta) {
        Get-MosyleTableMetaData -Class $Class
        Log verbose "Done [$Class metadata]"
        return
    }
    $definition = $script:MosyleTables[$Class]
    $system_params = ConvertFrom-Json2 $SystemParams
    $function_params = @{}
    if (-not [string]::IsNullOrWhiteSpace($FunctionParams)) {
        $function_params = ConvertFrom-Json2 $FunctionParams
    }
    $options = @{ page_size = Get-MosylePageSize -Settings $system_params }
    foreach ($name in $definition.Settings) {
        $value = $function_params[$name]
        if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
            if ($name -eq 'os') {
                $value = 'mac'
            }
            elseif ($name -eq 'is_security_group') {
                $value = '0'
            }
            elseif ($name -eq 'security_compliance_status') {
                $value = 'compliant'
            }

            elseif ($name -in @('iddevicegroup','rule_name')) {
                throw "Table setting '$name' is required."
            }
            else {
                continue
            }
        }
        if ($name -eq 'os') {
            $allowed = @('ios','mac','tvos','visionos')
            if ($Class -eq 'DeviceGroupDevices') {
                $allowed = @('ios','mac','tvos')
            }
            if ($Class -eq 'SharedDeviceGroups') {
                $allowed = @('ios','mac','visionos')
            }
            if ($value -notin $allowed) {
                throw "Unsupported os for $Class."
            }
        }
        if ($name -eq 'security_compliance_status' -and $value -notin @('compliant','noncompliant')) {
            throw 'security_compliance_status must be compliant or noncompliant.'
        }
        if ($name -eq 'is_security_group' -and [string]$value -notin @('0','1')) {
            throw 'is_security_group must be 0 or 1.'
        }

        if ($name -in @('tags','osversions','serial_numbers')) {
            $value = @(ConvertTo-MosyleArray $value)
        }
        $options[$name] = $value
    }
    $columns = @($definition.Columns -split ',')
    if ($Class -in @('Devices','Classes','SharedDeviceGroups')) {
        if (-not [string]::IsNullOrWhiteSpace([string]$function_params.specific_columns)) {
            $columns = @(([string]$function_params.specific_columns) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
        }
        foreach ($column in $columns) {
            if ($column -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                throw "Invalid column name '$column'."
            }
        }
        if ($columns.Count -eq 0) {
            throw 'At least one specific column is required.'
        }
        if ($Class -eq 'Devices') {
            $columns = @($columns | Where-Object { $_ -ne 'CustomDeviceAttributes' -and $_ -notlike 'CustomDevicesAttributes_*' })
        }
        if ($Class -eq 'Classes') {
            $columns = @($columns | Where-Object { $_ -notin @('teacher','teachers','students','coordinators') })
        }
        $options.specific_columns = $columns
    }
    if ($definition.ClassRole) {
        $options.specific_columns = @('id', $definition.ClassRole)
    }
    $membershipKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $page = 1
    $paged = $definition.Paged
    $useClassCache = ($Class -eq 'Classes' -or $definition.ClassRole) -and -not $RawClassData
    if ($RawClassData) {
        # Explicitly request relationship fields; the API default projection may omit them.
        $options.specific_columns = @('id','class_name','course_name','location','teacher','students','coordinators','account')
    }
    $useDeviceCache = $Class -eq 'Devices' -and -not $RawDeviceData
    if ($RawDeviceData) { $options.Remove('specific_columns') }
    if ($useDeviceCache) {
        $cachedDevices = @(Get-MosyleDevices -SystemParams $SystemParams -FunctionParams $FunctionParams)
        $paged = $false
    }
    elseif ($useClassCache) {
        $cachedClasses = @(Get-MosyleClasses -SystemParams $SystemParams)
        $paged = $false
    }
    else {
        $token = Get-MosyleAuthorization $system_params
    }
    $rowCount = 0L
    $sourceCount = 0L
    $seenPages = New-Object 'System.Collections.Generic.HashSet[string]'
    $pageOffset = $null
    do {
        $options.page = $page
        $body = @{
            accessToken = $system_params.accessToken
            options = $options
        }
        if ($Class -eq 'CustomDeviceAttributes') {
            $body.elements = @(@{ operation = 'list_custom_device_attributes'; os = $options.os })
        }
        if ($useDeviceCache) {
            $data = [PSCustomObject]@{ response = [PSCustomObject]@{ devices = $cachedDevices } }
        }
        elseif ($useClassCache) {
            $data = [PSCustomObject]@{ response = [PSCustomObject]@{ classes = $cachedClasses } }
        }
        else {
            $data = Invoke-MosyleApi -Settings $system_params -Authorization $token -Path $definition.Path -Body $body -Class $Class -LogMessage "[Page: $page]"
        }
        if ($Class -eq 'Accounts') {
            $container = $data
        }
        else {
            $containers = @($data.response)
            if ($containers.Count -ne 1 -or $null -eq $containers[0]) {
                throw "Unexpected response container for $Class."
            }
            $container = $containers[0]
        }
        $property = $container.PSObject.Properties[$definition.Collection]
        if ($null -eq $property -or $null -eq $property.Value) {
            throw "Missing $($definition.Collection) collection for $Class."
        }
        $items = @($property.Value)
        if ($paged -and $items.Count -gt 0) {
            $pageJson = ConvertTo-Json -InputObject $items -Depth 32 -Compress
            $hasher = [Security.Cryptography.SHA256]::Create()
            try {
                $signature = [Convert]::ToBase64String($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($pageJson)))
            }
            finally {
                $hasher.Dispose()
            }
            if (-not $seenPages.Add($signature)) {
                throw "Repeated page received for $Class; aborting to prevent duplicate or incomplete import."
            }
            if ($null -ne $container.page) {
                $actualPage = 0
                if (-not [int]::TryParse([string]$container.page, [ref]$actualPage)) {
                    throw "Invalid page metadata for $Class."
                }
                if ($null -eq $pageOffset) {
                    $pageOffset = $actualPage - $page
                }
                if ($actualPage -ne ($page + $pageOffset)) {
                    throw "Unexpected page metadata for $Class."
                }
            }
        }
        $sourceCount += $items.Count
        foreach ($item in $items) {
            if ($RawClassData -or $RawDeviceData) {
                $item
                $rowCount++
                continue
            }
            if ($definition.ClassRole) {
                $classId = [string]$item.id
                if ([string]::IsNullOrWhiteSpace($classId)) { throw 'Class membership response is missing the class id.' }
                $members = $item.($definition.ClassRole)
                if ($definition.ClassRole -eq 'teacher' -and $null -eq $members) { $members = $item.teachers }
                foreach ($member in @($members)) {
                    if ($null -eq $member) { continue }
                    $userId = $null
                    if ($member -is [string] -or $member -is [ValueType]) { $userId = [string]$member }
                    else {
                        foreach ($field in @('id','userid','UserID')) {
                            if ($null -ne $member.$field) { $userId = [string]$member.$field; break }
                        }
                    }
                    if ([string]::IsNullOrWhiteSpace($userId)) {
                        if ($member -is [string]) { continue }
                        throw 'Class membership response contains a member without a user id.'
                    }
                    $key = $classId + '_' + $userId
                    if ($membershipKeys.Add($key)) {
                        [PSCustomObject][ordered]@{ Key = $key; ClassID = $classId; UserID = $userId }
                        $rowCount++
                    }
                }
                continue
            }
            if ($definition.Membership) {
                if ($null -eq $item.deviceudids) {
                    throw 'Group response is missing deviceudids.'
                }
                foreach ($udid in @($item.deviceudids)) {
                    [PSCustomObject][ordered]@{ id = $item.id; name = $item.name; deviceudid = $udid }
                    $rowCount++
                }
                continue
            }
            if ($Class -eq 'DynamicGroupDevices') {
                [PSCustomObject][ordered]@{ iddevicegroup = $options.iddevicegroup; group_name = $container.group_name; deviceudid = $item }
                $rowCount++
                continue
            }
            $row = [ordered]@{}
            foreach ($column in $columns) {
                if ($Class -eq 'Devices' -and $column -eq 'CustomDeviceAttributes') { continue }
                $value = $item.$column
                # Class request names and response names differ in the supplied examples.
                if ($Class -eq 'Classes' -and $null -eq $value) {
                    if ($column -eq 'class_name') {
                        $value = $item.name
                    }
                    if ($column -eq 'location') {
                        $value = $item.locations
                    }
                }
                if ($Class -eq 'IOSSecurityCompliance' -and $column -eq 'rule_name') {
                    $value = $container.rule_name
                }
                if ($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]) {
                    $value = ConvertTo-Json -InputObject $value -Depth 32 -Compress
                }
                $row[$column] = $value
            }
            [PSCustomObject]$row
            $rowCount++
        }
        Log verbose "Retrieved [$Class] page $($page): $($items.Count) source records"
        if (-not $paged) {
            break
        }
        $totalValue = $null
        $totalKeys = @('total','total_rows','rows')
        if ($Class -eq 'Classes' -or $definition.ClassRole) {
            # Class 'rows' can describe the current page rather than the grand total.
            $totalKeys = @('total','total_rows')
        }
        foreach ($key in $totalKeys) {
            if ($null -ne $container.$key) {
                $totalValue = $container.$key
                break
            }
        }
        if ($null -ne $totalValue) {
            $total = 0L
            if (-not [long]::TryParse([string]$totalValue, [ref]$total) -or $total -lt 0) {
                throw "Invalid total metadata for $Class."
            }
            if ($sourceCount -ge $total) {
                break
            }
            if ($items.Count -eq 0) {
                throw "Empty page before reported total for $Class."
            }
        }
        elseif ($items.Count -eq 0) {
            break
        }
        # Classes have no documented total: continue until an empty page.
        $page++
    } while ($true)
    Log info "Done [$Class]: $rowCount rows retrieved"
}

function Invoke-MosyleAction {
    param (
        [switch] $GetMeta,
        [string] $SystemParams,
        [string] $FunctionParams,
        [string] $Action
    )

    Log verbose "-GetMeta=$GetMeta [$Action]"
    $definition = $script:MosyleActions[$Action]
    if ($GetMeta) {
        @{
            semantics = $definition.Semantics
            parameters = @(
                foreach ($name in $definition.Required) { @{ name = $name; allowance = 'mandatory' } }
                foreach ($name in $definition.Optional) { @{ name = $name; allowance = 'optional' } }
            )
        }
        return
    }
    $system_params = ConvertFrom-Json2 $SystemParams
    $function_params = ConvertFrom-Json2 $FunctionParams
    $element = @{}
    if ($definition.Operation) {
        $element.operation = $definition.Operation
    }
    foreach ($name in @($definition.Required) + @($definition.Optional)) {
        if (-not $function_params.ContainsKey($name)) {
            if ($name -in $definition.Required) {
                throw "Action parameter '$name' is required."
            }
            continue
        }
        $value = $function_params[$name]
        if ($name -in $definition.Arrays) {
            $value = @(ConvertTo-MosyleArray -Value $value -Objects:($name -eq 'locations'))
            if ($value.Count -eq 0) {
                throw "Action array '$name' cannot be empty."
            }
        }
        if ($name -in $definition.Required -and ($null -eq $value -or ($name -ne 'value' -and $value -is [string] -and [string]::IsNullOrWhiteSpace($value)))) {
            throw "Action parameter '$name' cannot be empty."
        }
        $element[$name] = $value
    }
    if ($element.ContainsKey('type') -and $element.type -notin @('S','T','STAFF')) {
        throw 'User type must be S, T, or STAFF.'
    }
    if ($element.ContainsKey('os') -and $element.os -notin @('ios','mac','tvos','visionos')) {
        throw 'Invalid device OS.'
    }
    if ($element.ContainsKey('welcome_email') -and [string]$element.welcome_email -notin @('0','1')) {
        throw 'welcome_email must be 0 or 1.'
    }
    if ($element.ContainsKey('welcome_email')) {
        $element.welcome_email = [int]$element.welcome_email
    }
    if ($Action -eq 'UserCreate' -and $element.type -eq 'T' -and [string]::IsNullOrWhiteSpace([string]$element.email)) {
        throw 'Email is required for teachers.'
    }
    foreach ($location in @($element.locations)) {
        if ($null -eq $location) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace([string]$location.name)) {
            throw 'Each location requires a name.'
        }
        if ($element.type -eq 'S' -and [string]::IsNullOrWhiteSpace([string]$location.grade_level)) {
            throw 'Student locations require grade_level.'
        }
    }
    if ($Action -eq 'DeviceUnassign' -and -not $element.devices -and -not $element.groups) {
        throw 'Specify devices or groups to unassign.'
    }
    if ($Action -eq 'DeviceLock' -and $element.ContainsKey('pincode') -and [string]$element.pincode -notmatch '^\d{6}$') { throw 'pincode must contain exactly six digits.' }
    if ($Action -eq 'DeviceUpdate' -and $element.Count -le 1) {
        throw 'Specify at least one device attribute to update.'
    }
    if ($Action -eq 'UserUpdate' -and @($element.Keys | Where-Object { $_ -notin @('operation','id','idaccount') }).Count -eq 0) { throw 'Specify at least one user attribute to update.' }
    # Validate documented string limits and account/group identifiers before sending writes.
    foreach ($name in @('id','email','managed_appleid')) {
        if ($element.ContainsKey($name) -and ([string]$element[$name]).Length -gt 255) {
            throw "Parameter '$name' exceeds 255 characters."
        }
    }
    if ($Action -like 'User*' -and ([string]$element.name).Length -gt 100) {
        throw 'User name exceeds 100 characters.'
    }
    foreach ($location in @($element.locations)) {
        if ($null -eq $location) {
            continue
        }
        if (([string]$location.name).Length -gt 50 -or ([string]$location.grade_level).Length -gt 50) {
            throw 'Location name and grade_level cannot exceed 50 characters.'
        }
    }
    foreach ($name in @('idaccount','idgroup','idshareddevicegroup')) {
        if ($element.ContainsKey($name)) {
            $number = 0L
            if (-not [long]::TryParse([string]$element[$name], [ref]$number) -or $number -le 0) {
                throw "Parameter '$name' must be a positive integer."
            }
            $element[$name] = $number
        }
    }
    $body = @{ accessToken = $system_params.accessToken }
    if ($definition.Envelope) {
        $body.elements = @($element)
    }
    else { foreach ($key in $element.Keys) { $body[$key] = $element[$key] } }
    $token = Get-MosyleAuthorization $system_params
    $result = Invoke-MosyleApi -Settings $system_params -Authorization $token -Path $definition.Path -Body $body -Class $Action -Mutation
    if ($definition.Path -eq '/v2/users' -and ($null -eq $result.elements -or @($result.elements).Count -ne 1)) {
        throw 'Mosyle did not return a user operation result.'
    }
    if ($definition.Path -eq '/v2/devices') {
        if ($element.serialnumber -notin @($result.devices)) {
            throw 'Mosyle did not confirm the requested device update.'
        }
    }
    elseif ($definition.Path -ne '/v2/users' -and ($null -eq $result.response -or @($result.response).Count -eq 0)) {
        throw 'Mosyle did not return an operation result.'
    }
    if ($definition.Path -eq '/v2/users') {
        if ($result.elements[0].status -ne 'OK' -or $result.elements[0].id -ne $element.id) {
            throw 'Mosyle did not confirm success for the requested user.'
        }
    }
    elseif ($definition.Path -ne '/v2/devices') {
        foreach ($item in @($result.response)) {
            if ($item.status -notin @('OK','COMMAND_SENT')) {
                throw 'Mosyle did not confirm operation success.'
            }
        }
    }
    Log info "Done [$Action]"
    $output = [ordered]@{}
    foreach ($key in $element.Keys | Sort-Object) {
        if ($key -eq 'operation' -or $key -eq 'pincode') {
            continue
        }
        $value = $element[$key]
        if ($value -is [array]) {
            $value = ConvertTo-Json -InputObject $value -Depth 32 -Compress
        }
        $output[$key] = $value
    }
    [PSCustomObject]$output
}

function Get-MosylePageSize {
    param (
        [hashtable] $Settings
    )

    $pageSize = 100
    if ($null -ne $Settings.page_size) {
        if (-not [int]::TryParse([string]$Settings.page_size, [ref]$pageSize) -or $pageSize -le 0) {
            throw 'Page Size must be a positive integer.'
        }
    }
    return $pageSize
}

function Get-MosyleClasses {
    param (
        [string] $SystemParams
    )

    # Compare a digest so connection secrets are not retained in the cache key.
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $key = [Convert]::ToBase64String($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($SystemParams)))
    }
    finally {
        $hasher.Dispose()
    }
    if ($null -eq $script:MosyleClassesCache -or $script:MosyleClassesCache.Key -ne $key) {
        $script:MosyleClassesCache = $null
        Log verbose 'Loading shared Classes cache'
        $rows = @(Read-MosyleTable -SystemParams $SystemParams -Class 'Classes' -RawClassData)
        $script:MosyleClassesCache = @{ Key = $key; Rows = $rows }
    }
    else {
        Log verbose 'Using shared Classes cache'
    }
    $script:MosyleClassesCache.Rows
}

function Idm-OnUnload {
    $script:MosyleClassesCache = $null
    $script:MosyleDevicesCache = $null
    $script:MosyleAuthorizationCache = $null
}

function Get-MosyleDevices {
    param (
        [string] $SystemParams,
        [string] $FunctionParams
    )

    $parameters = @{}
    if (-not [string]::IsNullOrWhiteSpace($FunctionParams)) { $parameters = ConvertFrom-Json2 $FunctionParams }
    $filters = [ordered]@{}
    foreach ($name in @('os','tags','osversions','serial_numbers')) {
        if ($parameters.ContainsKey($name)) { $filters[$name] = $parameters[$name] }
    }
    if (-not $filters.Contains('os') -or [string]::IsNullOrWhiteSpace([string]$filters.os)) { $filters.os = 'mac' }
    $filterJson = ConvertTo-Json -InputObject $filters -Depth 10 -Compress
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $key = [Convert]::ToBase64String($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($SystemParams + '|' + $filterJson)))
    }
    finally { $hasher.Dispose() }
    if ($null -eq $script:MosyleDevicesCache -or $script:MosyleDevicesCache.Key -ne $key) {
        $script:MosyleDevicesCache = $null
        Log verbose 'Loading shared Devices cache'
        # Without specific_columns, Mosyle returns all device fields including custom attributes.
        $rows = @(Read-MosyleTable -SystemParams $SystemParams -FunctionParams $filterJson -Class 'Devices' -RawDeviceData)
        $script:MosyleDevicesCache = @{ Key = $key; Rows = $rows }
    }
    else { Log verbose 'Using shared Devices cache' }
    $script:MosyleDevicesCache.Rows
}
