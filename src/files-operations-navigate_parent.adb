separate (Files.Operations)
   function Navigate_Parent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Parent : constant String :=
        Files.File_System.Parent_Directory (Files.Model.Current_Path (Model));
   begin
      --  A filesystem root has no parent, so navigating up is a safe no-op.
      if Parent = "" then
         return Disabled (Model, "error.navigate.no_parent");
      end if;

      return Load_And_Navigate (Model, Settings, Parent);
   end Navigate_Parent;
