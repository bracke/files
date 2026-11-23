with Files.File_System_Types;
with Files.Model.Root_Selector;
separate (Files.Operations.Navigation)
--  Shared normalize -> load -> navigate tail for the absolute-destination
--  navigations (Home, Parent, Trash, Select_Root). Path is the raw requested
--  path; on a normalize failure the error is reported against it, on a load
--  failure against the normalized path. Close_Selector closes the root selector
--  after a successful navigation (used only by Select_Root).
function Load_And_Navigate
  (Model          : in out Files.Model.Window_Model;
   Settings       : Files.Settings.Settings_Model;
   Path           : String;
   Close_Selector : Boolean := False)
   return Operation_Result
is
   Path_Result : constant Files.File_System_Types.Path_Result :=
     Files.File_System.Normalize_Path (Path);

   procedure Install
     (Model : in out Files.Model.Window_Model;
      Load  : Files.File_System.Directory_Load_Result) is
   begin
      Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
      if Close_Selector then
         Files.Model.Root_Selector.Close (Model);
      end if;
   end Install;
begin
   if Path_Result.Status /= Files.File_System_Types.Path_Valid then
      Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
      return Make_Result
        (Operation_Failed, To_String (Path_Result.Error_Key), Path);
   end if;
   return Support.Load_And_Show (Model, Settings, To_String (Path_Result.Directory_Path), Install'Access);
end Load_And_Navigate;
