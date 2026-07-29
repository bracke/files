with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.Paste;

with Zlib;

with Files.Operations.Support;

package body Files.Operations.Transfer is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Zlib.Status_Code;
   use Files.Operations.Support;

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

   --  Shared implementation for the create-symlink and create-hard-link
   --  commands. Each selected item gets a uniquely named link in the current
   --  directory; the created links are recorded so Undo can delete them.
   function Create_Links
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Hard     : Boolean)
      return Operation_Result
 is separate;

   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => False);
   end Create_Symlink_Selected;

   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => True);
   end Create_Hardlink_Selected;

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

   --  Full paths of every entry directly inside Directory (hidden entries
   --  included). Used as the "already exists" set for conflict detection and for
   --  rename uniquification, so a renamed paste avoids any existing name, not
   --  just the colliding one. Falls back to an empty set when the directory
   --  cannot be scanned; Execute_Drop_Import then still refuses to clobber.
   function Existing_Destination_Paths
     (Directory : String)
      return Files.Types.String_Vectors.Vector
 is separate;

   --  Build the paste work-list from validated plans: one item per valid plan,
   --  skipping a move whose destination equals its source (moving an item into
   --  the directory it already lives in is a no-op).
   function Paste_Work_List
     (Plans     : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Directory : String)
      return Files.Paste.Work_Item_Vectors.Vector
 is separate;

   --  Remove a destination that a Replace decision must overwrite: move it to the
   --  trash when a backend is available, otherwise delete it permanently. Never
   --  touches a destination that is also the source (a paste onto itself).
   function Clear_Replaced_Destination
     (Path    : String;
      Source  : String;
      Trashed : out Files.Types.UString)
      return Boolean is separate;

   --  Batch size for the first advance driven from Begin_Paste /
   --  Resolve_Paste_Conflict: large enough that ordinary interactive pastes
   --  finish in one step (so no progress overlay ever flickers), while larger
   --  batches keep animating through the per-frame render-loop advances.
   Paste_Execution_First_Batch : constant := 32;

   --  Finalize an armed paste execution: record one undo covering the items
   --  actually completed (move reversed by moving back; copy by deleting the
   --  created copies), clear the move-mode clipboard, reload, and clear the
   --  execution state. A non-empty Error_Key reports a mid-run write failure.
   function Finalize_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String)
      return Operation_Result
 is separate;

   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
 is separate;

   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model) is
   begin
      if Files.Model.Paste_Execution_Is_Active (Model) then
         Files.Model.Cancel_Paste_Execution (Model);
      end if;
   end Cancel_Paste_Execution;

   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result is
   begin
      return Begin_Paste_To
        (Model, Settings, Source_Paths, Files.Model.Current_Path (Model), Mode, From_Clipboard);
   end Begin_Paste;

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

end Files.Operations.Transfer;
