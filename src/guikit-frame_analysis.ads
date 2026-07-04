with Interfaces;

--  Structural analysis of a presented framebuffer.
--
--  This package is intentionally platform-agnostic: it depends on no GPU,
--  windowing, or Vulkan facilities and operates purely on an in-memory RGBA
--  byte buffer. It exists so the live GPU smoke test can turn a raw
--  framebuffer readback into an asserted structural verdict, and so that
--  verdict can be unit tested with synthetic in-memory buffers.
--
--  The metrics are deliberately design-independent: they survive palette,
--  margin, and layout tweaks yet still catch genuine display failures such as
--  a blank frame, a single flat color, or a whole region (toolbar, main area,
--  bottom bar) that failed to draw.
package Guikit.Frame_Analysis is

   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;
   --  A raw framebuffer payload, one 8-bit component per element.

   type Pixel_Format is (Pixel_Format_RGBA8);
   --  Supported framebuffer pixel layouts. RGBA8 stores four 8-bit
   --  components per pixel in red, green, blue, alpha order.

   Band_Count : constant := 3;
   --  Number of horizontal bands the frame is split into for per-region
   --  content checks (top/toolbar, middle/main area, bottom/bottom-bar).

   type Band_Index is range 1 .. Band_Count;

   type Band_Content_Array is array (Band_Index) of Boolean;

   type Frame_Metrics is record
      Analyzed            : Boolean := False;
      --  True when the input buffer was well-formed and metrics are valid.
      Width               : Natural := 0;
      Height              : Natural := 0;
      Total_Pixels        : Natural := 0;
      Distinct_Colors     : Natural := 0;
      --  Estimated count of distinct quantized colors present in the frame.
      Background_Fraction : Float := 1.0;
      --  Fraction of pixels sharing the single most common quantized color.
      Ink_Pixels          : Natural := 0;
      --  Count of pixels that differ strongly from the background color
      --  (text, icons, borders and other drawn content).
      Ink_Fraction        : Float := 0.0;
      Band_Has_Content    : Band_Content_Array := [others => False];
      --  Per-band flag: the band is non-uniform or holds non-background ink.
   end record;

   --  Analyze a raw framebuffer and return robust structural metrics.
   --
   --  The buffer is treated as Width x Height pixels in row-major order using
   --  Format. When the buffer is too small for the stated dimensions, or the
   --  dimensions are zero, the result is returned with Analyzed set to False.
   --
   --  @param Data Raw framebuffer bytes.
   --  @param Width Frame width in pixels.
   --  @param Height Frame height in pixels.
   --  @param Format Pixel layout of Data.
   --  @return Structural metrics describing the frame.
   function Analyze
     (Data   : Byte_Array;
      Width  : Natural;
      Height : Natural;
      Format : Pixel_Format := Pixel_Format_RGBA8)
      return Frame_Metrics;

   --  Return whether every band in Metrics holds drawn content.
   --
   --  @param Metrics Structural metrics produced by Analyze.
   --  @return True when no band is empty.
   function All_Bands_Have_Content (Metrics : Frame_Metrics) return Boolean;

   --  Return the number of bands in Metrics that hold drawn content.
   --
   --  @param Metrics Structural metrics produced by Analyze.
   --  @return Count of bands flagged with content.
   function Bands_With_Content (Metrics : Frame_Metrics) return Natural;

   --  Return the structural pass verdict for Metrics.
   --
   --  A frame passes when it was analyzed, is not blank (has several distinct
   --  colors), its most common color does not cover the whole frame, it holds
   --  a meaningful amount of ink, and every band holds content. The thresholds
   --  are lenient enough to survive design changes yet strict enough to fail a
   --  blank frame or one where a whole region is missing.
   --
   --  @param Metrics Structural metrics produced by Analyze.
   --  @return True when the frame passes the structural checks.
   function Passed (Metrics : Frame_Metrics) return Boolean;

   Default_Region_Ink_Fraction : constant Float := 0.01;
   --  Lenient default ink-presence threshold for Region_Has_Ink: a region is
   --  considered to hold drawn content when at least this fraction of its
   --  pixels differ strongly from the frame background. Chosen low enough that
   --  anti-aliasing and theme changes do not flake, yet strictly above zero so
   --  a fully empty (background-only) region fails.

   --  Return the fraction of "ink" pixels inside a rectangular region.
   --
   --  The rectangle (X, Y) .. (X + W, Y + H) is interpreted in the same
   --  row-major framebuffer pixel coordinates as Analyze and clamped to the
   --  frame. A pixel is "ink" when it differs strongly from the frame's
   --  background reference color, using the identical background and ink logic
   --  Analyze applies, so a layout-derived rectangle can be indexed straight
   --  into a read-back framebuffer to prove an element rendered there.
   --
   --  When the buffer is malformed for the stated dimensions, the region is
   --  empty, or the region lies fully outside the frame, the result is 0.0.
   --
   --  @param Data Raw framebuffer bytes.
   --  @param Width Frame width in pixels.
   --  @param Height Frame height in pixels.
   --  @param Format Pixel layout of Data.
   --  @param X Left edge of the region in frame pixels.
   --  @param Y Top edge of the region in frame pixels.
   --  @param W Region width in pixels.
   --  @param H Region height in pixels.
   --  @return Fraction (0.0 .. 1.0) of clamped-region pixels that are ink.
   function Region_Ink_Fraction
     (Data   : Byte_Array;
      Width  : Natural;
      Height : Natural;
      Format : Pixel_Format := Pixel_Format_RGBA8;
      X      : Natural;
      Y      : Natural;
      W      : Natural;
      H      : Natural)
      return Float;

   --  Return whether a rectangular region holds drawn content (ink).
   --
   --  This is Region_Ink_Fraction thresholded by Min_Fraction. An empty or
   --  out-of-range region returns False.
   --
   --  @param Data Raw framebuffer bytes.
   --  @param Width Frame width in pixels.
   --  @param Height Frame height in pixels.
   --  @param Format Pixel layout of Data.
   --  @param X Left edge of the region in frame pixels.
   --  @param Y Top edge of the region in frame pixels.
   --  @param W Region width in pixels.
   --  @param H Region height in pixels.
   --  @param Min_Fraction Minimum ink fraction for the region to count as drawn.
   --  @return True when the region's ink fraction is at least Min_Fraction.
   function Region_Has_Ink
     (Data         : Byte_Array;
      Width        : Natural;
      Height       : Natural;
      Format       : Pixel_Format := Pixel_Format_RGBA8;
      X            : Natural;
      Y            : Natural;
      W            : Natural;
      H            : Natural;
      Min_Fraction : Float := Default_Region_Ink_Fraction)
      return Boolean;

end Guikit.Frame_Analysis;
