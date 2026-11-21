with Files.Preference_Types;
separate (Files.Rendering.Build_Frame_Commands)
   --  The window's chrome under everything else: the canvas, the toolbar,
   --  main-view, bottom-bar and info-pane backgrounds and their borders, and
   --  the window, toolbar and main-view accessibility nodes.
   procedure Draw_Window_Chrome is
   begin
      Result.Layout := Layout;
      Result.Theme_Palette := Snapshot.Theme_Palette;

      Add_Rect (0, 0, Width, Height, Canvas_Color);
      Add_Rect (0, 0, Width, Layout.Toolbar_Height, Toolbar_Color);
      Add_Rect (Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height, Main_Color);
      Add_Rect (0, Bottom_Y, Width, Layout.Bottom_Bar_Height, Bottom_Bar_Color);
      if Layout.Toolbar_Height > 0 then
         Add_Rect (0, Layout.Toolbar_Height - 1, Width, 1, Border_Color);
      end if;
      Add_Rect (0, Bottom_Y, Width, 1, Border_Color);
      Add_Accessibility_Node
        (Role_Window,
         0,
         0,
         Width,
         Height,
         Snapshot.Current_Path);
      Add_Accessibility_Node
        (Role_Toolbar,
         0,
         0,
         Width,
         Layout.Toolbar_Height,
         Localized ("accessibility.toolbar"));
      Add_Accessibility_Node
        ((if Snapshot.View_Mode = Files.Preference_Types.Details then Role_Table else Role_List),
         Layout.Main_X,
         Layout.Main_Y,
         Layout.Main_Width,
         Layout.Main_Height,
         Localized ("accessibility.main_view"),
         Main_View_Accessible_Description (Snapshot));

      if Layout.Info_Pane_Width > 0 then
         Add_Rect
           (Guikit.Layout.Saturating_Add (Layout.Main_X, Layout.Main_Width),
            Layout.Main_Y,
            Layout.Info_Pane_Width,
            Layout.Main_Height,
            Pane_Color);
         Add_Rect
           (Guikit.Layout.Saturating_Add (Layout.Main_X, Layout.Main_Width),
            Layout.Main_Y,
            1,
            Layout.Main_Height,
            Border_Color);
      end if;
   end Draw_Window_Chrome;
