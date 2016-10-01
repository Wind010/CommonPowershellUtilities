#-------------------------------------------------------------------------------------------------
# <Copyright file="TFS.UnitTests.psm1">
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
#     Unit tests for TFS specific functions declared in Tfs.psm1.
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

function QueueTfsBuild_Pass
{
	$result = QueueTfsBuild
	if ($result) {return $true;} else {return false;}
}

function QueryBuild_Pass
{
	$result = QueryBuild
	if ($result) {return $true;} else {return false;}
}


function Main
{
  cls
	$currentDir = Get-ScriptDirectory
	$currentDir = (Get-Item $currentDir).Parent.FullName;
	Import-Module "$currentDir\Logger.psm1" #-verbose
	InitializeLog "Diagnostic" $true "$currentDir\TFS.UnitTest.log"
  Import-Module "$currentDir\Tfs.psm1"
	
	[bool] $success = $false
	$success = QueueTfsBuild_Pass
	
	if ($success)
	{	
		$success = QueryBuild_Pass
	}
}

Main