NAME=bc125at-perl-driver-helper

all: $(NAME)

$(NAME): bc125at-perl-driver-helper.c
	$(CC) $(CFLAGS) -Wall -o $(NAME) $(NAME).c

install: all
	/usr/bin/install -o root -g wheel -t /usr/local/bin $(NAME)
	chmod 6755 /usr/local/bin/$(NAME)
