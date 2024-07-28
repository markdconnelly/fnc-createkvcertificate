<#
.SYNOPSIS
    This function will create a new azure key vault certificate object based on the inputs provided. This function should only be executed via the Power Platform. 
    Specifically, this function is called from the CertificateManagement Power App. 
.DESCRIPTION
    Creating an Azure Key Vault certificate is not natively supported. This function will will provide custom support of this operation via PowerShell.
.NOTES
    This is a custom function written by Mark Connelly.
    Version:        0.1
    Author:         Mark D. Connelly Jr.
    Last Updated:   07-28-2024 - Mark Connelly
    Creation Date:  07-28-2024
    Purpose/Change: Initial script development
.LINK
    #
.EXAMPLE
     Import-AzKeyVaultCertificateFromPowerApps -Certificate $jsonPayloadArray
#>

using namespace System.Net

    # Input bindings are passed in via param block.
    param($Request, $TriggerMetadata)
    
    # Write to the Azure Functions log stream.
    Write-Host "PowerShell HTTP trigger function processed a request."

    # Initialize function level variables
    $errorMessage = ""
    $strKeyVaultName = $env:KeyVaultName
    $strKeyVaultURL_AFD = $env:KeyVaultURL_AFD
    $strKeyVaultURL_Regional = $env:KeyVaultURL_Regional

    # Check the current connections to Azure. If not connected, stop the function.
    $currentAzContext = Get-AzContext
    if($null -eq $currentAzContext){
        Write-Error "Not connected to the Azure Resource Manager. Please connect before running this function."
        $errorMessage = "Not connected to the Azure Resource Manager. Please connect before running this function."
    }
    Write-Host "Connected to Azure Resource Manager"
    Write-Host $currentAzContext
    
    # Check if the key vault exists. If it does not, stop the function and return an error to the application.
    if($errorMessage -eq $null){
        try {
            $objKeyVaultCertOps = Get-AzKeyVault -VaultName $strKeyVaultName -ErrorAction Stop
            Write-Host "Key Vault found"
        }
        catch {
            Write-Error "Unable to connect to the certificate management key vault. Please check the connection and try again."
            $errorMessage = "Unable to connect to the certificate management key vault $objKeyVaultCertOps. Please check the connection and try again."
        }
    }

    # Check if the certificate exists. If it does, stop the function and return an error to the application.
    if($errorMessage -eq $null){
        try {
            $objKeyVaultCertificate = Get-AzKeyVaultCertificate -VaultName $strKeyVaultName -Name $strCertificateName -ErrorAction Stop
            Write-Error "Certificate $objKeyVaultCertificate already exists. Return message to app and stop function."
            $errorMessage = "Certificate $objKeyVaultCertificate already exists. Please check the certificate name and try again."
        }
        catch {
            Write-Host "Certificate $strCertificateName not found. Proceeding with import operation."
        }
    }

    # Attempt to convert the certificate secret to secure string. If it fails, stop the function and return an error to the application.
    if($errorMessage -eq $null){
        try {
            $importSecret = ConvertTo-SecureString -String $strCertificateSecret -AsPlainText -Force
            Write-Host "Certificate secret converted to secure string"
        }
        catch {
            Write-Error "Unable to convert certificate secret to secure string. Please check the secret and try again."
            $errorMessage = "Unable to convert certificate secret to secure string. Please check the secret and try again."
            return $errorMessage
        }
    }

    # Import the certificate into the key vault
    if($errorMessage -eq $null){
        try {
            Import-AzKeyVaultCertificate -VaultName $strKeyVaultName -Name $strCertificateName -FilePath $strCertificateFilePath -Password $importSecret -ErrorAction Stop
            Write-Host "Certificate $strCertificateName imported successfully"
        }
        catch {
            Write-Error "Unable to import certificate $strCertificateName. Please check the certificate file path and try again."
            $errorMessage = "Unable to import certificate $strCertificateName. Please check the certificate file path and try again."
        }
    }

    # Document the certificate import operation and return it to the application.
    if($errorMessage -eq $null){
        try {
            $objKeyVaultCertificate = Get-AzKeyVaultCertificate -VaultName $strKeyVaultName -Name $strCertificateName -IncludePending -ErrorAction Stop
            Write-Host "Certificate details retrieved from the key vault successfully."

        }
        catch {
            Write-Error "Unable to retrieve certificate $strCertificateName from the key vault. Please check the certificate and try again."
            $errorMessage = "Unable to retrieve certificate $strCertificateName from the key vault. Please check the certificate and try again."
        }
    }

    if($errorMessage -eq $null){
        try {
            $objKeyVaultCertificate = $objKeyVaultCertificate | ConvertTo-Json
            Write-Host "Certificate details converted to JSON successfully."
        }
        catch {
            Write-Error "Unable to convert certificate details to JSON. Please check the certificate and try again."
            $errorMessage = "Unable to convert certificate details to JSON. Please check the certificate and try again."
        }
    }
    
    # If no errors were encountered, return the certificate object to the application in a json format.
    if($errorMessage -eq $null){
        $body = $objKeyVaultCertificate
        Push-OutputBinding -Name Response -Value (
            [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body = $body
            }
        )
    }
    # If an error was encountered, return the error message to the application.
    else{
        $body = $errorMessage
        Push-OutputBinding -Name Response -Value (
            [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::Conflict
                Body = $errorMessage
            }
        )
    }