// Taken from the docs at gtk.org

#include <gtk/gtk.h>

GtkWidget *muteButton;
GtkWidget *unmuteButton;

static void print (GtkWidget *widget, gpointer data)
{
  g_print (data);
  g_print ("\n");
}

static void set_mute (GtkWidget *widget, gpointer data)
{
  gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(muteButton), data)
  gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(muteButton), ! data)
}

static GtkWidget* new_button (gchar *label, gchar *output)
{
  GtkWidget *button;
  button = gtk_button_new_with_label (label);
  g_signal_connect (button, "clicked", G_CALLBACK (print), output);
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

  muteButton = gtk_toggle_button_new_with_label("Mute");
  unmuteButton = gtk_toggle_button_new_with_label("Unmute");
  g_signal_connect (muteButton, "clicked", G_CALLBACK (print), "mute");
  g_signal_connect (unmuteButton, "clicked", G_CALLBACK (print), "unmute");
  g_object_bind_property (G_OBJECT(muteButton), "active", G_OBJECT(unmuteButton), "active", G_BINDING_INVERT_BOOLEAN);
  g_object_bind_property (G_OBJECT(unmuteButton), "active", G_OBJECT(muteButton), "active", G_BINDING_INVERT_BOOLEAN);

  GtkWidget *blackButton = new_button("Black", "black");
  GtkWidget *splashButton = new_button("Splash", "splash");
  GtkWidget *webcamButton = new_button("Webcam", "stream");
  GtkWidget *mediaButton = new_button("Media", "open");

  g_signal_connect (blackButton, "clicked", G_CALLBACK (set_mute), TRUE);
  g_signal_connect (splashButton, "clicked", G_CALLBACK (set_mute), FALSE);
  g_signal_connect (webcamButton, "clicked", G_CALLBACK (set_mute), FALSE);
  g_signal_connect (mediaButton, "clicked", G_CALLBACK (set_mute), FALSE);

  gtk_grid_attach (GTK_GRID (grid), blackButton,                            0,0, 1,1);
  gtk_grid_attach (GTK_GRID (grid), splashButton,                           1,0, 1,1);
  gtk_grid_attach (GTK_GRID (grid), webcamButton,                           2,0, 1,1);

  gtk_grid_attach (GTK_GRID (grid), mediaButton,                            0,1, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Pause", "pause"),           1,1, 1,1);
  gtk_grid_attach (GTK_GRID (grid), new_button("Resume", "resume"),         2,1, 1,1);

  gtk_grid_attach (GTK_GRID (grid), muteButton,                             0,2, 1,1);
  gtk_grid_attach (GTK_GRID (grid), unmuteButton,                           1,2, 1,1);
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
