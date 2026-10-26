separate (Files_Suite.Rendering)
   --  Windows of one size share a text renderer. Glyphs one window built are
   --  reused while its text is unchanged -- but not once another window's
   --  text has packed new glyphs into the shared atlas: they index an atlas
   --  that has changed (it may have grown, and its old buffer been freed).
   procedure Test_Shared_Text_Renderer_Invalidates_Glyphs (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  A size no other test uses, so this test has the renderer to itself.
      Size      : constant := 17;
      First     : Text_Renderer;
      Second    : Text_Renderer;
      Frame_A   : Frame_Commands;
      Frame_B   : Frame_Commands;
      Glyphs_A  : Guikit.Draw.Text_Render_Result;
      Glyphs_B  : Guikit.Draw.Text_Render_Result;

      function Line (Content : String) return Guikit.Draw.Text_Command is
         Cmd : Guikit.Draw.Text_Command;
      begin
         Cmd.Width := 400;
         Cmd.Height := 20;
         Cmd.Text := To_Unbounded_String (Content);
         return Cmd;
      end Line;
   begin
      Assert (Initialize_Text (First, Files.Fonts.Default_Font_Path, Size, 10, 21) = Guikit.Draw.Text_Render_Success,
              "the first window's text loads");
      Assert (Initialize_Text (Second, Files.Fonts.Default_Font_Path, Size, 10, 21) = Guikit.Draw.Text_Render_Success,
              "the second window of the same size shares it");
      Frame_A.Text.Append (Line ("abc"));
      Glyphs_A := Build_Text_Glyphs (First, Frame_A);
      Assert (Text_Glyphs_Current (First, Glyphs_A), "fresh glyphs are current");
      Frame_B.Text.Append (Line ("XYZ 0123456789"));
      Glyphs_B := Build_Text_Glyphs (Second, Frame_B);
      Assert (Text_Glyphs_Current (Second, Glyphs_B), "the second window's glyphs are current");
      Assert (not Text_Glyphs_Current (First, Glyphs_A),
              "the first window's glyphs are stale once the shared atlas changed");
   end Test_Shared_Text_Renderer_Invalidates_Glyphs;
