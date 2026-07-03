with Files.Gui.Draw;

--  Domain-free drawing of simple, self-contained widgets.
--
--  Each procedure draws pixels for one visual widget by appending draw
--  commands to caller-supplied Files.Gui.Draw command vectors. Everything a
--  widget needs -- geometry (in pixels), clip bounds, and semantic colors --
--  is passed explicitly, so this package has no dependency on any file-manager
--  domain package (model, settings, localization, rendering, ...). Callers own
--  all policy: they compute geometry, resolve theme colors, decide visibility,
--  and register hit regions or accessibility nodes. The widget only emits the
--  rectangles and text.
--
--  Coordinates and sizes are window pixels. Clip_Width and Clip_Height give
--  the drawable window bounds; each emitted rectangle or text run is clipped to
--  them and dropped when it would be empty, matching the renderer's primitives.
package Files.Gui.Widgets is

   --  Draw a focus ring: a one-pixel border around the given box, plus a
   --  second border one pixel outside it when the box is not flush against the
   --  top-left window edge. Emits into a base-layer rectangle vector.
   --
   --  @param Rectangles Rectangle command vector to append the ring to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Ring left edge in pixels.
   --  @param Y Ring top edge in pixels.
   --  @param Width Ring width in pixels; nothing is drawn when zero.
   --  @param Height Ring height in pixels; nothing is drawn when zero.
   --  @param Color Ring color.
   procedure Draw_Focus_Ring
     (Rectangles  : in out Files.Gui.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Files.Gui.Draw.Render_Color);

   --  Draw a drop shadow along the bottom and right edges of a box: a
   --  horizontal band below it and a vertical band to its right, both offset by
   --  three pixels.
   --
   --  @param Rectangles Rectangle command vector to append the shadow to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Box left edge in pixels.
   --  @param Y Box top edge in pixels.
   --  @param Width Box width in pixels; nothing is drawn when zero.
   --  @param Height Box height in pixels; nothing is drawn when zero.
   --  @param Color Shadow color.
   procedure Draw_Drop_Shadow
     (Rectangles  : in out Files.Gui.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Files.Gui.Draw.Render_Color);

   --  Draw a panel close button: a filled, bordered square with the close
   --  glyph centered inside it. The rectangles and the glyph are appended to
   --  the supplied vectors (pass the base or the overlay vectors to target the
   --  desired layer). The caller resolves the fill color from hover/press
   --  state, computes the glyph geometry and its visibility, and registers the
   --  accessibility node.
   --
   --  @param Rectangles Rectangle command vector for the box (fill + border).
   --  @param Text Text command vector for the glyph.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Button_X Button left edge in pixels.
   --  @param Button_Y Button top edge in pixels.
   --  @param Button_Width Button width in pixels.
   --  @param Button_Height Button height in pixels.
   --  @param Fill_Color Button background color.
   --  @param Border_Color Button border color.
   --  @param Glyph_X Glyph cell left edge in pixels.
   --  @param Glyph_Y Glyph cell top edge in pixels.
   --  @param Glyph_Width Glyph cell width in pixels.
   --  @param Glyph_Height Glyph cell height in pixels.
   --  @param Glyph Close glyph text.
   --  @param Glyph_Color Glyph color.
   --  @param Show_Glyph When False, the glyph is not drawn (the box still is).
   procedure Draw_Close_Button
     (Rectangles    : in out Files.Gui.Draw.Rectangle_Command_Vectors.Vector;
      Text          : in out Files.Gui.Draw.Text_Command_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Button_X      : Natural;
      Button_Y      : Natural;
      Button_Width  : Natural;
      Button_Height : Natural;
      Fill_Color    : Files.Gui.Draw.Render_Color;
      Border_Color  : Files.Gui.Draw.Render_Color;
      Glyph_X       : Natural;
      Glyph_Y       : Natural;
      Glyph_Width   : Natural;
      Glyph_Height  : Natural;
      Glyph         : Files.Gui.Draw.UString;
      Glyph_Color   : Files.Gui.Draw.Render_Color;
      Show_Glyph    : Boolean);

end Files.Gui.Widgets;
