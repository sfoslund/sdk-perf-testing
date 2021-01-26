###### Configuration ######
$NumIterations=10
$TestSdkVersion=' 6.0.100-dev'
[ScriptBlock[][]]$SDKCommands = @(
    ({dotnet new wpf}, {dotnet -h}, $null),
    ({dotnet new wpf}, {dotnet build -h}, $null),
    ({dotnet new wpf}, {dotnet build}, $null),
    ({dotnet new wpf}, {dotnet publish}, $null),
    ({dotnet new sln;dotnet new console -o console}, {dotnet sln add ./console}, $null),
    ({dotnet new tool-manifest;dotnet tool install dotnetsay}, {dotnet tool list}, $null)
)
$ResultFilePath="./NoSuggestChange.txt"
###########################

function Invoke-Iteration($Iteration, $PreExpression, $ExpressionToMeasure, $PostExpression)
{
    # Create a random working directory.
    Write-Host "[$Iteration] Create Random Working Directory"
    $dirName = [Guid]::NewGuid().ToString();
    New-Item -Path $dirName -ItemType Directory | Out-Null
    
    # Switch to the working directory.
    Set-Location $dirName
    
    # Execute the pre-expression.
    if($null -ne $PreExpression)
    {
        Write-Host "[$Iteration] Pre-Expression: $PreExpression"
        $result = Measure-Command -Expression $PreExpression
        Write-Host "[$Iteration] Completed in $($result.TotalMilliseconds)ms"
    }

    # Execute the expression to measure.
    Write-Host "[$Iteration] Expression-To-Measure: $ExpressionToMeasure"
    $measurementResults = Measure-Command -Expression $ExpressionToMeasure
    Write-Host "[$Iteration] Completed in $($measurementResults.TotalMilliseconds)ms"

    # Execute the post-expression.
    if($null -ne $PostExpression)
    {
        Write-Host "[$Iteration] Post-Expression: $PostExpression"
        $result = Measure-Command -Expression $PostExpression
        Write-Host "[$Iteration] Completed in $($result.TotalMilliseconds)ms"
    }
    
    # Switch back to the original working directory and delete the random directory.
    Write-Host "[$Iteration] Delete Random Working Directory"
    Set-Location ../
    Remove-Item $dirName -Recurse | Out-Null

    return $measurementResults
}

function Get-Stats($results) {            
    $avg = $results | Measure-Object -Average | Select-Object Count, Average 
    $popdev = 0
    foreach ($number in $results){            
      $popdev +=  [math]::pow(($number - $avg.Average), 2)            
    }            
                
    $sd = [math]::sqrt($popdev / ($avg.Count-1))          
    $median = ($results | Sort-Object)[[int](($results.count -1) /2)]  
    return "Average: $($avg.Average)", "Median: $median", "Standard deviation: $sd"
}

function Test-Command($PreExpression, $ExpressionToMeasure, $PostExpression)
{
    # Setup the results list.
    $resultsList = New-Object -TypeName System.Collections.ArrayList

    # Print the command header.
    Out-Host -InputObject '======================================='
    Out-Host -InputObject "Measuring Perf for $ExpressionToMeasure"
    Out-Host -InputObject '======================================='

    # Warm-up.
    Out-Host -InputObject '*Warm-Up: Starting'
    Invoke-Iteration 0 $PreExpression $ExpressionToMeasure $PostExpression
    Out-Host -InputObject '*Warm-Up: Stopping'
    Out-Host -InputObject ""

    # Execute the test.
    Out-Host -InputObject "*Execute $($NumIterations) Iterations: Starting"
    for($i=1; $i -le $NumIterations; $i++)
    {
        $result = Invoke-Iteration $i $PreExpression $ExpressionToMeasure $PostExpression
        $resultsList.Add($result)
    }
    Out-Host -InputObject "*Execute $($NumIterations) Iterations: Stopping"
    Out-Host -InputObject ""
    Out-Host -InputObject ""

    # Dump the results to the screen.
    Out-Host -InputObject "Results for $ExpressionToMeasure (ms)"
    for($i=0; $i -le $resultsList.Count; $i++)
    {
        $result = $resultsList[$i]
        Out-Host -InputObject "$($result.TotalMilliseconds)"
    }
    $milisecResults = $resultsList | Select-Object -ExpandProperty TotalMilliseconds
    $statsResults = Get-Stats $milisecResults
    Out-Host -InputObject $statsResults
    Out-Host -InputObject ""

    # Dump the results to the output file.
    if ($null -ne $ResultFilePath) {
        Out-File -FilePath $ResultFilePath -InputObject "Results for $ExpressionToMeasure (ms)" -Append
        for($i=0; $i -le $resultsList.Count; $i++)
        {
            $result = $resultsList[$i]
            Out-File -FilePath $ResultFilePath -InputObject "$($result.TotalMilliseconds)" -Append
        }
        Out-File -FilePath $ResultFilePath -InputObject $statsResults -Append
        Out-File -FilePath $ResultFilePath -InputObject "" -Append
    }
}

# Print the header.
Out-Host -InputObject '==============================='
Out-Host -InputObject "Measuring Perf for SDK Commands"
Out-Host -InputObject '==============================='

dotnet new global.json --sdk-version $TestSdkVersion --force
dotnet --version

for($i=0; $i -lt $SDKCommands.Count; $i++)
{
    Test-Command $SDKCommands[$i][0] $SDKCommands[$i][1] $SDKCommands[$i][2]
}
