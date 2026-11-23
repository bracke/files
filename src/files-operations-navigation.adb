with Files.File_System_Types;
with Files.File_System;
with Files.Model.Recent;
with Files.File_System.Trash;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Files.IO.Fs_Primitives;
with Hostkit;
with Hostkit.Fs;
with Files.Operations.Support;
with Files.Refresh;
with Files.Diagnostics;
with Files.Model.Selection;

package body Files.Operations.Navigation is

   use Ada.Strings.Unbounded;
   use type Files.File_System_Types.Path_Status;
   use Files.Operations.Support;

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

   function Commit_Path_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is separate;

   function Navigate_Forward
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

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result is separate;

   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
   is separate;

   function Navigate_And_Select
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Operation_Result
   is separate;

   function Run_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.UI_Types.Tree_Search_Scope)
      return Operation_Result
   is separate;

end Files.Operations.Navigation;
