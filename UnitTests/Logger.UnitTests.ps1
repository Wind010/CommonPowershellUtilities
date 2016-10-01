#-------------------------------------------------------------------------------------------------
# <Copyright file="Logger.UnitTests.psm1">
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
#     Unit tests for Logging functions declared in Logger.psm1.
# </Description>
#
# <Remarks />
#
# <Disclaimer />
#-------------------------------------------------------------------------------------------------

# <summary>
#  Get the current directory the script is executing from.
# </summary>
function Get-ScriptDirectory
{
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value;
	$commandPath = Get-ChildItem $Invocation.ScriptName
	return $commandPath.DirectoryName
}

# <summary>
#  Calls WriteLog.
# </summary>
function WriteLog_Pass
{
	WriteLog "WriteLog():  Test - Clita vivendum et sed, mei exerci assueverit an, porro everti propriae ea mel."
}

# <summary>
#  Calls WriteWarnLog.
# </summary>
function WriteWarnLog_Pass
{
	WriteWarnLog "WriteWarnLog():  Test - Clita vivendum et sed, mei exerci assueverit an, porro everti propriae ea mel."
}

# <summary>
#  Calls WriteErrLog_Pass.
# </summary>
function WriteErrLog_Pass
{
	WriteErrLog "WriteErrLog():  Test - Clita vivendum et sed, mei exerci assueverit an, porro everti propriae ea mel." `
	-ErrorAction Continue
}


function Main
{
	cls
	$currentDir = Get-ScriptDirectory
	$currentDir = (Get-Item $currentDir).Parent.FullName;
    
	Import-Module "$currentDir\Logger.psm1" #-verbose
	InitializeLog "Diagnostic" $true "$currentDir\Logger.UnitTest.log"
	
	[bool] $success = $false
	WriteLog_Pass
	WriteWarnLog_Pass
	WriteErrLog_Pass
	
	Write-Host "Done running UnitTests for Logger.psm1."
}

Main