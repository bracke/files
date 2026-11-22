with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Files.Diagnostics;
with Files.File_System.Recovery;
with Files.File_System.Support;
with Hostkit.Fs;

package body Files.File_System.Testing is
   use Ada.Strings.Unbounded;

   --  What Change_Source_After_Copy armed; Changed once it has fired.
   Change_Trigger : Unbounded_String;
   Change_Source  : Unbounded_String;
   Change_Kind    : Source_Change := Edit_Source;
   Changed        : Boolean := False;

   --  What Fail_Directory_Restore armed.
   Restore_Trigger : Unbounded_String;
   Restore_Block   : Unbounded_String;

   --  What Fail_Owned_Delete armed.
   Delete_Trigger : Unbounded_String;

   --  Path with every '\' read as '/'.
   function Slashed (Path : String) return String is
      Result : String := Path;
   begin
      for Item of Result loop
         if Item = '\' then
            Item := '/';
         end if;
      end loop;
      return Result;
   end Slashed;

   --  Write Content to Path, replacing what it held.
   procedure Write (Path, Content : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      String'Write (Ada.Streams.Stream_IO.Stream (File), Content);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Write;

   --  The After_Metadata hook Change_Source_After_Copy installs.
   procedure Change_After_Metadata (Destination : String) is
      Path    : constant String := Slashed (Destination);
      Trigger : constant String := Slashed (To_String (Change_Trigger));
      Source  : constant String := To_String (Change_Source);
      Leaf    : constant String := "/payload";
   begin
      if Changed
        or else Trigger = ""
        or else Path'Length < Trigger'Length + Leaf'Length
        or else Path (Path'First .. Path'First + Trigger'Length - 1) /= Trigger
        or else Path (Path'Last - Leaf'Length + 1 .. Path'Last) /= Leaf
      then
         return;
      end if;
      Changed := True;
      case Change_Kind is
         when Edit_Source =>
            Write (Source, "new edits");
         when Replace_Source =>
            Ada.Directories.Rename (Source, Source & ".saved");
            Write (Source, "new edits");
         when Edit_Folder_Child =>
            Write (Hostkit.Fs.Join (Source, "child"), "new edits");
      end case;
   exception
      when Failure : others =>
         --  Unchanged: the test then sees the copy complete.
         Files.Diagnostics.Note (Failure, "Files.File_System.Testing");
   end Change_After_Metadata;

   --  Whether Change_Trashed_After_Copy has fired.
   Trashed_Changed : Boolean := False;

   --  The After_Restore_Copy hook Change_Trashed_After_Copy installs.
   procedure Change_Trashed (Trashed_Path : String) is
   begin
      if Trashed_Changed then
         return;
      end if;
      Trashed_Changed := True;
      Ada.Directories.Delete_File (Trashed_Path);
      Write (Trashed_Path, "another item");
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Testing");
   end Change_Trashed;

   --  The Refuse_Directory_Restore hook Fail_Directory_Restore installs.
   function Refuse_Restore (Directory : String) return Boolean is
      Block : constant String := To_String (Restore_Block);
   begin
      if Length (Restore_Trigger) = 0 or else Slashed (Directory) /= Slashed (To_String (Restore_Trigger)) then
         return False;
      end if;
      if Block /= "" and then not Ada.Directories.Exists (Block) then
         begin
            Ada.Directories.Create_Directory (Block);
            Write (Hostkit.Fs.Join (Block, "replacement"), "replacement bytes");
         exception
            when Failure : others =>
               Files.Diagnostics.Note (Failure, "Files.File_System.Testing");
         end;
      end if;
      return True;
   end Refuse_Restore;

   procedure Change_Source_After_Copy (Trigger, Source : String; Change : Source_Change) is
   begin
      Change_Trigger := To_Unbounded_String (Trigger);
      Change_Source := To_Unbounded_String (Source);
      Change_Kind := Change;
      Changed := False;
      After_Metadata := Change_After_Metadata'Access;
   end Change_Source_After_Copy;

   procedure Stop_Changing_Source is
   begin
      After_Metadata := null;
      Change_Trigger := Null_Unbounded_String;
      Change_Source := Null_Unbounded_String;
   end Stop_Changing_Source;

   procedure Change_Trashed_After_Copy is
   begin
      Trashed_Changed := False;
      After_Restore_Copy := Change_Trashed'Access;
   end Change_Trashed_After_Copy;

   procedure Stop_Changing_Trashed is
   begin
      After_Restore_Copy := null;
   end Stop_Changing_Trashed;

   procedure Fail_Directory_Restore (Trigger : String; Block : String := "") is
   begin
      Restore_Trigger := To_Unbounded_String (Trigger);
      Restore_Block := To_Unbounded_String (Block);
      Refuse_Directory_Restore := Refuse_Restore'Access;
   end Fail_Directory_Restore;

   procedure Stop_Failing_Directory_Restore is
   begin
      Refuse_Directory_Restore := null;
      Restore_Trigger := Null_Unbounded_String;
      Restore_Block := Null_Unbounded_String;
   end Stop_Failing_Directory_Restore;

   --  The Refuse_Owned_Delete hook Fail_Owned_Delete installs.
   function Refuse_Delete (Path : String) return Boolean is
     (Slashed (Path) = Slashed (To_String (Delete_Trigger)));

   procedure Fail_Owned_Delete (Trigger : String) is
   begin
      Delete_Trigger := To_Unbounded_String (Trigger);
      Refuse_Owned_Delete := Refuse_Delete'Access;
   end Fail_Owned_Delete;

   procedure Stop_Failing_Owned_Delete is
   begin
      Refuse_Owned_Delete := null;
      Delete_Trigger := Null_Unbounded_String;
   end Stop_Failing_Owned_Delete;

   --  What Watch_Ownership_Changes has seen.
   Ownership_Change_Count : Natural := 0;
   Last_User, Last_Group  : Files.Types.Account_Id := 0;

   --  The Before_Ownership_Change hook Watch_Ownership_Changes installs.
   procedure Note_Ownership_Change (Path : String; User_Id, Group_Id : Files.Types.Account_Id) is
      pragma Unreferenced (Path);
   begin
      Ownership_Change_Count := Ownership_Change_Count + 1;
      Last_User := User_Id;
      Last_Group := Group_Id;
   end Note_Ownership_Change;

   procedure Watch_Ownership_Changes is
   begin
      Ownership_Change_Count := 0;
      Last_User := 0;
      Last_Group := 0;
      Before_Ownership_Change := Note_Ownership_Change'Access;
   end Watch_Ownership_Changes;

   procedure Stop_Watching_Ownership_Changes is
   begin
      Before_Ownership_Change := null;
   end Stop_Watching_Ownership_Changes;

   function Ownership_Changes return Natural is (Ownership_Change_Count);

   function Last_Ownership_User return Files.Types.Account_Id is (Last_User);

   function Last_Ownership_Group return Files.Types.Account_Id is (Last_Group);

   --  The Refuse_Creation_Match hook Refuse_Creation_Matches installs.
   function Refuse_Every_Creation (Path : String) return Boolean is
      pragma Unreferenced (Path);
   begin
      return True;
   end Refuse_Every_Creation;

   procedure Refuse_Creation_Matches (Refuse : Boolean) is
   begin
      Refuse_Creation_Match := (if Refuse then Refuse_Every_Creation'Access else null);
   end Refuse_Creation_Matches;

   --  Where Pause_Sweep_Work holds a sweep.
   protected Sweep_Gate is
      procedure Close;
      procedure Arrive;
      procedure Open;
      function Reached return Boolean;
      entry Wait_Open;
   private
      Arrived : Boolean := False;
      Opened  : Boolean := True;
   end Sweep_Gate;

   protected body Sweep_Gate is
      procedure Close is
      begin
         Arrived := False;
         Opened := False;
      end Close;

      procedure Arrive is
      begin
         Arrived := True;
      end Arrive;

      procedure Open is
      begin
         Opened := True;
      end Open;

      function Reached return Boolean is (Arrived);

      entry Wait_Open when Opened is
      begin
         null;
      end Wait_Open;
   end Sweep_Gate;

   --  How long Hold_Sweep holds a sweep at most: far above any wait a test
   --  makes for something that must not wait for the held sweep, so such a
   --  wait cannot pass merely because the hold ran out.
   Sweep_Hold_Limit : constant Duration := 120.0;

   --  The During_Sweep_Work hook Pause_Sweep_Work installs.
   procedure Hold_Sweep (Payload : String) is
      pragma Unreferenced (Payload);
   begin
      Sweep_Gate.Arrive;
      select
         Sweep_Gate.Wait_Open;
      or
         delay Sweep_Hold_Limit;
      end select;
   end Hold_Sweep;

   procedure Pause_Sweep_Work is
   begin
      Sweep_Gate.Close;
      During_Sweep_Work := Hold_Sweep'Access;
   end Pause_Sweep_Work;

   function Sweep_Work_Paused return Boolean is (Sweep_Gate.Reached);

   procedure Resume_Sweep_Work is
   begin
      During_Sweep_Work := null;
      Sweep_Gate.Open;
   end Resume_Sweep_Work;

   procedure Delete_Owned_Tree (Path : String) is
   begin
      Files.File_System.Support.Delete_Owned_Tree (Path);
   end Delete_Owned_Tree;

   procedure Install_From_Environment is
      Trigger : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TRASH_TRIGGER", "");
      Source  : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TRASH_SOURCE", "");
      Fault   : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TRASH_FAULT", "");
      Restore : constant String := Ada.Environment_Variables.Value ("FILES_TEST_DIRECTORY_RESTORE_FAULT", "");
   begin
      if Trigger /= "" and then Source /= "" and then Fault /= "" then
         Change_Source_After_Copy
           (Trigger, Source,
            (if Fault = "replace" then Replace_Source
             elsif Fault = "folder" then Edit_Folder_Child
             else Edit_Source));
      end if;
      if Restore /= "" then
         Fail_Directory_Restore
           (Restore, Ada.Environment_Variables.Value ("FILES_TEST_DIRECTORY_RESTORE_BLOCK", ""));
      end if;
   end Install_From_Environment;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
   is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      return
        (Backend                 => Backend,
         Path                    => To_Unbounded_String (Path),
         Requires_Native_Api     => Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native,
         Can_Use_Current_Process => Backend not in Trash_Windows_Recycle_Bin | Trash_Macos_Native);
   end Native_Trash_Request_For;

   procedure Refuse_Native_Trash (Refuse : Boolean) is
   begin
      Native_Trash_Refused := Refuse;
   end Refuse_Native_Trash;

   procedure Trash_Says_Nowhere (Withhold : Boolean) is
   begin
      Trash_Location_Withheld := Withhold;
   end Trash_Says_Nowhere;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
   is
      Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
      Mutation   : Mutation_Result;
   begin
      if Request.Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native then
         return Trash_Natively (Request);
      end if;

      if not Evaluation.Supported then
         return Evaluation;
      end if;

      Mutation := Move_To_Trash (To_String (Request.Path));
      return
        (Supported => True,
         Attempted => True,
         Completed => Mutation.Success,
         Error_Key => Mutation.Error_Key);
   end Execute_Native_Trash;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      case Backend is
         when Trash_Windows_Recycle_Bin | Trash_Macos_Native =>
            return
              (Backend             => Backend,
               Native_Platform     => True,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => True,
               Permanent_Delete    => False);
         when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
            return
              (Backend             => Backend,
               Native_Platform     => False,
               Xdg_Compatible      => Backend /= Trash_Macos_Home,
               Metadata_Sidecar    => True,
               Collision_Safe_Name => True,
               Permanent_Delete    => False);
         when Trash_Unavailable =>
            return
              (Backend             => Trash_Unavailable,
               Native_Platform     => False,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => False,
               Permanent_Delete    => False);
      end case;
   end Trash_Capabilities_Of_Current_Environment;

   function Root_Discovery_Status return Root_Discovery_Diagnostics is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Result  : Root_Discovery_Diagnostics :=
        (Root_Count              => Natural (Entries.Length),
         Removable_Count         => 0,
         Windows_Drive_Count     => 0,
         Mount_Count             => 0,
         User_Mount_Count        => 0,
         Network_Mount_Count     => 0);
   begin
      for Root of Entries loop
         if Root.Removable then
            Result.Removable_Count := Result.Removable_Count + 1;
         end if;

         case Root.Kind is
            when Root_Windows_Drive =>
               Result.Windows_Drive_Count := Result.Windows_Drive_Count + 1;
            when Root_Mount =>
               Result.Mount_Count := Result.Mount_Count + 1;
            when Root_User_Mount =>
               Result.User_Mount_Count := Result.User_Mount_Count + 1;
            when Root_Network_Mount =>
               Result.Network_Mount_Count := Result.Network_Mount_Count + 1;
            when others =>
               null;
         end case;
      end loop;

      return Result;
   end Root_Discovery_Status;

   function Available_Roots return Files.Types.String_Vectors.Vector is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Roots   : Files.Types.String_Vectors.Vector;
   begin
      for Root of Entries loop
         Roots.Append (Root.Path);
      end loop;

      return Roots;
   end Available_Roots;

   function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean
     renames Files.File_System.Is_User_Visible_Mount_Point;

   function Storable_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean
     renames Files.File_System.Storable_Leaf_Name_At;

   function Trash_Backend_Of_Current_Environment return Trash_Backend
     renames Files.File_System.Trash_Backend_Of_Current_Environment;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Files.File_System.Evaluate_Native_Trash;

   function Trash_Natively
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Files.File_System.Trash_Natively;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
     renames Files.File_System.Trash_Deletion_Date;

   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Cancel : Cancellation_Check := Job_Cancelled;
      Batch  : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
   is
      Created : Created_Entry_Vectors.Vector;
   begin
      return Files.File_System.Execute_Drop_Import (Plans, Created, Cancel, Batch);
   end Execute_Drop_Import;

   function Path_Is_Within
     (Child, Parent : String;
      Folds         : not null access function (Directory : String) return Boolean)
      return Boolean is (Path_Is_Within_By (Child, Parent, Folds));

   function Move_By_Copy
     (Source, Destination : String;
      Expected_Identity   : String)
      return Mutation_Result
   is
      Identity, Revision : UString;
      Copy_Kept : Boolean;
   begin
      return Files.File_System.Recovery.Move_By_Copy
        (Source, Destination, "error.move.failed", Identity, Revision, Copy_Kept,
         Expected_Identity => Expected_Identity);
   end Move_By_Copy;

end Files.File_System.Testing;
