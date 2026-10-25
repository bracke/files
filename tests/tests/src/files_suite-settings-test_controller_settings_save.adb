separate (Files_Suite.Settings)
   procedure Test_Controller_Settings_Save (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded : constant Files.Settings.Settings_Parse_Result := Load_Saved_Details_Settings;
   begin
      Ada.Directories.Create_Path (Join (Root, "settings-dir"));
      declare
         Draft_Path : constant String := Join (Join (Root, "draft-config"), "settings.conf");
         Draft_Load : Files.Settings.Settings_Parse_Result;
         Draft_Model : Files.Model.Window_Model := Sample_Model;
         Draft_Settings : Files.Settings.Settings_Model := Loaded.Settings;
         Controller_Result : Files.Controller.Controller_Result;
         Lookup : Files.Settings.Action_Lookup_Result;
         Ctrl : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      begin
         Ctrl (Guikit.Input.Control_Key) := True;
         --  The earlier draft save left a settings file at Draft_Path; saves
         --  replace it atomically, so only its presence matters here.
         Ada.Directories.Create_Path (Join (Root, "draft-config"));
         Write_File (Draft_Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Files.Model.Begin_Settings_Edit (Draft_Model, Files.Settings.Make_Draft (Draft_Settings));
         --  Parse no longer injects the built-in mappings (the file is now
         --  authoritative), so seed this draft-editing test's mapping set from
         --  the defaults directly, keeping the same populated set it relies on.
         declare
            Defaults : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         begin
            Draft_Settings.Extension_Filetypes := Defaults.Extension_Filetypes;
            Draft_Settings.Icon_Mappings := Defaults.Icon_Mappings;
            Draft_Settings.Open_Actions := Defaults.Open_Actions;
         end;
         Files.Model.Toggle_Settings_Pane (Draft_Model);
         Controller_Result :=
           Files.Controller.Execute_Command
             (Files.Commands.Toggle_Settings_Pane_Command, Draft_Model, Draft_Settings);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Focus (Draft_Model),
            Files.Types.Focus_Settings_Input,
            "controller settings command opens editable settings focus");
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_Right);
         Files.Controller.Replace_Focused_Text (Draft_Model, "details");
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_Down);
         Files.Controller.Replace_Focused_Text (Draft_Model, "true");
         Files.Controller.Replace_Focused_Text (Draft_Model, "high_contrast");
         Files.Controller.Replace_Focused_Text (Draft_Model, "files-high-contrast");
         Controller_Result := Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_N, Ctrl);
         Files.Controller.Replace_Focused_Text (Draft_Model, "tmpdel");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-delete-me");
         Controller_Result :=
           Files.Controller.Handle_Key (Draft_Model, Draft_Settings, Guikit.Input.Key_Delete, Ctrl);
         Files.Controller.Replace_Focused_Text (Draft_Model, "cfg");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-config");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/x-config");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text");
         Files.Controller.Replace_Focused_Text (Draft_Model, "text/markdown");
         Files.Controller.Replace_Focused_Text (Draft_Model, "reader {path}");
         declare
            Bad : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Draft_Model);
         begin
            Bad.Default_View_Mode := To_Unbounded_String ("bad-view");
            Files.Model.Set_Settings_Draft (Draft_Model, Bad);
         end;
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Failed,
            "controller rejects invalid settings draft");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Error_Key),
            "error.settings.invalid_view_mode",
            "controller invalid settings save reports validation error");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Path),
            Draft_Path,
            "controller invalid settings save reports settings path");
         declare
            Good : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Draft_Model);
         begin
            Good.Default_View_Mode := To_Unbounded_String ("details");
            Good.Theme := To_Unbounded_String ("high_contrast");
            Good.Icon_Theme_Name := To_Unbounded_String ("files-high-contrast");
            Good.Show_Hidden_Files := To_Unbounded_String ("true");
            Good.Filetype_Keys.Clear;
            Good.Filetype_Values.Clear;
            Good.Filetype_Keys.Append (To_Unbounded_String ("cfg"));
            Good.Filetype_Values.Append (To_Unbounded_String ("text/x-config"));
            Good.Filetype_Keys.Append (To_Unbounded_String ("txt"));
            Good.Filetype_Values.Append (To_Unbounded_String ("text/plain"));
            Good.Icon_Keys.Clear;
            Good.Icon_Values.Clear;
            Good.Icon_Keys.Append (To_Unbounded_String ("text/x-config"));
            Good.Icon_Values.Append (To_Unbounded_String ("text"));
            Good.Open_Action_Keys.Clear;
            Good.Open_Action_Commands.Clear;
            Good.Open_Action_Keys.Append (To_Unbounded_String ("text/markdown"));
            Good.Open_Action_Commands.Append (To_Unbounded_String ("reader {path}"));
            Files.Model.Set_Settings_Draft (Draft_Model, Good);
         end;
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Join (Root, "settings-dir"));
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Failed,
            "controller settings save rejects directory path");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Error_Key),
            "error.settings.not_file",
            "controller settings save directory failure reports not-file diagnostic");
         Files_Suite.Support.Assert_Equal
           (Draft_Settings.Default_View,
            Loaded.Settings.Default_View,
            "controller settings save failure preserves live settings");
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Success,
            "controller saves edited settings draft");
         Files_Suite.Support.Assert_Equal
           (Draft_Settings.Default_View,
            Files.Types.Details,
            "controller save updates live settings");
         Assert
           (Draft_Settings.Theme = Files.Settings.Theme_High_Contrast,
            "controller save updates the live theme setting");
         Files_Suite.Support.Assert_Equal
           (To_String (Draft_Settings.Icon_Theme_Name),
            "files-high-contrast",
            "controller save updates live icon theme");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "cfg"),
            "text/x-config",
            "controller save updates live filetype mappings");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "txt"),
            "text/plain",
            "controller save preserves other filetype mappings");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Settings, "tmpdel"),
            "",
            "controller save omits removed filetype mappings");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Draft_Settings, "text/x-config"),
            "text",
            "controller save updates live icon mappings");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Settings,
              "text/markdown",
              Guikit.Input.No_Modifiers);
         Assert (Lookup.Found, "controller save updates live open-action settings");
         Draft_Load := Files.Settings.Load_File (Draft_Path);
         Assert (Draft_Load.Success, "controller-saved settings file reloads");
         Assert (Draft_Load.Settings.Show_Hidden_Files, "controller save persists edited hidden-file flag");
         declare
            Missing_Current_Path : constant String := Join (Root, "settings-save-missing-current");
            Missing_Model        : Files.Model.Window_Model;
            Missing_Settings     : Files.Settings.Settings_Model := Draft_Settings;
            Missing_Items        : Files.File_System.Item_Vectors.Vector;
            Missing_Result       : Files.Controller.Controller_Result;
         begin
            Ada.Directories.Create_Path (Missing_Current_Path);
            Files.Model.Initialize
              (Missing_Model,
               Directory_Path    => Missing_Current_Path,
               Items             => Missing_Items,
               Home_Path         => "/home/test",
               Default_View_Mode => Files.Types.Small_Icons);
            Missing_Result :=
              Files.Controller.Execute_Command
                (Files.Commands.Toggle_Settings_Pane_Command, Missing_Model, Missing_Settings);
            Files_Suite.Support.Assert_Equal
              (Missing_Result.Status,
               Files.Controller.Controller_Command_Executed,
               "missing-current save fixture executes settings command");
            Assert
              (Files.Model.Settings_Pane_Is_Open (Missing_Model),
               "missing-current save fixture opens settings pane");
            Ada.Directories.Delete_Directory (Missing_Current_Path);
            Missing_Result := Files.Controller.Save_Settings (Missing_Model, Missing_Settings, Draft_Path);
            Files_Suite.Support.Assert_Equal
              (Missing_Result.Operation.Status,
               Files.Operations.Operation_Failed,
               "controller settings save reports post-save refresh failure");
            Assert
              (To_String (Missing_Result.Operation.Error_Key) /= "",
               "controller settings save keeps refresh failure diagnostic");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Missing_Model),
               To_String (Missing_Result.Operation.Error_Key),
               "controller settings save leaves refresh failure visible");
         end;
      end;
   end Test_Controller_Settings_Save;
