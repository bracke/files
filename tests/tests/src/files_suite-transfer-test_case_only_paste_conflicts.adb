with Files.Model.Jobs;
with Files.Operations.Paste;
with Files_Suite.Listings;
with Files.Operation_Results;
with Files.Job_Drivers.Foreground;
with Files.Model.Clipboard;
separate (Files_Suite.Transfer)
   procedure Test_Case_Only_Paste_Conflicts (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      --  Where the folders go: the test root where its volume folds case
      --  (Windows, macOS), else a FAT volume CI mounts on Linux
      --  (FILES_TEST_STREAMLESS_VOLUME), whose names fold too.
      Volume   : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STREAMLESS_VOLUME", "");
      Base     : constant String :=
        (if Volume /= "" and then not Hostkit.Fs.Folds_Name_Case (Root)
         then Join (Volume, "files-test-case-paste")
         else Root);
      Src_Dir  : constant String := Join (Base, "case-src");
      Dest_Dir : constant String := Join (Base, "case-dest");

      --  An empty Base: the test root's reset, and on a volume of its own
      --  the folder there removed.
      procedure Clear is
         Removed : Files.File_System.Mutation_Result;
      begin
         Reset_Root;
         if Base /= Root and then Ada.Directories.Exists (Base) then
            Removed := Files.File_System.Delete_Permanently (Base);
            Assert (Removed.Success, "remove the folder on the case-folding volume");
         end if;
      end Clear;

      function UTF_8 (Text : Wide_Wide_String) return String is
      begin
         return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text);
      end UTF_8;

      --  ПРИВЕТ.txt and привет.txt, spelled by code point: a String literal
      --  cannot hold them. Their case fold lies outside ASCII and Latin-1.
      Upper_Cyrillic : constant String :=
        UTF_8 ([Wide_Wide_Character'Val (16#041F#), Wide_Wide_Character'Val (16#0420#),
                Wide_Wide_Character'Val (16#0418#), Wide_Wide_Character'Val (16#0412#),
                Wide_Wide_Character'Val (16#0415#), Wide_Wide_Character'Val (16#0422#)])
        & ".txt";
      Lower_Cyrillic : constant String :=
        UTF_8 ([Wide_Wide_Character'Val (16#043F#), Wide_Wide_Character'Val (16#0440#),
                Wide_Wide_Character'Val (16#0438#), Wide_Wide_Character'Val (16#0432#),
                Wide_Wide_Character'Val (16#0435#), Wide_Wide_Character'Val (16#0442#)])
        & ".txt";

      --  Paste Incoming from the source folder into a destination that already
      --  holds Present, which differs from it only by case.
      procedure Check (Incoming : String; Present : String; Script : String) is
         Load   : Files.File_System.Directory_Load_Result;
         Paths  : Files.Types.String_Vectors.Vector;
         Model  : Files.Model.Window_Model;
         Routed : Files.Controller.Controller_Result;
         pragma Unreferenced (Routed);
      begin
         Clear;
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Join (Src_Dir, Incoming), "SRC");
         Write_File (Join (Dest_Dir, Present), "DEST");
         Load := Files_Suite.Listings.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Paths.Append (To_Unbounded_String (Join (Src_Dir, Incoming)));
         Files.Model.Clipboard.Set (Model, Paths, Files.Model.Clipboard_Copy);
         Routed := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Paste_Items_Command, Model, Settings);
         Assert
           (Files.Model.Pasting.Conflict_Is_Active (Model),
            "on a case-insensitive destination, pasting a " & Script
            & " name that matches an existing one only by case asks about the conflict");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Pasting.Conflict_Name (Model),
            Incoming,
            "the dialog names the incoming " & Script & " item");

         --  Replace writes over the existing entry under its own name, and
         --  Undo brings the original back under that name too.
         declare
            Step : Files.Operation_Results.Operation_Result :=
              Files.Operations.Paste.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Paste.Choice_Replace,
                                                             False);
            pragma Unreferenced (Step);

            --  The folder's one entry, by name and content.
            procedure Expect (Content : String; What : String) is
               Listed : constant Files.File_System.Directory_Load_Result :=
                 Files_Suite.Listings.Load_Directory (Dest_Dir, Settings);
            begin
               Files_Suite.Support.Assert_Equal (Natural (Listed.Items.Length), 1, What & ": one entry");
               Files_Suite.Support.Assert_Equal
                 (To_String (Listed.Items.First_Element.Name), Present, What & ": named as before");
               Assert (File_Has_Bytes (Join (Dest_Dir, Present), Content), What & ": holding " & Content);
            end Expect;
         begin
            for Attempt in 1 .. 100 loop
               exit when not Files.Model.Jobs.Foreground_Job_Is_Active (Model);
               Step := Files.Job_Drivers.Foreground.Advance (Model, Settings, 8);
            end loop;
            Expect ("SRC", Script & " replace");
            Step := Operation_Commands.Undo_Last (Model, Settings);
            Expect ("DEST", Script & " undo");
         end;
      end Check;
   begin
      Clear;
      Ada.Directories.Create_Path (Dest_Dir);
      --  Only a destination whose volume folds case folds names: what the
      --  paste itself asks (Files.Paste, through Hostkit.Fs.Folds_Name_Case),
      --  not which host this is -- a case-sensitive APFS volume does not fold.
      --  A Linux test root is case-sensitive (ext4, tmpfs); there the FAT
      --  volume above is the one that folds.
      if not Hostkit.Fs.Folds_Name_Case (Dest_Dir) then
         Files_Suite.Support.Skip
           ("Test_Case_Only_Paste_Conflicts", "the test root's filesystem is case-sensitive");
         Clear;
         return;
      end if;
      Check ("Report.txt", "report.txt", "Latin");
      Check (Upper_Cyrillic, Lower_Cyrillic, "Cyrillic");
      --  A failed run leaves the folder for the next one to remove.
      Clear;
   end Test_Case_Only_Paste_Conflicts;
