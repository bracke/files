separate (Files_Suite.Rendering)
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Renderer : Text_Renderer;
      Result   : Guikit.Draw.Text_Render_Result;
   begin
      Assert (Files.Fonts.Default_Font_Path /= "", "a default text font is available");
      Assert
        (Initialize_Text
           (Renderer    => Renderer,
            Font_Path   => Files.Fonts.Default_Font_Path,
            Pixel_Size  => 16,
            Cell_Width  => 10,
            Cell_Height => 20) = Guikit.Draw.Text_Render_Success,
         "the text renderer loads the default font");
      Result := Build_Text_Glyphs (Renderer, Frame);
      Assert (Result.Status = Guikit.Draw.Text_Render_Success, "frame text rasterizes through textrender");
      Assert (Natural (Result.Glyphs.Length) > 0, "the text renderer emits glyph draw commands");
      Assert (Result.Atlas_Pixels /= System.Null_Address, "the text renderer exposes an atlas");
   end Test_Text_Glyph_Rasterization;
