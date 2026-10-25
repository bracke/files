separate (Files_Suite.Rendering)
   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Renderer : Text_Renderer;
      Text     : Guikit.Draw.Text_Render_Result;
      Batch    : Guikit.Vulkan.Submission_Batch;
   begin
      Assert
        (Initialize_Text (Renderer, Files.Fonts.Default_Font_Path, 16, 10, 20) = Guikit.Draw.Text_Render_Success,
         "the text renderer initialises for submission");
      Text  := Build_Text_Glyphs (Renderer, Frame);
      Batch := Guikit.Vulkan.Build_Submission
        (Rectangles         => Frame.Rectangles,
         Triangles          => Frame.Triangles,
         Icons              => Frame.Icons,
         Overlay_Rectangles => Frame.Overlay_Rectangles,
         Layout             => Frame.Layout,
         Theme              => Frame.Theme_Palette,
         Text               => Text);
      Files_Suite.Support.Assert_Equal (Batch.Width, Frame.Layout.Width, "the vulkan batch preserves the frame width");
      Files_Suite.Support.Assert_Equal
        (Batch.Height,
         Frame.Layout.Height,
         "the vulkan batch preserves the frame height");
      Files_Suite.Support.Assert_Equal
        (Batch.Rectangle_Vertex_Count,
         Natural (Frame.Rectangles.Length) * 6,
         "each rectangle expands to two triangles (six vertices)");
      Assert (Batch.Glyph_Vertex_Count > 0, "rasterized glyphs reach the vulkan submission batch");
   end Test_Vulkan_Submission;
