#-------------------------------------------------------------------------------------------------
# <Copyright file="Tfs.psm1">
#     Copyright (c) Jeff Tong.  All rights reserved.
# </Copyright>
#
# <Authors>
#	<Author Name="Jeff Jin Hung Tong">
# </Authors>
#
# <Description>
#     Powershell module for TFS functions.
# </Description>
#
# <Remarks>
#	This module uses Logger.psm1 and Utilities.psm1.
# </Remarks>
#
# <Disclaimer />
#-------------------------------------------------------------------------------------------------

[string] $script:TfsWorkingPath = "C:\Program Files\Microsoft Visual Studio 14.0\Common7\IDE"
[string] $script:TfExe = "$TfsWorkingPath\tf.exe"
[string] $script:TfsBuild = "$TfsWorkingPath\TfsBuild.exe"

[string] $script:TeamProject = "V1"
[string] $script:TfsUrlFlag = "/collection:"
[string] $script:TfsUrl = ""  # Define here.
[string] $script:BuildDefinitionFlag = "/BuildDefinition:"
[string] $script:BuildDefinition = "8.5"
[string] $script:DropLocationRoot = "" # Location to drop to.
[string] $script:DropLocationRootFlag = "/DropLocationRoot:"
[string] $script:MsbuildArgsFlag = "/msbuildarguments:"
[string] $script:MsbuildArgs = ''
[string] $script:LocalBuildRoot = "";
[string] $script:LogPath = "tfs-task.log"
[string] $script:BuildLocation = "";

[string[]] $script:TfsAssemblies = 'Microsoft.TeamFoundation.Build.Client', 'Microsoft.TeamFoundation.Client', `
	'Microsoft.TeamFoundation.Build.Common', 'Microsoft.TeamFoundation', 'Microsoft.TeamFoundation.Common', `
	'Microsoft.TeamFoundation.Library', 'Microsoft.TeamFoundation.VersionControl'


# All exceptions should be caught in calling function.
# Ensure that the ExecuteCommandLine function is declared by calling script.


# <summary>
#  Initialize the default log path for any TFS actions. 
# </summary>
function InitializeTfsModule([string] $root, [string] $tfsUri, [string] $script:assemblyPath, [string]:$mainScriptDir)
{
	[string] $script:BuildLocation = $root
	[string] $script:TfsUrl = $tfsUri
	[string] $script:LogPath = $(Join-Path -Path $root -ChildPath "tfs-task.log")
	
	LoadTfsAssemblies $script:assemblyPath
}


# <summary>
#  Load the TFS assemblies required for interfacing with TFS. If no assembly path is specified,
#  will attempt to load from GAC.  Checks that the assembly is not already loaded before attempting
#  to load.
# </summary>
# <param name="$assemblyPath" type="string">Path to assemblies.</param>
function LoadTfsAssemblies ([string] $assemblyPath)
{
	# Entry point for loading harmful assembly, but risk is small for internal tool.
	if(![string]::IsNullOrEmpty($assemblyPath))
	{
		$tfsDlls = gci "$assemblyPath\*.*" -include *.dll
		foreach($assembly in $tfsDlls)
		{
			if ($assembly.Name.Contains("Microsoft.TeamFoundation."))
			{
				#Start-Process "$assemblyPath\gacutil.exe" -ArgumentList "-i $dll" -NoNewWindow
				#Start-Sleep 1
				
				if(([AppDomain]::CurrentDomain.GetAssemblies() | Where {$_ -match $assembly.Name}) -eq $null)
				{
					WriteLog "Loading '$($assembly)'"
					# Use LoadFrom instead of LoadFile as it seems to work as expected.
					[void][Reflection.Assembly]::LoadFrom("$assembly")
				}
				else
				{
					WriteLog "'$($assembly)' is already loaded."
				}
			}
		}
	}
	else
	{		
		foreach ($assembly in $script:TfsAssemblies)
		{	
			if(([AppDomain]::CurrentDomain.GetAssemblies() | Where {$_ -match $assembly}) -eq $null)
			{
				# Powershell 2.0
				#	Add-Type -AssemblyName "Microsoft.TeamFoundation.Client, Version=11.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a, processorArchitecture=MSIL"
				
				#	[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.TeamFoundation.Build.Client')
				WriteLog "Loading '$($assembly)'"
				[void][Reflection.Assembly]::LoadWithPartialName("$assembly")
			}
			else
			{
				WriteLog "'$($assembly)' is already loaded."
			}
		}
	}
}



