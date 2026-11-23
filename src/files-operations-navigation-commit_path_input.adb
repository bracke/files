with Files.Items;
with Files.File_System_Types;
with GNAT.OS_Lib;

separate (Files.Operations.Navigation)
function Commit_Path_Input
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Typed : constant String := Files.File_System.Expand_User_Path (Files.Model.Path_Input_Text (Model));
   --  A relative path is relative to the folder on screen, not to wherever
   --  the program was started.
   Path_Result : constant Files.File_System_Types.Path_Result :=
     Files.File_System.Normalize_Path
       (if Typed = "" or else GNAT.OS_Lib.Is_Absolute_Path (Typed) then Typed
        else Hostkit.Fs.Join (Files.Model.Current_Path (Model), Typed));
   Empty_Items : Files.Items.Item_Vectors.Vector;

   procedure Install
     (Model : in out Files.Model.Window_Model;
      Load  : Files.File_System.Directory_Load_Result) is
   begin
      Files.Model.Commit_Path_Input (Model, Path_Result, Load.Items);
   end Install;
begin
   if Path_Result.Status /= Files.File_System_Types.Path_Valid then
      Files.Model.Commit_Path_Input (Model, Path_Result, Empty_Items);
      Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
      return Make_Result (Operation_Failed, To_String (Path_Result.Error_Key));
   end if;
   return Support.Load_And_Show (Model, Settings, To_String (Path_Result.Directory_Path), Install'Access);
end Commit_Path_Input;
