# SPDX-License-Identifier: AGPL-3.0-only
param([string]$PreviewPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ZwiftAccountPicker.psm1') -Force
$project=if ($PreviewPath) {[IO.Path]::GetDirectoryName($PreviewPath)} else {Get-ZwiftPickerDataRoot}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$form=New-Object Windows.Forms.Form
$form.Text='Zwift Online - choose account'
$form.Size=New-Object Drawing.Size(540,490)
$form.MinimumSize=New-Object Drawing.Size(540,490)
$form.FormBorderStyle='FixedDialog'
$form.MaximizeBox=$false
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Segoe UI',11)
$form.BackColor=[Drawing.Color]::FromArgb(21,36,51)
$form.ForeColor=[Drawing.Color]::White

$heading=New-Object Windows.Forms.Label
$heading.Text='Who is riding online?'
$heading.Font=New-Object Drawing.Font('Segoe UI',18,[Drawing.FontStyle]::Bold)
$heading.SetBounds(24,20,470,38)
$form.Controls.Add($heading)
$help=New-Object Windows.Forms.Label
$help.Text='Each person signs in once in official Zwift. This picker keeps separate remembered sessions.'
$help.SetBounds(26,68,470,54)
$form.Controls.Add($help)
$list=New-Object Windows.Forms.ListBox
$list.SetBounds(26,130,470,110)
$list.DisplayMember='name'
$list.BackColor=[Drawing.Color]::FromArgb(35,57,76)
$list.ForeColor=[Drawing.Color]::White
$form.Controls.Add($list)

$nameLabel=New-Object Windows.Forms.Label
$nameLabel.Text='Add another person (name or label)'
$nameLabel.SetBounds(26,246,470,24)
$form.Controls.Add($nameLabel)
$name=New-Object Windows.Forms.TextBox
$name.SetBounds(26,273,315,30)
$name.AccessibleName='New account label'
$name.ForeColor=[Drawing.Color]::Black
$form.Controls.Add($name)
$add=New-Object Windows.Forms.Button
$add.Text='Add account'
$add.SetBounds(351,271,145,34)
$add.ForeColor=[Drawing.Color]::Black
$add.BackColor=[Drawing.Color]::FromArgb(227,234,240)
$form.Controls.Add($add)
$start=New-Object Windows.Forms.Button
$start.Text='Start official Zwift'
$start.SetBounds(26,322,310,44)
$start.BackColor=[Drawing.Color]::FromArgb(255,139,61)
$start.ForeColor=[Drawing.Color]::Black
$form.Controls.Add($start)
$cancel=New-Object Windows.Forms.Button
$cancel.Text='Cancel'
$cancel.SetBounds(351,322,145,44)
$cancel.ForeColor=[Drawing.Color]::Black
$cancel.BackColor=[Drawing.Color]::FromArgb(227,234,240)
$cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancel)
$location=New-Object Windows.Forms.Button
$location.Text='Change Zwift location'
$location.SetBounds(26,382,240,32)
$location.ForeColor=[Drawing.Color]::Black
$location.BackColor=[Drawing.Color]::FromArgb(227,234,240)
$location.Add_Click({try {$null=Get-ZwiftLauncherPath -Project $project -ChooseAgain} catch {[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Zwift location','OK','Warning')}})
$form.Controls.Add($location)
$form.CancelButton=$cancel
$form.AcceptButton=$start

function Refresh-Accounts {
    $list.Items.Clear()
    foreach ($item in @(Get-ZwiftOnlineAccounts -Project $project)) {[void]$list.Items.Add($item)}
    if ($list.Items.Count) {$list.SelectedIndex=0}
    $start.Enabled=$list.Items.Count -gt 0
}
$script:selectedAccount=$null
$add.Add_Click({
    try {
        $created=Add-ZwiftOnlineAccount -Project $project -Name $name.Text
        Refresh-Accounts
        for ($i=0;$i -lt $list.Items.Count;$i++) {if ($list.Items[$i].id -ceq $created.id) {$list.SelectedIndex=$i;break}}
        $name.Clear()
    } catch {[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Could not add account','OK','Warning')}
})
$start.Add_Click({
    if ($list.SelectedItem) {$script:selectedAccount=$list.SelectedItem.id;$form.DialogResult=[Windows.Forms.DialogResult]::OK;$form.Close()}
})
try {
    if ($PreviewPath) {
        [void]$list.Items.Add([pscustomobject]@{id='preview-one';name='Rider One'})
        [void]$list.Items.Add([pscustomobject]@{id='preview-two';name='Rider Two'})
        $list.SelectedIndex=0
        $form.ShowInTaskbar=$false
        $form.Opacity=0
        $form.Show()
        [Windows.Forms.Application]::DoEvents()
        $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
        try {
            $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
            $bitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png)
        } finally {$bitmap.Dispose()}
        exit 0
    }
    Refresh-Accounts
    $result=$form.ShowDialog()
    if ($result -eq [Windows.Forms.DialogResult]::OK -and $script:selectedAccount) {
        & (Join-Path $PSScriptRoot 'Start-ZwiftOnlineAccount.ps1') -OnlineAccount $script:selectedAccount -NoPause
    }
} catch {[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Zwift Online launcher','OK','Error')}
finally {$form.Dispose()}
