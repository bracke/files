separate (Files.Operations)
function Navigate_And_Select
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Path     : String)
   return Operation_Result
is
   Parent : constant String := Files.Fs_Primitives.Parent_Directory (Path);
begin
   if Parent = "" then
      return Make_Result (Operation_Disabled, Path => Path);
   end if;
   return Result : constant Operation_Result := Select_Root (Model, Settings, Parent) do
      if Result.Status = Operation_Navigated then
         declare
            --  An item gone since stays unselected; the folder still opens.
            Selected : constant Boolean :=
              Files.Model.Selection.Select_By_Name (Model, Files.Types.Leaf_Of (Path));
            pragma Unreferenced (Selected);
         begin
            null;
         end;
      end if;
   end return;
end Navigate_And_Select;
