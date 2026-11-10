separate (Files.Rendering)
   function Calculate_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := Files.UI.Base_Line_Height)
      return Layout_Metrics
   is
      Toolbar    : constant Natural := Files.UI.Toolbar_Height (Line_Height);
      Bottom     : constant Natural :=
        Files.UI.Bottom_Bar_Height (Line_Height);
      Used_Y     : constant Natural := Saturating_Add (Toolbar, Bottom);
      Main_H     : constant Natural := (if Height > Used_Y then Height - Used_Y else 0);
      --  A quarter-width pane is too narrow for ordinary metadata at the
      --  default window size (dates and short prose wrap after only a handful
      --  of words). Prefer sixteen text rows' worth of width while retaining
      --  at least half of the window for the file view on compact windows.
      Pane_W     : constant Natural :=
        (if not Snapshot.Info_Pane_Open
         then 0
         else Natural'Min
           (Width / 2,
            Natural'Max (Width / 4, Saturating_Multiply (Line_Height, 16))));
      Beside_W   : constant Natural := (if Width > Pane_W then Width - Pane_W else 0);
      --  The folder tree takes the view's left side rather than covering it,
      --  so nothing in the view can be selected unseen beneath it: a quarter
      --  of the window or sixteen rows' worth, at most half what is left.
      Tree_W     : constant Natural :=
        (if not Snapshot.Tree_Panel_Open
         then 0
         else Natural'Min
           (Beside_W / 2,
            Natural'Max (Width / 4, Saturating_Multiply (Line_Height, 16))));
      Main_W     : constant Natural := Beside_W - Tree_W;
      Command_W  : constant Natural := Scaled_Down (Width, 8, 10);
      Command_H  : constant Natural := Scaled_Down (Height, 8, 10);
      Command_X  : constant Natural := (if Width > Command_W then (Width - Command_W) / 2 else 0);
      Command_Y  : constant Natural :=
        (if Height > Command_H then Natural'Min (Line_Height, Height - Command_H) else 0);
   begin
      return
        (Width             => Width,
         Height            => Height,
         Toolbar_Height    => Toolbar,
         Bottom_Bar_Height => Bottom,
         Main_X            => Tree_W,
         Main_Y            => Toolbar,
         Main_Width        => Main_W,
         Main_Height       => Main_H,
         Info_Pane_Width   => Pane_W,
         Command_X         => Command_X,
         Command_Y         => Command_Y,
         Command_Width     => Command_W,
         Command_Height    => Command_H);
   end Calculate_Layout;
