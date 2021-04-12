# ========================= CONSTANT VARIABLE ================
# execute bat folder
set-variable -name execute_bat_folder -value ($args[0]) -option constant
# soql.txt file path
set-variable -name soql_txt_file -value (Join-Path -Path $execute_bat_folder -ChildPath soql.txt) -option constant
# new line
set-variable -name crlf -value ([System.Environment]::NewLine) -option constant
# current directory
set-variable -name current_dir -value $PSScriptRoot -option constant
# temp csv file
set-variable -name temp_csv_file -value "$current_dir\temp.csv" -option constant
# Utf8NoBomEncoding
set-variable -name Utf8NoBomEncoding -value (New-Object System.Text.UTF8Encoding $False) -option constant
# records count per json file
set-variable -name records_count -value 200 -option constant
# 
# =================================================================


# ========================= FUNCTION ========================
#  execute soql and return csv format data
function Query($soql_string) {
    $soql_string = $soql_string.Replace("`r`n", "`n")
    $soql = $soql_string.Split("`n")
    (sfdx force:data:soql:query -q "$soql" -r csv > $temp_csv_file) > $null
    $datas = Import-Csv $temp_csv_file -Encoding UTF8
    Remove-Item $temp_csv_file
    return $datas;
}

# Function for writing log
# Param: $text = content of logs
# Param: $type = "info" (will shown as blue text) | "debug" (yellow) | "error" (red) | any other (white)
# Return: None
function writeLog($text, $type) {
    if ($type -eq "info") {
        Write-Host (Get-Date -Format "yyyy/MM/dd HH:mm:ss |")  ("[" + $type.ToUpper() + "]") $text -ForegroundColor Blue
    }
    elseif ($type -eq "error") {
        Write-Host (Get-Date -Format "yyyy/MM/dd HH:mm:ss |")  ("[" + $type.ToUpper() + "]") $text -ForegroundColor Red
    }
    elseif ($type -eq "debug") {
        Write-Host (Get-Date -Format "yyyy/MM/dd HH:mm:ss |")  ("[" + $type.ToUpper() + "]") $text -ForegroundColor Yellow
    }
    else {
        Write-Host (Get-Date -Format "yyyy/MM/dd HH:mm:ss |")  ("[" + $type.ToUpper() + "]") $text
    }
}

# Function for extract object name from soql
# Param: $soql = soql
# Return: Sobject Name
function getSobjectNameFromSoql($soql) {
    # regex
    $regexContent = '';
    if($soql -match "where"){
        $regexContent = 'From\s+([a-z_]+)[\s]+';
    }else{
        $regexContent = 'From\s+([a-z_]+)';
    }
    
    # sobject name
    $sobjectName = '';
    if($soql -match $regexContent){
        $sobjectName = $Matches[1]
    } else {
        writeLog "Can't get sObject Name From soql. Please check your soql.$($crlf)soql=[$soql]" "error"
        exit 1;
    }

    if([string]::IsNullOrEmpty($sobjectName)){
        writeLog "Can't get sObject Name From soql. Please check your soql.$($crlf)soql=[$soql]" "error"
        exit 1;
    }
    return $sobjectName;
}

# create json file bu csv datas
function convertCsvDataToJsonFile($csv_datas, $object_name, $id_referenceId_map, $parentFlg){
    $json_datas = @{}
    $records = @()
    $num = 1;
    foreach ($csv_data in $csv_datas) {
        $referenceId = $object_name + "Ref" + $num;
        if($parentFlg){
            $id_referenceId_map.Add($csv_data.Id, $referenceId);
        }

        $csv_data.psobject.properties.remove('ID')
        $attributes = New-Object pscustomobject
        $element = New-Object pscustomobject
    
        $attributes | Add-Member -MemberType NoteProperty -Name "type" -Value $object_name;
        $attributes | Add-Member -MemberType NoteProperty -Name "referenceId" -Value $referenceId;
        $element | Add-Member -MemberType NoteProperty -Name "attributes" -Value $attributes
    
        $csv_data = $csv_data | ForEach-Object {
            $NonEmptyProperties = $_.psobject.Properties | Where-Object {$_.Value} | Select-Object -ExpandProperty Name
            $_ | Select-Object -Property $NonEmptyProperties
        }
    
        $csv_data.PSObject.Properties | ForEach-Object {
            $element | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
        }
    
        $records += $element;
        $num = $num + 1;
    }
    $json_datas.Add("records", $records);
    
    $jsonFile = "$execute_bat_folder/$object_name.json"
    
    $jsonContent = $json_datas | ConvertTo-Json -Depth 3
    [System.IO.File]::WriteAllLines($jsonFile, $jsonContent, $Utf8NoBomEncoding)
}

# Because sfdx import command can only import data with 200 records per json file,this method is used for split json file
function splitJsonFile($object_name, $objectName_json_files){
    $json_file = "$execute_bat_folder/$object_name.json";
    # get json file content
    $json_objects = (Get-Content -Encoding UTF8 -Path $json_file | ConvertFrom-Json).records;

    # created json files name list
    $json_fiels = @();
    if($json_objects.Count -le $records_count){
        $json_fiels += "$object_name.json";
        $objectName_json_files.Add($object_name, $json_fiels);
        return $objectName_json_files;
    }

    # loop count
    $loop_count = [Math]::Ceiling(($json_objects.Count/$records_count));
    
    for ($i = 0; $i -lt $loop_count; $i++) {
        $json_datas = @{}

        $start = $i * $records_count;
        $end = (($i + 1) * $records_count) - 1;

        $part_json = $json_objects[$start..$end];

        $json_datas.Add("records", $part_json);
    
        $json_file_name = $object_name + "s" + ($i + 1) + ".json"

        $jsonFile = "$execute_bat_folder/$json_file_name"
        
        $jsonContent = $json_datas | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllLines($jsonFile, $jsonContent, $Utf8NoBomEncoding)
        $json_fiels += $json_file_name;
    }
    $objectName_json_files.Add($object_name, $json_fiels);
    return $objectName_json_files;
}

