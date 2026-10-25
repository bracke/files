separate (Files_Suite.Settings)
   procedure Test_Color_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      use type Files.Types.Group_Mode;
      File_Path   : constant String := "/home/user/report.txt";
      Folder_Path : constant String := "/home/user/projects";
      Base        : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      --  A fresh model carries no labels.
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.No_Label,
         "an unlabeled path reports No_Label");

      --  Set and replace a label on a file path.
      Files.Settings.Set_Label (Base, File_Path, Files.Types.Red);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.Red,
         "a set label is reported back");
      Files.Settings.Set_Label (Base, File_Path, Files.Types.Blue);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.Blue,
         "re-labeling replaces the previous color");

      --  Label a folder path too.
      Files.Settings.Set_Label (Base, Folder_Path, Files.Types.Green);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, Folder_Path),
         Files.Types.Green,
         "a folder path can carry a label");
      Files.Settings.Set_Label
        (Base, File_Path & Character'Val (0) & "ignored", Files.Types.Red);
      Files_Suite.Support.Assert_Equal
        (Natural (Base.Labels.Length),
         2,
         "a NUL-containing path cannot create a persisted color label");

      --  No_Label clears the entry.
      Files.Settings.Set_Label (Base, File_Path, Files.Types.No_Label);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, File_Path),
         Files.Types.No_Label,
         "No_Label clears a stored label");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Base, Folder_Path),
         Files.Types.Green,
         "clearing one path leaves the other labeled");

      --  Full round-trip through the settings text format for file and folder.
      declare
         Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Settings.Set_Label (Source, File_Path, Files.Types.Purple);
         Files.Settings.Set_Label (Source, Folder_Path, Files.Types.Gray);
         Source.Group_By := Files.Types.Group_By_Label;
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "labeled settings text parses");
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Label_Of (Reloaded.Settings, File_Path),
               Files.Types.Purple,
               "a file path's label round-trips");
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Label_Of (Reloaded.Settings, Folder_Path),
               Files.Types.Gray,
               "a folder path's label round-trips");
            Files_Suite.Support.Assert_Equal
              (Reloaded.Settings.Group_By,
               Files.Types.Group_By_Label,
               "label grouping mode round-trips");
         end;
      end;

      --  An unknown color in the file is skipped rather than failing the load.
      declare
         Text : constant String :=
           "[labels]" & ASCII.LF
           & "label = ""fuchsia|/home/user/bad.txt""" & ASCII.LF
           & "label = ""yellow|/home/user/good.txt""" & ASCII.LF;
         Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse (Text);
      begin
         Assert (Parsed.Success, "an unknown color does not fail the load");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Parsed.Settings, "/home/user/bad.txt"),
            Files.Types.No_Label,
            "an entry with an unknown color is skipped");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Parsed.Settings, "/home/user/good.txt"),
            Files.Types.Yellow,
            "a valid entry alongside an invalid one still loads");
      end;
   end Test_Color_Labels;
