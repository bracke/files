with Files_Suite.Listings;
with Files.Operation_Results;
with Files.File_System.Permissions;
with Files.Controller.Testing;
with Files.File_System.Testing;
separate (Files_Suite.Operations)
   --  Enter in the owner (or group) field without a change called chown all
   --  the same, which on Linux clears a file's set-user-id and set-group-id
   --  bits and its capabilities, and recorded an Undo that changed nothing;
   --  and an edit of the user sent the group as listed, which may no longer
   --  be the file's. Now an unchanged field asks for nothing and records
   --  nothing, and an edit of one id leaves the other as the file has it.
   procedure Test_Ownership_Enter_Asks_Only_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Account_Id;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "enter_own.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Uid, Gid : Files.Types.Account_Id := 0;
      Avail    : Boolean := False;

      --  An id that is not Id, nor Keep_Id.
      function Other (Id : Files.Types.Account_Id) return Files.Types.Account_Id is (if Id = 1 then 2 else 1);

      --  Edit the owner (or the group) field to Text and press Enter.
      procedure Commit (Group : Boolean; Text : String) is
      begin
         Select_Name (Model, "enter_own.txt");
         Files.Model.Focus_Ownership_Input (Model, Editing_Group => Group, Account_Name => "");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Focus (Model), Files.UI_Types.Focus_Ownership_Input, "the ownership field is edited");
         Files.Controller.Testing.Replace_Focused_Text (Model, Text);
         Routed := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      end Commit;
   begin
      if not Files.File_System.Permissions.Supports_Ownership then
         Files_Suite.Support.Skip
           ("Test_Ownership_Enter_Asks_Only_Changes", "this host has no POSIX owner and group to change");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "own me");
      Hostkit.Metadata.File_Ownership (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "enter_own.txt");
      Files.File_System.Testing.Watch_Ownership_Changes;

      --  Enter on the ids the file has, typed or as seeded.
      Commit (Group => False, Text => Files.Types.Account_Image (Uid));
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status, Files.Operation_Results.Operation_Success, "an unchanged owner commits");
      Commit (Group => True, Text => Files.Types.Account_Image (Gid));
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status, Files.Operation_Results.Operation_Success, "an unchanged group commits");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model), Files.UI_Types.Focus_None, "and the field is closed");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Testing.Ownership_Changes, 0, "no ownership change is asked of the host");
      Assert (not Files.Model.History.Undo_Available (Model), "and no Undo is recorded");

      --  An edit of the user leaves the group to the file, and the other way.
      Commit (Group => False, Text => Files.Types.Account_Image (Other (Uid)));
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Testing.Ownership_Changes, 1, "an edited owner is asked for");
      Assert (Files.File_System.Testing.Last_Ownership_User = Other (Uid), "with the user typed");
      Assert (Files.File_System.Testing.Last_Ownership_Group = Hostkit.Metadata.Keep_Id,
              "and the group kept as the file has it");
      Commit (Group => True, Text => Files.Types.Account_Image (Other (Gid)));
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Testing.Ownership_Changes, 2, "an edited group is asked for");
      Assert (Files.File_System.Testing.Last_Ownership_Group = Other (Gid), "with the group typed");
      Assert (Files.File_System.Testing.Last_Ownership_User = Hostkit.Metadata.Keep_Id,
              "and the user kept as the file has it");
      Files.File_System.Testing.Stop_Watching_Ownership_Changes;
      Reset_Root;
   exception
      when others =>
         Files.File_System.Testing.Stop_Watching_Ownership_Changes;
         raise;
   end Test_Ownership_Enter_Asks_Only_Changes;
