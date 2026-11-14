with Files.Model.Clipboard;
separate (Files_Suite.Transfer)
   procedure Test_Case_Only_Paste_Conflicts (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "case-src");
      Dest_Dir : constant String := Join (Root, "case-dest");

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
         Reset_Root;
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Join (Src_Dir, Incoming), "SRC");
         Write_File (Join (Dest_Dir, Present), "DEST");
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
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
            Step : Files.Operations.Operation_Result :=
              Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Replace, False);
            pragma Unreferenced (Step);

            --  The folder's one entry, by name and content.
            procedure Expect (Content : String; What : String) is
               Listed : constant Files.File_System.Directory_Load_Result :=
                 Files.File_System.Load_Directory (Dest_Dir, Settings);
            begin
               Files_Suite.Support.Assert_Equal (Natural (Listed.Items.Length), 1, What & ": one entry");
               Files_Suite.Support.Assert_Equal
                 (To_String (Listed.Items.First_Element.Name), Present, What & ": named as before");
               Assert (File_Has_Bytes (Join (Dest_Dir, Present), Content), What & ": holding " & Content);
            end Expect;
         begin
            for Attempt in 1 .. 100 loop
               exit when not Files.Model.Pasting.Execution_Is_Active (Model);
               Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
            end loop;
            Expect ("SRC", Script & " replace");
            Step := Files.Operations.Undo_Last (Model, Settings);
            Expect ("DEST", Script & " undo");
         end;
      end Check;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dest_Dir);
      --  Only a case-insensitive destination folds names. A Linux test root is
      --  case-sensitive (ext4, tmpfs), and Uses_Dos_Filename_Rules reads the
      --  real mount table, so there is no stand-in to force it here; the
      --  Windows and macOS runs are the ones that exercise the fold.
      if not (Hostkit.Host.Current in Hostkit.Host.Windows | Hostkit.Host.MacOS
              or else Hostkit.Fs.Uses_Dos_Filename_Rules (Dest_Dir))
      then
         Files_Suite.Support.Skip
           ("Test_Case_Only_Paste_Conflicts", "the test root's filesystem is case-sensitive");
         return;
      end if;
      Check ("Report.txt", "report.txt", "Latin");
      Check (Upper_Cyrillic, Lower_Cyrillic, "Cyrillic");
   end Test_Case_Only_Paste_Conflicts;
