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

   --  The undo history is recorded by Files.Operations.Undo_Recording; these name it
   --  here for the bodies that record.
   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Undo.History.Undo_Action_Kind;
      Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
        Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector := Files.Undo.History.Kept_Copy_Vectors.Empty_Vector)
     renames Files.Operations.Undo_Recording.Record_Undo;

   --  Items an action published (Files.Operations.Undo_Recording.Published).
   function Published
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector
     renames Files.Operations.Undo_Recording.Published;

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
     (Model  : in out Files.Model.Window_Model;
      Folder : Boolean)
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

end Files.Operations.Editing;
