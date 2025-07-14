Write-Host "Please enter your system credentials (e.g. DOMAIN\\your-username)"
$username = Read-Host "Username"
$password = Read-Host "Password" 
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$password = $null
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
$securePassword = $null

Write-Host "Please enter a list of property codes (each on a new line):"

Add-Type -AssemblyName PresentationFramework

$propertyArray = $null

# UI input dialog for property codes
$propertyInputXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Enter Property Codes" Height="300" Width="400" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Topmost="True">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <TextBox Name="InputTextBox" AcceptsReturn="True" VerticalScrollBarVisibility="Visible" TextWrapping="Wrap" />
        <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="OkButton" Width="75" Margin="5,0,0,0">OK</Button>
            <Button Name="CancelButton" Width="75" Margin="5,0,0,0">Cancel</Button>
        </StackPanel>
    </Grid>
</Window>
"@

$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($propertyInputXAML)

$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)

$InputTextBox = $window.FindName("InputTextBox")
$OkButton = $window.FindName("OkButton")
$CancelButton = $window.FindName("CancelButton")

$OkButton.Add_Click({
    $script:propertyArray = $InputTextBox.Text -split "`r`n"
    $window.Close()
})

$CancelButton.Add_Click({
    $window.Close()
})

$null = $window.ShowDialog()

$sqlCommand = @'
-- Simplified sample SQL logic --
USE PropertyDB
IF (SELECT Country FROM Property) = 'DE'
BEGIN
    IF (SELECT dbo.GetSetting('EnableFiscalIntegration')) = 'True'
    BEGIN
        SELECT * FROM IntegrationRequests WHERE Status = 'Y'
    END
    ELSE
        SELECT 'Fiscal integration not enabled for this property.'
END
ELSE
    SELECT 'Not a German property.'
'@

foreach ($code in $propertyArray) {
    Write-Host "Connecting to $code..."
    $output = Invoke-Command -ComputerName "$code-server.internal.domain" -Credential $credential `
               -ScriptBlock { Invoke-Sqlcmd -Database "PropertyDB" -Query $using:sqlCommand -QueryTimeout 180 }

    $output | Format-Table -AutoSize
}

Read-Host "Press any key to exit"
