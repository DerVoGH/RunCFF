param(
    [string[]]$TargetDirArg = @()
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-CollisionName {
    param(
        [string]$OriginalName,
        [string]$Type,
        [int]$Index,
        [string]$DuplicatePattern
    )

    $baseName = if ($Type -eq 'folder') { $OriginalName } else { [System.IO.Path]::GetFileNameWithoutExtension($OriginalName) }
    $ext = if ($Type -eq 'folder') { '' } else { [System.IO.Path]::GetExtension($OriginalName) }

    $candidate = ''
    try {
        $candidate = [string]::Format($DuplicatePattern, $baseName, $Index, $ext)
    } catch {
        $candidate = "{0}({1}){2}" -f $baseName, $Index, $ext
    }

    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = "{0}({1}){2}" -f $baseName, $Index, $ext
    }

    if ($Type -eq 'file') {
        $candidateExt = [System.IO.Path]::GetExtension($candidate)
        if ([string]::IsNullOrWhiteSpace($candidateExt)) {
            $candidate = "$candidate$ext"
        }
    }

    return $candidate
}

function Get-UniqueName {
    param(
        [string]$Name,
        [string]$TargetDir,
        [string]$Type,
        [string]$DuplicatePattern,
        [string]$IgnorePath,
        [System.Collections.Generic.HashSet[string]]$ReservedNames
    )

    $candidate = $Name
    $i = 1
    while ($true) {
        $fullPath = Join-Path $TargetDir $candidate
        $pathExists = Test-Path -LiteralPath $fullPath
        $isIgnore = $false

        if ($pathExists -and -not [string]::IsNullOrWhiteSpace($IgnorePath)) {
            $resolvedExisting = (Resolve-Path -LiteralPath $fullPath).Path
            $isIgnore = [string]::Equals($resolvedExisting, $IgnorePath, [System.StringComparison]::OrdinalIgnoreCase)
        }

        $isReserved = $false
        if ($ReservedNames) {
            $isReserved = $ReservedNames.Contains($candidate)
        }

        if ((-not $pathExists -or $isIgnore) -and (-not $isReserved)) {
            return $candidate
        }

        $candidate = Get-CollisionName -OriginalName $Name -Type $Type -Index $i -DuplicatePattern $DuplicatePattern
        $i++
    }
}

function Build-Names {
    param(
        [int]$Count,
        [string[]]$InputNames,
        [string]$Pattern,
        [string]$Type,
        [string]$FallbackExt,
        [string]$TargetDir,
        [string]$DuplicatePattern
    )

    $result = New-Object System.Collections.Generic.List[string]
    for ($i = 1; $i -le $Count; $i++) {
        $nameFromList = ''
        if ($i -le $InputNames.Count) {
            $nameFromList = [string]$InputNames[$i - 1]
        }

        $candidate = Resolve-NameByPattern -Index $i -NameFromList $nameFromList -Pattern $Pattern -Type $Type -FallbackExt $FallbackExt
        $candidate = Get-UniqueName -Name $candidate -TargetDir $TargetDir -Type $Type -DuplicatePattern $DuplicatePattern -IgnorePath '' -ReservedNames $null
        $result.Add($candidate)
    }

    return $result
}

function Ensure-FileExtension {
    param(
        [string]$Name,
        [string]$FallbackExt
    )

    $extToUse = $FallbackExt
    if ([string]::IsNullOrWhiteSpace($extToUse)) { $extToUse = 'txt' }

    $ext = [System.IO.Path]::GetExtension($Name)
    if ([string]::IsNullOrWhiteSpace($ext)) {
        return "$Name.$extToUse"
    }

    return $Name
}

function Resolve-NameByPattern {
    param(
        [int]$Index,
        [string]$NameFromList,
        [string]$Pattern,
        [string]$Type,
        [string]$FallbackExt
    )

    $hasSeq = ($Pattern -match '\{0\}')
    $hasName = ($Pattern -match '\{1\}')
    $candidate = [string]$Index

    if (-not [string]::IsNullOrWhiteSpace($NameFromList) -and ($hasSeq -or $hasName)) {
        try {
            $candidate = [string]::Format($Pattern, $Index, $NameFromList)
        } catch {
            $candidate = "{0}.{1}" -f $Index, $NameFromList
        }
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            $candidate = [string]$Index
        }
    }

    if ($Type -eq 'file') {
        $candidate = Ensure-FileExtension -Name $candidate -FallbackExt $FallbackExt
    }

    return $candidate
}

