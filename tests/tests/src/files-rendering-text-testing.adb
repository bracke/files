package body Files.Rendering.Text.Testing is

   function Initialize_Text
     (Renderer     : in out Text_Renderer;
      Font_Path    : String;
      Pixel_Size   : Positive;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024)
      return Text_Render_Status is
     (Files.Rendering.Text.Initialize_Text
        (Renderer.Inner, Font_Path, Pixel_Size, Cell_Width, Cell_Height, Atlas_Width, Atlas_Height));

   function Initialize_Text
     (Renderer   : in out Text_Renderer;
      Font_Path  : String;
      Pixel_Size : Positive)
      return Text_Render_Status is
     (Files.Rendering.Text.Initialize_Text (Renderer.Inner, Font_Path, Pixel_Size));

   function Text_Glyphs_Current (Renderer : Text_Renderer; Glyphs : Text_Render_Result) return Boolean is
     (Files.Rendering.Text.Text_Glyphs_Current (Renderer.Inner, Glyphs));

   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result is
     (Files.Rendering.Text.Build_Text_Glyphs (Renderer.Inner, Frame));

end Files.Rendering.Text.Testing;
