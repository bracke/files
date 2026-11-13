separate (Files_Suite.Interaction)
   --  The cross-window settings sync as the window layer runs it: Share_From
   --  with Files.Settings_Sharing.Adopt_Window as its Adopt, the very call
   --  Files.Application.Windows.Share_Settings_From makes over a window's
   --  own fields, here over three stand-in windows with real models. A
   --  change in one window reaches each of the others, and each of them
   --  drops its cached frame (it does not compare settings, so it would show
   --  the old ones); the source window keeps its frame, and a pass with no
   --  change drops no frame anywhere.
   procedure Test_Settings_Adoption_Drops_Frames (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      type Stand_In is record
         Model             : Files.Model.Window_Model;
         Settings          : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Frame_Cache_Valid : Boolean := True;
         Synced            : Natural := 0;
      end record;

      type Stand_Ins is array (Positive range <>) of Stand_In;

      function Revision (Windows : Stand_Ins; Index : Positive) return Natural is
        (Files.Model.Settings_Revision (Windows (Index).Model));

      function Synced_Revision (Windows : Stand_Ins; Index : Positive) return Natural is (Windows (Index).Synced);

      procedure Mark_Synced (Windows : in out Stand_Ins; Index : Positive; At_Revision : Natural) is
      begin
         Windows (Index).Synced := At_Revision;
      end Mark_Synced;

      procedure Adopt (Windows : in out Stand_Ins; Target : Positive; Source : Positive) is
      begin
         Files.Settings_Sharing.Adopt_Window
           (Model             => Windows (Target).Model,
            Settings          => Windows (Target).Settings,
            Shared            => Windows (Source).Settings,
            Frame_Cache_Valid => Windows (Target).Frame_Cache_Valid);
      end Adopt;

      procedure Share is new Files.Settings_Sharing.Share_From
        (Window_Set      => Stand_Ins,
         Revision        => Revision,
         Synced_Revision => Synced_Revision,
         Mark_Synced     => Mark_Synced,
         Adopt           => Adopt);

      Windows : Stand_Ins (1 .. 3);
      Result  : Files.Interaction.Interaction_Result;
   begin
      Files_Suite.Support.Reset_Root;
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Files_Suite.Support.Root, "Alpha.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Files_Suite.Support.Root, ".hidden_one"));
      for Window of Windows loop
         declare
            Load_Result : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Files_Suite.Support.Root, Window.Settings);
         begin
            Files.Model.Initialize
              (Window.Model,
               Directory_Path => Files_Suite.Support.Root,
               Items          => Load_Result.Items,
               Home_Path      => "/home/test");
         end;
         Window.Synced := Files.Model.Settings_Revision (Window.Model);
         Window.Frame_Cache_Valid := True;
      end loop;

      --  Nothing changed: no window adopts, no frame is dropped.
      for Source in Windows'Range loop
         Share (Windows, Windows'First, Windows'Last, Source);
      end loop;
      for Window of Windows loop
         Assert (Window.Frame_Cache_Valid, "a pass with no settings change drops no cached frame");
      end loop;

      --  Window 2 turns hidden files on and shares it.
      Files.Interaction.Execute_Command
        (Windows (2).Model, Windows (2).Settings, "", Files.Commands.Toggle_Hidden_Files_Command, Result => Result);
      Assert (Windows (2).Settings.Show_Hidden_Files, "window 2 turns hidden files on");
      Share (Windows, Windows'First, Windows'Last, 2);

      Assert (Windows (1).Settings.Show_Hidden_Files and then Windows (3).Settings.Show_Hidden_Files,
              "both other windows take the shared settings");
      Assert (not Windows (1).Frame_Cache_Valid, "window 1 adopted the settings and drops its cached frame");
      Assert (not Windows (3).Frame_Cache_Valid, "window 3 adopted the settings and drops its cached frame");
      Assert (Windows (2).Frame_Cache_Valid, "the window whose change was shared adopts nothing and keeps its frame");

      --  Drawn again; the next passes find nothing left to share.
      for Window of Windows loop
         Window.Frame_Cache_Valid := True;
      end loop;
      for Source in Windows'Range loop
         Share (Windows, Windows'First, Windows'Last, Source);
      end loop;
      for Window of Windows loop
         Assert (Window.Frame_Cache_Valid, "a shared change is adopted once: the next pass drops no frame");
      end loop;
   end Test_Settings_Adoption_Drops_Frames;
