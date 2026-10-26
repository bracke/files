with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files_Config;

with Files.Folder_Size;
with Files.Fs_Primitives;
with Files.Paste;
with Files.Shared_Bytes;
with Files.Transfer_Jobs;
with Files.Process_Jobs;
with Files.Operation_Jobs;
with Files.Job_Context;
with Hostkit.Metadata;

with Hostkit;
with Hostkit.Fs;
with Hostkit.Process;
with Hostkit.Shell;

with Zlib;

with Files.Operations.Support;
with Ada.Containers;
with Hostkit.Host;
with Files.Refresh_Jobs;
with Files.Diagnostics;
with Files.Copy_Context;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;
with Files.File_Identities;
with Files.History_Journal;
with Files.Archive_Writing;

package body Files.Operations is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Thumbnail_Status;
   use type Files.Types.Item_Kind;
   use type Files.File_System.Path_Status;
   use type GNAT.OS_Lib.Argument_List_Access;
   use type GNAT.OS_Lib.String_Access;
   use type Ada.Directories.File_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Model.Undo_Action_Kind;
   use type Zlib.Status_Code;

   use Files.Operations.Support;

   function Open_Action_Policy return Open_Action_Execution_Policy is separate;

   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle
   is separate;

   function Unsafe_Open_Action
     (Model : in out Files.Model.Window_Model;
      Path  : String)
      return Operation_Result is separate;

   function Shell_Executable return String is separate;

   function Shell_Command_Option return String is separate;

   function Host_Arguments
     (Arguments : Files.Types.String_Vectors.Vector)
      return Hostkit.String_Vectors.Vector
   is separate;

   function Is_Windows_Start_Opener
     (Executable : String;
      Arguments  : Hostkit.String_Vectors.Vector)
      return Boolean
   is separate;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean
   is separate;

   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean is separate;

   function Detected_Terminal return String is separate;

   function Open_Terminal
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Open_Selected
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is separate;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is separate;

   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   Content_Search_Max_Bytes   : constant := 64 * 1024;

   Content_Search_Max_Matches : constant := 1_000;

   Content_Search_Max_Files   : constant := 20_000;

   Content_Search_Max_Depth   : constant := 64;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean is separate;

   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is separate;

   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Refresh_If_Changed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Commit_Path_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Load_And_Navigate
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Path           : String;
      Close_Selector : Boolean := False)
      return Operation_Result
   is separate;

   type History_Direction is (History_Back, History_Forward);

   function Navigate_History
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Direction : History_Direction)
      return Operation_Result
   is separate;

   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Navigate_Parent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Navigate_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Navigate_Recent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result is separate;

   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
   is separate;

   package Archive_Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   type Text_Array_Access is access Zlib.Text_Array;

   procedure Free_Text_Array is new Ada.Unchecked_Deallocation
     (Zlib.Text_Array, Text_Array_Access);

   --  Keep the shorter local name at the mutation sites while using the shared
   --  filesystem-identity check for every trash-directory decision.
   function Is_Trash_Directory (Path : String) return Boolean
     renames Files.File_System.Is_Trash_Files_Directory;

   function Is_Trash_Child (Path : String) return Boolean is separate;

   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result
   is separate;

   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Leaf_Extension_Start (Name : String) return Natural is separate;

   function Leaf_Extension (Name : String) return String is separate;

   function Leaf_Base (Name : String) return String is separate;

   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Create_Links
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Hard     : Boolean)
      return Operation_Result
   is separate;

   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Restore_Selected_From_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Empty_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Existing_Destination_Paths
     (Directory : String;
      Listed    : out Boolean)
      return Files.Types.String_Vectors.Vector
   is separate;

   function With_Case_Aliases
     (Work      : Files.Paste.Work_Item_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      Directory : String)
      return Files.Types.String_Vectors.Vector
   is separate;

   function Paste_Work_List
     (Plans     : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Directory : String)
      return Files.Paste.Work_Item_Vectors.Vector
   is separate;

   function Clear_Replaced_Destination
     (Path    : String;
      Source  : String;
      Trashed : out Files.Types.UString)
      return Boolean is separate;

   Paste_Execution_First_Batch : constant := 32;

   function Finalize_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String)
      return Operation_Result
   is separate;

   --  Resolve a preserved original's destination and check its live entry,
   --  then record it in the model's paste execution.
   procedure Record_Paste_Replaced_Trash
     (Model         : in out Files.Model.Window_Model;
      Trash_Path    : Files.Types.UString;
      Identity      : String;
      Original_Path : String);

   procedure Record_Paste_Replaced_Trash
     (Model         : in out Files.Model.Window_Model;
      Trash_Path    : Files.Types.UString;
      Identity      : String;
      Original_Path : String) is separate;

   --  Check a published destination against its creation snapshot, then
   --  record the write in the model's paste execution.
   procedure Record_Paste_Write
     (Model         : in out Files.Model.Window_Model;
      Dest_Path     : Files.Types.UString;
      Source_Path   : Files.Types.UString;
      Name          : String;
      Identity      : String;
      Tree_Revision : String;
      Retain_Verified_Snapshot : Boolean := False);

   procedure Record_Paste_Write
     (Model         : in out Files.Model.Window_Model;
      Dest_Path     : Files.Types.UString;
      Source_Path   : Files.Types.UString;
      Name          : String;
      Identity      : String;
      Tree_Revision : String;
      Retain_Verified_Snapshot : Boolean := False) is separate;

   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
   is separate;

   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model) is separate;

   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result is separate;

   function Begin_Paste_To
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Destination    : String;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result
   is separate;

   function Resolve_Paste_Conflict
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Choice    : Conflict_Choice;
      Apply_All : Boolean)
      return Operation_Result
   is separate;

   function Commit_Create_File
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Commit_Rename
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Generate_Selected_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
      First_Name : Unbounded_String;
      Unsupported_Key  : Unbounded_String;
      Unsupported_Path : Unbounded_String;

      function Cache_Directory return String is
      begin
         return Files.File_System.Default_Thumbnail_Cache_Directory (Files.Model.Current_Path (Model));
      end Cache_Directory;
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      for Item of Items loop
         declare
            Thumbnail : constant Files.File_System.Thumbnail_Result :=
              Files.File_System.Generate_Thumbnail (To_String (Item.Full_Path), Cache_Directory);
         begin
            if Thumbnail.Status = Files.File_System.Thumbnail_Unsupported then
               --  A folder or non-image in a mixed selection is not a failure;
               --  stopping here skipped every image after it.
               Unsupported_Key := Thumbnail.Error_Key;
               Unsupported_Path := Item.Full_Path;
            elsif Thumbnail.Status /= Files.File_System.Thumbnail_Generated then
               --  Refresh so thumbnails already generated for earlier items in
               --  the batch are shown, then restore the failure diagnostic.
               Files.Model.Set_Error (Model, To_String (Thumbnail.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Thumbnail.Error_Key));
               end;
               return Make_Result
                 (Operation_Failed, To_String (Thumbnail.Error_Key), To_String (Item.Full_Path));
            elsif Length (First_Path) = 0 then
               First_Path := Thumbnail.Thumbnail_Path;
               First_Name := Item.Name;
            end if;
         end;
      end loop;

      if Length (First_Path) = 0 and then Length (Unsupported_Key) > 0 then
         --  Nothing in the selection could have a thumbnail.
         Files.Model.Set_Error (Model, To_String (Unsupported_Key));
         return Make_Result (Operation_Failed, To_String (Unsupported_Key), To_String (Unsupported_Path));
      end if;

      Files.Model.Set_Error (Model, "");
      declare
         Reload : constant Operation_Result :=
           Reload_Current_Directory (Model, Settings, Select_Name => To_String (First_Name));
         pragma Unreferenced (Reload);
      begin
         null;
      end;
      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Generate_Selected_Thumbnails;

   function Ownership_Text
     (User_Id, Group_Id : Files.Types.Account_Id; User_Name, Group_Name : String)
      return String
   is
     (Files.Types.Account_Image (User_Id)
      & " "
      & Files.Types.Account_Image (Group_Id)
      & ASCII.NUL & User_Name & ASCII.NUL & Group_Name);

   function Permissions_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is separate;

   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Ownership_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is separate;

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Files.Types.Account_Id;
      Group_Id : Files.Types.Account_Id;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   procedure Settle_Current_Is_Trash
     (Model : in out Files.Model.Window_Model) is
   begin
      Files.Model.Set_Current_Is_Trash (Model, Is_Trash_Directory (Files.Model.Current_Path (Model)));
   end Settle_Current_Is_Trash;

   procedure Ensure_Selected_Item_Extra
     (Model : in out Files.Model.Window_Model) is
   begin
      if Files.Model.Selected_Item_Needs_Extra (Model) then
         declare
            Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         begin
            Files.Model.Set_Selected_Item_Extra
              (Model,
               Files.File_System.Extra_Info_Token
                 (To_String (Item.Full_Path), Item.Kind, To_String (Item.Filetype)));
         end;
      end if;
   end Ensure_Selected_Item_Extra;

   procedure Focus_Ownership_Input
     (Model         : in out Files.Model.Window_Model;
      Editing_Group : Boolean) is
   begin
      if not Files.File_System.Supports_Ownership or else Files.Model.Selected_Count (Model) /= 1 then
         return;
      end if;
      declare
         Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
      begin
         Files.Model.Focus_Ownership_Input
           (Model,
            Editing_Group,
            (if Editing_Group
             then Files.File_System.Group_Name_For_Id (Item.Group_Id)
             else Files.File_System.User_Name_For_Id (Item.Owner_Id)));
      end;
   end Focus_Ownership_Input;

   procedure Poll_Folder_Sizes (Model : in out Files.Model.Window_Model) is
      Scan      : Files.Folder_Size.Session := Files.Model.Folder_Scan (Model);
      Path      : Unbounded_String;
      Result    : Files.File_System.Directory_Size_Result;
      Available : Boolean;
   begin
      Files.Folder_Size.Step (Scan);
      loop
         Files.Folder_Size.Take (Scan, Path, Result, Available);
         exit when not Available;
         Files.Model.Note_Folder_Size (Model, To_String (Path), Result);
      end loop;
      Files.Model.Set_Folder_Scan (Model, Scan);
   end Poll_Folder_Sizes;

   procedure Cancel_Folder_Scan (Model : in out Files.Model.Window_Model) is
      Scan      : Files.Folder_Size.Session := Files.Model.Folder_Scan (Model);
      Path      : Unbounded_String;
      Result    : Files.File_System.Directory_Size_Result;
      Available : Boolean;
   begin
      Files.Folder_Size.Cancel (Scan);
      loop
         Files.Folder_Size.Take (Scan, Path, Result, Available);
         exit when not Available;
      end loop;
      Files.Model.Set_Folder_Scan (Model, Scan);
   end Cancel_Folder_Scan;

   procedure Update_Folder_Size
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      pragma Unreferenced (Settings);
   begin
      --  A size result changes the render revision. Stop older measurements
      --  before a listing request captures it, and resume after that read applies.
      if Files.Model.Paste_Execution_Is_Active (Model)
        or else Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
      then
         Cancel_Folder_Scan (Model);
         return;
      end if;
      --  The helper process performs the recursive subtree walk. Here we only
      --  request selected directories; the frame loop polls for completed totals.
      --  Every selected directory is measured -- for any selection, not only when
      --  the info pane is open -- so both the info pane and the bottom bar's
      --  combined total can count folder contents.
      if Files.Model.Selected_Count (Model) >= 1
        and then not Files.Model.Selection_Includes_Temporary (Model)
      then
         declare
            Targets : Files.Folder_Size.Path_Vectors.Vector;
         begin
            Files.Model.Prune_Folder_Sizes_To_Selection (Model);
            for Item of Files.Model.Selected_Items (Model) loop
               if Item.Kind = Files.Types.Directory_Item then
                  declare
                     Path : constant String := To_String (Item.Full_Path);
                  begin
                     if not Files.Model.Folder_Size_Cached_For (Model, Path) then
                        Targets.Append (To_Unbounded_String (Path));
                     end if;
                  end;
               end if;
            end loop;
            declare
               Scan : Files.Folder_Size.Session := Files.Model.Folder_Scan (Model);
            begin
               Files.Folder_Size.Set_Targets (Scan, Targets);
               Files.Model.Set_Folder_Scan (Model, Scan);
            end;
         end;
      else
         Cancel_Folder_Scan (Model);
         Files.Model.Clear_Folder_Size (Model);
      end if;
   end Update_Folder_Size;

   use type Files.Model.Undo_Create_Kind;

   function Hard_Link_Snapshot (Source : String) return String is separate;

   procedure Remove_Completion
     (Action : in out Files.Model.Undo_Entry;
      Path : Files.Types.UString;
      Forward : Boolean)
   is separate;

   function Move_Back
     (Action : in out Files.Model.Undo_Entry;
      Model : in out Files.Model.Window_Model;
      Forward : Boolean) return Boolean
   is separate;

   function Change_Recorded_Mode
     (Action : Files.Model.Undo_Entry; Index : Positive; Mode : Natural) return Boolean
   is separate;

   function Change_Recorded_Ownership
     (Action : Files.Model.Undo_Entry; Index : Positive;
      User_Id, Group_Id : Files.Types.Account_Id;
      Owner_Name, Group_Name : String) return Boolean
   is separate;

   function Parse_Ownership_Text
     (Text : String; User_Id, Group_Id : out Files.Types.Account_Id;
      User_Name, Group_Name : out Files.Types.UString) return Boolean
   is separate;

   function Restore_Recorded_Trash
     (Path : Files.Types.UString; Identities, Targets : Files.Types.String_Vectors.Vector;
      Index : Positive) return Boolean is separate;

   function Apply_Reverse
     (Action : in out Files.Model.Undo_Entry; Model : in out Files.Model.Window_Model)
      return Boolean
   is separate;

   function Completed_Creation_Matches
     (Action : Files.Model.Undo_Entry; Index : Positive; Path : String)
      return Boolean
   is separate;

   function Apply_Forward
     (Action : in out Files.Model.Undo_Entry; Model : in out Files.Model.Window_Model)
      return Boolean
   is separate;

   function Finish_Action
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Directory : String;
      Succeeded : Boolean) return Operation_Result
   is separate;

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Tree_Revisions : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Targets : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Retain_Verified_Main : Natural := 0;
      Retain_Verified_Restores : Natural := 0) return Boolean is separate;

   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Tree_Revisions : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Targets : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Retain_Verified_Main : Natural := 0;
      Retain_Verified_Restores : Natural := 0)
   is separate;

   procedure Clear_Undo (Model : in out Files.Model.Window_Model) is separate;

   procedure Release_History (Model : in out Files.Model.Window_Model) is separate;

   procedure Settle_History (Model : in out Files.Model.Window_Model) is separate;

   function Prepare_Quick_Look
     (Item : Files.File_System.Directory_Item)
      return Files.Quick_Look.Quick_Look_Content
   is
      use type Files.Quick_Look.Content_Kind;
      Name     : constant String := To_String (Item.Name);
      Filetype : constant String := To_String (Item.Filetype);
      Icon_Id  : constant String := To_String (Item.Icon_Id);
      Path     : constant String := To_String (Item.Full_Path);
      Is_Image : constant Boolean :=
        Files.File_System.Is_Image_Item (Item.Kind, Filetype, Name, Icon_Id);
      Raw      : constant String :=
        (if Is_Image
           or else (Item.Kind /= Files.Types.Regular_File_Item
                    and then Item.Kind /= Files.Types.Executable_Item)
         then ""
         else Files.File_System.Read_Preview_Text
                (Path, Files.Quick_Look.Max_Preview_Bytes));
      --  Preview resolution for the decoded original image, matching the icon
      --  atlas's large-tile bound so it renders crisply within the panel.
      Preview_Size : constant Positive := 512;
      Content : Files.Quick_Look.Quick_Look_Content :=
        Files.Quick_Look.Prepare_Content
          (Name           => Name,
           Filetype       => Filetype,
           Icon_Id        => Icon_Id,
           Kind           => Item.Kind,
           Size_Available => Item.Size_Available,
           Size           => Item.Size,
           Is_Image       => Is_Image,
           Image_Path     => Path,
           Raw_Bytes      => Raw);
   begin
      --  Decode the original image once here (Files.Quick_Look is pure), so the
      --  preview scales the source rather than the small thumbnail.
      if Content.Kind = Files.Quick_Look.Image_Content then
         declare
            Decoded : constant Files.File_System.Decoded_Image :=
              Files.File_System.Decode_Image_To_Pixels (Path, Preview_Size);
         begin
            if Decoded.Available then
               Content.Image_Pixels := Files.Shared_Bytes.To_Shared (Decoded.Pixels);
               Content.Image_Width := Decoded.Width;
               Content.Image_Height := Decoded.Height;
            end if;
         end;
      end if;
      return Content;
   end Prepare_Quick_Look;

end Files.Operations;
