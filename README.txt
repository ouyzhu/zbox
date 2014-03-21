# ZBOX

Zbox want to unify the installation of tools. 
Still under developing, quite incomplete.

## Status
Developing, lots need to add, and lots will be changed!

## Concept

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

## Features



## Dev

### TODO
logging
verify

### Guide
all logic in function
variable as "local" as possible


## Unsorted notes

Layout
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

Record

	Refactoring - (2014-02-14, renaming for better consistency)

		Rename
			exe/setup > ins						done
			zbox_process > zbox_ins_process				done
			zbox_ins_process_ins > zbox_ins_process			done
			zbox_url > zbox_src_url					done
			zbox_dependency > zbox_dep				done
			zbox_stage > zbox_stg					done
			zbox_gen_env_vars > zbox_ins_gen_env_vars		done
			zbox_ins_process > ins_steps				done
			zbox_src_url > src_url					done
			zbox_ins_make_configure_opts > ins_make_configure_opts	done
			ins_steps_make_steps > ins_make_steps			done
			ins_steps_uncompress > ins_uncompress			done
			ins_steps_pre_script > ins_pre_script			done
			zbox_dep_apt_get > ins_dep_apt				done
			zbox_ins_make_install_cmd > ins_make_install_cmd	done
			src_url > ins_download_url				done
			gen_env > env						done
			zbox_ins_env_vars > ins_env_vars			done
			ins_steps_move_post_script > ins_move_post_script	done

			zbox_stg_ > stg_					done	(NOTE: not include func_zbox_stg)

			make_install > install					done	(NOTE: only in "ins_make_steps")
			ins_copy/ins_make/ins_move/ins_dep > copy/make/move/dep	done	(NOTE: only in "ins_steps")
			(more ...)
		
		Test - ins
		Test - stg
