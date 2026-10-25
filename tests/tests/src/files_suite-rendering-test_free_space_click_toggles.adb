separate (Files_Suite.Rendering)
   --  Clicking the counts area toggles hidden files; clicking the free-space
   --  field toggles between free and used space.
   procedure Test_Free_Space_Click_Toggles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      declare
         Free_W   : constant Natural := Files.Rendering.Free_Space_Label_Width (Snap, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         BBP      : constant Natural := Guikit.Layout.Bottom_Bar_Padding;
         Bottom_Y : constant Natural := 800 - (20 + 2 * BBP);
         Y        : constant Natural := Bottom_Y + BBP + 5;
         Counts_X : constant Natural := Bar.Info_X + 5;
         Free_X   : constant Natural := Bar.Info_X + Bar.Info_Width - 5;
      begin
         Assert (Free_W > 0, "the free-space field is present in a wide window");
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Bottom_Bar_Command_At (Counts_X, Y, 1000, 800, Snap.Sort_Field, Free_W, 20),
            Files.Commands.Toggle_Hidden_Files_Command,
            "clicking the counts area toggles hidden files");
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Bottom_Bar_Command_At (Free_X, Y, 1000, 800, Snap.Sort_Field, Free_W, 20),
            Files.Commands.Toggle_Free_Space_Display_Command,
            "clicking the free-space field toggles free/used space");
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Bottom_Bar_Command_At (Counts_X, Bottom_Y + 1, 1000, 800, Snap.Sort_Field, Free_W, 20),
            Files.Commands.Toggle_Hidden_Files_Command,
            "the visible top of the counts area toggles hidden files");
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Bottom_Bar_Command_At (Counts_X, 799, 1000, 800, Snap.Sort_Field, Free_W, 20),
            Files.Commands.Toggle_Hidden_Files_Command,
            "the visible bottom of the counts area toggles hidden files");
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Bottom_Bar_Command_At (Free_X, Bottom_Y + 1, 1000, 800, Snap.Sort_Field, Free_W, 20),
            Files.Commands.Toggle_Free_Space_Display_Command,
            "the visible top of the free-space field toggles its display");
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Bottom_Bar_Command_At (Free_X, 799, 1000, 800, Snap.Sort_Field, Free_W, 20),
            Files.Commands.Toggle_Free_Space_Display_Command,
            "the visible bottom of the free-space field toggles its display");
      end;
   end Test_Free_Space_Click_Toggles;
