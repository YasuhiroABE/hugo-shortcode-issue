
.PHONY: all
all:
	hugo

.PHONY: clean
clean:
	find . -type f -name '*~' -exec rm {} \; -print

