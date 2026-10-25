separate (Files_Suite.Operations)
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
         Files.Model.Set_Clipboard (Model, Paths, Files.Model.Clipboard_Copy);
         Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
         Assert
           (Files.Model.Paste_Conflict_Is_Active (Model),
            "on a case-insensitive destination, pasting a " & Script
            & " name that matches an existing one only by case asks about the conflict");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Paste_Conflict_Name (Model),
            Incoming,
            "the dialog names the incoming " & Script & " item");
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
