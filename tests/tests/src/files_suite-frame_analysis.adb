with Interfaces;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Files.Rendering.Frame_Analysis;

--  Structural framebuffer-analysis tests. These exercise the pure, GPU-free
--  analysis on synthetic in-memory RGBA buffers: a blank frame must fail, a
--  frame with distinct top/middle/bottom bands and scattered ink must pass,
--  and a frame with one empty band must fail. No display or Vulkan is needed.
package body Files_Suite.Frame_Analysis is

   use AUnit.Assertions;
   use Files.Rendering.Frame_Analysis;
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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Rendering_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Frame_Analysis;
