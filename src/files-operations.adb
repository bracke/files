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

with Files.Operations.History;
with Files.Operations.Metadata;
with Files.Operations.Navigation;
with Files.Operations.Open;
with Files.Operations.Search;
with Files.Operations.Support;
with Files.Operations.Transfer;

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

   --  The open/launch/terminal operations now live in the
   --  Files.Operations.Open child; these renamings keep them on the public API.
   function Open_Action_Policy return Open_Action_Execution_Policy
     renames Files.Operations.Open.Open_Action_Policy;

   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle
     renames Files.Operations.Open.Open_Action_Lifecycle_Of;

   function Shell_Executable return String
     renames Files.Operations.Open.Shell_Executable;

   function Shell_Command_Option return String
     renames Files.Operations.Open.Shell_Command_Option;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean
     renames Files.Operations.Open.Execute_Open_Action;

   function Detected_Terminal return String
     renames Files.Operations.Open.Detected_Terminal;

   function Open_Terminal
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Open.Open_Terminal;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     renames Files.Operations.Open.Prepare_Open_Selected_Action;

   function Open_Selected
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     renames Files.Operations.Open.Open_Selected;

   --  The recursive name/content search operations now live in the
   --  Files.Operations.Search child; these renamings keep them on the public API.
   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Search.Run_Recursive_Search;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean
     renames Files.Operations.Search.Content_Matches;

   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Search.Run_Content_Search;

   --  The directory-navigation operations now live in the
   --  Files.Operations.Navigation child; these renamings keep them on the public API.
   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      renames Files.Operations.Navigation.Apply_Ui_State;

   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Refresh;

   function Refresh_If_Changed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Refresh_If_Changed;

   function Commit_Path_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Commit_Path_Input;

   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Navigate_Home;

   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Navigate_Back;

   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Navigate_Forward;

   function Navigate_Parent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Navigate_Parent;

   function Navigate_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Navigate_Trash;

   function Navigate_Recent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Navigate_Recent;

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result
      renames Files.Operations.Navigation.Select_Root;

   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
      renames Files.Operations.Navigation.Eject_Selected_Root;

   --  The archive / link / delete / trash / paste transfer operations now live
   --  in the Files.Operations.Transfer child; these renamings keep them on the
   --  parent's public API.
   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result
     renames Files.Operations.Transfer.Compress_Selected;

   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Extract_Selected;

   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Duplicate_Selected;

   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Create_Symlink_Selected;

   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Create_Hardlink_Selected;

   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Delete_Selected;

   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Delete_Selected_Permanently;

   function Restore_Selected_From_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Restore_Selected_From_Trash;

   function Empty_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Empty_Trash;

   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
     renames Files.Operations.Transfer.Advance_Paste_Execution;

   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model)
     renames Files.Operations.Transfer.Cancel_Paste_Execution;

   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result
     renames Files.Operations.Transfer.Begin_Paste;

   function Begin_Paste_To
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Destination    : String;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result
     renames Files.Operations.Transfer.Begin_Paste_To;

   function Resolve_Paste_Conflict
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Choice    : Conflict_Choice;
      Apply_All : Boolean)
      return Operation_Result
     renames Files.Operations.Transfer.Resolve_Paste_Conflict;

   function Commit_Create_File
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Commit_Create_File;

   function Commit_Rename
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Transfer.Commit_Rename;

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

   --  The permission/ownership operations now live in the Files.Operations.Metadata
   --  child; these renamings keep them on the parent's public API.
   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Metadata.Set_Permissions_For;

   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Metadata.Toggle_Permission_Bit;

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Natural;
      Group_Id : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Metadata.Set_Ownership_For;

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

   --  The undo/redo history operations now live in the Files.Operations.History
   --  child; these renamings keep public Undo_Last/Redo_Last on the parent.
   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.History.Undo_Last;

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.History.Redo_Last;

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
