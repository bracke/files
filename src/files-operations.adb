with Files.File_System.Trash;
with Files.Operations.Navigation;
with Files.File_System;
with Files.Model.Recent;
with Files.Model.Filtering;
with Ada.Strings.Unbounded;

with Files.Operations.Support;
with Files.Refresh;
with Files.IO.Errors;
with Files.Model.Folder_Sizes;
with Files.Model.Selection;

package body Files.Operations is
   use Ada.Strings.Unbounded;

   use Files.Operations.Support;

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

   function Search_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result is
   begin
      if Files.Model.Filtering.Filter_Text (Model) = "" then
         return Disabled (Model, "error.filter.empty");
      elsif Files.Model.Current_Path (Model) = "" or else Files.Model.Recent.In_Recent_View (Model) then
         return Disabled (Model, Files.IO.Errors.Directory_Load_Key);
      end if;
      return (Status => Operation_Success, others => <>);
   end Search_Refusal;

   function Trash_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result is
     (if Files.File_System.Trash.Is_Trash_Files_Directory (Files.Model.Current_Path (Model))
      then Disabled (Model, "error.trash.failed")
      else (Status => Operation_Success, others => <>));

   function Creation_Refusal
     (Model       : in out Files.Model.Window_Model;
      Failure_Key : String) return Operation_Result is
   begin
      if Files.Model.Selection.Includes_Temporary (Model) then
         return Disabled (Model, "error.create.pending");
      elsif Files.File_System.Trash.Is_Trash_Files_Directory (Files.Model.Current_Path (Model)) then
         return Disabled (Model, Failure_Key);
      end if;
      return (Status => Operation_Success, others => <>);
   end Creation_Refusal;

   function Start_At_Folder
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Directory_Path : String;
      Home_Path      : String)
      return Operation_Result
   is
      Load : constant Files.File_System.Directory_Load_Result := Load_Folder (Settings, Directory_Path);
   begin
      if not Load.Success then
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), Directory_Path);
      end if;
      Files.Model.Initialize
        (Model             => Model,
         Directory_Path    => To_String (Load.Path),
         Items             => Load.Items,
         Home_Path         => Home_Path,
         Default_View_Mode => Settings.Default_View);
      --  The signature Initialize derives from the items never matches the
      --  watch's: every startup folder was read again for nothing.
      Show_Loaded_Folder (Model, Load);
      return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
   end Start_At_Folder;

   procedure Settle_Current_Is_Trash
     (Model : in out Files.Model.Window_Model) is
   begin
      Files.Model.Set_Current_Is_Trash
        (Model, Files.File_System.Trash.Is_Trash_Files_Directory (Files.Model.Current_Path (Model)));
   end Settle_Current_Is_Trash;

end Files.Operations;
