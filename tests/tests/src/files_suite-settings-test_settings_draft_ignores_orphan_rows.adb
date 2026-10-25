separate (Files_Suite.Settings)
   procedure Test_Settings_Draft_Ignores_Orphan_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded : constant Files.Settings.Settings_Parse_Result := Load_Saved_Details_Settings;
      Lookup : Files.Settings.Action_Lookup_Result;
   begin
      declare
         Empty_Settings : Files.Settings.Settings_Model := Loaded.Settings;
         Empty_Model    : Files.Model.Window_Model := Sample_Model;
         Empty_Load     : Files.Settings.Settings_Parse_Result;
         Repair_Draft   : Files.Settings.Settings_Draft;
      begin
         Empty_Settings.Extension_Filetypes.Clear;
         Empty_Settings.Icon_Mappings.Clear;
         Empty_Settings.Open_Actions.Clear;
         --  Keep missing open-action lookups deterministic by opting out of
         --  the host opener fallback that would otherwise resolve.
         Empty_Settings.Use_System_Default_Opener := False;
         Files.Model.Begin_Settings_Edit (Empty_Model, Files.Settings.Make_Draft (Empty_Settings));

         Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
         Assert (Empty_Load.Success, "empty mapping draft remains valid after ignored edits");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Empty_Load.Settings, "ghost"),
            "",
            "ignored empty-list filetype edit is not saved");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Empty_Load.Settings, "text/x-ghost"),
            "",
            "ignored empty-list icon edit is not saved");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Empty_Load.Settings,
              "text/x-ghost",
              Guikit.Input.No_Modifiers);
         Assert (not Lookup.Found, "ignored empty-list open-action edit is not saved");

         Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
         Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
         Repair_Draft.Filetype_Index := 1;
         Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
         Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
         Assert (Empty_Load.Success, "repaired misaligned filetype draft validates");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Empty_Load.Settings, "orphan-ext"),
            "",
            "repaired misaligned filetype edit is not saved");

         Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
         Repair_Draft.Icon_Values.Append (To_Unbounded_String ("orphan-icon"));
         Repair_Draft.Icon_Index := 1;
         Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
         Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
         Assert (Empty_Load.Success, "repaired misaligned icon draft validates");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Icon_For_Filetype (Empty_Load.Settings, "text/x-orphan"),
            "",
            "repaired misaligned icon edit is not saved");

         Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
         Repair_Draft.Open_Action_Keys.Append (To_Unbounded_String ("text/x-orphan"));
         Repair_Draft.Open_Action_Index := 1;
         Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
         Empty_Load := Files.Settings.Apply_Draft (Empty_Settings, Files.Model.Settings_Draft_Of (Empty_Model));
         Assert (Empty_Load.Success, "repaired misaligned open-action draft validates");
         Lookup :=
           Files.Settings.Lookup_Open_Action
             (Empty_Load.Settings,
              "text/x-orphan",
              Guikit.Input.No_Modifiers);
         Assert (not Lookup.Found, "repaired misaligned open-action edit is not saved");

         Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
         Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
         Repair_Draft.Filetype_Index := 1;
         Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
         Files_Suite.Support.Assert_Equal
           (Natural (Files.Model.Settings_Draft_Of (Empty_Model).Filetype_Keys.Length),
            0,
            "begin settings edit drops orphan filetype rows");

         Files.Settings.Add_Extension_Mapping (Empty_Settings, "ada", "text/x-ada");
         Repair_Draft := Files.Settings.Make_Draft (Empty_Settings);
         Repair_Draft.Filetype_Keys.Append (To_Unbounded_String ("orphan-ext"));
         Repair_Draft.Filetype_Index := Natural (Repair_Draft.Filetype_Keys.Length);
         Repair_Draft.Filetype_Extension := To_Unbounded_String ("stale-ext");
         Repair_Draft.Filetype_Value := To_Unbounded_String ("text/x-stale");
         Files.Model.Begin_Settings_Edit (Empty_Model, Repair_Draft);
      end;
   end Test_Settings_Draft_Ignores_Orphan_Rows;
