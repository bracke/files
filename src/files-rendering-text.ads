with Ada.Real_Time;

with Guikit.Draw;

--  Text for the frames Files.Rendering builds: the fonts and glyph atlas a
--  text configuration loads, pooled across the windows that share it, and
--  each window's text -- loaded once, retried after a pause when the load
--  fails, its glyphs reused while the frame's text and the atlas stay the
--  same.
package Files.Rendering.Text is

   --  Text rasterization outcome and glyph/atlas result, Guikit.Draw's.
   subtype Text_Render_Status is Guikit.Draw.Text_Render_Status;

   --  Re-export of the successful text-rasterization status literal.
   --  @return The Text_Render_Success value from Guikit.Draw.
   function Text_Render_Success return Text_Render_Status
     renames Guikit.Draw.Text_Render_Success;

   subtype Text_Render_Result is Guikit.Draw.Text_Render_Result;

   --  How long a window waits before loading its text again after a load
   --  failed at its size: not on every frame, nor never.
   Retry_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (5);

   --  A window's text: its renderer, whether the fonts are loaded, when a
   --  failed load is tried again, and the glyphs of the frame text it drew
   --  last.
   type Window_Text is private;

   --  Whether the window's text is to be loaded now: it is not loaded, and
   --  a load never failed at Pixel_Size or failed Retry_Interval ago.
   --
   --  @param Text The window's text.
   --  @param Pixel_Size The size the window draws text at.
   --  @param Now The current time.
   --  @return True when Ensure_Loaded would load.
   function Retry_Due
     (Text       : Window_Text;
      Pixel_Size : Positive;
      Now        : Ada.Real_Time.Time)
      return Boolean;

   --  Load the window's fonts at Pixel_Size when Retry_Due: cheap when
   --  another window already holds the size. A failure is remembered, so
   --  the next try waits for Retry_Interval or another size.
   --
   --  @param Text The window's text.
   --  @param Font_Path TrueType font path.
   --  @param Pixel_Size The size the window draws text at.
   --  @param Now The current time.
   procedure Ensure_Loaded
     (Text       : in out Window_Text;
      Font_Path  : String;
      Pixel_Size : Positive;
      Now        : Ada.Real_Time.Time);

   --  Forget the loaded fonts and the glyphs: the size changed, or the next
   --  frame is to load and build them again.
   --
   --  @param Text The window's text.
   procedure Invalidate (Text : in out Window_Text);

   --  The glyphs for Frame's text: those of the last frame when its text is
   --  the same and the atlas they index is still the renderer's, built
   --  otherwise; none while the fonts are not loaded. A renderer whose
   --  pooled fonts went to another size and did not load again counts as a
   --  failed load.
   --
   --  @param Text The window's text.
   --  @param Frame The frame to draw.
   --  @param Now The current time.
   --  @return The glyph draw commands and atlas state.
   function Glyphs_For
     (Text  : in out Window_Text;
      Frame : Frame_Commands;
      Now   : Ada.Real_Time.Time)
      return Text_Render_Result;

private

   --  A window's handle on a pooled text renderer (fonts and glyph atlas of
   --  one configuration), reached by the window only through Window_Text;
   --  tests reach it through Files.Rendering.Text.Testing.
   type Text_Renderer is record
      Loaded       : Boolean := False;
      --  The pooled renderer it draws with, and the configuration that
      --  renderer must have (another window may have taken the slot since).
      Slot         : Natural := 0;
      Key          : UString;
      Pixel_Size   : Positive := 16;
      Font_Path    : UString;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive := Guikit.Layout.Reference_Line_Height;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024;
   end record;

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
   --  Pixel_Size (Cell_Width_For, Cell_Height_For).
   --
   --  @param Renderer Renderer state to initialize.
   --  @param Font_Path TrueType font path.
   --  @param Pixel_Size Glyph rasterization size in pixels.
   --  @return Text render initialization status.
   function Initialize_Text
     (Renderer   : in out Text_Renderer;
      Font_Path  : String;
      Pixel_Size : Positive)
      return Text_Render_Status is
     (Initialize_Text
        (Renderer, Font_Path, Pixel_Size,
         Cell_Width  => Cell_Width_For (Pixel_Size),
         Cell_Height => Cell_Height_For (Pixel_Size)));

   --  Whether glyphs built earlier for Renderer still index the atlas its
   --  renderer holds now. Renderers are shared by windows of one size, and
   --  another window's text can grow, empty or reload the atlas: glyphs from
   --  before then point at an atlas that is gone, so they are built again.
   --
   --  @param Renderer The window's text renderer.
   --  @param Glyphs Glyphs Build_Text_Glyphs returned for it.
   --  @return True when Glyphs may be drawn and uploaded as they are.
   function Text_Glyphs_Current (Renderer : Text_Renderer; Glyphs : Text_Render_Result) return Boolean;

   --  Rasterize frame text commands into glyph draw commands.
   --
   --  This uses textrender glyph metrics and atlas coordinates. Text commands
   --  are decoded from UTF-8 before glyph lookup.
   --
   --  @param Renderer Initialized text renderer.
   --  @param Frame Frame command list containing text commands.
   --  @return Glyph draw commands and atlas state.
   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result;

   --  Whether Renderer has its fonts: False after an initialization, or a
   --  reload when its pooled renderer went to another size, failed.
   --
   --  @param Renderer The window's text renderer.
   --  @return True when Build_Text_Glyphs can draw with it.
   function Text_Loaded (Renderer : Text_Renderer) return Boolean;

   type Window_Text is record
      Renderer    : Text_Renderer;
      Ready       : Boolean := False;
      --  The size a load last failed at, or 0, and when.
      Failed_Size : Natural := 0;
      Failed_At   : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  The text Glyphs were built from, while Glyphs_Valid: equal text
      --  commands reuse the glyphs.
      Glyph_Text         : Guikit.Draw.Text_Command_Vectors.Vector;
      Glyph_Overlay_Text : Guikit.Draw.Text_Command_Vectors.Vector;
      Glyphs_Valid       : Boolean := False;
      Glyphs             : Text_Render_Result;
   end record;

end Files.Rendering.Text;
