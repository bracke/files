separate (Files_Suite.Settings)
   procedure Test_Settings_Draft_Apply_And_Save (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded : constant Files.Settings.Settings_Parse_Result := Load_Saved_Details_Settings;
      Saved  : Files.Settings.Settings_Write_Result;
   begin
      declare
         Reset_Draft : constant Files.Settings.Settings_Draft := Files.Settings.Reset_Draft_To_Defaults;
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Reset_Draft.Scalars (Files.Settings.Default_View_Mode_Setting)),
            "small_icons",
            "reset settings draft restores default view mode");
      end;
      declare
         Draft_Path : constant String := Join (Join (Root, "draft-config"), "settings.conf");
         Draft      : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Loaded.Settings);
         Draft_Load : Files.Settings.Settings_Parse_Result;
         Draft_Model : Files.Model.Window_Model := Sample_Model;
         Draft_Settings : Files.Settings.Settings_Model := Loaded.Settings;
         Controller_Result : Files.Controller.Controller_Result;
         Lookup : Files.Settings.Action_Lookup_Result;
      begin
         Controller_Result := Files.Controller.Save_Settings (Draft_Model, Draft_Settings, Draft_Path);
         Files_Suite.Support.Assert_Equal
           (Controller_Result.Operation.Status,
            Files.Operations.Operation_Disabled,
            "closed settings pane cannot save settings");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Error_Key),
            "error.settings.closed",
            "closed settings save reports a localized disabled error");
         Files_Suite.Support.Assert_Equal
           (To_String (Controller_Result.Operation.Path),
            Draft_Path,
            "closed settings save reports settings path");
         Draft.Scalars (Files.Settings.Default_View_Mode_Setting) := To_Unbounded_String ("details");
         Draft.Scalars (Files.Settings.Show_Hidden_Files_Setting) := To_Unbounded_String ("true");
         Draft.Scalars (Files.Settings.Sort_Field_Setting) := To_Unbounded_String ("size");
         Draft.Scalars (Files.Settings.Sort_Ascending_Setting) := To_Unbounded_String ("false");
         Draft.Scalars (Files.Settings.Theme_Setting) := To_Unbounded_String ("high_contrast");
         Draft.Scalars (Files.Settings.Icon_Theme_Setting) := To_Unbounded_String ("files-high-contrast");
         Draft.Filetype_Extension := To_Unbounded_String ("log");
         Draft.Filetype_Value := To_Unbounded_String ("text/x-log");
         Draft.Icon_Filetype := To_Unbounded_String ("text/x-log");
         Draft.Icon_Value := To_Unbounded_String ("text");
         Draft.Open_Action_Token := To_Unbounded_String ("application/ld+json+alt");
         Draft.Open_Action_Command := To_Unbounded_String ("json-editor {path}");
         Assert (Files.Settings.Validate_Draft (Draft).Success, "settings draft validates editable values");
         Draft_Load := Files.Settings.Apply_Draft (Loaded.Settings, Draft);
         Assert (Draft_Load.Success, "settings draft applies to a settings model");
         Files_Suite.Support.Assert_Equal
           (Draft_Load.Settings.Default_View,
            Files.Types.Details,
            "draft applies default view");
         Assert (Draft_Load.Settings.Show_Hidden_Files, "draft applies hidden-file flag");
         Files_Suite.Support.Assert_Equal
           (Draft_Load.Settings.Sort_Field_Value,
            Files.Settings.Sort_By_Size,
            "draft applies sort field");
         Assert
           (Draft_Load.Settings.Theme = Files.Settings.Theme_High_Contrast,
            "draft applies the high-contrast theme");
         Files_Suite.Support.Assert_Equal
           (To_String (Draft_Load.Settings.Icon_Theme_Name),
            "files-high-contrast",
            "draft applies icon theme selection");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Load.Settings, "log"),
            "text/x-log",
            "draft applies filetype mapping");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Draft_Load.Settings, "text/x-log"),
            "text",
            "draft applies icon mapping");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Load.Settings,
              "application/ld+json",
              [Guikit.Input.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "draft applies modifier-specific open action");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "json-editor",
            "draft action executable is parsed");
         Saved := Files.Settings.Save_Draft (Draft_Path, Loaded.Settings, Draft);
         Assert (Saved.Success, "settings draft saves to disk");
         Draft_Load := Files.Settings.Load_File (Draft_Path);
         Assert (Draft_Load.Success, "saved draft settings load");
         Files_Suite.Support.Assert_Equal
           (Draft_Load.Settings.Default_View,
            Files.Types.Details,
            "saved draft persists default view");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Draft_Load.Settings, "log"),
            "text/x-log",
            "saved draft persists filetype mapping");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Draft_Load.Settings, "text/x-log"),
            "text",
            "saved draft persists icon mapping");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Draft_Load.Settings,
              "application/ld+json",
              [Guikit.Input.Alt_Key => True, others => False]);
         Assert (Lookup.Found, "saved draft persists open action");
         Files_Suite.Support.Assert_Equal
           (To_String (Lookup.Action.Executable),
            "json-editor",
            "saved draft persists structured-suffix open action executable");
         Draft.Scalars (Files.Settings.Default_View_Mode_Setting) := To_Unbounded_String ("bad-view");
         Saved := Files.Settings.Save_Draft (Draft_Path, Loaded.Settings, Draft);
         Assert (not Saved.Success, "invalid settings draft is not saved");
         Files_Suite.Support.Assert_Equal
           (To_String (Saved.Error_Key),
            "error.settings.invalid_view_mode",
            "invalid draft save reports validation diagnostic");
      end;
   end Test_Settings_Draft_Apply_And_Save;
