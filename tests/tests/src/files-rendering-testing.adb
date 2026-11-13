package body Files.Rendering.Testing is

   function Label_Render_Color
     (Label : Files.Types.Color_Label)
      return Guikit.Draw.Render_Color
     renames Files.Rendering.Label_Render_Color;

   function Any_Overlay_Open (Snapshot : View_Snapshot) return Boolean
     renames Files.Rendering.Any_Overlay_Open;

   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
     renames Files.Rendering.Context_Menu_Row_Top;

   function Context_Menu_Row_Left
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
     renames Files.Rendering.Context_Menu_Row_Left;

   function Context_Menu_Row_Width
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
     renames Files.Rendering.Context_Menu_Row_Width;

   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout
     renames Files.Rendering.Calculate_Paste_Progress_Layout;

end Files.Rendering.Testing;
