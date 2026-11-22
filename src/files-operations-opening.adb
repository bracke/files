with Files.File_System;
with Files.Model.Recent;
with Files.File_System.Trash;
with Ada.Strings.Unbounded;
with Hostkit;
with Hostkit.Process;
with Hostkit.Shell;
with Files.Operations.Support;
with Files.Diagnostics;
with Files.Model.Selection;

package body Files.Operations.Opening is

   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;
   use Files.Operations.Support;

   function Unsafe_Open_Action
     (Model : in out Files.Model.Window_Model;
      Path  : String)
      return Operation_Result is separate;

   function Host_Arguments
     (Arguments : Files.Types.String_Vectors.Vector)
      return Hostkit.String_Vectors.Vector
   is separate;

   function Launch_Open_Actions
     (Model   : in out Files.Model.Window_Model;
      Actions : Files.Desktop_Applications.Open_Action_Vectors.Vector;
      Paths   : Files.Types.String_Vectors.Vector)
      return Operation_Result
   is separate;

   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean is separate;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Failure_Key : out UString;
      Detach      : Boolean := False)
      return Boolean
   is separate;

   function Open_Selected
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is separate;

   function Open_Terminal
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
   is separate;

   function Launch_Application
     (Model   : in out Files.Model.Window_Model;
      App     : Files.Desktop_Applications.Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Operation_Result
   is separate;

   procedure Begin_Open_With (Model : in out Files.Model.Window_Model) is separate;

   function Detected_Terminal return String renames Hostkit.Process.Default_Terminal;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is separate;

end Files.Operations.Opening;
