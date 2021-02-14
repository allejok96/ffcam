CFLAGS:=  $(shell pkg-config --cflags gtk+-3.0)
LIBS:= $(shell pkg-config --libs gtk+-3.0)

.PHONY: all clean

all: ffcam-gui

ffcam-gui: ffcam-gui.c
	gcc $(CFLAGS) -o ffcam-gui ffcam-gui.c $(LIBS)

install:
	install -d /usr/local/bin
	install -m 755 ffcam.sh /usr/local/bin/ffcam
	-install -m 755 ffcam-gui /usr/local/bin/ffcam-gui

uninstall:
	-rm -f /usr/local/bin/ffcam-gui
	rm -f /usr/local/bin/ffcam

clean:
	-rm -f ffcam-gui

