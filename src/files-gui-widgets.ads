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

   --  One cell's label for a segmented selector: the display text (already
   --  localized and fitted to the cell width by the caller) and whether that
   --  fitting truncated it. An empty Text draws no label for that cell -- the
   --  fill and border still draw -- letting the caller suppress a label that is
   --  fully clipped or covered by an overlay while keeping the cell box.
   type Segment_Label is record
      Text      : Files.Gui.Draw.UString;
      Truncated : Boolean := False;
   end record;

   --  One-based row of segment labels; its length is the number of cells drawn.
   type Segment_Label_Array is array (Positive range <>) of Segment_Label;

   --  Draw a horizontal segmented cycling selector: a row of cells, each a
   --  filled, bordered box with a left-aligned label inset by Padding. Cell
   --  widths come from Content_Width / Cell_Count; the cell whose zero-based
   --  offset equals Cell_Count - 1 absorbs the integer-division remainder so a
   --  full row of cells spans exactly Content_Width. Cell_Count is the grid
   --  divisor, which may exceed Labels'Length: a caller that draws fewer cells
   --  than the divisor (so no drawn cell is the remainder cell) leaves the
   --  cells at the uniform Content_Width / Cell_Count width. The cell whose
   --  one-based index equals Active_Index is filled with Active_Color; the rest
   --  with Inactive_Color (Active_Index = 0 draws none active). Cells of zero
   --  width are skipped. The caller resolves the labels, the active index, and
   --  the colors, and registers any hit regions; the widget only emits pixels.
   --
   --  @param Rectangles Rectangle command vector for the fills and borders.
   --  @param Text Text command vector for the labels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Row left edge in pixels.
   --  @param Box_Y Top edge of each cell's fill and border in pixels.
   --  @param Label_Y Top edge of each cell's label in pixels.
   --  @param Content_Width Total row width in pixels; cell width is this over
   --    Cell_Count and nothing is drawn when zero.
   --  @param Cell_Count Grid divisor for the cell width and remainder cell.
   --  @param Height Height of each cell and its label in pixels.
   --  @param Labels One label per drawn cell, at offsets 0 .. Labels'Length - 1.
   --  @param Active_Index One-based index of the active cell, or 0 for none.
   --  @param Active_Color Fill color of the active cell.
   --  @param Inactive_Color Fill color of the inactive cells.
   --  @param Border_Color Cell border color.
   --  @param Label_Color Label text color.
   --  @param Padding Left inset of each label from its cell edge in pixels.
   procedure Draw_Segmented
     (Rectangles     : in out Files.Gui.Draw.Rectangle_Command_Vectors.Vector;
      Text           : in out Files.Gui.Draw.Text_Command_Vectors.Vector;
      Clip_Width     : Natural;
      Clip_Height    : Natural;
      X              : Natural;
      Box_Y          : Natural;
      Label_Y        : Natural;
      Content_Width  : Natural;
      Cell_Count     : Natural;
      Height         : Natural;
      Labels         : Segment_Label_Array;
      Active_Index   : Natural;
      Active_Color   : Files.Gui.Draw.Render_Color;
      Inactive_Color : Files.Gui.Draw.Render_Color;
      Border_Color   : Files.Gui.Draw.Render_Color;
      Label_Color    : Files.Gui.Draw.Render_Color;
      Padding        : Natural);

   --  Draw a vertical scrollbar: a full-height track rectangle with a thumb
   --  rectangle painted on top of it, the thumb outlined by a one-pixel border
   --  and -- when it is at least seven pixels tall and the track is wide enough
   --  for a grip -- three horizontal grip lines centered on the thumb. The
   --  caller computes the track and thumb geometry from the scroll offset and
   --  content height, resolves the theme colors, decides visibility, and
   --  registers any drag hit region; the widget only emits the rectangles.
   --
   --  @param Rectangles Rectangle command vector to append the scrollbar to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Track_X Left edge of the track and thumb in pixels.
   --  @param Track_Y Track top edge in pixels.
   --  @param Track_Width Width of both the track and the thumb in pixels.
   --  @param Track_Height Track height in pixels.
   --  @param Thumb_Y Thumb top edge in pixels.
   --  @param Thumb_Height Thumb height in pixels.
   --  @param Track_Color Track fill color; also used for the thumb's border.
   --  @param Thumb_Color Thumb fill color.
   --  @param Grip_Color Color of the three grip lines.
   procedure Draw_Scrollbar
     (Rectangles   : in out Files.Gui.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      Track_X      : Natural;
      Track_Y      : Natural;
      Track_Width  : Natural;
      Track_Height : Natural;
      Thumb_Y      : Natural;
      Thumb_Height : Natural;
      Track_Color  : Files.Gui.Draw.Render_Color;
      Thumb_Color  : Files.Gui.Draw.Render_Color;
      Grip_Color   : Files.Gui.Draw.Render_Color);

end Files.Gui.Widgets;
