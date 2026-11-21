with Files.Preference_Types;
with Files.Settings.Path_References;
separate (Files_Suite.Settings)
   procedure Test_Color_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Preference_Types.Color_Label;
      use type Files.Preference_Types.Group_Mode;
      File_Path   : constant String := "/home/user/report.txt";
      Folder_Path : constant String := "/home/user/projects";
      Base        : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      --  A fresh model carries no labels.
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Path_References.Label_Of (Base, File_Path),
         Files.Preference_Types.No_Label,
         "an unlabeled path reports No_Label");

      --  Set and replace a label on a file path.
      Files.Settings.Path_References.Set_Label (Base, File_Path, Files.Preference_Types.Red);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Path_References.Label_Of (Base, File_Path),
         Files.Preference_Types.Red,
         "a set label is reported back");
      Files.Settings.Path_References.Set_Label (Base, File_Path, Files.Preference_Types.Blue);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Path_References.Label_Of (Base, File_Path),
         Files.Preference_Types.Blue,
         "re-labeling replaces the previous color");

      --  Label a folder path too.
      Files.Settings.Path_References.Set_Label (Base, Folder_Path, Files.Preference_Types.Green);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Path_References.Label_Of (Base, Folder_Path),
         Files.Preference_Types.Green,
         "a folder path can carry a label");
      Files.Settings.Path_References.Set_Label
        (Base, File_Path & Character'Val (0) & "ignored", Files.Preference_Types.Red);
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Settings.Path_References.Path_Labels (Base).Length),
         2,
         "a NUL-containing path cannot create a persisted color label");

      --  No_Label clears the entry.
      Files.Settings.Path_References.Set_Label (Base, File_Path, Files.Preference_Types.No_Label);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Path_References.Label_Of (Base, File_Path),
         Files.Preference_Types.No_Label,
         "No_Label clears a stored label");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Path_References.Label_Of (Base, Folder_Path),
         Files.Preference_Types.Green,
         "clearing one path leaves the other labeled");

      --  Full round-trip through the settings text format for file and folder.
      declare
         Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Settings.Path_References.Set_Label (Source, File_Path, Files.Preference_Types.Purple);
         Files.Settings.Path_References.Set_Label (Source, Folder_Path, Files.Preference_Types.Gray);
         Source.Group_By := Files.Preference_Types.Group_By_Label;
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "labeled settings text parses");
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Path_References.Label_Of (Reloaded.Settings, File_Path),
               Files.Preference_Types.Purple,
               "a file path's label round-trips");
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Path_References.Label_Of (Reloaded.Settings, Folder_Path),
               Files.Preference_Types.Gray,
               "a folder path's label round-trips");
            Files_Suite.Support.Assert_Equal
              (Reloaded.Settings.Group_By,
               Files.Preference_Types.Group_By_Label,
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
           (Files.Settings.Path_References.Label_Of (Parsed.Settings, "/home/user/bad.txt"),
            Files.Preference_Types.No_Label,
            "an entry with an unknown color is skipped");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Path_References.Label_Of (Parsed.Settings, "/home/user/good.txt"),
            Files.Preference_Types.Yellow,
            "a valid entry alongside an invalid one still loads");
      end;
   end Test_Color_Labels;
