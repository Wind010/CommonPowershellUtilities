#-------------------------------------------------------------------------------------------------
# <Copyright file="Utilities.psm1">
#     Copyright (c) Jeff Tong.  All rights reserved.
# </Copyright>
#
# <Authors>
#	<Author Name="Jeff Jin Hung Tong">
# </Authors>
#
# <Parameters>
#	
# </Parameters>
#
# <Description>
#     Commonly used methods.
# </Description>
#
# <Remarks />
#
# <Disclaimer />
#-------------------------------------------------------------------------------------------------


function Intialize()
{
	
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

