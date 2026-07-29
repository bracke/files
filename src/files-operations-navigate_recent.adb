separate (Files.Operations)
   function Navigate_Recent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Recent : constant Files.Types.String_Vectors.Vector :=
        Files.Settings.Recent_Paths (Settings);
      Items  : Files.File_System.Item_Vectors.Vector;
   begin
      --  Stat each stored path in most-recent-first order, skipping any that no
      --  longer resolve so a stale entry silently drops from the view.
      for Path of Recent loop
         declare
            Loaded : constant Files.File_System.Item_Load_Result :=
              Files.File_System.Load_Item (To_String (Path), Settings);
         begin
            if Loaded.Success then
               Items.Append (Loaded.Item);
            end if;
         end;
      end loop;

      Files.Model.Navigate_Recent (Model, Items);
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Navigated);
   end Navigate_Recent;
