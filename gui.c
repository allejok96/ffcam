// https://developer.gnome.org/gtk3/stable/gtk-getting-started.html
#include <gtk/gtk.h>

static void print (GtkWidget *widget, gpointer   data)
{
  g_print (data);
  g_print ("\n");
}

static GtkWidget* new_button (gchar *label, gchar *output)
{
  GtkWidget *button;
  button = gtk_button_new_with_label (label);
  g_signal_connect (button, "clicked", G_CALLBACK (print), output);
  return button;
}

static void activate (GtkApplication *app, gpointer user_data)
{
  GtkWidget *window;
  GtkWidget *grid;

  window = gtk_application_window_new (app);
  gtk_window_set_title (GTK_WINDOW (window), "FFcam");
  //gtk_window_set_default_size (GTK_WINDOW (window), 200, 200);

  grid = gtk_grid_new ();
  gtk_container_add (GTK_CONTAINER (window), grid);

  gtk_grid_attach (GTK_GRID (grid), new_button("Black", "black"),           0,0, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Splash", "splash"),         1,0, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Webcam", "stream"),         2,0, 1,1);

  gtk_grid_attach (GTK_GRID (grid), new_button("Media", "open"),            0,1, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Pause", "pause"),           1,1, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Resume", "resume"),         2,1, 1,1);

  gtk_grid_attach (GTK_GRID (grid), new_button("Mute", "mute"),             0,2, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Unmute", "unmute"),         1,2, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Set mic", "mic"),           2,2, 1,1);

  gtk_grid_attach (GTK_GRID (grid), new_button("Set splash", "image"),      0,3, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Set camera", "cam"),        1,3, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Set virtual", "virtual"),   2,3, 1,1);

  gtk_grid_set_column_homogeneous (GTK_GRID (grid), TRUE);
  
  gtk_widget_show_all (window);
}

int main (int argc, char **argv)
{
  GtkApplication *app;
  int status;

  app = gtk_application_new ("org.gtk.example", G_APPLICATION_FLAGS_NONE);
  g_signal_connect (app, "activate", G_CALLBACK (activate), NULL);
  status = g_application_run (G_APPLICATION (app), argc, argv);
  g_object_unref (app);

  return status;
}