# <summary>
#  Initialize the credentials.
# </summary>
function InitializeCredentials([bool] $debug)
{
	if ($debug)
	{
#		$User = "Domain\UserName"
#		$PWord = ConvertTo-SecureString –String "<YourPassWord>" –AsPlainText -Force
#		$credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord
	}
	else
	{
		$credential = Get-Credential
	}
	
	return $credential
}


# <summary>
#  Run the given command with arguments and output standard out and error to log file.
# </summary>
# <param name="$command" type="string">The command to run.</param>
# <param name="$arguments" type="string">The arguments to run with the command.</param>
# <param name="$workingdir" type="bool">The path where the command is run from.</param>
# <param name="$logFile" type="string">The log file to write to.</param>
# <param name="$retries" type="int">Number of times to retry.  Empty to try once.  Zero to repeat indefinitely.</param>
function StartProcess()
{
	Param
	(
		[string] $command, [string] $arguments, [string] $workingDir, 
		[string] $logFile, [bool] $append = $false, [int] $retries = 1
	)
	
	WriteLog "Running command: $command $arguments"
    WriteLog "Working directory: $workingDir"
    if ($workingDir -and !(Test-Path -Path $workingDir) )
    {
        WriteErrLog "Working directory path not found: $workingDir" -ErrorAction stop
    }
	
    [int] $returnCode = 0;
	
	try
	{ 
		$pInfo = New-Object System.Diagnostics.ProcessStartInfo
		$pInfo.FileName = $command
		
		if ($workingDir) { $pInfo.WorkingDirectory = $workingDir }
		
		if ($logFile -ne "") { $sw = new-object System.IO.StreamWriter("$logFile", $append) }
		
		$pInfo.RedirectStandardError = $true
		$pInfo.RedirectStandardOutput = $true
		$pInfo.UseShellExecute = $false
		$pInfo.Arguments = $arguments
		$p = New-Object System.Diagnostics.Process
		$p.StartInfo = $pinfo
		
		[bool] $success = $false
		if ($retries -ge 0)
		{
			$tries = 0
			while ($tries -le $retries -and !$success)
		    {
				if ($retries -gt 0)
				{
		        	$tries++
				}
				try
				{
					$p = New-Object System.Diagnostics.Process
					$p.StartInfo = $pinfo
					$p.Start() | Out-Null
					$stdOut = $p.StandardOutput.ReadToEnd()
					$stdErr = $p.StandardError.ReadToEnd()
					$p.WaitForExit()
					
					if ($stdOut -or $stdErr -and ($logFile -ne "")) 
					{  
						if ($stdOut) 
						{ 
							WriteLog $stdOut
							$sw.WriteLine($stdOut)
						}
						if ($stdErr) 
						{
							WriteWarnLog $stdErr -ErrorAction Continue
							$sw.WriteLine($stdErr)
						}
					}
					
					while ($p.HasExited -eq $false)
				    {
				        WriteLog "Processing...."
				        Start-Sleep -Seconds 5
				    }
				    
				    WriteLog ("Process ExitCode=$procExitCode" + $p.ExitCode)
				    $returnCode = $p.ExitCode
					
				    if ($p.ExitCode -ne 0)
				    {
						if ($tries -lt $retries)
						{
				        	WriteWarnLog "Command returned an exit code of [$($p.ExitCode)]" -ErrorAction Continue
							WriteLog "Retrying ($tries of $retries) ..."
						}
						else
						{
							WriteErrLog "Command returned an exit code of [$($p.ExitCode)]" -ErrorAction Stop
						}
				    }
				}
				catch [Exception]
				{
					if ($_)
					{
						if ($_.Exception.Message) 
						{
							$msg = $_.Exception.Message
							WriteWarnLog "Win32Exception encountered:  $msg"
						}
						if ($_Exception.StackTrace) { WriteWarnLog $_.Exception.StackTrace }
					}
				}
				
				
				if ($returnCode -eq 0)
				{
					$success = $true
				}
				elseif ($tries -lt $retries)
				{
					$success = $true
				}
				else
				{ 
					Throw [Exception]
				}
			}
		}
		
	}
	catch [Exception]
	{
		if ($_)
		{
			if ($_.Exception.Message) 
			{
				$msg = $_.Exception.Message
				WriteWarnLog "Exception encountered:  $msg" 
			}
			if ($_Exception.StackTrace) { WriteWarnLog $_.Exception.StackTrace }
		}
		
		if ($returnCode -ne 0)
		{
			WriteErrLog "StartProcess():  Exception encountered."
		}
		else
		{
			WriteErrLog "StartProcess():  '$($command)' failed with [$($returnCode)]"
		}
	}
	finally
	{
		if ($sw) { $sw.Flush(); $sw.Close(); $sw.Dispose(); [System.GC]::Collect(); }
	}

    WriteLog "Done running command."
	
	return $p.ExitCode
}