function Add-PathItem {
    param(
        [System.Windows.Forms.ListBox]$List,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    $isContainer = Test-Path -LiteralPath $Path -PathType Container
    $isLeaf = Test-Path -LiteralPath $Path -PathType Leaf
    if (-not $isContainer -and -not $isLeaf) { return }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    foreach ($existing in $List.Items) {
        if ([string]::Equals($existing, $resolved, [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }

    [void]$List.Items.Add($resolved)
}

function Remove-SelectedListItems {
    param(
        [System.Windows.Forms.ListBox]$List
    )

    $selected = New-Object System.Collections.Generic.List[object]
    foreach ($item in $List.SelectedItems) {
        [void]$selected.Add($item)
    }
    foreach ($item in $selected) {
        [void]$List.Items.Remove($item)
    }
}

function Parse-InputNames {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    # Use non-capturing split so newline tokens are not injected into results.
    return ($Text -split "(?:`r`n|`n|`r)")
}

function Get-TargetDirsFromItems {
    param(
        [System.Windows.Forms.ListBox]$List
    )

    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($item in $List.Items) {
        $path = [string]$item
        if (Test-Path -LiteralPath $path -PathType Container) {
            [void]$dirs.Add((Resolve-Path -LiteralPath $path).Path)
        } elseif (Test-Path -LiteralPath $path -PathType Leaf) {
            $parent = Split-Path -Path $path -Parent
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                [void]$dirs.Add((Resolve-Path -LiteralPath $parent).Path)
            }
        }
    }

    return ($dirs | Select-Object -Unique)
}

[System.Windows.Forms.Application]::EnableVisualStyles()

$undoStack = New-Object System.Collections.Generic.List[object]

function Push-Undo {
    param(
        [object]$Operation
    )
    if ($Operation -ne $null) {
        [void]$undoStack.Add($Operation)
    }
}

function Pop-Undo {
    if ($undoStack.Count -eq 0) { return $null }
    $op = $undoStack[$undoStack.Count - 1]
    $undoStack.RemoveAt($undoStack.Count - 1)
    return $op
}

function Show-Info {
    param([string]$Message, [string]$Title = '提示')
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

function Show-Error {
    param([string]$Message, [string]$Title = '错误')
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

function Show-Confirm {
    param([string]$Message, [string]$Title = '确认')
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Question)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = '生成FF 文件/文件夹工具 v2026.02.13.2'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(640, 760)
$form.MaximizeBox = $false
$form.FormBorderStyle = 'FixedDialog'
$form.AllowDrop = $true

$grpItems = New-Object System.Windows.Forms.GroupBox
$grpItems.Text = '目标列表（文件夹 + 文件）'
$grpItems.Location = New-Object System.Drawing.Point(14, 12)
$grpItems.Size = New-Object System.Drawing.Size(602, 198)
$form.Controls.Add($grpItems)

$lstItems = New-Object System.Windows.Forms.ListBox
$lstItems.Location = New-Object System.Drawing.Point(14, 28)
$lstItems.Size = New-Object System.Drawing.Size(430, 146)
$lstItems.SelectionMode = 'MultiExtended'
$lstItems.AllowDrop = $true
$grpItems.Controls.Add($lstItems)

$btnAddFolder = New-Object System.Windows.Forms.Button
$btnAddFolder.Text = '添加文件夹'
$btnAddFolder.Location = New-Object System.Drawing.Point(458, 28)
$btnAddFolder.Size = New-Object System.Drawing.Size(124, 32)
$grpItems.Controls.Add($btnAddFolder)

$btnAddFiles = New-Object System.Windows.Forms.Button
$btnAddFiles.Text = '添加文件'
$btnAddFiles.Location = New-Object System.Drawing.Point(458, 66)
$btnAddFiles.Size = New-Object System.Drawing.Size(124, 32)
$grpItems.Controls.Add($btnAddFiles)

$btnRemoveItem = New-Object System.Windows.Forms.Button
$btnRemoveItem.Text = '删除选中'
$btnRemoveItem.Location = New-Object System.Drawing.Point(458, 104)
$btnRemoveItem.Size = New-Object System.Drawing.Size(124, 32)
$grpItems.Controls.Add($btnRemoveItem)

$btnClearItem = New-Object System.Windows.Forms.Button
$btnClearItem.Text = '清空目录'
$btnClearItem.Location = New-Object System.Drawing.Point(458, 142)
$btnClearItem.Size = New-Object System.Drawing.Size(124, 32)
$grpItems.Controls.Add($btnClearItem)

$grpConfig = New-Object System.Windows.Forms.GroupBox
$grpConfig.Text = '命名规则'
$grpConfig.Location = New-Object System.Drawing.Point(14, 220)
$grpConfig.Size = New-Object System.Drawing.Size(602, 132)
$form.Controls.Add($grpConfig)

$lblFolderPattern = New-Object System.Windows.Forms.Label
$lblFolderPattern.Text = '文件夹命名格式（{0}=序号, {1}=名称列表）:'
$lblFolderPattern.Location = New-Object System.Drawing.Point(14, 30)
$lblFolderPattern.AutoSize = $true
$grpConfig.Controls.Add($lblFolderPattern)

$txtFolderPattern = New-Object System.Windows.Forms.TextBox
$txtFolderPattern.Location = New-Object System.Drawing.Point(330, 26)
$txtFolderPattern.Size = New-Object System.Drawing.Size(252, 24)
$txtFolderPattern.Text = '{0}.{1}'
$grpConfig.Controls.Add($txtFolderPattern)

$lblFilePattern = New-Object System.Windows.Forms.Label
$lblFilePattern.Text = '文件命名格式（{0}=序号, {1}=名称列表中）:'
$lblFilePattern.Location = New-Object System.Drawing.Point(14, 66)
$lblFilePattern.AutoSize = $true
$grpConfig.Controls.Add($lblFilePattern)

$txtFilePattern = New-Object System.Windows.Forms.TextBox
$txtFilePattern.Location = New-Object System.Drawing.Point(330, 62)
$txtFilePattern.Size = New-Object System.Drawing.Size(252, 24)
$txtFilePattern.Text = '{0}.{1}.txt'
$grpConfig.Controls.Add($txtFilePattern)

$lblRenameRule = New-Object System.Windows.Forms.Label
$lblRenameRule.Text = '重命名按以上格式执行；文件若未写后缀则自动补 .txt'
$lblRenameRule.Location = New-Object System.Drawing.Point(14, 102)
$lblRenameRule.AutoSize = $true
$grpConfig.Controls.Add($lblRenameRule)

$grp生成 = New-Object System.Windows.Forms.GroupBox
$grp生成.Text = '创建参数'
$grp生成.Location = New-Object System.Drawing.Point(14, 362)
$grp生成.Size = New-Object System.Drawing.Size(602, 78)
$form.Controls.Add($grp生成)

$lblType = New-Object System.Windows.Forms.Label
$lblType.Text = '创建类型:'
$lblType.Location = New-Object System.Drawing.Point(14, 34)
$lblType.AutoSize = $true
$grp生成.Controls.Add($lblType)

$cmbType = New-Object System.Windows.Forms.ComboBox
$cmbType.Location = New-Object System.Drawing.Point(82, 30)
$cmbType.Size = New-Object System.Drawing.Size(110, 24)
$cmbType.DropDownStyle = 'DropDownList'
[void]$cmbType.Items.Add('文件夹')
[void]$cmbType.Items.Add('文件')
$cmbType.SelectedIndex = 0
$grp生成.Controls.Add($cmbType)

$lblCount = New-Object System.Windows.Forms.Label
$lblCount.Text = '创建数量:'
$lblCount.Location = New-Object System.Drawing.Point(230, 34)
$lblCount.AutoSize = $true
$grp生成.Controls.Add($lblCount)

$numCount = New-Object System.Windows.Forms.NumericUpDown
$numCount.Location = New-Object System.Drawing.Point(298, 30)
$numCount.Size = New-Object System.Drawing.Size(90, 24)
$numCount.Minimum = 1
$numCount.Maximum = 999
$numCount.Value = 1
$grp生成.Controls.Add($numCount)

$lblCreateHint = New-Object System.Windows.Forms.Label
$lblCreateHint.Text = '名称为空时自动使用序号命名'
$lblCreateHint.Location = New-Object System.Drawing.Point(396, 34)
$lblCreateHint.AutoSize = $true
$lblCreateHint.ForeColor = [System.Drawing.Color]::DimGray
$grp生成.Controls.Add($lblCreateHint)

$lblNames = New-Object System.Windows.Forms.Label
$lblNames.Text = '名称列表（每行一个；创建可留空走默认；重命名必须与目标数量一致）'
$lblNames.Location = New-Object System.Drawing.Point(18, 450)
$lblNames.AutoSize = $true
$form.Controls.Add($lblNames)

$txtNames = New-Object System.Windows.Forms.TextBox
$txtNames.Location = New-Object System.Drawing.Point(18, 474)
$txtNames.Size = New-Object System.Drawing.Size(598, 145)
$txtNames.Multiline = $true
$txtNames.ScrollBars = 'Vertical'
$form.Controls.Add($txtNames)

$lblTips1 = New-Object System.Windows.Forms.Label
$lblTips1.Text = '提示: 支持拖拽文件夹和文件到列表；创建时文件会使用其所在目录'
$lblTips1.Location = New-Object System.Drawing.Point(18, 626)
$lblTips1.AutoSize = $true
$lblTips1.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($lblTips1)

$lblTips2 = New-Object System.Windows.Forms.Label
$lblTips2.Text = '提示: 占位符可灵活使用；都不含时默认按序号命名（文件自动补 .txt）'
$lblTips2.Location = New-Object System.Drawing.Point(18, 646)
$lblTips2.AutoSize = $true
$lblTips2.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($lblTips2)

$btn生成 = New-Object System.Windows.Forms.Button
$btn生成.Text = '生成'
$btn生成.Location = New-Object System.Drawing.Point(280, 668)
$btn生成.Size = New-Object System.Drawing.Size(76, 30)
$form.Controls.Add($btn生成)

$btnUndo = New-Object System.Windows.Forms.Button
$btnUndo.Text = '撤销'
$btnUndo.Location = New-Object System.Drawing.Point(360, 668)
$btnUndo.Size = New-Object System.Drawing.Size(76, 30)
$btnUndo.Enabled = $false
$form.Controls.Add($btnUndo)

$btnRename = New-Object System.Windows.Forms.Button
$btnRename.Text = '重命名'
$btnRename.Location = New-Object System.Drawing.Point(440, 668)
$btnRename.Size = New-Object System.Drawing.Size(76, 30)
$form.Controls.Add($btnRename)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = '结束'
$btnClose.Location = New-Object System.Drawing.Point(520, 668)
$btnClose.Size = New-Object System.Drawing.Size(76, 30)
$form.Controls.Add($btnClose)

$dragEnterHandler = {
    if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $_.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $_.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
}

$dragDropToItems = {
    if (-not $_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { return }
    $paths = $_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    foreach ($p in $paths) {
        Add-PathItem -List $lstItems -Path $p
    }
}

$form.Add_DragEnter($dragEnterHandler)
$form.Add_DragDrop($dragDropToItems)
$lstItems.Add_DragEnter($dragEnterHandler)
$lstItems.Add_DragDrop($dragDropToItems)

$btnAddFolder.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = '选择要添加的文件夹'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Add-PathItem -List $lstItems -Path $dlg.SelectedPath
    }
})

$btnAddFiles.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Multiselect = $true
    $dlg.Title = '选择要添加的文件（可多选）'
    $dlg.Filter = '所有文件 (*.*)|*.*'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($f in $dlg.FileNames) {
            Add-PathItem -List $lstItems -Path $f
        }
    }
})

