target=/usr/local/bin

all:
	@echo "Only use is \"make install\""

install:
	install datedist.pl $(target)