# <summary>
#  Run the given command with arguments and output standard out and error to log file.
#  -Doesn't work consistently, but necessary for TF get without TFS SDK.
# </summary>
# <param name="$command" type="string">The command to run.</param>
# <param name="$workingDir" type="bool">The path where the command is run from.</param>
# <param name="$arguments" type="string">The arguments to run with the command.</param>
# <param name="$logFile" type="string">The log file to write to.</param>
# <param name="$retries" type="int">Number of times to retry.  Empty to try once.  Zero to repeat indefinitely.</param>
function ExecuteCommandLine([string]$command, [string] $workingDir, [string] $arguments, $credentials, [string] $logFile, [int] $retries = 1)
{
    WriteLog "Running command: $command $arguments"
    WriteLog "Working directory: $workingDir"
    if ($workingDir -and !(test-path -Path $workingDir))
    {
        WriteErrLog "Working directory path not found: $workingDir" -ErrorAction stop
    }
    $currentDir = Get-Location
    Set-Location $workingDir
   
	[bool] $success = $false
	if ($retries -ge 0)
	{
		$tries = 0
		while ($tries -le $retries -and !$success)
	    {
			if ($retries -gt 0)
			{
	        	$tries++
			}
			try
			{ 
				if ($credentials)
				{
			    	$process = Start-Process -FilePath $command -workingDirectory $workingDir `
						-ArgumentList $arguments -Credential $credentials `
						-RedirectStandardError $logFile -PassThru -Wait -NoNewWindow
				}
				else
				{
					$process = Start-Process -FilePath $command -workingDirectory $workingDir `
						-ArgumentList $arguments -RedirectStandardError $logFile -PassThru -Wait -NoNewWindow
				}
				
				$process.WaitForExit()
				
				while ($process.HasExited -eq $false)
			    {
			        WriteLog "Processing...."
			        Start-Sleep -Seconds 5
			    }
			    
				WriteLog ("Process ExitCode=$procExitCode" + $process.ExitCode)
			    
				if ($process.ExitCode -ne 0)
			    {
					if ($tries -lt $retries)
					{
			        	WriteWarnLog "Command returned an exit code of [$($process.ExitCode)]" -ErrorAction Continue
						WriteLog "Retrying ($tries of $retries) ..."
					}
					else
					{
						WriteErrLog "Command returned an exit code of [$($process.ExitCode)]`nHere is the error output:`n$(gc $logFile)`n`n" -ErrorAction Stop
					}
			    }
			}
			catch [System.ComponentModel.Win32Exception]
			{
				WriteWarnLog "Win32Exception encountered:  " + $_.Exception.Message. + "The process may have succeeded."
				WriteLog $_.Exception.StackTrace
			}
			catch
			{
				WriteLog "Exception caught:"
				WriteErrLog "$_" -ErrorAction Stop
			}
			
			$success = $true
		}
	}

    WriteLog "Done running command."
    Set-Location $currentDir
	
	return $process.ExitCode
}


#untested
# <summary>
#  Execute a command using TF.exe.
# </summary>
function ExecuteTfCommand($sourcePath, $arguments)
{
    ExecuteCommandLine -Command $TfExe -workingDir $sourcepath -arguments $arguments -logfile $LogPath
}


#untested
# <summary>
#  Sync to the latest file revisions using tf.exe.
# </summary>
function GetLatestTfsFiles([string] $sourcePath, [bool] $force)
{
	if (Test-Path -Path $sourcePath -PathType Container)
	{
		if (!$sourcePath.Contains("\*"))
		{
			$sourcePathAll = "$sourcePath\*"
		}
		else
		{
			$sourcePathAll = $sourcePath
		}
	}
	else
	{
		$sourcePathAll = $sourcePath
	}
	
	if ($force)
	{
    	ExecuteTfCommand -sourcePath "$TfsWorkingPath" -arguments "get /recursive /noprompt /force `"$sourcePathAll`""
	}
	else
	{
		ExecuteTfCommand -sourcePath "$TfsWorkingPath" -arguments "get /recursive /noprompt `"$sourcePathAll`""
	}
}


# <summary>
#  Apply a label to TFS using TF.exe.
# </summary>
function ApplyTfsLabel([string]$sourcePath, [string]$label, [string]$comment)
{
    ExecuteTfCommand -sourcePath $sourcePath -arguments "label  `"$label`" `"$sourcePath`" /comment:`"$comment`" /recursive"
}


# <summary>
#  Starts a build using TfsBuild.exe.  The process will continue until the build completes.
# </summary>
# <returns>Microsoft.TeamFoundation.Build.Client.IIQueuedBuild</returns>
function StartTfsBuild()
{	
	$arguments = "start $script:TfsUrlFlag$script:TfsUrl $BuildDefinitionFlag$BuildDefinition $DropLocationRootFlag$DropLocationRoot"
	ExecuteCommandLine -Command $TfsBuild -workingDir $TfsWorkingPath -arguments $arguments -logfile $LogPath
}


# <summary>
#  Queue a build.
# </summary>
# <param name="$DropLocationRoot" type="string">The root location to drop the build.</param>
# <param name="$teamProject" type="bool">The team project.</param>
# <param name="$buildDefinition" type="string">The build definition.</param>
# <returns>Microsoft.TeamFoundation.Build.Client.IIQueuedBuild</returns>
function QueueTfsBuild
{
	Param
	(
		[Parameter(Position=0)]
		[string] $dropLocationRoot = $script:DropLocationRoot,
		
		[Parameter(Position=1)]
		[string] $teamProject = $script:TeamProject,

		[Parameter(Position=2)]
		[string] $buildDefinition = $script:BuildDefinition
	)
	
	$projectCollection = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($script:TfsUrl)
    $buildServer = $projectCollection.GetService([Type]"Microsoft.TeamFoundation.Build.Client.IBuildServer")
	
	# For requesting from specific build agent.
#	$queryResult = $buildServer.QueryBuildAgents($buildServer.CreateBuildAgentSpec($TeamProject, buildAgentName));
#
#    if (queryResult.Failures.Length -gt 0 -or queryResult.Agents.Length -ne 1)
#    {
#      throw new Exception("Invalid Build Agent")
#    }
#    $buildAgent = $queryResult.Agents[0]
#	
	$buildDef = $buildServer.GetBuildDefinition($teamProject, $buildDefinition)
	$request = $buildDef.CreateBuildRequest()
	$request.RequestedFor = [Environment]::UserName + " - Daily Build"
	$request.Priority = "High"
	$request.DropLocation = $dropLocationRoot
	
    return $buildServer.QueueBuild($request);
	
	# TODO:  Test the returned object.
	#Build : BuildDetail instance 16839237
}


# <summary>
#   Query for the latest build and return build definition.
# </summary>
# <param name="$dropLocationRoot" type="string">The root location to drop the build.</param>
# <param name="$buildDefName" type="string">The build definition name.</param>
# <param name="$requestedBy" type="string">User that requested the build.</param>
# <param name="$buildStatus" type="String">Status of the build we are looking for. All, Succeeded, Failed, Queued.</param>
# <returns>Microsoft.TeamFoundation.Build.Client.IBuildQueryResult</returns>
function QueryTfsBuild
{
	Param
	(
		[Parameter(Position=0)]
		[string] $dropLocationRoot = $script:DropLocationRoot,
		
		[Parameter(Position=1)]
		[string] $buildDefName = $script:BuildDefinition,
		
		[Parameter(Position=2)]
		[string] $requestedBy = [Environment]::UserName,
		
		[Parameter(Position=3)]
		[string] $buildStatus = "All"
	)

	[Microsoft.TeamFoundation.Build.Client.BuildStatus] $buildStatus = DetermineBuildStatus $buildStatus
	
	# Note that in TFS2010 the Team Project Collection does not have to be noted in the TfsUrl.
	# TFS2012 requires the Team Project Collection: http:\\<Url>:<Port>\tfs\<TeamProjectCollection>
	$teamProjectCollection = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($script:TfsUrl)
	$teamProjectCollection.EnsureAuthenticated()
	$service = $teamProjectCollection.GetService([Type]"Microsoft.TeamFoundation.Build.Client.IBuildServer")
	$buildspec = $service.CreateBuildDetailSpec($script:TeamProject, $buildDefName)

	$buildspec.MaxBuildsPerDefinition = 1 # Only get latest  
	$buildspec.QueryOrder = [Microsoft.TeamFoundation.Build.Client.BuildQueryOrder]::FinishTimeDescending
	$buildspec.Status = $buildStatus
	$buildspec.RequestedFor = $requestedBy
	$buildspec.MaxFinishTime = [DateTime]::Now
	
	$results = $service.QueryBuilds($buildspec)
	
	# Calling method may be interested in DropLocation and BuildNumber properties.
	return $results
}



# <summary>
#   Query for the latest build.
# </summary>
# <param name="$dropLocationRoot" type="string">The root location to drop the build.</param>
# <param name="$buildDefName" type="string">The build definition name.</param>
# <param name="$requestedBy" type="string">User that requested the build.</param>
# <param name="$buildStatus" type="String">Status of the build we are looking for. All, Succeeded, Failed, Queued.</param>
# <returns>Microsoft.TeamFoundation.Build.Client.IBuildDetail</returns>
function QueryBuild
{
	Param
	(
		[Parameter(Position=0)]
		[string] $dropLocationRoot = $script:DropLocationRoot,
		
		[Parameter(Position=1)]
		[string] $buildDefName = $script:BuildDefinition,
		
		[Parameter(Position=2)]
		[string] $requestedBy = [Environment]::UserName,
		
		[Parameter(Position=3)]
		[string] $buildStatus = "NotStarted"
	)
	
	[Microsoft.TeamFoundation.Build.Client.BuildStatus] $buildStatus = DetermineBuildStatus $buildStatus

	#TODO:  Find a better indicator that is it he build that we queued/built.
	#$buildspec.RequestedFor = [Environment]::UserName + " - $buildDefinition"
	$results = QueryTfsBuild -buildDefName $buildDefName -buildStatus $buildStatus
	
	while($results.Builds.Length -eq 1)
	{
		#Look for any inprogress builds and sleep if found.
		WriteLog "Found one build 'NotStarted' matching criteria."
		WriteLog "Waiting 60 seconds..."
		Start-Sleep -Seconds 60
		$results = QueryTfsBuild -buildDefName $buildDefName -buildStatus $buildStatus
	}
	
	$buildStatus = [Microsoft.TeamFoundation.Build.Client.BuildStatus]::InProgress
	$results = QueryTfsBuild -buildDefName $buildDefName -buildStatus $buildStatus
	while($results.Builds.Length -eq 1)
	{
		#Look for any inprogress builds and sleep if found.
		WriteLog "Found one build 'InProgress' matching criteria."
		WriteLog "Waiting 60 seconds..."
		Start-Sleep -Seconds 60
		$results = QueryTfsBuild -buildDefName $buildDefName -buildStatus $buildStatus
	}
	
	$buildStatus = [Microsoft.TeamFoundation.Build.Client.BuildStatus]::Succeeded
	$results = QueryTfsBuild -buildDefName $buildDefName -buildStatus $buildStatus
	
	if (($results.Builds.Length -eq 1) -and ($results.Builds[0].DropLocationRoot -eq $dropLocationRoot)) 
	{
		return $results.Builds[0]
	}
	
	while($results.Builds.Length -eq 0)
	{
		#Look for any inprogress builds and sleep if found.
		WriteLog "Found one build 'SucessFul' matching criteria."
		WriteLog "Waiting 60 seconds..."
		Start-Sleep -Seconds 60
		$results = $results = QueryTfsBuild -buildDefName $buildDefName -buildStatus $buildStatus
	}
	
	# Calling method may be interested in DropLocation and BuildNumber properties.
	return $results.Builds[0]
}


# <summary>
#	Determine the Microsoft.TeamFoundation.Build.Client.BuildStatus with given string.
# </summary>
# <param name="$buildStatus" type="string">status</param>
# <returns>Microsoft.TeamFoundation.Build.Client.BuildStatus</returns>
function DetermineBuildStatus([string] $buildStatus)
{
	switch ($buildStatus) 
    { 
        "ALL" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::ALL } 
        "Failed" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::Failed } 
        "InProgress" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::InProgress } 
        "None" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::None } 
        "NotStarted" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::NotStarted } 
        "PartiallySucceeded" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::PartiallySucceeded } 
        "Stopped" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::Stopped } 
        "Succeeded" {return [Microsoft.TeamFoundation.Build.Client.BuildStatus]::Succeeded }
		
		default {throw "$($status) is not a valid [Microsoft.TeamFoundation.Build.Client.BuildStatus]"}
    }

}


# <summary>
#   Get the build drop location.  Dependent on the DropLocationRoot variable.
# </summary>
# <returns>string - Build drop location when the dropRoot is specified.</returns>
function GetDropFolder()
{
	$di = dir $DropLocationRoot | where {$_.PsIsContainer} | Select-Object Name
	$script:BuildLocation = "$DropLocationRoot\" + $di[0].Name
	return $BuildLocation
}


function Find-ChildProcess 
{
	param
	(
		$ID=$PID,
		[string] $childProcessName
	)

	$CustomColumnID = @{
		Name = 'Id'
		Expression = { [Int[]]$_.ProcessID }
	}

		$result = Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$ID" |
		Select-Object -Property ProcessName, $CustomColumnID, CommandLine

		$result
		$result | Where-Object { ($_.ID -ne $null) -and ($_.ProcessName -eq $childProcessName) } | ForEach-Object {
		Find-ChildProcess -id $_.Id
	}
	
	return $result;
}
