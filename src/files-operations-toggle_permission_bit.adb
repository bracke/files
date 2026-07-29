separate (Files.Operations)
   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
   begin
      if Bit > 8 or else not Permissions_Editable_Selection (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      declare
         Item     : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         Mask     : constant Natural := 2 ** (8 - Bit);
         New_Mode : constant Natural :=
           (if (Item.Mode_Bits / Mask) mod 2 = 1
            then Item.Mode_Bits - Mask
            else Item.Mode_Bits + Mask);
      begin
         return Set_Permissions_For (Model, New_Mode, Settings);
      end;
   end Toggle_Permission_Bit;
