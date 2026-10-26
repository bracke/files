separate (Files_Suite.Rendering)
   --  An icon atlas that has not changed is the same buffer from frame to
   --  frame, not a copy; and two windows showing different pictures do not
   --  rebuild each other's atlas every frame.
   procedure Test_Icon_Atlas_Shared_Across_Frames (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Frame_Commands := Build_Frame_Commands
        (Sample_Snapshot (2, Files.Types.Details), Width => 800, Height => 600, Line_Height => 20);

      --  One window's icons: a 2x2 picture of one colour.
      function Window_Icons (Red : Interfaces.Unsigned_8) return Guikit.Draw.Icon_Command_Vectors.Vector is
         Pixels : Guikit.Shared_Bytes.Byte_Vectors.Vector;
         Result : Guikit.Draw.Icon_Command_Vectors.Vector;
      begin
         for Pixel in 1 .. 4 loop
            Pixels.Append (Red);
            Pixels.Append (0);
            Pixels.Append (0);
            Pixels.Append (255);
         end loop;
         Result.Append
           (Guikit.Draw.Icon_Command'
              (X => 10, Y => 10, Size => 32,
               Icon_Id => To_Unbounded_String ("thumbnail"),
               Thumbnail_Width => 2, Thumbnail_Height => 2,
               Thumbnail_Pixels => Guikit.Shared_Bytes.To_Shared (Pixels),
               others => <>));
         return Result;
      end Window_Icons;

      function Atlas_Of (Icons : Guikit.Draw.Icon_Command_Vectors.Vector) return Guikit.Shared_Bytes.Bytes is
        (Guikit.Vulkan.Build_Submission
           (Rectangles         => Frame.Rectangles,
            Triangles          => Frame.Triangles,
            Icons              => Icons,
            Overlay_Rectangles => Frame.Overlay_Rectangles,
            Layout             => Frame.Layout,
            Theme              => Frame.Theme_Palette,
            Text               => (others => <>)).Icon_Atlas_Pixels);

      One : constant Guikit.Draw.Icon_Command_Vectors.Vector := Window_Icons (200);
      Two : constant Guikit.Draw.Icon_Command_Vectors.Vector := Window_Icons (100);
      First_One : constant Guikit.Shared_Bytes.Bytes := Atlas_Of (One);
      First_Two : constant Guikit.Shared_Bytes.Bytes := Atlas_Of (Two);
   begin
      Assert (not Guikit.Shared_Bytes.Is_Empty (First_One), "the picture is in an atlas");
      Assert (Guikit.Shared_Bytes.Serial (First_One) /= Guikit.Shared_Bytes.Serial (First_Two),
              "two windows' pictures make two atlases");
      Files_Suite.Support.Assert_Equal
        (Guikit.Shared_Bytes.Serial (Atlas_Of (One)), Guikit.Shared_Bytes.Serial (First_One),
         "the first window's next frame shares its atlas, after the second window's frame");
      Files_Suite.Support.Assert_Equal
        (Guikit.Shared_Bytes.Serial (Atlas_Of (Two)), Guikit.Shared_Bytes.Serial (First_Two),
         "and so does the second window's");
   end Test_Icon_Atlas_Shared_Across_Frames;
