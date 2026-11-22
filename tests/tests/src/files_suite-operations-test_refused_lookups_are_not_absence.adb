with Files.Operations.Navigation;
with Files.Settings.Storage;
with Files.File_System.Transfer;
with Files.IO.Fs_Primitives.Testing;
with Files.Operation_Results;
with Files.Settings.Path_References;
separate (Files_Suite.Operations)
   --  The host may refuse to say whether an entry is there (a folder that
   --  may not be searched, a flaky share, a device not ready). Taken for
   --  absence, such a refusal lost things: the settings file was "missing"
   --  and seeded over with the defaults, a Recent entry dropped from the
   --  view, a name in use handed out by a free-name search, and a delete
   --  answered "missing" without deleting. Each is checked here with the
   --  lookup refused, the way the suite's seam refuses it.
   procedure Test_Refused_Lookups_Are_Not_Absence (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings_File : constant String := Join (Root, "settings.txt");
      Kept          : constant String := Join (Root, "kept.txt");
      Doomed        : constant String := Join (Root, "doomed.txt");
      Incoming      : constant String := Join (Root, "incoming");
      Settings      : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Custom        : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model         : Files.Model.Window_Model;
      Result        : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;

      --  A settings file that cannot be looked at is neither loaded as the
      --  defaults nor seeded over with them.
      Custom.Window_Width := 1234;
      Write_File (Settings_File, Files.Settings.To_Text (Custom));
      Files.IO.Fs_Primitives.Testing.Refuse_Lookups (Settings_File);
      declare
         Held   : constant String := Project_Tools.Files.Read_Raw_File (Settings_File);
         Loaded : constant Files.Settings.Settings_Parse_Result := Files.Settings.Storage.Load_File (Settings_File);
         Seeded : constant Files.Settings.Settings_Write_Result :=
           Files.Settings.Storage.Ensure_Default_File (Settings_File);
      begin
         Files.IO.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         Assert (not Loaded.Success or else Loaded.Settings.Window_Width = 1234,
                 "a settings file not seen does not load as the defaults");
         Assert (Seeded.Success, "a settings file that is there is not seeded: " & To_String (Seeded.Error_Key));
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Settings_File), Held,
            "the settings file keeps what it held");
      end;

      --  A Recent entry that cannot be looked at stays in the view.
      Write_File (Kept);
      Files.Settings.Path_References.Note_Recent (Settings, Ada.Directories.Full_Name (Kept));
      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.IO.Fs_Primitives.Testing.Refuse_Lookups (Ada.Directories.Full_Name (Kept));
      Result := Files.Operations.Navigation.Navigate_Recent (Model, Settings);
      Files.IO.Fs_Primitives.Testing.Stop_Refusing_Lookups;
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Navigated, "the recent view opens");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model), 1, "a recent entry not seen stays listed");

      --  A name that cannot be looked at is not handed out by a free-name
      --  search: that source's drop plan fails instead.
      Ada.Directories.Create_Path (Incoming);
      Write_File (Join (Incoming, "kept.txt"));
      Files.IO.Fs_Primitives.Testing.Refuse_Lookups (Kept);
      declare
         Sources : Files.Types.String_Vectors.Vector;
         Plan    : Files.File_System.Drop_Import_Result;
      begin
         Sources.Append (To_Unbounded_String (Join (Incoming, "kept.txt")));
         Plan := Files.File_System.Transfer.Plan_Drop_Import (Sources, Root);
         Files.IO.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         Assert (Natural (Plan.Plans.Length) = 1, "one plan for one source");
         Assert (not Plan.Plans.First_Element.Valid
                 or else To_String (Plan.Plans.First_Element.Destination_Path) /= Kept,
                 "a destination not seen is not taken for free: "
                 & To_String (Plan.Plans.First_Element.Destination_Path));
      end;

      --  A delete whose target cannot be looked at deletes it, not "missing".
      Write_File (Doomed);
      Files.IO.Fs_Primitives.Testing.Refuse_Lookups (Doomed);
      declare
         Deleted : constant Files.File_System.Mutation_Result := Files.File_System.Delete_Permanently (Doomed);
      begin
         Files.IO.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         Assert (Deleted.Success, "a target not seen is still deleted: " & To_String (Deleted.Error_Key));
         Assert (not Ada.Directories.Exists (Doomed), "and it is gone");
      end;
      Reset_Root;
   exception
      when others =>
         Files.IO.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         raise;
   end Test_Refused_Lookups_Are_Not_Absence;
