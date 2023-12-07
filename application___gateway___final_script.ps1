#Creation of the ResourceGroup and Vnet and subnets
$rgname = 'myrg-02'
$loc = 'eastus2'

#create the ResourceGroup
New-AzResourceGroup -name $rgname -Location $loc > $null

#Create a Vnet with 2 subnets
New-AzVirtualNetwork -name 'myvnet01' -location $loc -ResourceGroupName $rgname `
                      -AddressPrefix 10.1.0.0/16 `
                      -Subnet $(New-AzVirtualNetworkSubnetConfig -name 'subnet01' -AddressPrefix 10.1.1.0/24), `
                      $(New-AzVirtualNetworkSubnetConfig -name 'subnet02' -AddressPrefix 10.1.2.0/24)  > $null

#take this vnet,subnet1,subnet2 values into a variables (psobjects)
$vnet = Get-AzVirtualNetwork -name 'myvnet01' -ResourceGroupName $rgname
$sub1 = Get-AzVirtualNetworkSubnetConfig -name 'subnet01' -VirtualNetwork $vnet  #loadbalancer
$sub2 = Get-AzVirtualNetworkSubnetConfig -name 'subnet02' -VirtualNetwork $vnet  # vm's

#Step-01 : Front port , Frontip (Publicip)
#Creation of the Public ip
$mypip = New-AzPublicIpAddress -Name 'mypip' -ResourceGroupName $rgname -Location $loc `
                      -Sku Standard -AllocationMethod Static
$frontip = New-AzApplicationGatewayFrontendIPConfig -name 'frontdoor' -PublicIPAddress $mypip

$frontport = New-AzApplicationGatewayFrontendPort -Name 'frontendport1'-Port 80 

#step-02
#sku
$s = New-AzApplicationGatewaySku -Name Standard_v2 -Tier Standard_v2 -Capacity 2

#Listner
$lis = New-AzApplicationGatewayHttpListener -name 'ear01' -FrontendIPConfiguration $frontip `
                                     -FrontendPort $frontport -Protocol Http


#Routing rule (bakcenpool)

#Step-03
$pool = New-AzApplicationGatewayBackendAddressPool -name 'pool-a' 
#backend connection
$PoolSetting = New-AzApplicationGatewayBackendHttpSetting -Name 'mysetting' -Port 80 -Protocol "http" -CookieBasedAffinity Disabled 


#Loadbalancer ipconfiguration
$Gatewayipconfig = New-AzApplicationGatewayIPConfiguration -Name 'mygatewayip' -Subnet $sub1 
#rule
$rule  =New-AzApplicationGatewayRequestRoutingRule  -Name 'myrule01' -RuleType Basic `
            -Priority 200 -BackendHttpSettings $PoolSetting -HttpListener $lis `
            -BackendAddressPool $pool 



                                        
                                        
                                                   
#Creation of Loadbalancer
New-AzApplicationGateway -Name 'myappgw' -ResourceGroupName $rgname -location $loc `
                -FrontendIPConfigurations $frontip `
                -Sku $s `
                -FrontendPorts $frontport `
                -BackendAddressPools $pool `
                -HttpListeners $lis `
                -BackendHttpSettingsCollection $PoolSetting `
                -RequestRoutingRules $rule `
                -GatewayIPConfigurations $Gatewayipconfig 
#VM
$cr = Get-Credential 
for($i = 1; $i -lt 4; $i++)
{
$mynic = New-AzNetworkInterface -name MyNIC$i -ResourceGroupName $rgname -Location $loc -ApplicationGatewayBackendAddressPool $Pool -Subnet $sub2
$vm = New-AzVMConfig -VMName VM-00$i -VMSize Standard_DS1_v2 

            Set-AzVMSourceImage -VM $vm -PublisherName MicrosoftWindowsServer -Offer windowsserver -Skus 2016-Datacenter -Version latest

            Set-AzVMOperatingSystem -vm $vm -Windows -ComputerName VM-00$i -Credential $cr 

            Add-AzVMNetworkInterface -vm $vm -NetworkInterface $mynic

            Set-AzVMBootDiagnostic -VM $vm -Disable 


#creation
new-azvm -ResourceGroupName $rgname -Location $loc -vm $vm 

#Creation of VirtualMachine with reference of $vm variablle




#updation of the iis webserver html webpage
Set-AzVMExtension -ResourceGroupName $rgname `
                  -Location $loc `
                   -Publisher Microsoft.compute `
                   -VMName VM-00$i `
                   -ExtensionName IIS `
                   -ExtensionType CustomScriptExtension `
                   -TypeHandlerVersion "1.4"  `
                   -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
}
