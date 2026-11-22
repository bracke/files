with Files.File_System.Trash;
with Files.File_System;
with Files.Model.Recent;
with Files.File_System.Thumbnails;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Jobs.Context;
with Hostkit;
with Hostkit.Fs;
with Files.Operations.Support;
with Files.Leaf_Names;
with Files.Diagnostics;
with Files.Jobs.Copy_Context;
with Files.File_Identities;
with Files.Operations.Undo_Recording;
with Files.Model.Rename;
with Files.Model.Selection;
with Files.Undo.History;

package body Files.Operations.Editing is

   use Ada.Strings.Unbounded;
   use type Files.File_System.Thumbnails.Thumbnail_Status;
   use type Files.Types.Item_Kind;
   use type Files.Undo.History.Undo_Action_Kind;
   use Files.Operations.Support;
   use Files.Operations.Undo_Recording;

   function Create_Links
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Hard     : Boolean)
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
      return Operation_Result is separate;

   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Commit_Create_File
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   procedure Begin_Create_Item
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Folder   : Boolean) is separate;

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

end Files.Operations.Editing;
