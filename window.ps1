Add-Type -AssemblyName PresentationFramework

$xamlFile="C:\Users\ssspure\Desktop\powershell\DesignVs.xaml"

$inputXAML=Get-Content -Path $xamlFile -Raw
$inputXAML=$inputXAML -replace 'mc:Ignorable="d"','' -replace "x:N","N" -replace '^<Win.*','<Window'
[XML]$XAML=$inputXAML

$reader = New-Object System.Xml.XmlNodeReader $XAML

try{
    $psform = [Windows.Markup.XamlReader]::Load($reader)
}catch{
    Write-Host $_.Exception
    throw
}

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    try{
        Set-Variable -Name "var_$($_.Name)" -value $psform.FindName($_.Name) -ErrorAction Stop
    }catch{
        throw
    }
}

Get-Variable

Get-Service | ForEach-Object { $var_dropDown.Items.Add($_.Name) }

function getServiceDetail(){
    $selectedService = $var_dropDown.SelectedItem

    $serviceDetail = Get-Service -Name $selectedService | Select *
    
    $var_labelServiceNameValue.Content = $serviceDetail.Name
    $var_labelServicevalue.Content = $serviceDetail.Status

    if($serviceDetail.Status -eq 'Running'){
        $var_labelServicevalue.Foreground = 'Green'
    }else{
        $var_labelServicevalue.Foreground = 'Red'
    }
}

$var_dropDown.Add_SelectionChanged({getServiceDetail})


$psform.ShowDialog()
