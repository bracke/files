separate (Files_Suite.Interaction)
   --  A details column dragged at a 2x line height is stored in reference
   --  units (half its framebuffer pixels) and drawn back at the pixel width it
   --  was dragged to, while at the reference line height the two coincide.
   procedure Test_Column_Width_Reference_Units (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Double : constant Positive := 2 * Guikit.Layout.Reference_Line_Height;
      Wide_W : constant Natural := 2 * Window_W;
      Wide_H : constant Natural := 2 * Window_H;
      Items  : Files.Items.Item_Vectors.Vector;
      Model  : Files.Model.Window_Model;

      --  The size column's drawn width for Settings at Line_Height.
      function Size_Width (Settings : Files.Settings.Settings_Model; Line_Height : Positive) return Natural is
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Wide_W, Wide_H, Line_Height);
      begin
         for Cell of Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height) loop
            if Cell.Visible_Index = 1 then
               return Cell.Size_Width;
            end if;
         end loop;
         return 0;
      end Size_Width;

      --  Drag the size column's separator left by Delta pixels from Origin_Width.
      procedure Drag
        (Settings     : in out Files.Settings.Settings_Model;
         Origin_Width : Natural;
         Delta_X      : Natural;
         Line_Height  : Positive)
      is
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Interaction.Apply_Column_Resize
           (Model, Settings, Files.Types.Size_Column,
            Origin_X     => 500,
            Origin_Width => Origin_Width,
            Current_X    => 500 - Delta_X,
            Result       => Result,
            Line_Height  => Line_Height);
         Assert (Result.Settings_Changed, "the resize step reports a width change");
      end Drag;
   begin
      for Index in 1 .. 4 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      --  At 2x: an even pixel target is stored as exactly half and drawn back
      --  at the same pixel width.
      declare
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Base_W   : constant Natural := Size_Width (Settings, Double);
         Delta_X  : constant Natural := 40 + Base_W mod 2;
         Target   : constant Natural := Base_W + Delta_X;
      begin
         Assert (Base_W > 2 * Files.Types.Minimum_Detail_Column_Width,
                 "the size column starts well above the scaled minimum at 2x");
         Drag (Settings, Base_W, Delta_X, Double);
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Widths (Files.Types.Size_Column),
            Target / 2,
            "a width dragged at line height 40 is stored as half its framebuffer pixels");
         Files_Suite.Support.Assert_Equal
           (Size_Width (Settings, Double),
            Target,
            "the stored width is drawn back at the dragged pixel width at line height 40");
         Files_Suite.Support.Assert_Equal
           (Size_Width (Settings, Guikit.Layout.Reference_Line_Height),
            Target / 2,
            "the same stored width draws at half the pixels at the reference line height");
      end;

      --  At the reference line height the stored width is the pixel width,
      --  so settings files written before the unit change keep their meaning.
      declare
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Base_W   : constant Natural := Size_Width (Settings, Line);
      begin
         Drag (Settings, Base_W, 37, Line);
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Widths (Files.Types.Size_Column),
            Base_W + 37,
            "at line height 20 the stored width equals the dragged pixel width");
         Files_Suite.Support.Assert_Equal
           (Size_Width (Settings, Line),
            Base_W + 37,
            "at line height 20 the stored width draws at its own pixel width");
      end;
   end Test_Column_Width_Reference_Units;
