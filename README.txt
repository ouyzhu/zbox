# ZBOX

Zbox want to unify the installation of tools.

Still under developing, quite incomplete.

# Unsorted notes
Process
	Logstash	url > (download)                                                                     executable > (     copy        ) > target
	vim		url > (download)                            ucd > (configure) > configured > (build) > executable > (          install) > target
	python ??
	Maven		url > (download) > package > (uncompress)                                                  executable > (move             ) > target

	CASE	PROCESS										EXAMPLE
	1	url > (download) > package                      > (ins_copy) > target		logstash
	2	url > (download) > package > (uncompress) > ucd > (ins_move) > target		maven
	3	url > (download) > package > (uncompress) > ucd > (ins_make) > target		nginx
		CNF                SRC                      TMP                  EXE
		url                src                      ucd

Abbreviation
	cnf	config/configuration
	src	source
	exe	executable
	ucd	uncompressed

Concept
	Tool			the most basic concept, e.g. vim, ruby, etc

Naming
	<tname>			name of the tool, without any version info. E.g. vim, ruby, etc.
	<tver>			version of tool
	<tadd>			addition info of tool, useful when need diff build for same version
	<uname>			the unique name of the specific tool, <tname>-<tver> or <tname>-<tver>-<tadd>

Config
	zbox_setup_process	defineds the setup process
	zbox_setup_url		in cnf

Layout
	exe				for builds, executable binaries
		<tname>			symbolic link, to the real build, 1st build will create this link, need manual update afterwards
		<tname>-<tver>		the real build

	cnf				configuration
		<tname>			dir,
			setup		basic/general info for installation
			setup-<tver>	specific info for version <tver>, which could override those settings in "setup"

	src				source code (for CVS like GIT, HG, etc), source packages (for source code distributed in packages)
		<tname>			dir,

	zbox				misc, e.g. logs
		script			zbox scripts

		? sourceme.bash		source this file to use zbox, for bash

	#TODO				customizations goes here

Script
	all logic in function
	variable as "local" as possible

