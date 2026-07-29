separate (Files.Operations)
   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      Mapped : constant Files.Model.Sort_Field :=
        (case Settings.Sort_Field_Value is
            when Files.Settings.Sort_By_Name     => Files.Model.Sort_Name,
            when Files.Settings.Sort_By_Filetype => Files.Model.Sort_Type,
            when Files.Settings.Sort_By_Size     => Files.Model.Sort_Size,
            when Files.Settings.Sort_By_Created  => Files.Model.Sort_Created,
            when Files.Settings.Sort_By_Modified => Files.Model.Sort_Changed);
   begin
      Files.Model.Set_View_Mode (Model, Settings.Default_View);
      Files.Model.Apply_Sort (Model, Mapped, Settings.Sort_Ascending);
   end Apply_Ui_State;
