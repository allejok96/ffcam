// https://developer.gnome.org/gtk3/stable/gtk-getting-started.html
#include <gtk-3.0/gtk/gtk.h>


static void print (GtkWidget *widget,
                   gpointer   data)
{
  g_print (data);
  g_print ("\n");
}


static void add_button (GtkWidget * box,
                        gchar * label,
                        gchar * output,
                        gchar * icon)
{
  GtkWidget * button;

  button = gtk_button_new_from_icon_name (icon, GTK_ICON_SIZE_BUTTON);
  gtk_widget_set_tooltip_text (button, label);

  g_signal_connect (button, "clicked", G_CALLBACK (print), output);

  gtk_box_pack_start (GTK_BOX (box), button, FALSE, FALSE, 0);
}


static GtkWidget * add_item (GtkWidget * menu,
                             gchar * label,
                             gchar * output)
{
  GtkWidget * item;

  if (label != NULL)
    {
      item = gtk_menu_item_new_with_label (label);

      if (output != NULL)
        {
          g_signal_connect (item, "activate", G_CALLBACK (print), output);
        }
    }
  else
    {
      item = gtk_separator_menu_item_new ();
    }

  gtk_menu_shell_append (GTK_MENU_SHELL(menu), item);

  return item;
}


static void activate (GtkApplication *app, gpointer user_data)
{
  GtkWidget * window;
  GtkWidget * box;
  GtkWidget * menuButton;
  GtkWidget * menu;
  GtkWidget * settingsItem;
  GtkWidget * settingsMenu;

  // Main window
  window = gtk_application_window_new (app);
  gtk_window_set_title (GTK_WINDOW (window), "FFcam");
  gtk_window_set_keep_above (GTK_WINDOW (window), TRUE);

  // Settings submenu
  settingsMenu = gtk_menu_new ();
  add_item (settingsMenu, "Splash image…", "image");
  add_item (settingsMenu, "Microphone…", "mic");
  add_item (settingsMenu, "Webcamera…", "cam");
  add_item (settingsMenu, "Output device…", "virtual");

  // Dropdown menu
  menu = gtk_menu_new ();
  add_item (menu, "Screencast", "screen");
  add_item (menu, "Screenshot", "screenshot");
  add_item (menu, NULL, NULL);
  add_item (menu, "Unmute", "unmute");
  add_item (menu, NULL, NULL);
  add_item (menu, "Show webcam", "self");
  add_item (menu, "Show preview", "preview");
  add_item (menu, NULL, NULL);
  settingsItem = add_item (menu, "Settings", NULL);
  gtk_menu_item_set_submenu (GTK_MENU_ITEM (settingsItem), settingsMenu);

  // Main window container
  box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 0);
  add_button (box, "Black", "black", "view-conceal-symbolic");
  add_button (box, "Webcam", "stream", "camera-web-symbolic");
  add_button (box, "Splash screen", "splash", "preferences-desktop-wallpaper-symbolic");
  add_button (box, "Media", "open", "applications-multimedia-symbolic");
  add_button (box, "Resume", "resume", "media-playback-start-symbolic");
  add_button (box, "Pause", "pause", "media-playback-pause-symbolic");
  gtk_container_add (GTK_CONTAINER (window), box);

  // Dropdown menu button
  menuButton = gtk_menu_button_new ();
  gtk_menu_button_set_popup (GTK_MENU_BUTTON (menuButton), menu);
  gtk_box_pack_start (GTK_BOX (box), menuButton, FALSE, FALSE, 0);

  gtk_widget_show_all (menu);
  gtk_widget_show_all (window);
}


int main (int argc, char **argv)
{
  GtkApplication *app;
  int status;

  app = gtk_application_new ("org.ffcam.app", G_APPLICATION_FLAGS_NONE);
  g_signal_connect (app, "activate", G_CALLBACK (activate), NULL);
  status = g_application_run (G_APPLICATION (app), argc, argv);
  g_object_unref (app);

  return status;
}