# replace child json file lookup field value to parent sObject referenceId
function replaceLookupFieldValue($object_name, $parentId_referenceId_map){
    $json_file = "$execute_bat_folder/$object_name.json"
    # get child json file content
    $child_json_content = Get-Content -Encoding UTF8 -Path $json_file;

    foreach ($parentId in $parentId_referenceId_map.Keys) {
        $child_json_content = $child_json_content -replace $parentId, ("@" + $parentId_referenceId_map[$parentId])
    }

    [System.IO.File]::WriteAllLines($json_file, $child_json_content, $Utf8NoBomEncoding)
}

# create plan json file
function createJsonObjectForPlanFile($object_name, $parent_flg, $files){
    $json_object = New-Object pscustomobject
    
    $json_object | Add-Member -MemberType NoteProperty -Name "sobject" -Value $object_name;
    if($parent_flg){
        $json_object | Add-Member -MemberType NoteProperty -Name "saveRefs" -Value $TRUE;
        $json_object | Add-Member -MemberType NoteProperty -Name "resolveRefs" -Value $FALSE;
    } else {
        $json_object | Add-Member -MemberType NoteProperty -Name "saveRefs" -Value $FALSE;
        $json_object | Add-Member -MemberType NoteProperty -Name "resolveRefs" -Value $TRUE;
    }
    $json_object | Add-Member -MemberType NoteProperty -Name "files" -Value $files;
    return $json_object;
}
# =================================================================

# check if soql.txt is exists
if(-Not(Test-Path $soql_txt_file)){
    writeLog "There is no soql.txt in $execute_bat_folder directory" "error"
    exit 1;
}

# get soql from soql.txt
$soqlMap = ConvertFrom-StringData (Get-Content $soql_txt_file -raw -Encoding UTF8)

# parent object name
$parent_object = '';
# parent object soql
$parent_soql = '';

# child object name and soql map key：child object name  value：child object soql
$child_object_name_soql = @{}

foreach ($soqlObject in $soqlMap.Keys) {
    $soql = ($soqlMap.$soqlObject).Trim()
    if($soqlObject.Trim().length -gt 0 -And $soql.length -gt 0){
        if($soqlObject -like '*parentObjectSoql*'){
            $parent_soql = $soql;
            $parent_object = getSobjectNameFromSoql $parent_soql;
        } elseif($soqlObject -like '*childObjectSoql*'){
            $child_soql = $soql
            $child_object = getSobjectNameFromSoql $child_soql
            $child_object_name_soql.Add($child_object, $child_soql);
        }
    }
}

# check if parent object soql and child object soql are not setted
if([string]::IsNullOrEmpty($parent_object) -Or [string]::IsNullOrEmpty($parent_soql)){
    writeLog "Please set at least one sObject soql in $soql_txt_file" "error"
    exit 1;
}

if($child_object_name_soql.Count -gt 0){
    $child_objects = '';
    foreach ($child_object in $child_object_name_soql.Keys) {
        $child_objects = $child_objects + ' ' + $child_object
    }
    $child_objects = $child_objects.Trim()
    writeLog "You will create json data for Parent sObject: [$parent_object], Child sObject:[$child_objects]." "info"
} else {
    writeLog "You will create json data for [$parent_object] sObject." "info"
}

writeLog "Start to Create $parent_object sObject json files." "info"

# query parent sObject data to csv
$parent_csv_datas = query $parent_soql

# parent id and referenceId map
$parentId_referenceId_map = @{}

# convert parent csv data to json and create json file
convertCsvDataToJsonFile $parent_csv_datas $parent_object $parentId_referenceId_map $TRUE

# key：sObject Name  value：split json files name
$objectName_json_files = @{}

# split parent json files
$objectName_json_files = splitJsonFile $parent_object $objectName_json_files;

# plan json object array
$plan_json_objects = @();

# create parent plan json object
$parent_plan_json_object = createJsonObjectForPlanFile $parent_object $TRUE $objectName_json_files[$parent_object]
$plan_json_objects += $parent_plan_json_object;

writeLog "Create $parent_object sObject json files successfully." "info"

# plan file name
$plan_file_name = "$parent_object-";

# get child sObject data and create json file
foreach ($child_object in $child_object_name_soql.Keys) {
    writeLog "Start to Create $child_object sObject json files." "info"

    # retrive child data by soql
    $child_csv_datas = query $child_object_name_soql.$child_object

    # convert child csv data to json and create json file
    convertCsvDataToJsonFile $child_csv_datas $child_object $null $FALSE

    # replace child json file lookup field value to parent sObject referenceId
    replaceLookupFieldValue $child_object $parentId_referenceId_map

    # split json file , set 200 json object in one json file for sfdx import
    $objectName_json_files = splitJsonFile $child_object $objectName_json_files

    # create child plan json file
    $child_plan_json_object = createJsonObjectForPlanFile $child_object $FALSE $objectName_json_files[$child_object]
    $plan_json_objects += $child_plan_json_object;

    $plan_file_name = $plan_file_name + "$child_object-";

    writeLog "Create $child_object sObject json files successfully." "info"
}

# create plan json file
$plan_file_name = $plan_file_name + "plan.json";

$plan_json_content = ConvertTo-Json -Depth 3 $plan_json_objects
[System.IO.File]::WriteAllLines("$execute_bat_folder/$plan_file_name", $plan_json_content, $Utf8NoBomEncoding)

writeLog "Create json files successfully." "info"