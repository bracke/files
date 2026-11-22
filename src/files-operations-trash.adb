with Files.File_System;
with Files.Model.Recent;
with Files.File_System.Trash;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Jobs.Context;
with Files.Operations.Support;
with Files.Diagnostics;
with Files.File_Identities;
with Files.Model.Selection;
with Files.Undo.History;

package body Files.Operations.Trash is

   use Ada.Strings.Unbounded;
   use type Files.Undo.History.Undo_Action_Kind;
   use Files.Operations.Support;

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

end Files.Operations.Trash;
