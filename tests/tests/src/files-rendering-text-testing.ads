--  Test-only access to the pooled text renderer behind Files.Rendering.Text's
--  Window_Text: a renderer of a chosen configuration, its glyphs, and
--  whether glyphs built earlier still index its atlas. Kept out of the program.
package Files.Rendering.Text.Testing is

   --  A text renderer handle, as a window's Window_Text holds one.
   type Text_Renderer is private;

   --  Load the text renderer font and initialize the textrender atlas.
   --
   --  @param Renderer Renderer state to initialize.
   --  @param Font_Path TrueType font path.
   --  @param Pixel_Size Glyph rasterization size in pixels.
   --  @param Cell_Width Monospace cell width in pixels.
   --  @param Cell_Height Monospace cell height in pixels.
   --  @param Atlas_Width Glyph atlas width in pixels.
   --  @param Atlas_Height Glyph atlas height in pixels.
   --  @return Text render initialization status.
   function Initialize_Text
     (Renderer     : in out Text_Renderer;
      Font_Path    : String;
      Pixel_Size   : Positive;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024)
      return Text_Render_Status;

   --  Load the text renderer font with the text cell the layouts use for
   --  Pixel_Size.
   --
   --  @param Renderer Renderer state to initialize.
   --  @param Font_Path TrueType font path.
   --  @param Pixel_Size Glyph rasterization size in pixels.
   --  @return Text render initialization status.
   function Initialize_Text
     (Renderer   : in out Text_Renderer;
      Font_Path  : String;
      Pixel_Size : Positive)
      return Text_Render_Status;

   --  Whether glyphs built earlier for Renderer still index its atlas.
   --
   --  @param Renderer The text renderer.
   --  @param Glyphs Glyphs Build_Text_Glyphs returned for it.
   --  @return True when Glyphs may be drawn as they are.
   function Text_Glyphs_Current (Renderer : Text_Renderer; Glyphs : Text_Render_Result) return Boolean;

   --  Rasterize frame text commands into glyph draw commands.
   --
   --  @param Renderer Initialized text renderer.
   --  @param Frame Frame command list containing text commands.
   --  @return Glyph draw commands and atlas state.
   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result;

private

   type Text_Renderer is record
      Inner : Files.Rendering.Text.Text_Renderer;
   end record;

end Files.Rendering.Text.Testing;
