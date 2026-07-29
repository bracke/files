separate (Files.Model)
   procedure Set_Settings_Draft
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
   end Set_Settings_Draft;