$btnRemoveItem.Add_Click({
    Remove-SelectedListItems -List $lstItems
})

$btnClearItem.Add_Click({
    $lstItems.Items.Clear()
})

# 启动时保持目标列表为空

$btn生成.Add_Click({
    try {
        if ($lstItems.Items.Count -eq 0) {
            Show-Error -Message '请至少添加一个目标项。'
            return
        }

        $targetDirs = Get-TargetDirsFromItems -List $lstItems
        if ($targetDirs.Count -eq 0) {
            Show-Error -Message '没有可用于创建的有效目录。'
            return
        }

        $count = [int]$numCount.Value
        $duplicatePattern = '{0}({1}){2}'
        $inputNames = Parse-InputNames -Text $txtNames.Text
        $folderPattern = $txtFolderPattern.Text.Trim()
        $filePattern = $txtFilePattern.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($folderPattern)) { $folderPattern = '{0}.{1}' }
        if ([string]::IsNullOrWhiteSpace($filePattern)) { $filePattern = '{0}.{1}.txt' }

        $type = if ($cmbType.SelectedItem -eq '文件夹') { 'folder' } else { 'file' }
        $kindText = if ($type -eq 'folder') { '个文件夹' } else { '个文件' }
        $pattern = if ($type -eq 'folder') { $folderPattern } else { $filePattern }
        $defaultFileExt = 'txt'

        $previewDir = $targetDirs[0]
        $previewItems = Build-Names -Count $count -InputNames $inputNames -Pattern $pattern -Type $type -FallbackExt $defaultFileExt -TargetDir $previewDir -DuplicatePattern $duplicatePattern
        $previewText = ($previewItems | ForEach-Object { "- $_" }) -join [Environment]::NewLine
        $dirListText = ($targetDirs | ForEach-Object { "- $_" }) -join [Environment]::NewLine

        $confirmText = "将在 $($targetDirs.Count) 个目录中，各创建 $count$kindText（共 $($targetDirs.Count * $count) 个）。`r`n`r`n目标目录：`r`n$dirListText`r`n`r`n命名预览（首个目录）：`r`n$previewText"
        $ok = Show-Confirm -Message $confirmText -Title '确认生成'
        if ($ok -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $createdTotal = 0
        $createdPaths = New-Object System.Collections.Generic.List[string]
        foreach ($dir in $targetDirs) {
            $items = Build-Names -Count $count -InputNames $inputNames -Pattern $pattern -Type $type -FallbackExt $defaultFileExt -TargetDir $dir -DuplicatePattern $duplicatePattern
            foreach ($name in $items) {
                $fullPath = Join-Path $dir $name
                if ($type -eq 'folder') {
                    New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                } else {
                    New-Item -Path $fullPath -ItemType File -Force | Out-Null
                }
                [void]$createdPaths.Add($fullPath)
                $createdTotal++
            }
        }

        if ($createdPaths.Count -gt 0) {
            Push-Undo -Operation ([PSCustomObject]@{
                Type = 'create'
                Items = @($createdPaths)
            })
            $btnUndo.Enabled = $true
        }

        Show-Info -Message "创建完成，共创建 $createdTotal 个。" -Title '完成'
    } catch {
        $errType = $_.Exception.GetType().FullName
        $errLine = $_.InvocationInfo.ScriptLineNumber
        Show-Error -Message "执行失败: $($_.Exception.Message)`r`n类型: $errType`r`n行号: $errLine"
    }
})

