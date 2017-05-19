$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSReplicationGroup'

#region HEADER
# Unit Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xDFS'
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit
#endregion HEADER

# Begin Testing
try
{
    # Ensure that the tests can be performed on this computer
    $productType = (Get-CimInstance Win32_OperatingSystem).ProductType
    Describe 'Environment' {
        Context 'Operating System' {
            It 'should be a Server OS' {
                $productType | Should Be 3
            }
        }
    }

    if ($productType -ne 3)
    {
        break
    }

    $featureInstalled = (Get-WindowsFeature -Name FS-DFS-Replication).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'should have the DFS Replication Feature Installed' {
                $featureInstalled | Should Be $true
            }
        }
    }

    if ($featureInstalled -eq $false)
    {
        break
    }

    $featureInstalled = (Get-WindowsFeature -Name RSAT-DFS-Mgmt-Con).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'should have the DFS Management Tools Feature Installed' {
                $featureInstalled | Should Be $true
            }
        }
    }
    if ($featureInstalled -eq $false)
    {
        break
    }

    #region Pester Tests
    InModuleScope $script:DSCResourceName {

        # Create the Mock Objects that will be used for running tests
        $replicationGroup = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }

        $replicationGroupAllFQDN = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1.CONTOSO.COM','FileServer2.CONTOSO.COM')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }

        $replicationGroupSomeDns = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1.CONTOSO.COM','FileServer2')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }

        $replicationGroupConnections = @(
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $replicationGroup.Members[0]
                DestinationComputerName = $replicationGroup.Members[1]
                Ensure = 'Present'
                Description = 'Connection Description'
                EnsureEnabled = 'Enabled'
                EnsureRDCEnabled = 'Enabled'
                DomainName = 'CONTOSO.COM'
            },
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $replicationGroup.Members[1]
                DestinationComputerName = $replicationGroup.Members[0]
                Ensure = 'Present'
                Description = 'Connection Description'
                EnsureEnabled = 'Enabled'
                EnsureRDCEnabled = 'Enabled'
                DomainName = 'CONTOSO.COM'
            }
        )

        $replicationGroupConnectionDisabled = $replicationGroupConnections[0].Clone()
        $replicationGroupConnectionDisabled.EnsureEnabled = 'Disabled'

        $mockReplicationGroup = [PSObject]@{
            GroupName = $replicationGroup.GroupName
            DomainName = $replicationGroup.DomainName
            Description = $replicationGroup.Description
        }

        $mockReplicationGroupMember = @(
            [PSObject]@{
                GroupName = $replicationGroup.GroupName
                DomainName = $replicationGroup.DomainName
                ComputerName = $replicationGroup.Members[0]
                DnsName = "$($replicationGroup.Members[0]).$($replicationGroup.DomainName)"
            },
            [PSObject]@{
                GroupName = $replicationGroup.GroupName
                DomainName = $replicationGroup.DomainName
                ComputerName = $replicationGroup.Members[1]
                DnsName = "$($replicationGroup.Members[1]).$($replicationGroup.DomainName)"
            }
        )

        $mockReplicationGroupFolder = @(
            [PSObject]@{
                GroupName = $replicationGroup.GroupName
                DomainName = $replicationGroup.DomainName
                FolderName = $replicationGroup.Folders[0]
                Description = 'Description 1'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
            },
            [PSObject]@{
                GroupName = $replicationGroup.GroupName
                DomainName = $replicationGroup.DomainName
                FolderName = $replicationGroup.Folders[1]
                Description = 'Description 2'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
            }
        )

        $mockReplicationGroupMembership = [PSObject]@{
            GroupName = $replicationGroup.GroupName
            DomainName = $replicationGroup.DomainName
            FolderName = $replicationGroup.Folders[0]
            ComputerName = $replicationGroup.Members[0]
            ContentPath = 'd:\public\software\'
            StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
            ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
            ReadOnly = $False
            PrimaryMember = $True
        }

        $mockReplicationGroupMembershipNotPrimary = $mockReplicationGroupMembership.Clone()
        $mockReplicationGroupMembershipNotPrimary.PrimaryMember = $False

        $mockReplicationGroupConnections = @(
            [PSObject]@{
                GroupName = $replicationGroupConnections[0].GroupName
                SourceComputerName = $replicationGroupConnections[0].SourceComputerName
                DestinationComputerName = $replicationGroupConnections[0].DestinationComputerName
                Description = $replicationGroupConnections[0].Description
                Enabled = ($replicationGroupConnections[0].EnsureEnabled -eq 'Enabled')
                RDCEnabled = ($replicationGroupConnections[0].EnsureRDCEnabled -eq 'Enabled')
                DomainName = $replicationGroupConnections[0].DomainName
            },
            [PSObject]@{
                GroupName = $replicationGroupConnections[1].GroupName
                SourceComputerName = $replicationGroupConnections[1].SourceComputerName
                DestinationComputerName = $replicationGroupConnections[1].DestinationComputerName
                Description = $replicationGroupConnections[1].Description
                Enabled = ($replicationGroupConnections[1].EnsureEnabled -eq 'Enabled')
                RDCEnabled = ($replicationGroupConnections[1].EnsureRDCEnabled -eq 'Enabled')
                DomainName = $replicationGroupConnections[1].DomainName
            }
        )

        $mockReplicationGroupConnectionDisabled = [PSObject]@{
            GroupName = $replicationGroupConnections[0].GroupName
            SourceComputerName = $replicationGroupConnections[0].SourceComputerName
            DestinationComputerName = $replicationGroupConnections[0].DestinationComputerName
            Description = $replicationGroupConnections[0].Description
            Enabled = $False
            RDCEnabled = ($replicationGroupConnections[0].EnsureRDCEnabled -eq 'Enabled')
            DomainName = $replicationGroupConnections[0].DomainName
        }

        $replicationGroupContentPath = $replicationGroup.Clone()
        $replicationGroupContentPath += @{ ContentPaths = @($mockReplicationGroupMembership.ContentPath) }

        Describe "MSFT_xDFSReplicationGroup\Get-TargetResource" {
            Context 'No replication groups exist' {
                Mock Get-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Get-DfsReplicatedFolder

                It 'should return absent replication group' {
                    $result = Get-TargetResource `
                        -GroupName $replicationGroup.GroupName `
                        -Ensure Present
                    $result.Ensure | Should Be 'Absent'
                }

                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Requested replication group does exist' {
                Mock Get-DfsReplicationGroup -MockWith { return @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $replicationGroup.GroupName `
                        -Ensure Present
                    $result.Ensure | Should Be 'Present'
                    $result.GroupName | Should Be $replicationGroup.GroupName
                    $result.Description | Should Be $replicationGroup.Description
                    $result.DomainName | Should Be $replicationGroup.DomainName
                    <#
                        Tests disabled until this issue is resolved:
                        https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    #>
                    if ($false) {
                        $result.Members | Should Be $replicationGroup.Members
                        $result.Folders | Should Be $replicationGroup.Folders
                    }
                }

                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                    <#
                        Tests disabled until this issue is resolved:
                        https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    #>
                    if ($false) {
                        Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                        Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    }
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroup\Set-TargetResource" {
            Context 'Replication Group does not exist but should' {
                Mock Get-DfsReplicationGroup
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 2
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 2
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has different description' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Description = 'Changed'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but all Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroupAllFQDN.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but some Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroupSomeDns.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but is missing a member' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Members = @('FileServer2','FileServer1','FileServerNew')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has an extra member' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Members = @('FileServer2')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but is missing a folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Folders = @('Folder2','Folder1','FolderNew')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has an extra folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Folders = @('Folder2')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but should not' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists and is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[0]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and has one missing connection' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and has all connections missing' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and has a disabled connection' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { return $mockReplicationGroupConnectionDisabled } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $replicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set but needs to be changed' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($mockReplicationGroupMembership) }
                Mock Set-DfsrMembership

                It 'should not throw error' {
                    {
                        $splat = $replicationGroupContentPath.Clone()
                        $splat.ContentPaths = @('Different')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set and does not need to be changed' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($mockReplicationGroupMembership) }
                Mock Set-DfsrMembership

                It 'should not throw error' {
                    {
                        $splat = $replicationGroupContentPath.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 0
                }
            }

            Context 'Replication Group Content Path is set and does not need to be changed but primarymember does' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($mockReplicationGroupMembershipNotPrimary) }
                Mock Set-DfsrMembership

                It 'should not throw error' {
                    {
                        $splat = $replicationGroupContentPath.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroup\Test-TargetResource" {
            Context 'Replication Group does not exist but should' {
                Mock Get-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Get-DfsReplicatedFolder

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has different description' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Description = 'Changed'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but all Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroupAllFQDN.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but some Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroupSomeDns.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but is missing a member' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Members = @('FileServer2','FileServer1','FileServerNew')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but has an extra member' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Members = @('FileServer2')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but is missing a folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Folders = @('Folder2','Folder1','FolderNew')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but has an extra folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Folders = @('Folder2')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but should not' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists and is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }

                It 'should return true' {
                    $splat = $replicationGroup.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group Fullmesh Topology is required and correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[0]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }

                It 'should return true' {
                    $splat = $replicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Fullmesh Topology is required and one connection missing' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[0]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter { `
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Fullmesh Topology is required and all connections missing' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }

                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Fullmesh Topology is required and connection is disabled' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { return $mockReplicationGroupConnectionDisabled } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($mockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($replicationGroupConnections[1].SourceComputerName).$($replicationGroupConnections[1].DomainName)"
                    }

                It 'should return false' {
                    $splat = $replicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Content Path is set and different' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($mockReplicationGroupMembership) }

                It 'should return false' {
                    $splat = $replicationGroupContentPath.Clone()
                    $splat.ContentPaths = @('Different')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set and the same and PrimaryMember is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($mockReplicationGroupMembership) }

                It 'should return true' {
                    $splat = $replicationGroupContentPath.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set and the same and PrimaryMember is not correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($mockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $mockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $mockReplicationGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($mockReplicationGroupMembershipNotPrimary) }

                It 'should return false' {
                    $splat = $replicationGroupContentPath.Clone()
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroup\Get-FQDNMemberName" {
            Context 'ComputerName passed includes Domain Name that matches DomainName' {
                It 'should return correct FQDN' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test.contoso.com'
                        DomainName = 'CONTOSO.COM'
                    }

                    Get-FQDNMemberName @splat | Should Be 'test.contoso.com'
                }
            }

            Context 'ComputerName passed includes Domain Name that does not match DomainName' {
                It 'should throw ReplicationGroupDomainMismatchError exception' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test.contoso.com'
                        DomainName = 'NOTMATCH.COM'
                    }

                    $errorRecord = Get-InvalidOperationRecord `
                        -Message ($($LocalizedData.ReplicationGroupDomainMismatchError `
                        -f $splat.GroupName,$splat.ComputerName,$splat.DomainName))

                    { Get-FQDNMemberName @splat } | Should Throw $errorRecord
                }
            }

            Context 'ComputerName passed does not include Domain Name and DomainName was passed' {
                It 'should return correct FQDN' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test'
                        DomainName = 'CONTOSO.COM'
                    }

                    Get-FQDNMemberName @splat | Should Be 'test.contoso.com'
                }
            }

            Context 'ComputerName passed does not include Domain Name and DomainName was not passed' {
                It 'should return correct FQDN' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test'
                    }

                    Get-FQDNMemberName @splat | Should Be 'test'
                }
            }
        }
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
