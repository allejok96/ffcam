CFLAGS:=  $(shell pkg-config --cflags gtk+-3.0)
LIBS:= $(shell pkg-config --libs gtk+-3.0)

.PHONY: all clean

all: ffcam-gui

ffcam-gui: gui.c
	gcc $(CFLAGS) -o ffcam-gui gui.c $(LIBS)

clean:
	-rm ffcam-gui