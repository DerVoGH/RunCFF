# RunCFF

<div align="center">

![Version](https://img.shields.io/badge/version-2026.02.13.2-blue)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**文件夹/文件创建工具 - 批量创建与重命名**

[English](#english) | [中文](#chinese)

</div>

---

## 中文介绍

一个简单易用的 Windows 桌面工具，用于批量创建文件/文件夹，以及批量重命名文件或文件夹。

### 功能特点

| 功能 | 说明 |
|------|------|
| **批量创建** | 在多个目录中同时创建多个文件或文件夹 |
| **批量重命名** | 对选中的文件或文件夹进行批量重命名 |
| **模式化命名** | 支持 `{0}` (序号) 和 `{1}` (自定义名称) 占位符 |
| **自动补全扩展名** | 创建文件时未指定扩展名则自动补 `.txt` |
| **冲突处理** | 自动检测并处理重名问题 |
| **撤销操作** | 支持撤销最近一次创建或重命名操作 |
| **拖拽支持** | 支持直接拖拽文件/文件夹到目标列表 |
| **单文件运行** | 无需安装，双击即可使用 |

### 使用场景

- 📁 在多个目录中批量创建规则化命名的文件夹
- 📄 批量生成测试文件
- 🏷️ 批量重命名照片、文档等文件
- 🔧 快速整理项目目录结构

### 快速开始

#### 方式一：直接运行（推荐）

双击 `Run-CreateFF.vbs` 即可启动工具，无需打开 PowerShell 控制台。

#### 方式二：PowerShell 运行

```powershell
.\CreateFF.ps1
```

### 使用说明

1. **添加目标**
   - 点击「添加文件夹」或「添加文件」按钮
   - 或直接拖拽文件/文件夹到列表中

2. **配置命名规则**
   - `{0}` = 序号（从 1 开始）
   - `{1}` = 名称列表中的名称
   - 例如：`{0}.{1}` 会生成 `1.文件名`、`2.文件名`...

3. **批量创建**
   - 选择创建类型（文件/文件夹）
   - 设置创建数量
   - 填写名称列表（可选）
   - 点击「生成」

4. **批量重命名**
   - 添加需要重命名的文件/文件夹
   - 确保名称列表数量与目标数量一致
   - 点击「重命名」

5. **撤销操作**
   - 点击「撤销」可回退最近一次操作

### 命名示例

| 模式 | 输入 | 输出示例 |
|------|------|----------|
| `{0}.{1}` | `项目A\n项目B` | `1.项目A`, `2.项目B` |
| `{0}_test_{1}.txt` | `alpha\nbeta` | `1_test_alpha.txt`, `2_test_beta.txt` |
| `{0}` | (留空) | `1`, `2`, `3`, ... |

### 项目结构

```
RunCFF/
├── CreateFF.ps1          # 主程序（PowerShell GUI）
├── Run-CreateFF.vbs      # 启动器（隐藏窗口运行）
└── README.md             # 项目文档
```

### 技术实现

- **GUI 框架**: Windows Forms
- **语言**: PowerShell 5.1+
- **启动器**: VBScript (用于无窗口启动)
- **核心算法**:
  - [Build-Names](CreateFF.ps1#L76) - 基于模式生成名称列表
  - [Get-UniqueName](CreateFF.ps1#L40) - 处理名称冲突
  - [撤销栈](CreateFF.ps1#L219) - 操作历史管理

### 未来计划

- [ ] 支持多步撤销与操作历史列表
- [ ] 支持模板预设与一键保存/加载配置
- [ ] 增加名称预览窗口与冲突提示优化
- [ ] 支持更多占位符（日期、时间、父级路径等）
- [ ] 添加正则表达式重命名模式

### 常见问题

**Q: 为什么脚本运行被阻止？**

A: 右键 `Run-CreateFF.vbs` → 属性 → 取消「阻止」。或以管理员身份运行 PowerShell 执行 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Q: 重命名时为什么需要一一对应？**

A: 为避免混淆和误操作，重命名功能要求名称列表与目标数量完全一致。

**Q: 撤销功能能撤销多步吗？**

A: 目前仅支持撤销最近一次操作。未来版本将增加多步撤销支持。

### 贡献

欢迎提交 Issue 和 Pull Request！

### 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

<div align="center">

Made with ❤️

</div>

---

## English

A simple yet powerful Windows desktop tool for batch creating files/folders and batch renaming operations.

### Features

| Feature | Description |
|---------|-------------|
| **Batch Creation** | Create multiple files/folders across multiple directories |
| **Batch Renaming** | Rename selected files or folders in bulk |
| **Pattern-based Naming** | Support `{0}` (index) and `{1}` (custom name) placeholders |
| **Auto Extension** | Auto-add `.txt` extension when creating files without one |
| **Conflict Handling** | Automatically detect and resolve name conflicts |
| **Undo Support** | Undo last create or rename operation |
| **Drag & Drop** | Drag files/folders directly into target list |
| **Portable** | No installation needed, just run |

### Use Cases

- 📁 Create multiple folders with structured naming in multiple directories
- 📄 Generate test files in bulk
- 🏷️ Batch rename photos, documents, etc.
- 🔧 Quickly organize project directory structures

### Quick Start

#### Method 1: Direct Run (Recommended)

Double-click `Run-CreateFF.vbs` to launch the tool without opening PowerShell console.

#### Method 2: PowerShell

```powershell
.\CreateFF.ps1
```

### Usage

1. **Add Targets**
   - Click "添加文件夹" or "添加文件" buttons
   - Or drag & drop files/folders into the list

2. **Configure Naming Pattern**
   - `{0}` = Sequence number (starting from 1)
   - `{1}` = Name from the name list
   - Example: `{0}.{1}` generates `1.filename`, `2.filename`...

3. **Batch Create**
   - Select type (file/folder)
   - Set creation count
   - Fill name list (optional)
   - Click "生成"

4. **Batch Rename**
   - Add files/folders to rename
   - Ensure name list count matches target count
   - Click "重命名"

5. **Undo**
   - Click "撤销" to revert the last operation

### Naming Examples

| Pattern | Input | Output Examples |
|---------|-------|-----------------|
| `{0}.{1}` | `ProjectA\nProjectB` | `1.ProjectA`, `2.ProjectB` |
| `{0}_test_{1}.txt` | `alpha\nbeta` | `1_test_alpha.txt`, `2_test_beta.txt` |
| `{0}` | (empty) | `1`, `2`, `3`, ... |

### Project Structure

```
RunCFF/
├── CreateFF.ps1          # Main program (PowerShell GUI)
├── Run-CreateFF.vbs      # Launcher (hidden window)
└── README.md             # Documentation
```

### Tech Stack

- **GUI Framework**: Windows Forms
- **Language**: PowerShell 5.1+
- **Launcher**: VBScript (for background execution)
- **Core Algorithms**:
  - [Build-Names](CreateFF.ps1#L76) - Generate names based on pattern
  - [Get-UniqueName](CreateFF.ps1#L40) - Handle name conflicts
  - [Undo Stack](CreateFF.ps1#L219) - Operation history management

### Roadmap

- [ ] Multi-step undo with operation history
- [ ] Template presets with save/load configuration
- [ ] Enhanced name preview with conflict hints
- [ ] More placeholders (date, time, parent path, etc.)
- [ ] Regex-based renaming patterns

### FAQ

**Q: Script execution blocked?**

A: Right-click `Run-CreateFF.vbs` → Properties → Unblock. Or run PowerShell as admin: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Q: Why must name list match target count for rename?**

A: To avoid confusion and mistakes, rename requires an exact one-to-one match.

**Q: Can undo multiple steps?**

A: Currently only one-step undo. Multi-step undo is planned for future versions.

### Contributing

Issues and Pull Requests are welcome!

### License

MIT License - See [LICENSE](LICENSE) for details

---

<div align="center">

Made with ❤️

</div>