$btnRename.Add_Click({
    try {
        if ($lstItems.Items.Count -eq 0) {
            Show-Error -Message '请至少添加一个要重命名的文件或文件夹。'
            return
        }

        $duplicatePattern = '{0}({1}){2}'

        $inputNames = Parse-InputNames -Text $txtNames.Text
        $folderPattern = $txtFolderPattern.Text.Trim()
        $filePattern = $txtFilePattern.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($folderPattern)) { $folderPattern = '{0}.{1}' }
        if ([string]::IsNullOrWhiteSpace($filePattern)) { $filePattern = '{0}.{1}.txt' }

        $renameItems = @()
        $fileCount = 0
        $folderCount = 0
        foreach ($item in $lstItems.Items) {
            $path = [string]$item
            $isFolder = Test-Path -LiteralPath $path -PathType Container
            $isFile = Test-Path -LiteralPath $path -PathType Leaf
            if (-not $isFolder -and -not $isFile) { continue }
            if ($isFolder) { $folderCount++ }
            if ($isFile) { $fileCount++ }

            $name = Split-Path -Path $path -Leaf
            $parent = Split-Path -Path $path -Parent
            $baseName = if ($isFolder) { $name } else { [System.IO.Path]::GetFileNameWithoutExtension($name) }
            $ext = if ($isFolder) { '' } else { [System.IO.Path]::GetExtension($name) }

            $renameItems += [PSCustomObject]@{
                OriginalPath = $path
                OriginalName = $name
                ParentDir = $parent
                IsFolder = $isFolder
                BaseName = $baseName
                Extension = $ext
            }
        }

        if ($renameItems.Count -eq 0) {
            Show-Error -Message '未检测到有效的重命名对象。'
            return
        }

        if ($fileCount -gt 0 -and $folderCount -gt 0) {
            Show-Error -Message '重命名目标不能混合文件和文件夹，请只保留一种类型。'
            return
        }

        if ($inputNames.Count -ne $renameItems.Count) {
            Show-Error -Message "名称列表数量（$($inputNames.Count)）与目标数量（$($renameItems.Count)）不一致。请保证一一对应。"
            return
        }

        if ($inputNames | Where-Object { [string]::IsNullOrWhiteSpace($_) }) {
            Show-Error -Message '名称列表包含空行或空名称，请填写完整名称。'
            return
        }

        $reservedByDir = @{}
        $operations = New-Object System.Collections.Generic.List[object]
        $renamePattern = if ($fileCount -gt 0) { $filePattern } else { $folderPattern }
        for ($i = 1; $i -le $renameItems.Count; $i++) {
            $item = $renameItems[$i - 1]
            $nameFromList = [string]$inputNames[$i - 1]
            if ($nameFromList -match '[\\/:*?"<>|]') {
                Show-Error -Message "名称列表第 $i 行包含非法字符：\ / : * ? "" < > |。"
                return
            }

            $candidateName = Resolve-NameByPattern -Index $i -NameFromList $nameFromList -Pattern $renamePattern -Type $(if ($item.IsFolder) { 'folder' } else { 'file' }) -FallbackExt 'txt'

            if (-not $reservedByDir.ContainsKey($item.ParentDir)) {
                $reservedByDir[$item.ParentDir] = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
            }
            $reservedSet = $reservedByDir[$item.ParentDir]

            $safeName = Get-UniqueName -Name $candidateName -TargetDir $item.ParentDir -Type $(if ($item.IsFolder) { 'folder' } else { 'file' }) -DuplicatePattern $duplicatePattern -IgnorePath $item.OriginalPath -ReservedNames $reservedSet
            [void]$reservedSet.Add($safeName)

            $operations.Add([PSCustomObject]@{
                OriginalPath = $item.OriginalPath
                OriginalName = $item.OriginalName
                ParentDir = $item.ParentDir
                IsFolder = $item.IsFolder
                FinalName = $safeName
                Changed = (-not [string]::Equals($item.OriginalName, $safeName, [System.StringComparison]::OrdinalIgnoreCase))
            })
        }

        $previewLines = @()
        foreach ($op in $operations) {
            $previewLines += "- $($op.OriginalName) -> $($op.FinalName)"
        }
        $previewText = ($previewLines | Select-Object -First 30) -join [Environment]::NewLine
        if ($previewLines.Count -gt 30) {
            $previewText += [Environment]::NewLine + "...（$($previewLines.Count) 项）"
        }

        $changeCount = ($operations | Where-Object { $_.Changed }).Count
        if ($changeCount -eq 0) {
            Show-Info -Message '所有对象的新名称与原名称相同，无需重命名。' -Title '提示'
            return
        }

        $confirmText = "将重命名 $changeCount 个对象（共 $($operations.Count) 个目标）。`r`n`r`n预览：`r`n$previewText"
        $ok = Show-Confirm -Message $confirmText -Title '确认重命名'
        if ($ok -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $opsToRename = @($operations | Where-Object { $_.Changed })
        $tempOps = New-Object System.Collections.Generic.List[object]
        foreach ($op in $opsToRename) {
            $tmpName = "__rename_tmp_{0}" -f ([Guid]::NewGuid().ToString('N'))
            if (-not $op.IsFolder) {
                $tmpName += $([System.IO.Path]::GetExtension($op.OriginalName))
            }
            $tmpPath = Join-Path $op.ParentDir $tmpName
            Rename-Item -LiteralPath $op.OriginalPath -NewName $tmpName
            $tempOps.Add([PSCustomObject]@{
                TempPath = $tmpPath
                FinalName = $op.FinalName
            })
        }

        foreach ($op in $tempOps) {
            Rename-Item -LiteralPath $op.TempPath -NewName $op.FinalName
        }

        $renameUndoItems = @()
        foreach ($op in $opsToRename) {
            $renameUndoItems += [PSCustomObject]@{
                From = $op.FinalName
                To = $op.OriginalName
                ParentDir = $op.ParentDir
            }
        }

        if ($renameUndoItems.Count -gt 0) {
            $undoOperation = [PSCustomObject]@{
                Type = 'rename'
                Items = $renameUndoItems
            }
            Push-Undo -Operation $undoOperation
            $btnUndo.Enabled = $true
        }

        Show-Info -Message "重命名完成，共重命名 $changeCount 个对象。" -Title '完成'
    } catch {
        $errType = $_.Exception.GetType().FullName
        $errLine = $_.InvocationInfo.ScriptLineNumber
        Show-Error -Message "执行失败: $($_.Exception.Message)`r`n类型: $errType`r`n行号: $errLine"
    }
})

