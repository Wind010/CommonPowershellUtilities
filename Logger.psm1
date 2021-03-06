#-------------------------------------------------------------------------------------------------
# <Copyright file="Logger.psm1">
#     Copyright (c) Jeff Tong.  All rights reserved.
# </Copyright>
#
# <Authors>
#	<Author Name="Jeff Jin Hung Tong">
# </Authors>
#
# <Description>
#     General logger script.
# </Description>
#
# <Remarks />
#
# <Disclaimer />
#-------------------------------------------------------------------------------------------------

[string] $script:LogPath;
[string] $script:Verbosity = "Diagnostic";
[bool] $script:WriteToConsole = $true;


# <summary>
#  Write to the Log.  InitializeLog function must be called at least once.
#  a new file log file will be created each time.
# </summary>
# <param name="$verbosity" type="string">The message to write to log.</param>
# <param name="$writeToConsole" type="bool">The indication to write to console/host.</param>
# <param name="$logPath" type="string">Full path to write log to.</param>
function InitializeLog()
{
	Param
	(
		[Parameter(Position=0)] [ValidateSet("Normal", "Detailed", "Diagnostic")]
		[string] $verbosity = $Verbosity,
		
		[Parameter(Position=1)]
		[bool] $writeToConsole = $true,

		[Parameter(Position=2)]
		[IO.FileInfo] $logPath="$env:temp\Logger.log"
	)
	
	# Must use the scope variable otherwise local scope is infered.
	[string] $logDir = [System.IO.Path]::GetDirectoryName($logPath);
	if (!(Test-Path $logDir))
	{
		if ($logPath.ToString().Contains("."))
		{
			New-Item -Path $logDir -ItemType Directory
		}
	}
	
	$script:LogPath = $logPath;
	$script:Verbosity = $verbosity;
	$script:WriteToConsole = $writeToConsole;
}


# <summary>
#  Write to the Log.  InitializeLog function must be called at least once.
#  a new file log file will be created each time.
# </summary>
# <param name="$message" type="string">The message to write to log.</param>
function WriteLog
{
	[cmdletbinding()]
	Param
	(
		[Parameter(Position=0)] [ValidateNotNullOrEmpty()]
		[string] $message
	)
	
	try 
	{
		#Write-Debug $LogPath;
		if (!$LogPath)
		{
			[IO.FileInfo] $LogPath="$env:temp\Logger.log";
			[string] $wrnMsg = "Log was not initialized.  Log outputted to " + $LogPath;
			WriteLog $wrnMsg;
			Write-Host $wrnMsg;
		}
	
		try
		{
			#$sw = [System.IO.StreamWriter] $LogPath.ToString() 
			$sw = New-Object System.IO.StreamWriter("$LogPath", $true)
			#$msg = "{0} :{1}: $msg" -f (Get-Date -Format "yyyy-MM-dd_HH:mm:ss"), $Verbosity.ToUpper();
			#$msg = "{0}: $msg" -f (Get-Date -Format "yyyy-MM-dd_HH:mm:ss")
			
			$msg = (Get-Date -Format "yyyy-MM-dd_HH:mm:ss") + ":  " + $message 
			
			if ($writeToConsole -and !$msg.StartsWith("ERROR:") -and !$msg.StartsWith("WARNING:"))
			{ Write-Host $message }
					
			$sw.WriteLine($msg)
		}
		finally
		{
			$sw.Flush()
			$sw.Close()
			$sw.Dispose()
			[System.GC]::Collect();
		}
		
		
		#$msg | Out-File -FilePath $LogPath -Append
	} 
	catch 
	{
		[string] $m = "Failed to create log entry in: ‘$LogPath’. The error was: ‘$_’.";
		Write-Host $message
		Write-Host $m;
		throw $m;
	}
}


# <summary>
#  Write to the Log.  InitializeLog function must be called at least once.
#  a new file log file will be created each time.
# </summary>
# <param name="$message" type="string">The message to write to log.</param>
# <param name="$verbosity" type="string">Will only write to log if verbosity is more or 
#	equal to the verbosity set upon initalization.
# </param>
function WriteLogV
{
	Param
	(
		[Parameter(Position=0)] [ValidateNotNullOrEmpty()]
		[string] $message,
		
		[Parameter(Position=1)] [ValidateSet("Normal", "Detailed", "Diagnostic")]
		[string] $verbosity
	)
	
	#TODO:  Refactor using enumeration.
	switch ($Verbosity) 
	{
		"Normal" { if ($verbosity -ieq $Verbosity) {WriteLog $message} }
		"Detailed" { if (($verbosity -ieq $Verbosity) -or ($verbosity -ieq "Normal")) {WriteLog $message} }
		"Diagnostic" { WriteLog $message } 
	}
}


# <summary>
#  Write error to the Log.  InitializeLog function must be called at least once.
#  a new file log file will be created each time.
# </summary>
# <param name="$message" type="string">The message to write to log.</param>
# <param name="$ErrorAction" type="Same as the Write-Error ErrorAction</param>
function WriteErrLog([string] $msg
, [System.Management.Automation.ActionPreference] $ErrorAction= [System.Management.Automation.ActionPreference]::Stop)
{
	[string] $newMsg = "ERROR: " + $msg;
	WriteLog $newMsg
	Write-Error $msg -ErrorAction $ErrorAction
}


# <summary>
#  Write warning to log.  InitializeLog function must be called at least once.
#  a new file log file will be created each time.
# </summary>
# <param name="$message" type="string">The message to write to log.</param>
# <param name="$ErrorAction" type="Same as the Write-Warning ErrorAction</param>
function WriteWarnLog([string] $msg
, [System.Management.Automation.ActionPreference] $ErrorAction= [System.Management.Automation.ActionPreference]::Continue)
{
	[string] $newMsg = "WARNING: " + $msg
	WriteLog $newMsg
	Write-Warning $msg -ErrorAction $ErrorAction
}
