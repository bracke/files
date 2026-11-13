with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Files.Diagnostics;
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
         Ready_Count             => 0,
         Removable_Count         => 0,
         Windows_Drive_Count     => 0,
         Mount_Count             => 0,
         User_Mount_Count        => 0,
         Network_Mount_Count     => 0);
   begin
      for Root of Entries loop
         if Root.Ready = Root_Ready then
            Result.Ready_Count := Result.Ready_Count + 1;
         end if;

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

end Files.File_System.Testing;
