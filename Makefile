# https://www.gnu.org/software/make/manual/make.html

 PHONY := all play debug check lint tags
.PHONY: $(PHONY)

# targets are playbook names with optional dash prefix/suffix (refer to
# comments in runlist.sh for how args are parsed to create the runlist)
# https://www.gnu.org/software/make/manual/html_node/Shell-Function.html
PLAYBOOKS := $(shell yq '.[].tags' main.yml)

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
	@./play.sh $(play_args)

# run the debugging playbook (usually invoked via
# `make debug -- -t <play>` to run specific play)
debug:
	@ansible-playbook $(rest_goals) debug.yml

# perform syntax checking on all playbooks
check:
	@ansible-playbook --syntax-check $(addsuffix .yml,$(PLAYBOOKS))

# run ansible-lint on all/specific playbooks
lint:
	@ansible-lint $(addsuffix .yml,$(rest_goals))

# print list of playbook tags
tags:
	@printf "%s\n" $(PLAYBOOKS)
