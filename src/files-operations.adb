with Files.File_System.Trash;
with Files.File_System.Permissions;
with Files.File_System.Thumbnails;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files.Fs_Primitives;
with Files.Undo_Payloads;
with Files.Transfer_Jobs;
with Files.Job_Context;
with Hostkit.Metadata;

with Hostkit;
with Hostkit.Fs;
with Hostkit.Process;
with Hostkit.Shell;

with Zlib;

with Files.Operations.Support;
with Ada.Containers;
with Files.Refresh_Jobs;
with Files.Diagnostics;
with Files.Copy_Context;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;
with Files.File_Identities;
with Files.History_Journal;
with Files.Undo_Recording;
with Files.Archive_Writing;
with Files.Model.Pasting;
with Files.Model.Folder_Sizes;
with Files.Model.History;
with Files.Model.Rename;
with Files.Model.Selection;

package body Files.Operations is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Thumbnails.Thumbnail_Status;
   use type Files.Types.Item_Kind;
   use type Files.File_System.Path_Status;
   use type Ada.Directories.File_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Model.Undo_Action_Kind;
   use type Zlib.Status_Code;

   use Files.Operations.Support;

   --  The undo history is recorded by Files.Undo_Recording; these name it
   --  here for the bodies that record.
   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Recorded_Original_Vectors.Vector :=
        Files.Model.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Model.Kept_Copy_Vectors.Vector := Files.Model.Kept_Copy_Vectors.Empty_Vector)
      return Boolean
     renames Files.Undo_Recording.Try_Record_Undo;

   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Recorded_Original_Vectors.Vector :=
        Files.Model.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Model.Kept_Copy_Vectors.Vector := Files.Model.Kept_Copy_Vectors.Empty_Vector)
     renames Files.Undo_Recording.Record_Undo;

   --  Items an action published (Files.Undo_Recording.Published).
   function Published
     (Items : Files.Model.Undo_Item_Vectors.Vector) return Files.Model.Recorded_Item_Vectors.Vector
     renames Files.Undo_Recording.Published;

   procedure Settle_History (Model : in out Files.Model.Window_Model) renames Files.Undo_Recording.Settle_History;

   function Unsafe_Open_Action
     (Model : in out Files.Model.Window_Model;
      Path  : String)
      return Operation_Result is separate;

   function Host_Arguments
     (Arguments : Files.Types.String_Vectors.Vector)
      return Hostkit.String_Vectors.Vector
   is separate;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Failure_Key : out UString;
      Detach      : Boolean := False)
      return Boolean
   is separate;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean
   is
      Ignored_Key : UString;
   begin
      return Execute_Open_Action (Action, Exit_Status, Ignored_Key, Detach);
   end Execute_Open_Action;

   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean is separate;

   function Detected_Terminal return String renames Hostkit.Process.Default_Terminal;

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

   function Run_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.Types.Tree_Search_Scope)
      return Operation_Result
   is separate;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean renames Files.File_System.Content_Matches;

   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is separate;

   function Refresh
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Measure_Again : Boolean := True)
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
     renames Files.File_System.Trash.Is_Trash_Files_Directory;

   function Is_Trash_Child (Path : String) return Boolean is separate;

   function Search_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result is
   begin
      if Files.Model.Filter_Text (Model) = "" then
         return Disabled (Model, "error.filter.empty");
      elsif Files.Model.Current_Path (Model) = "" or else Files.Model.In_Recent_View (Model) then
         return Disabled (Model, "error.directory.load");
      end if;
      return (Status => Operation_Success, others => <>);
   end Search_Refusal;

   function Trash_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result is
     (if Is_Trash_Directory (Files.Model.Current_Path (Model))
      then Disabled (Model, "error.trash.failed")
      else (Status => Operation_Success, others => <>));

   function Creation_Refusal
     (Model       : in out Files.Model.Window_Model;
      Failure_Key : String) return Operation_Result is
   begin
      if Files.Model.Selection.Includes_Temporary (Model) then
         return Disabled (Model, "error.create.pending");
      elsif Is_Trash_Directory (Files.Model.Current_Path (Model)) then
         return Disabled (Model, Failure_Key);
      end if;
      return (Status => Operation_Success, others => <>);
   end Creation_Refusal;

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

   Paste_Execution_First_Batch : constant := 32;

   function Finalize_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Kept      : Kept_Copy := No_Kept_Copy)
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
   is separate;

   function Ownership_Text
     (User_Id, Group_Id : Files.Types.Account_Id; User_Name, Group_Name : String)
      return String
   is
     (Files.Undo_Payloads.Ownership_Text
        ((User_Id, Group_Id, To_Unbounded_String (User_Name), To_Unbounded_String (Group_Name))));

   --  Which file metadata an editable-selection check is about.
   type Editable_Metadata is (Ownership_Metadata, Permissions_Metadata);

   --  The one check behind Permissions_ and Ownership_Editable_Selection:
   --  exactly one real (non-temporary) item is selected outside a trash's
   --  files directory, the platform can change What, and the item's What
   --  was read.
   function Metadata_Editable_Selection
     (Model : Files.Model.Window_Model;
      What  : Editable_Metadata)
      return Boolean
   is separate;

   function Permissions_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is (Metadata_Editable_Selection (Model, Permissions_Metadata));

   --  What a permission or ownership change on Path does once it is made:
   --  record its undo (Old_Text back, New_Text forward, the file's identity
   --  as provenance), reload the folder and clear the error.
   function Finish_Attribute_Change
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind     : Files.Model.Undo_Action_Kind;
      Path     : String;
      Identity : Files.Types.UString;
      Old_Text : String;
      New_Text : String)
      return Operation_Result
   is
   begin
      Record_Undo
        (Model, Kind,
         Published
           (Files.Model.Undo_Item_Vectors.To_Vector
              ((From          => To_Unbounded_String (Path),
                To            => To_Unbounded_String (Old_Text),
                Forward       => To_Unbounded_String (New_Text),
                Identity      => Identity,
                Tree_Revision => Null_Unbounded_String), 1)));
      declare
         Reload : constant Operation_Result :=
           Reload_Current_Directory (Model, Settings, Files.Model.Selection.Selected_Name (Model));
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Path);
   end Finish_Attribute_Change;

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
   is (Metadata_Editable_Selection (Model, Ownership_Metadata));

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

   use type Files.Model.Undo_Create_Kind;

   function Hard_Link_Snapshot (Source : String) return String is separate;

   --  An action's completed paths, for a membership test per step that does
   --  not scan the whole list (Undo_Entry keeps them as a list).
   package Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   function To_Set (Paths : Files.Types.String_Vectors.Vector) return Path_Sets.Set is
      Result : Path_Sets.Set;
   begin
      for Path of Paths loop
         Result.Include (To_String (Path));
      end loop;
      return Result;
   end To_Set;

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

   --  Apply Mode, or the access record Access_Text when there is one, to
   --  Action's entry Index, verified by its recorded identity.
   function Change_Recorded_Mode
     (Action : Files.Model.Undo_Entry; Index : Positive; Mode : Natural; Access_Text : String := "") return Boolean
   is separate;

   --  Apply Owner to Action's entry Index, verified by its recorded identity.
   function Change_Recorded_Ownership
     (Action : Files.Model.Undo_Entry; Index : Positive; Owner : Files.Undo_Payloads.Ownership) return Boolean
   is separate;

   --  Which recorded value a permission or ownership replay applies: the
   --  one the change replaced (undo) or the one it set (redo).
   type Metadata_Side is (Before_Change, After_Change);

   --  How a metadata replay ended: every item put back, at least one that
   --  could not be, or cancelled before the end.
   type Replay_Outcome is (Replayed, Item_Failed, Stopped);

   --  Put back each entry of a permission or ownership change as Side
   --  recorded it, verified by its identity: the one replay undo and redo
   --  share. A malformed record fails its item, not the rest.
   function Replay_Metadata (Action : Files.Model.Undo_Entry; Side : Metadata_Side) return Replay_Outcome
   is separate;

   --  Put Original back from the trash, verified by its identity.
   function Restore_Recorded_Trash (Original : Files.Model.Replaced_Original) return Boolean is separate;

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

   --  Which stack Replay takes its entry from.
   type Replay_Direction is (Replay_Undo, Replay_Redo);

   --  Undo (apply in reverse) or redo (apply forward) the newest entry of
   --  one stack, then reload the directory. A fully applied entry moves to
   --  the other stack -- an undo-only one is consumed -- and a partly
   --  applied one goes back with its completed steps.
   --
   --  @param Model Window model carrying the history to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Direction Which stack to take the entry from.
   --  @return Structured operation result.
   function Replay
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Direction : Replay_Direction)
      return Operation_Result
   is separate;

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is (Replay (Model, Settings, Replay_Undo));

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is (Replay (Model, Settings, Replay_Redo));

   procedure Clear_Undo (Model : in out Files.Model.Window_Model) is separate;

   procedure Release_History (Model : in out Files.Model.Window_Model) is separate;

   function Launch_Open_Actions
     (Model   : in out Files.Model.Window_Model;
      Actions : Files.Desktop_Applications.Open_Action_Vectors.Vector;
      Paths   : Files.Types.String_Vectors.Vector)
      return Operation_Result
   is separate;

   function Launch_Application
     (Model   : in out Files.Model.Window_Model;
      App     : Files.Desktop_Applications.Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Operation_Result
   is separate;

   procedure Begin_Open_With (Model : in out Files.Model.Window_Model) is separate;

   procedure Begin_Create_Item
     (Model  : in out Files.Model.Window_Model;
      Folder : Boolean)
   is separate;

   function Root_Entries_With_Favorites
     (Settings : Files.Settings.Settings_Model)
      return Files.File_System.Root_Entry_Vectors.Vector
   is separate;

   procedure Seed_Tree
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is separate;

   procedure Load_Tree_Children
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Positive)
   is separate;

   function Classify_Favorite (Path : String) return Favorite_Target is separate;

   function Navigate_And_Select
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Operation_Result
   is separate;

   procedure Focus_Ownership_Input
     (Model         : in out Files.Model.Window_Model;
      Editing_Group : Boolean)
   is separate;

   function Commit_Ownership_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Prepare_Quick_Look
     (Item : Files.Items.Directory_Item)
      return Files.Quick_Look.Quick_Look_Content
   is
      Name     : constant String := To_String (Item.Name);
      Filetype : constant String := To_String (Item.Filetype);
      Icon_Id  : constant String := To_String (Item.Icon_Id);
      Path     : constant String := To_String (Item.Full_Path);
      Is_Image : constant Boolean :=
        Files.File_System.Thumbnails.Is_Image_Item (Item.Kind, Filetype, Name, Icon_Id);
      Text_File : constant Boolean :=
        not Is_Image
        and then (Item.Kind = Files.Types.Regular_File_Item or else Item.Kind = Files.Types.Executable_Item);
      Read_Ok  : Boolean := False;
      Complete : Boolean := True;
      Raw      : constant String :=
        (if Text_File
         then Files.File_System.Read_Preview_Text (Path, Files.Quick_Look.Max_Preview_Bytes, Read_Ok, Complete)
         else "");
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
           Raw_Bytes      => Raw,
           Bytes_Complete => Complete or else not Read_Ok);
   begin
      --  The original image, so the preview scales the source rather than the
      --  small thumbnail, is decoded off the UI thread: Poll_Quick_Look asks
      --  for it, and the thumbnail shows until it is in.
      Content.Source_Stamp := Quick_Look_Stamp (Item);
      return Content;
   end Prepare_Quick_Look;

   function Quick_Look_Stamp (Item : Files.Items.Directory_Item) return Files.Types.UString is
     (To_Unbounded_String
        (Long_Long_Integer'Image (Item.Size)
         & (if Item.Modified_Available
            then " " & Ada.Calendar.Formatting.Image (Item.Modified_Time, Include_Time_Fraction => True)
            else "")));

   procedure Begin_Paste_Execution
     (Model           : in out Files.Model.Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
   is
      Writes : Natural := 0;
   begin
      for Action of Actions loop
         if not Action.Skip then
            Writes := Writes + 1;
         end if;
      end loop;
      Files.Model.Pasting.Begin_Execution
        (Model, Actions, Mode, Clear_Clipboard,
         Batch => (if Writes > 1 then Files.Copy_Context.Create else Files.Copy_Context.Empty_Session));
   end Begin_Paste_Execution;

end Files.Operations;
