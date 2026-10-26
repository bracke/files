separate (Files_Suite.Rendering)
   --  Of the pooled text renderers, the one used least recently is reloaded
   --  for a new configuration -- also when the others were only drawn with,
   --  not loaded, since.
   procedure Test_Text_Pool_Evicts_Least_Recent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame     : constant Frame_Commands := Build_Frame_Commands
        (Sample_Snapshot (2, Files.Types.Small_Icons), Width => 800, Height => 600, Line_Height => 20);
      Renderers : array (1 .. 5) of Text_Renderer;
      Glyphs    : array (1 .. 5) of Files.Rendering.Text_Render_Result;
   begin
      --  Four sizes no other test uses fill the pool.
      for Index in 1 .. 4 loop
         Assert (Initialize_Text (Renderers (Index), Files.Fonts.Default_Font_Path, 30 + Index, 18, 36)
                   = Guikit.Draw.Text_Render_Success, "a renderer loads");
      end loop;
      --  The first three draw after the fourth was loaded.
      for Index in 1 .. 3 loop
         Glyphs (Index) := Build_Text_Glyphs (Renderers (Index), Frame);
      end loop;
      Assert (Initialize_Text (Renderers (5), Files.Fonts.Default_Font_Path, 35, 18, 36)
                = Guikit.Draw.Text_Render_Success, "a fifth configuration loads");
      for Index in 1 .. 3 loop
         Assert (Text_Glyphs_Current (Renderers (Index), Glyphs (Index)),
                 "a renderer drawn with since keeps its place:" & Index'Image);
      end loop;
      Glyphs (4) := Build_Text_Glyphs (Renderers (4), Frame);
      Assert (Glyphs (4).Status = Guikit.Draw.Text_Render_Success, "the evicted one loads again when it draws");
   end Test_Text_Pool_Evicts_Least_Recent;
