separate (Files.Rendering.Layouts)
   function Calculate_Frame_Layout
     (Snapshot : View_Snapshot; Width : Natural; Height : Natural; Line_Height : Positive) return Frame_Layout
   is
      Layout     : constant Layout_Metrics := Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Input_Y    : constant Natural := Guikit.Layout.Toolbar_Input_Y (Line_Height);
      Input_H    : constant Natural := Guikit.Layout.Toolbar_Input_Height (Line_Height);
      Bottom_Y   : constant Natural := Bottom_Bar_Y (Height, Line_Height);
      Bottom_Pad : constant Natural := Guikit.Layout.Scaled (Guikit.Layout.Bottom_Bar_Padding, Line_Height);
   begin
      return
        (Layout               => Layout,
         Main_View            => Calculate_Main_View_Layout (Snapshot, Layout, Line_Height),
         Toolbar              => Guikit.Layout.Calculate_Toolbar_Layout (Width, Line_Height),
         Bottom               => Calculate_Bottom_Bar_Layout (Width, Snapshot.Sort_Field, Line_Height),
         Palette              => Calculate_Command_Palette_Layout (Layout, Line_Height),
         Root_Selector        => Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height),
         Tree_Panel           => Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height),
         Info_Pane            => Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height),
         Settings_Pane        => Settings_Pane_Region (Layout, Line_Height),
         Toolbar_Input_Y      => Input_Y,
         Toolbar_Input_H      => Input_H,
         Toolbar_Input_Text_Y =>
           (if Input_H > Line_Height
            then Optically_Raised (Guikit.Layout.Saturating_Add (Input_Y, (Input_H - Line_Height) / 2), Line_Height)
            else Input_Y),
         Toolbar_Input_Text_H => Natural'Min (Line_Height, Input_H),
         Bottom_Y             => Bottom_Y,
         Bottom_Content_Y     => Guikit.Layout.Saturating_Add (Bottom_Y, Optically_Raised (Bottom_Pad, Line_Height)),
         Bottom_Content_H     =>
           (if Layout.Bottom_Bar_Height > Guikit.Layout.Saturating_Multiply (Bottom_Pad, 2)
            then Layout.Bottom_Bar_Height - Guikit.Layout.Saturating_Multiply (Bottom_Pad, 2)
            else Layout.Bottom_Bar_Height));
   end Calculate_Frame_Layout;
