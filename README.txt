#ZBOX

##Background

###Target
Zbox want to:
- make the installation/compilation of tools easier
- make the tools NOT system wide, which means more "green"
- make the usage of tool more easier

### Status
- Still under developing, quite incomplete. Lots need to add, and lots will be changed!

### Requirement
- Currently only tested on ubuntu 13.10 (some tool dependency need apt-get)
- Script language is in bash

##Usage

###Basic
Checkout source
	`cd ~ && git clone https://github.com/ouyzhu/zbox.git .zbox`
Source the script
	`cd ~/.zbox && source zbox_func.sh`
Check what could be installed out of box
	`zbox list`
Install a some tool
	`zbox install python 3.3.4`
Find out the "Installed" status changed to Y
	`zbox list`
Use it
	`zbox use maven 3.1.1 && mvn -version`
Make it more convenient if you like it. Source it in .bashrc
	`vi ~/.bashrc`
Add content
	zbox_func=${HOME}/.zbox/zbox_func.sh
	if [ -e "${zbox_func}" ]  ; then
		source "${zbox_func}"
		func_zbox_use python 3.3.4
	fi

###Tips
- Find better place for source 
  Source downloading is usually a time costing task. Put .zbox/src to another place, and make a symbolic link. So the source could survive even after OS re-install.

##Develop

### Concept

| Abbreviation | Concept            | Description                                                         |
| ----         | ----               | ----                                                                |
| tool         | tool               | the most basic concept, e.g. vim, ruby, etc                         |
|              |                    |                                                                     |
| stg          | stage              | working area, e.g. an apache www dir                                |
| src          | source             | source packages/code for installation                               |
| cnf          | configure          | zbox configuration, for tool installation, stage setup, etc         |
| ucd          | uncompress(ed)     | uncompressed materials, e.g. uncompressed souce package for compile |
| dep          | dependency         | dependency information |
|              |                    |                                                                     |
| tver         | tool ver           | version of tool                                                     |
| tadd         | tool addition info | addition info of tool, useful when need diff build for same version |
| tname        | tool name          | name of the tool, without any version info. E.g. vim, ruby, etc.    |
| uname        | unique name        | the unique tool name, <tname>-<tver> or <tname>-<tver>-<tadd>       |
| sname        | stage name         | stage name, a name for the working area                             |
| usname       | unique stage name  | the unique stage name, <tname>-<sname>                              |
|              |                    |                                                                     |

###TODO
logging
verify

###Guide
all logic in function
variable as "local" as possible

###Layout
	ins					for builds, executable binaries
		<tname>				dir,
			<tname>			symbolic link, to the real build, 1st build will create this link, need manual update afterwards
			<uname>			the real build
			<uname>_env		the env file to make tool usable

	cnf					configuration
		<tname>				dir,
			ins			basic/general info for installation
			ins-<tver>		specific info for version <tver>, which could override those settings in "ins" file

	src					source code or package (e.g. *-hg/svn/git, *.zip/tar/bz2, etc)
		<tname>				dir,
			<uname>			'standard name' for source, probably a symbolic link point to the real download/checkout file
	
	stg					working area for tools
		<tname>
			<usname>
	tmp
		<uname>				tmp files, usually extraced files,

	zbox_func.sh				(bash) zbox scripts
	zbox_lib.sh				(bash) common scripts which not zbox specific