$btnUndo.Add_Click({
    try {
        $op = Pop-Undo
        if ($null -eq $op) {
            Show-Info -Message '没有可撤销的操作。' -Title '提示'
            $btnUndo.Enabled = $false
            return
        }

        if ($op.Type -eq 'create') {
            $deleted = 0
            $skipped = 0
            foreach ($p in $op.Items) {
                if (-not (Test-Path -LiteralPath $p)) {
                    $skipped++
                    continue
                }

                if (Test-Path -LiteralPath $p -PathType Leaf) {
                    Remove-Item -LiteralPath $p -Force
                    $deleted++
                    continue
                }

                if (Test-Path -LiteralPath $p -PathType Container) {
                    $children = Get-ChildItem -LiteralPath $p -Force
                    if ($children.Count -eq 0) {
                        Remove-Item -LiteralPath $p -Force
                        $deleted++
                    } else {
                        $skipped++
                    }
                }
            }

            $msg = "已撤销创建：删除 $deleted 项"
            if ($skipped -gt 0) { $msg += "，跳过 $skipped 项（不存在或文件夹非空）" }
            Show-Info -Message $msg -Title '撤销完成'
        } elseif ($op.Type -eq 'rename') {
            $restored = 0
            $skipped = 0
            foreach ($item in $op.Items) {
                $fromPath = Join-Path $item.ParentDir $item.From
                $toPath = Join-Path $item.ParentDir $item.To

                if (-not (Test-Path -LiteralPath $fromPath)) {
                    $skipped++
                    continue
                }

                if (Test-Path -LiteralPath $toPath) {
                    $skipped++
                    continue
                }

                Rename-Item -LiteralPath $fromPath -NewName $item.To
                $restored++
            }

            $msg = "已撤销重命名：还原 $restored 项"
            if ($skipped -gt 0) { $msg += "，跳过 $skipped 项（不存在或名称冲突）" }
            Show-Info -Message $msg -Title '撤销完成'
        } else {
            Show-Error -Message '未知撤销类型。'
        }

        if ($undoStack.Count -eq 0) {
            $btnUndo.Enabled = $false
        }
    } catch {
        Show-Error -Message "撤销失败: $($_.Exception.Message)"
    }
})

$btnClose.Add_Click({
    $form.结束()
})

[void]$form.ShowDialog()
