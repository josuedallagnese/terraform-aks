# -- Gateway
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-${local.sufix_gateway_name}"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  sku                 = "Developer"
  virtual_network_id  = azurerm_virtual_network.vnet_gateway.id
  tags                = local.tags
}

# -- Build Server
resource "azurerm_network_interface" "nic_build" {
  name                = "nic-build-${local.sufix_gateway_name}"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "build" {
  name                            = "vm-build-${local.sufix_gateway_name}"
  location                        = azurerm_resource_group.gateway.location
  resource_group_name             = azurerm_resource_group.gateway.name
  size                            = var.gateway.build_server.size
  admin_username                  = "build"
  computer_name                   = "build"
  disable_password_authentication = true

  tags = local.tags

  network_interface_ids = [
    azurerm_network_interface.nic_build.id,
  ]

  os_disk {
    caching              = var.gateway.build_server.os_disk_caching
    storage_account_type = var.gateway.build_server.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = var.gateway.build_server.image_publisher
    offer     = var.gateway.build_server.image_offer
    sku       = var.gateway.build_server.image_sku
    version   = var.gateway.build_server.image_version
  }

  admin_ssh_key {
    username   = "build"
    public_key = data.azurerm_key_vault_secret.build_pub_key.value
  }
}

resource "azurerm_virtual_machine_extension" "vm_init" {
  name                 = "vm-build-init"
  virtual_machine_id   = azurerm_linux_virtual_machine.build.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = jsonencode({
    fileUris = [
      "https://${data.azurerm_storage_account.shared.name}.blob.core.windows.net/tools-${local.env}/vm-build-init.sh${data.azurerm_storage_account_sas.tools_sas.sas}",
      "https://${data.azurerm_storage_account.shared.name}.blob.core.windows.net/tools-${local.env}/psql-connect.sh${data.azurerm_storage_account_sas.tools_sas.sas}",
      "https://${data.azurerm_storage_account.shared.name}.blob.core.windows.net/tools-${local.env}/psql-backup.sh${data.azurerm_storage_account_sas.tools_sas.sas}",
      "https://${data.azurerm_storage_account.shared.name}.blob.core.windows.net/tools-${local.env}/psql-restore.sh${data.azurerm_storage_account_sas.tools_sas.sas}"
    ]
  })

  protected_settings = jsonencode({
    commandToExecute = <<EOC
bash -c '
  set -e

  echo "Executando script principal"
  chmod +x vm-build-init.sh
  ./vm-build-init.sh

  echo "Copiando scripts para /home/build/tools"
  mkdir -p /home/build/tools
  cp psql-*.sh /home/build/tools/
  chmod +x /home/build/tools/*.sh
  chown -R build:build /home/build/tools
  chmod -R 755 /home/build/tools

  echo "Gravando kubeconfig do AKS"
  mkdir -p /home/build/.kube
  cat > /home/build/.kube/config <<'EOF'
${replace(azurerm_kubernetes_cluster.aks.kube_config_raw, "$", "\\$")}
EOF

  chown -R build:build /home/build/.kube
  chmod 600 /home/build/.kube/config
'
EOC
  })

  lifecycle {
    ignore_changes = [
      settings
    ]
  }
}

resource "azurerm_network_interface_security_group_association" "nic_build_association" {
  network_interface_id      = azurerm_network_interface.nic_build.id
  network_security_group_id = azurerm_network_security_group.nsg_gateway.id
}

# -- Developer Server
resource "azurerm_network_interface" "nic_dev" {
  count               = var.gateway.dev_server.enabled ? 1 : 0
  
  name                = "nic-dev-${local.sufix_gateway_name}"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "dev" {
  count                           = var.gateway.dev_server.enabled ? 1 : 0
  
  name                            = "vm-dev-${local.sufix_gateway_name}"
  location                        = azurerm_resource_group.gateway.location
  resource_group_name             = azurerm_resource_group.gateway.name
  size                            = var.gateway.dev_server.size
  admin_username                  = "dev"
  computer_name                   = "dev"
  admin_password                  = data.azurerm_key_vault_secret.dev_admin_password.value

  tags = local.tags

  network_interface_ids = [
    azurerm_network_interface.nic_dev[count.index].id,
  ]

  source_image_reference {
    publisher = var.gateway.dev_server.image_publisher
    offer     = var.gateway.dev_server.image_offer
    sku       = var.gateway.dev_server.image_sku
    version   = var.gateway.dev_server.image_version
  }

  os_disk {
    caching              = var.gateway.dev_server.os_disk_caching
    storage_account_type = var.gateway.dev_server.os_disk_storage_account_type
  }
}

resource "azurerm_virtual_machine_extension" "vm_dev_init" {
  count                      = var.gateway.dev_server.enabled ? 1 : 0
  name                       = "vm-dev-init"
  virtual_machine_id         = azurerm_windows_virtual_machine.dev[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version        = "1.10"

  settings = jsonencode({
    fileUris = [
      "https://${data.azurerm_storage_account.shared.name}.blob.core.windows.net/tools-${local.env}/vm-dev-init.ps1${data.azurerm_storage_account_sas.tools_sas.sas}"
    ]
  })

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -File vm-dev-init.ps1"
  })

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings
    ]
  }
}

resource "azurerm_network_interface_security_group_association" "nic_dev_association" {
  count                     = var.gateway.dev_server.enabled ? 1 : 0
  network_interface_id      = azurerm_network_interface.nic_dev[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg_gateway.id
}