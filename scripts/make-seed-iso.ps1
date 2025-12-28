# PowerShell script to create a cloud-init seed ISO using oscdimg (Windows ADK)
# Or use a tool like ImgBurn/PowerISO

$seedDir = "$PSScriptRoot\..\iso\nocloud"
$outputIso = "$PSScriptRoot\..\build\cidata.iso"

Write-Host "Creating cloud-init seed ISO..."
Write-Host "Seed directory: $seedDir"
Write-Host "Output ISO: $outputIso"

# Check for oscdimg (from Windows ADK)
$oscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

if (Test-Path $oscdimg) {
    & $oscdimg -n -d -m "$seedDir" "$outputIso"
    Write-Host "Created: $outputIso"
} else {
    Write-Host ""
    Write-Host "oscdimg not found. Install Windows ADK or use one of these methods:"
    Write-Host ""
    Write-Host "Method 1: Use WSL"
    Write-Host "  wsl genisoimage -output build/cidata.iso -volid cidata -joliet -rock iso/nocloud/"
    Write-Host ""
    Write-Host "Method 2: Use ImgBurn (free)"
    Write-Host "  1. Download ImgBurn from https://imgburn.com"
    Write-Host "  2. Create ISO from folder: iso\nocloud\"
    Write-Host "  3. Set volume label to: cidata"
    Write-Host "  4. Save as: build\cidata.iso"
    Write-Host ""
    Write-Host "Method 3: Use cloud-init disk for your hypervisor"
    Write-Host "  VirtualBox: Mount iso\nocloud\ folder directly via shared folders"
}
