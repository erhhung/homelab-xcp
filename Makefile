# https://www.gnu.org/software/make/manual/make.html

# make sure using GNU Make 4+ (e.g. default
# Make on macOS <= 15.x is 3.81 from 2006!)
major_ver := $(firstword $(subst ., ,$(MAKE_VERSION)))
ifneq ($(filter 0 1 2 3,$(major_ver)),)
$(error Using GNU Make $(MAKE_VERSION). Version 4+ is required)
endif

# https://www.gnu.org/software/make/manual/make.html#Choosing-the-Shell
# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
 SHELL      := /usr/bin/env
.SHELLFLAGS := bash -o pipefail -c
.ONESHELL:   # require GNU Make 4+

 PHONY := all play debug check lint cloc tags
.PHONY: $(PHONY)

# targets are playbook names with optional dash prefix/suffix (refer to
# comments in runlist.sh for how args are parsed to create the runlist)
# https://www.gnu.org/software/make/manual/html_node/Shell-Function.html
PLAYBOOKS := $(shell yq '.[].tags | select(.)' main.yml)

# https://www.gnu.org/software/make/manual/html_node/Goals.html
# https://www.gnu.org/software/make/manual/html_node/Text-Functions.html
first_goal := $(firstword           $(MAKECMDGOALS))
rest_goals := $(wordlist 2,$(words  $(MAKECMDGOALS)),$(MAKECMDGOALS))
play_args  := $(filter-out $(PHONY),$(MAKECMDGOALS))
first_arg  := $(firstword           $(play_args))

define swallow_goal
.PHONY: $(1)
$(1):
	@:
endef

# to pass extra args, this target must be
# named explicitly: e.g. `make all -- -v`
all: play

# ignore all goals not explicitly defined as targets, then
# make first goal run `play` if it's not an explicit target
# https://www.gnu.org/software/make/manual/html_node/Foreach-Function.html
# https://www.gnu.org/software/make/manual/html_node/Eval-Function.html
$(foreach g,$(rest_goals),$(eval $(call swallow_goal,$(g))))
ifeq ($(first_goal),$(first_arg))
$(first_goal): play
endif

# this target is run implicitly if the
# first goal is not an explicit target
play:
	@scripts/play.sh $(play_args)

# run the debugging playbook (usually invoked via
# `make debug -- -t <play>` to run specific play)
debug:
	@ansible-playbook $(rest_goals) playbooks/debug.yml

# perform syntax checking on all playbooks
check:
	@ansible-playbook --syntax-check $(addprefix playbooks/, \
																	 $(addsuffix .yml, $(PLAYBOOKS)))

# run ansible-lint on all/specific playbooks
lint:
	@ansible-lint $(addprefix playbooks/, \
								$(addsuffix .yml, $(rest_goals))) \
		2> >(sed -E 's/ Last profile.+$$//' >&2)

# count lines of code in the project
# `make cloc -- --csv | rich --csv -`
cloc:
	@scripts/cloc.sh $(rest_goals)

# print list of playbook tags
tags:
	@printf "%s\n" $(PLAYBOOKS)
