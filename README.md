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

###Tips
- Find better place for source 
  Source downloading is usually a time costing task. Put .zbox/src to another place, and make a symbolic link. So the source could survive even after OS re-install.

##Usage

###Basic

Checkout source

	# works
	cd $HOME && git clone https://github.com/ouyzhu/zbox.git .zbox
	# works, seems can NOT direct pipe the zip content to unzip
	wget https://github.com/ouyzhu/zbox/archive/master.zip -O /tmp/zbox.zip; unzip /tmp/zbox.zip -d $HOME && mv $HOME/{zbox-master,.zbox}

Source the script

	cd ~/.zbox && source zbox_func.sh

Check what could be installed out of box

	zbox list

Install a some tool

	zbox install python 3.3.4

Find out the "Installed" status changed to Y

	zbox list

Use some installed tool

	zbox use maven 3.1.1 && mvn -version

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

###Command

####list

| Command       | Desc                   |
| ----          | ----                   |
| zbox list     | list all tool status   |
| zbox list xxx | list 'xxx' tool status |
