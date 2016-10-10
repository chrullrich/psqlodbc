$LIBPQ_VERSION="9.5"
$configurationXmlPath=""
$configurationTemplatePath=""

function InitConfiguration($savePath)
{
	$configInfo = [xml](Get-Content $configurationTemplatePath)
	if ($env:PROCESSOR_ARCHITECTURE -eq "x86")
	{
		$x64info = $configInfo.Configuration.x64
		$x64info.libpq.include = ""
		$x64info.libpq.lib = ""
		$x64info.libpq.bin = ""
	}
	$configInfo.save($savePath)

	return $configInfo
}

function GetConfiguration($loadPath)
{
	$configInfo =  [xml] (Get-Content $loadPath)
	set-variable -name xmlFormatVersion -value "0.4" -option constant
	if ($configInfo.Configuration.formatVersion -ne $xmlFormatVersion)
	{
		$xmlDoc2 = [xml](Get-Content $configurationTemplatePath)
        	$root2 = $XmlDoc2.get_DocumentElement()
        	$root1 = $configInfo.get_DocumentElement()
        	unifyNodes $root1 $root2

		$root1.formatVersion = $xmlFormatVersion
		$configInfo.save($loadPath)
	}

	return $configInfo
}

function LoadConfiguration($configPath, $configDir)
{
	Write-Debug "configPath=$configPath"
	set-variable -name configurationTemplatePath -scope 1 -value "$configDir\configuration_template.xml"
	if ("$configPath" -eq "") {
		$configPath = "$configDir\configuration.xml"
	}
	set-variable -name configurationXmlPath -scope 1 -value $configPath
	if (!(Test-Path -path $configPath))
	{
		return InitConFiguration $configPath
	}
	else
	{
		return GetConfiguration $configPath
	}
}

function SaveConfiguration($configInfo, $savePath)
{
	if ("$savePath" -eq "") {
		$savePath = $configurationXmlPath
	}
	$configInfo.save($savePath)
}

function unifyNodes($node1, $node2)
{
    $attributes2 = $node2.get_Attributes()
    if ($attributes2.Count -gt 0)
    {
        $attributes1 = $node1.get_Attributes()
        foreach ($attrib in $attributes2)
        {
            $attribname = $attrib.name
            if (($attributes1.Count -eq 0) -or ($attributes1.GetNamedItem($attribname) -eq $null))
            {
                Write-Debug " Adding attribute=$attribname"
                $addattr = $node1.OwnerDocument.ImportNode($attrib, $true)
                $added = $attributes1.Append($addattr)
            }
        }
    }
    if (!$node2.get_HasChildNodes()) {
        return;
    }
    foreach ($child2 in $node2.get_ChildNodes())
    {
        $nodename = $child2.get_Name()
        if ($nodename -eq "#text"){
            continue
        }
        $matchnode = $node1.SelectSingleNode($nodename)
        if ($matchnode -eq $null)
        {
                Write-Debug "Adding node=$nodename"
                $addnode = $node1.OwnerDocument.ImportNode($child2, $true)
                $added = $node1.AppendChild($addnode)
                continue
        }
        unifyNodes $matchnode $child2
    }
}

function getPGDir($configInfo, $Platform, $kind)
{
	if ($Platform -ieq "x64") {
		$platinfo=$configInfo.Configuration.x64
	} else {
		$platinfo=$configInfo.Configuration.x86
	}
	$LIBPQVER=$platinfo.libpq.version
	if ("$LIBPQVER" -eq "") {
		$LIBPQVER = $LIBPQ_VERSION
	}
	if ($kind -eq "include") {
		$result=$platinfo.libpq.include
	} elseif ($kind -eq "lib") {
		$result=$platinfo.libpq.lib
	} else {
		$result=$platinfo.libpq.bin
	}
	if ($result -ne "default") {
		return $result
	}
	if ($Platform -ieq "x64") {
		if ($env:PROCESSOR_ARCHITECTURE -eq "x86") {
			$pgmfs = $env:ProgramW6432
		} else {
			$pgmfs = $env:ProgramFiles
		}
	} else {
		if ($env:PROCESSOR_ARCHITECTURE -eq "x86") {
			$pgmfs = $env:ProgramFiles
		} else {
			$pgmfs = ${env:ProgramFiles(x86)}
		}
	}
	if ("$pgmfs" -eq "") {
		$result = $null
	} else {
		$result = "$pgmfs\PostgreSQL\$LIBPQVER\$kind"
	}
	return $result
}

Export-ModuleMember -function LoadConfiguration, SaveConfiguration, unifyNodes, getPGDir -variable LIBPQ_VERSION