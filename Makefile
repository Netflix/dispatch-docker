REPOSITORY?=dispatch-docker
TAG?=latest

OK_COLOR=\033[32;01m
NO_COLOR=\033[0m

build:
	@printf "$(OK_COLOR)==>$(NO_COLOR) Building $(REPOSITORY):$(TAG)\n"
	@docker build --pull --rm -t $(REPOSITORY):$(TAG) .

$(REPOSITORY)_$(TAG).tar: build
	@printf "$(OK_COLOR)==>$(NO_COLOR) Saving $(REPOSITORY):$(TAG) > $@\n"
	@docker save $(REPOSITORY):$(TAG) > $@

push: build
	@printf "$(OK_COLOR)==>$(NO_COLOR) Pushing $(REPOSITORY):$(TAG)\n"
	@docker push $(REPOSITORY):$(TAG)

all: build push

.PHONY: all build push