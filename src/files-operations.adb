with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files_Config;

with Files.Folder_Size;
with Files.Fs;
with Files.Paste;
with Files.Platform.Metadata;

with Hostkit;
with Hostkit.Fs;
with Hostkit.Process;
with Hostkit.Shell;

with Zlib;

with Files.Operations.Support;
with Files.File_System;
with Files.Types;
with Files.Quick_Look;

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

   --  The open/launch/terminal operations are subunits of Files.Operations.
   --  Hoisted from the former History child (now subunits).
   use Ada.Strings.Unbounded;
   use type Files.Model.Undo_Action_Kind;
   use Files.Operations.Support;

   --  Hoisted from the former Metadata child (now subunits).
   use Ada.Strings.Unbounded;
   use Files.Operations.Support;

   --  Hoisted from the former Search child (now subunits).
   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;
   use Files.Operations.Support;

   --  Bounded content-search guards. Bytes read per file mirror the Quick Look
   --  text preview cap; the file and depth caps mirror Directory_Size so the walk
   --  cannot run away on huge or deeply nested trees.
   Content_Search_Max_Bytes   : constant := 64 * 1024;
   Content_Search_Max_Matches : constant := 1_000;
   Content_Search_Max_Files   : constant := 20_000;
   Content_Search_Max_Depth   : constant := 64;

   --  Hoisted from the former Navigation child (now subunits).
   use Ada.Strings.Unbounded;
   use type Files.File_System.Path_Status;
   use type Files.Types.Item_Kind;
   use Files.Operations.Support;

   --  Shared normalize -> load -> navigate tail for the absolute-destination
   --  navigations (Home, Parent, Trash, Select_Root). Path is the raw requested
   --  path; on a normalize failure the error is reported against it, on a load
   --  failure against the normalized path. Close_Selector closes the root selector
   --  after a successful navigation (used only by Select_Root).
   --  Hoisted from the former Open child (now subunits).
   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;
   use type GNAT.OS_Lib.Argument_List_Access;
   use type GNAT.OS_Lib.String_Access;
   use Files.Operations.Support;

   --  Hoisted from the former Transfer child (now subunits).
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Zlib.Status_Code;
   use Files.Operations.Support;

   --  Shared implementation for the create-symlink and create-hard-link
   --  commands. Each selected item gets a uniquely named link in the current
   --  directory; the created links are recorded so Undo can delete them.
   function Create_Links
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Hard     : Boolean)
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

   function Unsafe_Open_Action
     (Model : in out Files.Model.Window_Model;
      Path  : String)
      return Operation_Result is separate;

   --  These stay public because callers and tests ask for them, but the answer is
   --  Hostkit's: which shell, and how it wants a command introduced, is one question
   --  asked in one place, not re-derived per crate.

   --  An open action's arguments, in the vector Hostkit speaks.
   function Host_Arguments
     (Arguments : Files.Types.String_Vectors.Vector)
      return Hostkit.String_Vectors.Vector
 is separate;

   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean is separate;

   function Load_And_Navigate
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Path           : String;
      Close_Selector : Boolean := False)
      return Operation_Result
 is separate;

   type History_Direction is (History_Back, History_Forward);

   --  History navigation shared by Navigate_Back and Navigate_Forward: mirror
   --  images differing only in the availability check, the error key, the move,
   --  and which way the rollback moves on a failed reload.
   function Navigate_History
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Direction : History_Direction)
      return Operation_Result
 is separate;

   function Permissions_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
 is separate;

   function Ownership_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
 is separate;

   function Move_Back
     (Sources : Files.Types.String_Vectors.Vector;
      Targets : Files.Types.String_Vectors.Vector)
      return Boolean
 is separate;

   --  Apply the reverse (undo) direction of Action. Returns True on full
   --  success. Mirrors the pre-existing single-level undo behaviour.
   function Apply_Reverse
     (Action : Files.Model.Undo_Entry)
      return Boolean
 is separate;

   --  Apply the forward (redo) direction of Action. Returns True on full
   --  success. Undo_Restore_Trash is undo-only and never reaches here.
   function Apply_Forward
     (Action : Files.Model.Undo_Entry)
      return Boolean
 is separate;

   function Open_Action_Policy return Open_Action_Execution_Policy
     is separate;

   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle
     is separate;

   function Shell_Executable return String
     is separate;

   function Shell_Command_Option return String
     is separate;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean
     is separate;

   function Detected_Terminal return String
     is separate;

   function Open_Terminal
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     is separate;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     is separate;

   function Open_Selected
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     is separate;

   --  The recursive name/content search operations are subunits of Files.Operations.
   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     is separate;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean
     is separate;

   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     is separate;

   --  The directory-navigation operations are subunits of Files.Operations.
   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      is separate;

   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      is separate;

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

   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      is separate;

   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      is separate;

   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      is separate;

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

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result
      is separate;

   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
      is separate;

   --  The archive / link / delete / trash / paste transfer operations now live
   --  The clipboard/paste/trash transfer operations are subunits of Files.Operations.
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

   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     is separate;

   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     is separate;

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

   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
     is separate;

   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model)
     is separate;

   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result
     is separate;

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
            if Thumbnail.Status /= Files.File_System.Thumbnail_Generated then
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

   --  The permission/ownership operations are subunits of Files.Operations.
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

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Natural;
      Group_Id : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      is separate;

   procedure Update_Folder_Size
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      pragma Unreferenced (Settings);
   begin
      --  Folder size is a recursive subtree walk. It runs incrementally off the
      --  UI path (Files.Folder_Size), so measuring it does not block: here we just
      --  request the selected directories and the frame loop advances the walks.
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
            Files.Folder_Size.Set_Targets (Targets);
         end;
      else
         Files.Model.Clear_Folder_Size (Model);
         Files.Folder_Size.Cancel;
      end if;
   end Update_Folder_Size;

   --  The undo/redo history operations are subunits of Files.Operations.
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
               Content.Image_Pixels := Decoded.Pixels;
               Content.Image_Width := Decoded.Width;
               Content.Image_Height := Decoded.Height;
            end if;
         end;
      end if;
      return Content;
   end Prepare_Quick_Look;

end Files.Operations;
