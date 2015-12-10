# ZBOX


## Background

### What is zbox

Zbox is an install tool like homebrew, apt-get, with some difference:
- install in user space/privilege (note: dependency might need in system level)
- multiple version of same software, switch any version with signle command
- could create "green" workspace for software, also multiple ones
- only based on bash, better portability (homebrew needs ruby)
- support Linux and OSX (note: need apt-get/macports for dependency)

Zbox是一个开发软件安装工具，类似homebrew，apt-get。但有自己的特点：
- 完全在用户空间/权限下，“安装”绿色（部分软件仍需要系统级依赖）
- 支持安装同一软件的多个版本，一条命令切换使用版本
- 支持建立工作空间，“工作空间”也完全绿色，支持多个独立工作空间
- 完全基于Bash，对了环境最小依赖（homebrew基于ruby）
- 支持Linux和OSX（注意：安装系统级依赖时需要使用apt-get/macports)

### Status
- Still under developing. Lots need to add.
- Personally used on Ubuntu, LinuxMint and OSX

## Usage

### Quick Guide

Checkout/Install

	cd $HOME && git clone https://github.com/ouyzhu/zbox.git .zbox

	# Way 2: download source package instead of git checkout
	#wget https://github.com/ouyzhu/zbox/archive/master.zip -O /tmp/zbox.zip
	#unzip /tmp/zbox.zip -d $HOME && mv $HOME/{zbox-master,.zbox}

Import script

	# better to put this in ~/.bashrc
	cd ~/.zbox && source zbox_func.sh

Show status

	# shows what installed, what ready to install
	zbox list

Install tool

	zbox install maven 3.1.1
	zbox install maven 2.2.1

Show status again

	zbox list maven

Use the installed tool

	zbox use maven 3.1.1 && mvn -version
	zbox use maven 2.2.1 && mvn -version

Check what tool is in use

	zbox using

Make it more convenient if you like it. Source it in .bashrc

	vi ~/.bashrc

Add content

	zbox_func=${HOME}/.zbox/zbox_func.sh
	if [ -e "${zbox_func}" ]  ; then
		source "${zbox_func}"
		func_zbox_use python 3.3.4
	fi

### Abbreviations

| Symbol | Abbreviation       | Description                                                                                                     |
| ----   | ----               | ----                                                                                                            |
| tool   | tool               | the most basic concept, e.g. vim, ruby, etc                                                                     |
|        |                    |                                                                                                                 |
| stg    | stage              | a totally independent workspace, e.g. could create diff stage for redis with diff ports (and use them together) |
| src    | source             | source packages/code for installation                                                                           |
| cnf    | configure          | zbox configuration, for tool installation, stage setup, etc                                                     |
| ucd    | uncompress(ed)     | uncompressed materials, e.g. uncompressed souce package for compile                                             |
| dep    | dependency         | dependency information                                                                                          |
| rem    | remove             | uninstall, but keep the downloaded source                                                                       |
| pur    | purge              | uninstall, also remove the downloaded sourcej                                                                   |
|        |                    |                                                                                                                 |
| ver    | version            | version                                                                                                         |
| tver   | tool version       | tool version                                                                                                    |
| tadd   | tool addition info | addition info of tool, useful when need diff build/installation for same version                                |
| tname  | tool name          | name of the tool, without any version info. E.g. vim, ruby, etc.                                                |
| uname  | unique name        | the unique tool name: <tname>-<tver>, or <tname>-<tver>-<tadd> if <tadd> not empty                              |
| sname  | stage name         | stage name, a name for the working area                                                                         |
| usname | unique stage name  | the unique stage name: <tname>-<tver>-<sname>, or <tname>-<tver>-<tadd>-<sname> if <tadd> not empty             |

### Command list

| Command                            | Desc                                                                                                  |
| ----                               | ----                                                                                                  |
| zbox list                          | list all tool status                                                                                  |
| zbox list <tname>                  | list <tname> tool status                                                                              |
| zbox use <tname> <tver> <tadd>     | use tool, require <tname>/<tver>, <tadd> is optional                                                  |
| zbox install <tname> <tver> <tadd> | install tool, require <tname>/<tver>, <tadd> is optional                                              |
| zbox remove <tname> <tver> <tadd>  | uninstall tool and keep the downloaded source (so not need download next time)                        |
| zbox purge <tname> <tver> <tadd>   | uninstall tool and remove the downloaded source                                                       |
| zbox mkstg <tname> <tver> <sname>  | make stage (workspace), require <tname>/<tver>/<sname>. Note: some software might not need make stage |
