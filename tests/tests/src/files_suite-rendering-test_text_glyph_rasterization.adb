with Files.Text_Case;
with Files.Preference_Types;
with Files.Rendering.Text.Testing; use Files.Rendering.Text.Testing;
separate (Files_Suite.Rendering)
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Preference_Types.Details);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Renderer : Text_Renderer;
      Result   : Guikit.Draw.Text_Render_Result;
   begin
      Assert (Files.Fonts.Default_Font_Path /= "", "a default text font is available");
      --  Font discovery offers no TrueType collection: the text renderer
      --  cannot initialize a .ttc, and a frame that fell back to one would
      --  draw no text at all.
      declare
         function Is_Collection (Path : String) return Boolean is
           (Path'Length >= 4
            and then Files.Text_Case.Fold_Case (Path (Path'Last - 3 .. Path'Last)) = ".ttc");
      begin
         Assert (not Is_Collection (Files.Fonts.Default_Font_Path),
                 "the default font is no collection: " & Files.Fonts.Default_Font_Path);
         for Path of Files.Fonts.Fallback_Font_Paths loop
            Assert (not Is_Collection (To_String (Path)), "no fallback font is a collection: " & To_String (Path));
         end loop;
      end;
      Assert
        (Initialize_Text
           (Renderer    => Renderer,
            Font_Path   => Files.Fonts.Default_Font_Path,
            Pixel_Size  => 16) = Guikit.Draw.Text_Render_Success,
         "the text renderer loads the default font");
      Result := Build_Text_Glyphs (Renderer, Frame);
      Assert (Result.Status = Guikit.Draw.Text_Render_Success, "frame text rasterizes through textrender");
      Assert (Natural (Result.Glyphs.Length) > 0, "the text renderer emits glyph draw commands");
      Assert (Result.Atlas_Pixels /= System.Null_Address, "the text renderer exposes an atlas");
   end Test_Text_Glyph_Rasterization;
