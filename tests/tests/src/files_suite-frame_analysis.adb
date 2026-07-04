with Interfaces;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Frame_Analysis;

--  Structural framebuffer-analysis tests. These exercise the pure, GPU-free
--  analysis on synthetic in-memory RGBA buffers: a blank frame must fail, a
--  frame with distinct top/middle/bottom bands and scattered ink must pass,
--  and a frame with one empty band must fail. No display or Vulkan is needed.
package body Files_Suite.Frame_Analysis is

   use AUnit.Assertions;
   use Guikit.Frame_Analysis;
   use type Interfaces.Unsigned_8;

   Frame_Width  : constant := 64;
   Frame_Height : constant := 96;
   --  96 rows split cleanly into three 32-row bands.

   subtype Sample_Buffer is Byte_Array (1 .. Frame_Width * Frame_Height * 4);

   type Rendering_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Rendering_Test_Case);

   procedure Test_Uniform_Frame_Fails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Banded_Frame_Passes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Band_Fails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Region_Ink_Detection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Region_Clamping (T : in out AUnit.Test_Cases.Test_Case'Class);

   --  Write one RGBA pixel into Buffer at column X, row Y.
   procedure Set_Pixel
     (Buffer : in out Sample_Buffer;
      X, Y   : Natural;
      Red, Green, Blue : Interfaces.Unsigned_8)
   is
      Base : constant Positive := ((Y * Frame_Width) + X) * 4 + 1;
   begin
      Buffer (Base) := Red;
      Buffer (Base + 1) := Green;
      Buffer (Base + 2) := Blue;
      Buffer (Base + 3) := 255;
   end Set_Pixel;

   --  Fill the whole buffer with a single background color.
   procedure Fill_Background
     (Buffer : in out Sample_Buffer;
      Red, Green, Blue : Interfaces.Unsigned_8) is
   begin
      for Y in 0 .. Frame_Height - 1 loop
         for X in 0 .. Frame_Width - 1 loop
            Set_Pixel (Buffer, X, Y, Red, Green, Blue);
         end loop;
      end loop;
   end Fill_Background;

   --  Paint a run of bright ink pixels across one row of a band.
   procedure Paint_Ink_Row
     (Buffer : in out Sample_Buffer;
      Y      : Natural;
      Red, Green, Blue : Interfaces.Unsigned_8) is
   begin
      for X in 0 .. Frame_Width - 1 loop
         Set_Pixel (Buffer, X, Y, Red, Green, Blue);
      end loop;
   end Paint_Ink_Row;

   --  Fill a solid rectangle of pixels with one color.
   procedure Fill_Rect
     (Buffer : in out Sample_Buffer;
      X, Y, W, H : Natural;
      Red, Green, Blue : Interfaces.Unsigned_8) is
   begin
      for Row in Y .. Y + H - 1 loop
         for Column in X .. X + W - 1 loop
            Set_Pixel (Buffer, Column, Row, Red, Green, Blue);
         end loop;
      end loop;
   end Fill_Rect;

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files framebuffer structural analysis");
   end Name;

   overriding procedure Register_Tests (T : in out Rendering_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Uniform_Frame_Fails'Access, "a uniform blank frame fails the structural check");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Banded_Frame_Passes'Access, "a banded frame with scattered ink passes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Band_Fails'Access, "a frame with one empty band fails");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Region_Ink_Detection'Access,
         "an inked rectangle reports high region ink; a background region reports none");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Region_Clamping'Access,
         "region checks clamp safely for out-of-range and empty rectangles");
   end Register_Tests;

   procedure Test_Uniform_Frame_Fails (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Buffer  : Sample_Buffer;
      Metrics : Frame_Metrics;
   begin
      Fill_Background (Buffer, 60, 60, 60);
      Metrics := Analyze (Buffer, Frame_Width, Frame_Height);
      Assert (Metrics.Analyzed, "uniform frame is analyzed");
      Assert (Metrics.Distinct_Colors = 1, "uniform frame has one distinct color");
      Assert (Metrics.Background_Fraction >= 0.999, "uniform frame background covers the whole frame");
      Assert (Metrics.Ink_Pixels = 0, "uniform frame has no ink");
      Assert (not Passed (Metrics), "a uniform blank frame must not pass");
   end Test_Uniform_Frame_Fails;

   procedure Test_Banded_Frame_Passes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Buffer  : Sample_Buffer;
      Metrics : Frame_Metrics;
   begin
      Fill_Background (Buffer, 30, 30, 40);
      --  Top band (rows 0..31): white ink rows.
      Paint_Ink_Row (Buffer, 4, 255, 255, 255);
      Paint_Ink_Row (Buffer, 12, 255, 255, 255);
      Paint_Ink_Row (Buffer, 20, 255, 255, 255);
      --  Middle band (rows 32..63): red ink rows.
      Paint_Ink_Row (Buffer, 36, 220, 40, 40);
      Paint_Ink_Row (Buffer, 44, 220, 40, 40);
      Paint_Ink_Row (Buffer, 52, 220, 40, 40);
      --  Bottom band (rows 64..95): green ink rows.
      Paint_Ink_Row (Buffer, 68, 40, 200, 60);
      Paint_Ink_Row (Buffer, 76, 40, 200, 60);
      Paint_Ink_Row (Buffer, 84, 40, 200, 60);

      Metrics := Analyze (Buffer, Frame_Width, Frame_Height);
      Assert (Metrics.Analyzed, "banded frame is analyzed");
      Assert (Metrics.Distinct_Colors >= 4, "banded frame exposes several distinct colors");
      Assert (Metrics.Background_Fraction < 1.0, "background does not cover the whole banded frame");
      Assert (Metrics.Ink_Pixels > 0, "banded frame contains ink");
      Assert (All_Bands_Have_Content (Metrics), "every band of the frame holds content");
      Assert (Bands_With_Content (Metrics) = 3, "all three bands report content");
      Assert (Passed (Metrics), "a banded frame with scattered ink must pass");
   end Test_Banded_Frame_Passes;

   procedure Test_Empty_Band_Fails (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Buffer  : Sample_Buffer;
      Metrics : Frame_Metrics;
   begin
      Fill_Background (Buffer, 30, 30, 40);
      --  Top band: white ink.
      Paint_Ink_Row (Buffer, 4, 255, 255, 255);
      Paint_Ink_Row (Buffer, 12, 255, 255, 255);
      Paint_Ink_Row (Buffer, 20, 255, 255, 255);
      --  Middle band (rows 32..63): left entirely as background (missing region).
      --  Bottom band: green ink.
      Paint_Ink_Row (Buffer, 68, 40, 200, 60);
      Paint_Ink_Row (Buffer, 76, 40, 200, 60);
      Paint_Ink_Row (Buffer, 84, 40, 200, 60);

      Metrics := Analyze (Buffer, Frame_Width, Frame_Height);
      Assert (Metrics.Analyzed, "frame with an empty band is analyzed");
      Assert (not All_Bands_Have_Content (Metrics), "the empty middle band reports no content");
      Assert (Bands_With_Content (Metrics) = 2, "only two bands hold content");
      Assert (not Passed (Metrics), "a frame with a missing region must not pass");
   end Test_Empty_Band_Fails;

   procedure Test_Region_Ink_Detection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Buffer : Sample_Buffer;
      Inked_Rect_X : constant := 8;
      Inked_Rect_Y : constant := 40;
      Inked_Rect_W : constant := 24;
      Inked_Rect_H : constant := 16;
      Ink_Fraction    : Float;
      Background_Fraction : Float;
   begin
      --  A frame whose background dominates, with one bright solid rectangle
      --  painted in the middle band. The rectangle's own rectangle must read as
      --  almost fully inked, while a same-size rectangle over plain background
      --  reads as empty.
      Fill_Background (Buffer, 30, 30, 40);
      Fill_Rect
        (Buffer, Inked_Rect_X, Inked_Rect_Y, Inked_Rect_W, Inked_Rect_H,
         240, 240, 250);

      Ink_Fraction :=
        Region_Ink_Fraction
          (Buffer, Frame_Width, Frame_Height,
           X => Inked_Rect_X, Y => Inked_Rect_Y,
           W => Inked_Rect_W, H => Inked_Rect_H);
      Assert (Ink_Fraction > 0.9,
              "a rectangle painted with ink reports a near-full ink fraction");
      Assert
        (Region_Has_Ink
           (Buffer, Frame_Width, Frame_Height,
            X => Inked_Rect_X, Y => Inked_Rect_Y,
            W => Inked_Rect_W, H => Inked_Rect_H),
         "an inked rectangle is reported as holding ink");

      --  A background-only rectangle in the top band, well clear of the ink.
      Background_Fraction :=
        Region_Ink_Fraction
          (Buffer, Frame_Width, Frame_Height,
           X => 0, Y => 0, W => 16, H => 16);
      Assert (Background_Fraction < 0.01,
              "a background-only region reports essentially no ink");
      Assert
        (not Region_Has_Ink
           (Buffer, Frame_Width, Frame_Height,
            X => 0, Y => 0, W => 16, H => 16),
         "a background-only region is not reported as holding ink");
   end Test_Region_Ink_Detection;

   procedure Test_Region_Clamping (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Buffer : Sample_Buffer;
   begin
      Fill_Background (Buffer, 30, 30, 40);
      --  Ink pixels touching the far bottom-right corner, so a rectangle that
      --  overhangs the frame edge still clamps onto real inked pixels.
      Fill_Rect
        (Buffer, Frame_Width - 8, Frame_Height - 8, 8, 8, 250, 250, 250);

      --  A rectangle whose origin is outside the frame yields no ink.
      Assert
        (Region_Ink_Fraction
           (Buffer, Frame_Width, Frame_Height,
            X => Frame_Width, Y => 0, W => 10, H => 10) = 0.0,
         "a region starting outside the frame yields zero ink");

      --  A zero-area rectangle yields no ink.
      Assert
        (Region_Ink_Fraction
           (Buffer, Frame_Width, Frame_Height,
            X => 4, Y => 4, W => 0, H => 0) = 0.0,
         "an empty region yields zero ink");

      --  A rectangle overhanging the bottom-right edge clamps to the frame and
      --  still detects the inked corner rather than reading out of bounds.
      Assert
        (Region_Has_Ink
           (Buffer, Frame_Width, Frame_Height,
            X => Frame_Width - 8, Y => Frame_Height - 8, W => 64, H => 64),
         "a rectangle overhanging the frame edge clamps and finds corner ink");

      --  A malformed (too small) buffer for the stated dimensions yields no ink.
      declare
         Tiny : constant Byte_Array (1 .. 16) := [others => 0];
      begin
         Assert
           (Region_Ink_Fraction
              (Tiny, Frame_Width, Frame_Height,
               X => 0, Y => 0, W => 4, H => 4) = 0.0,
            "a buffer too small for the stated dimensions yields zero ink");
      end;
   end Test_Region_Clamping;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Rendering_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Frame_Analysis;
