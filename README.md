**status**: experimental, unstable

# Pass

`Pass` - is a simple tool for system configuration. Configuration change is described as `checks` and `actions`. `Check` is for checking current state of system (eg. if nginx installed). `Action` changes state of system (eg. install nginx). `Pass` allows either apply changes or verify if changes can be applied based on described checks.

# How to use

`Checks` and `Actions` are organized into `Instructions`, and list of `Instructions` is making `Playbook`.

`Check` - only checks current state of system, don't change anything, it is just true/false flag

`Action` - changes system settings, can fail

`Instruction` - contains `environment checks`, `preparation checks`, `confirmation checks` and `action` to be applied. `Environment checks` must not change before and after `action` (eg. version of OS). `Preparation checks` only checked before `action`, and must be true. `Confirmation checks` must fail before `action`, and be true after `action`.

`Playbook` - contains `environment checks` and list of `instructions`. `Environment checks` must not change before and after every `action` of `playbook`. `Playbook` allows either apply changes, or verify if changes can be applied.

Some examples available inside `examples/` folder. Keep in mind changes will be applied to current system, so run in virtual machine for testing.

# Checks

* Named - allows to set name of another check
* Check_AlwaysOk - always true
* Check_And - checks multiple checks with `and` operator
* Check_Constant - always returns constant configured value
* Check_FileContainsOnce - verifies if file contains provided data once
* Check_FileContent - verifies if files is exactly as provided data
* Check_IsDir - verifies if path is directory
* Check_IsFile - verifies if path is regular file
* Check_Not - negates another check
* Check_Or - checks multiple checks with `or` operator
* Check_PathReadable - checks if file can be read
* Check_PathWritable - checks if file can be written
* Check_StderrContainsOnce - checks if standard error output of command contains provided data once
* Check_StdoutContainsOnce - checks if standard output of command contains provided data once
* Check_UserIsRoot - checks if current user is root

# Actions

* Named - allows to set name of another action
* Action_Constant - always fails or succeeds based on provided value
* Action_CreateDir - create directory
* Action_DeleteFile - delete file
* Action_DoNothing - doing nothing
* Action_InstallAptPackages - installs listed apt packages
* Action_Many - wraps multiple actions, making it single action
* Action_RenameDir - rename directory
* Action_ReplaceInFileOnce - replaces data in file exactly once, fails if no matches or more than one match
* Action_RunProcess - run shell command
* Action_SetFilePermissions - sets file access mode, user owner and group owner
* Action_WriteFile - write data to file

# Comptime variants

Each check and action has `comptime` variant (less boilerplate code), naming rules is:

* comptime variant of `Check_AlwaysOk` is `alwaysOk`

exceptions is:

* `Check_And` and `Check_Or`, for which `comptime` variants is `and_` and `or_`